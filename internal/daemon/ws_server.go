package daemon

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
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
	Type    string `json:"type"`
	Project string `json:"project,omitempty"`
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

func (s *wsServer) InvokeTool(tool string, args map[string]any, timeout time.Duration) (toolResultMessage, error) {
	conn := s.currentConn()
	if conn == nil {
		return toolResultMessage{}, fmt.Errorf("plugin is not connected")
	}

	requestID := fmt.Sprintf("req_%d", atomic.AddUint64(&s.requestID, 1))
	pendingCh := make(chan pendingResult, 1)

	s.pendingMu.Lock()
	s.pending[requestID] = pendingCh
	s.pendingMu.Unlock()

	msg := toolInvokeMessage{
		Type: "tool_invoke",
		ID:   requestID,
		Tool: tool,
		Args: args,
	}

	if err := s.writeJSON(conn, msg); err != nil {
		s.pendingMu.Lock()
		delete(s.pending, requestID)
		s.pendingMu.Unlock()
		return toolResultMessage{}, fmt.Errorf("send tool invoke: %w", err)
	}

	select {
	case result := <-pendingCh:
		if result.err != nil {
			return toolResultMessage{}, result.err
		}
		return result.result, nil
	case <-time.After(timeout):
		s.pendingMu.Lock()
		delete(s.pending, requestID)
		s.pendingMu.Unlock()
		return toolResultMessage{}, fmt.Errorf("tool request timed out")
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
	s.failAllPending(fmt.Errorf("daemon shutting down"))
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
		messageType, payload, err := conn.ReadMessage()
		if err != nil {
			log.Printf("ws read ended: %v", err)
			return
		}
		if messageType != websocket.TextMessage {
			continue
		}

		var msgType wsMessage
		if err := json.Unmarshal(payload, &msgType); err != nil {
			log.Printf("ws invalid json: %v", err)
			continue
		}

		switch msgType.Type {
		case "hello":
			var msg wsMessage
			if err := json.Unmarshal(payload, &msg); err != nil {
				continue
			}
			s.state.SetConnected(msg.Project)
			log.Printf("plugin connected (project=%s)", msg.Project)
			_ = s.writeJSON(conn, wsMessage{Type: "welcome"})
		case "ping":
			_ = s.writeJSON(conn, wsMessage{Type: "pong"})
		case "tool_result":
			var msg toolResultMessage
			if err := json.Unmarshal(payload, &msg); err != nil {
				log.Printf("ws invalid tool_result json: %v", err)
				continue
			}
			s.completePending(msg)
		}
	}
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
		s.failAllPending(fmt.Errorf("plugin disconnected"))
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
	s.pendingMu.Lock()
	ch, ok := s.pending[msg.ID]
	if ok {
		delete(s.pending, msg.ID)
	}
	s.pendingMu.Unlock()

	if ok {
		ch <- pendingResult{result: msg}
	}
}

func (s *wsServer) failAllPending(err error) {
	s.pendingMu.Lock()
	defer s.pendingMu.Unlock()

	for id, ch := range s.pending {
		delete(s.pending, id)
		ch <- pendingResult{err: err}
	}
}
