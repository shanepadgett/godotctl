package daemon

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gorilla/websocket"
)

type wsServer struct {
	addr     string
	state    *connectionState
	server   *http.Server
	upgrader websocket.Upgrader

	connMu    sync.Mutex
	writeMu   sync.Mutex
	conn      *websocket.Conn
	pending   map[string]chan pendingResult
	pendingMu sync.Mutex
	requestID uint64
}

type wsMessage struct {
	Type       string   `json:"type"`
	Project    string   `json:"project,omitempty"`
	Tools      []string `json:"tools,omitempty"`
	OwnerToken string   `json:"owner_token,omitempty"`
}

type toolInvokeMessage struct {
	Type string         `json:"type"`
	ID   string         `json:"id"`
	Tool string         `json:"tool"`
	Args map[string]any `json:"args"`
}

type toolResultMessage struct {
	Type   string         `json:"type"`
	ID     string         `json:"id"`
	Ok     bool           `json:"ok"`
	Result map[string]any `json:"result,omitempty"`
	Error  string         `json:"error,omitempty"`
}

type pendingResult struct {
	result toolResultMessage
	err    error
}

func newWSServer(addr string, state *connectionState) *wsServer {
	s := &wsServer{
		addr:    addr,
		state:   state,
		pending: make(map[string]chan pendingResult),
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool { return true },
		},
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/ws", s.handleWS)

	s.server = &http.Server{
		Addr:    addr,
		Handler: mux,
	}

	return s
}

func (s *wsServer) InvokeTool(ctx context.Context, tool string, args map[string]any, timeout time.Duration) (toolResultMessage, error) {
	conn := s.currentConn()
	if conn == nil {
		return toolResultMessage{}, newBrokerError(BrokerErrorCodePluginDisconnected, "plugin is not connected", nil, "")
	}

	requestID := fmt.Sprintf("req_%d", atomic.AddUint64(&s.requestID, 1))
	pendingCh := make(chan pendingResult, 1)

	s.addPending(requestID, pendingCh)

	msg := toolInvokeMessage{
		Type: "tool_invoke",
		ID:   requestID,
		Tool: tool,
		Args: args,
	}
	if msg.Args == nil {
		msg.Args = map[string]any{}
	}
	if err := validateToolInvokeMessage(msg); err != nil {
		s.removePending(requestID)
		return toolResultMessage{}, newBrokerError(BrokerErrorCodeValidation, "invalid tool invoke payload", err, requestID)
	}

	if err := s.writeJSON(conn, msg); err != nil {
		s.removePending(requestID)
		return toolResultMessage{}, newBrokerError(BrokerErrorCodeOperationFailed, "send tool invoke", err, requestID)
	}

	timer := time.NewTimer(timeout)
	defer timer.Stop()

	select {
	case result := <-pendingCh:
		if result.err != nil {
			return toolResultMessage{}, wrapPendingError(result.err, requestID)
		}
		return result.result, nil
	case <-timer.C:
		s.removePending(requestID)
		return toolResultMessage{}, newBrokerError(BrokerErrorCodeTimeout, "tool request timed out", nil, requestID)
	case <-ctx.Done():
		s.removePending(requestID)
		return toolResultMessage{}, newBrokerError(BrokerErrorCodeCancelled, "tool request cancelled", ctx.Err(), requestID)
	}
}

func (s *wsServer) Start() error {
	err := s.server.ListenAndServe()
	if errors.Is(err, http.ErrServerClosed) {
		return nil
	}
	return err
}

func (s *wsServer) Shutdown() {
	ctx, cancel := contextWithTimeout(shutdownTimeout())
	defer cancel()
	_ = s.server.Shutdown(ctx)

	s.connMu.Lock()
	defer s.connMu.Unlock()
	if s.conn != nil {
		_ = s.conn.Close()
		s.conn = nil
	}
	s.state.SetDisconnected()
	s.failAllPending(newBrokerError(BrokerErrorCodeOperationFailed, "daemon shutting down", nil, ""))
}

func (s *wsServer) handleWS(w http.ResponseWriter, r *http.Request) {
	conn, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("ws upgrade failed: %v", err)
		return
	}

	s.setActiveConn(conn)
	defer s.clearActiveConn(conn)

	conn.SetPongHandler(func(appData string) error {
		return conn.SetReadDeadline(time.Now().Add(30 * time.Second))
	})

	if err := conn.SetReadDeadline(time.Now().Add(30 * time.Second)); err != nil {
		log.Printf("ws set read deadline failed: %v", err)
	}

	for {
		frameType, payload, err := conn.ReadMessage()
		if err != nil {
			log.Printf("ws read ended: %v", err)
			return
		}
		if frameType != websocket.TextMessage {
			continue
		}

		var msgType wsMessage
		if err := json.Unmarshal(payload, &msgType); err != nil {
			log.Printf("ws invalid json: %v", err)
			continue
		}

		messageType := strings.TrimSpace(msgType.Type)
		switch messageType {
		case "hello":
			var msg wsMessage
			if err := json.Unmarshal(payload, &msg); err != nil {
				log.Printf("ws invalid hello json: %v", err)
				continue
			}
			if err := validateHelloMessage(msg); err != nil {
				log.Printf("ws invalid hello message: %v", err)
				continue
			}
			s.state.SetConnected(msg.Project, normalizeTools(msg.Tools))
			log.Printf("plugin connected (project=%s)", msg.Project)
			_ = s.writeJSON(conn, wsMessage{Type: "welcome", OwnerToken: s.state.OwnerToken()})
		case "ping":
			_ = s.writeJSON(conn, wsMessage{Type: "pong"})
		case "tool_result":
			var msg toolResultMessage
			if err := json.Unmarshal(payload, &msg); err != nil {
				log.Printf("ws invalid tool_result json: %v", err)
				continue
			}
			if err := validateToolResultMessage(msg); err != nil {
				log.Printf("ws invalid tool_result message: %v", err)
				continue
			}
			s.completePending(msg)
		default:
			log.Printf("ws unknown message type: %q", messageType)
		}
	}
}

func validateHelloMessage(msg wsMessage) error {
	if strings.TrimSpace(msg.Type) != "hello" {
		return fmt.Errorf("type must be hello")
	}

	for i, tool := range msg.Tools {
		if strings.TrimSpace(tool) == "" {
			return fmt.Errorf("tools[%d] must be non-empty", i)
		}
	}

	return nil
}

func validateToolInvokeMessage(msg toolInvokeMessage) error {
	if strings.TrimSpace(msg.Type) != "tool_invoke" {
		return fmt.Errorf("type must be tool_invoke")
	}
	if strings.TrimSpace(msg.ID) == "" {
		return fmt.Errorf("id is required")
	}
	if strings.TrimSpace(msg.Tool) == "" {
		return fmt.Errorf("tool is required")
	}
	if msg.Args == nil {
		return fmt.Errorf("args is required")
	}

	return nil
}

func validateToolResultMessage(msg toolResultMessage) error {
	if strings.TrimSpace(msg.Type) != "tool_result" {
		return fmt.Errorf("type must be tool_result")
	}
	if strings.TrimSpace(msg.ID) == "" {
		return fmt.Errorf("id is required")
	}

	hasResult := msg.Result != nil
	hasError := strings.TrimSpace(msg.Error) != ""

	if msg.Ok {
		if !hasResult {
			return fmt.Errorf("result is required when ok=true")
		}
		if hasError {
			return fmt.Errorf("error must be empty when ok=true")
		}
		return nil
	}

	if !hasError {
		return fmt.Errorf("error is required when ok=false")
	}
	if hasResult {
		return fmt.Errorf("result must be empty when ok=false")
	}

	return nil
}

func normalizeTools(tools []string) []string {
	if len(tools) == 0 {
		return []string{"ping"}
	}

	normalized := make([]string, 0, len(tools))
	seen := make(map[string]struct{}, len(tools))
	for _, tool := range tools {
		name := strings.TrimSpace(tool)
		if name == "" {
			continue
		}
		if _, ok := seen[name]; ok {
			continue
		}
		seen[name] = struct{}{}
		normalized = append(normalized, name)
	}

	if len(normalized) == 0 {
		return []string{"ping"}
	}

	return normalized
}

func (s *wsServer) setActiveConn(conn *websocket.Conn) {
	s.connMu.Lock()
	defer s.connMu.Unlock()

	if s.conn != nil {
		_ = s.conn.Close()
	}
	s.conn = conn
}

func (s *wsServer) clearActiveConn(conn *websocket.Conn) {
	s.connMu.Lock()
	defer s.connMu.Unlock()

	if s.conn == conn {
		s.conn = nil
		s.state.SetDisconnected()
		s.failAllPending(newBrokerError(BrokerErrorCodePluginDisconnected, "plugin disconnected", nil, ""))
	}
}

func (s *wsServer) currentConn() *websocket.Conn {
	s.connMu.Lock()
	defer s.connMu.Unlock()
	return s.conn
}

func (s *wsServer) writeJSON(conn *websocket.Conn, v any) error {
	s.writeMu.Lock()
	defer s.writeMu.Unlock()
	return conn.WriteJSON(v)
}

func (s *wsServer) completePending(msg toolResultMessage) {
	ch, ok := s.removePending(msg.ID)
	if ok {
		ch <- pendingResult{result: msg}
	}
}

func (s *wsServer) addPending(requestID string, ch chan pendingResult) {
	s.pendingMu.Lock()
	defer s.pendingMu.Unlock()

	s.pending[requestID] = ch
	s.state.SetPendingRequests(len(s.pending))
}

func (s *wsServer) removePending(requestID string) (chan pendingResult, bool) {
	s.pendingMu.Lock()
	defer s.pendingMu.Unlock()

	ch, ok := s.pending[requestID]
	if ok {
		delete(s.pending, requestID)
		s.state.SetPendingRequests(len(s.pending))
	}

	return ch, ok
}

func wrapPendingError(err error, requestID string) error {
	if err == nil {
		return newBrokerError(BrokerErrorCodeOperationFailed, "tool request failed", nil, requestID)
	}

	var brokerErr *BrokerError
	if errors.As(err, &brokerErr) {
		if brokerErr.RequestID == "" {
			brokerErr.RequestID = requestID
		}
		return brokerErr
	}

	return newBrokerError(BrokerErrorCodeOperationFailed, "tool request failed", err, requestID)
}

func (s *wsServer) failAllPending(err error) {
	s.pendingMu.Lock()
	defer s.pendingMu.Unlock()

	for id, ch := range s.pending {
		delete(s.pending, id)
		ch <- pendingResult{err: err}
	}
	s.state.SetPendingRequests(0)
}
