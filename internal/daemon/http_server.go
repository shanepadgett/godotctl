package daemon

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"
)

type httpServer struct {
	addr   string
	state  *connectionState
	ws     *wsServer
	server *http.Server
}

type toolCallRequest struct {
	Tool      string         `json:"tool"`
	Args      map[string]any `json:"args"`
	TimeoutMS int            `json:"timeout_ms,omitempty"`
}

type toolCallResponse struct {
	Ok        bool           `json:"ok"`
	Result    map[string]any `json:"result,omitempty"`
	Error     *toolCallError `json:"error,omitempty"`
	RequestID string         `json:"request_id,omitempty"`
}

type toolCallError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func newHTTPServer(addr string, state *connectionState, ws *wsServer) *httpServer {
	h := &httpServer{addr: addr, state: state, ws: ws}

	mux := http.NewServeMux()
	mux.HandleFunc("/status", h.handleStatus)
	mux.HandleFunc("/tools/list", h.handleToolsList)
	mux.HandleFunc("/daemon/stop", h.handleStop)
	mux.HandleFunc("/tools/call", h.handleToolCall)

	h.server = &http.Server{
		Addr:    addr,
		Handler: mux,
	}

	return h
}

func (h *httpServer) Start() error {
	err := h.server.ListenAndServe()
	if errors.Is(err, http.ErrServerClosed) {
		return nil
	}
	return err
}

func (h *httpServer) Shutdown() {
	ctx, cancel := contextWithTimeout(shutdownTimeout())
	defer cancel()
	_ = h.server.Shutdown(ctx)
}

func (h *httpServer) handleStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(h.state.Snapshot())
}

func (h *httpServer) handleToolsList(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(h.state.ToolsSnapshot())
}

func (h *httpServer) handleStop(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	ownerToken := r.URL.Query().Get("owner_token")
	stopped := true
	message := "daemon stopping"
	if ownerToken != "" {
		if h.state.OwnerToken() == ownerToken {
			h.state.Stop()
		} else {
			stopped = false
			message = "daemon not stopped: owner token mismatch"
		}
	} else {
		h.state.Stop()
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{"ok": true, "stopped": stopped, "message": message})
}

func (h *httpServer) handleToolCall(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	var req toolCallRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeToolError(w, http.StatusBadRequest, BrokerErrorCodeValidation, "invalid request body", "")
		return
	}

	if req.Tool == "" {
		h.writeToolError(w, http.StatusBadRequest, BrokerErrorCodeValidation, "tool is required", "")
		return
	}

	if req.Args == nil {
		req.Args = map[string]any{}
	}

	timeout := 5 * time.Second
	if req.TimeoutMS > 0 {
		timeout = time.Duration(req.TimeoutMS) * time.Millisecond
	}

	result, err := h.ws.InvokeTool(r.Context(), req.Tool, req.Args, timeout)
	if err != nil {
		code, message, requestID := brokerErrorDetails(err)
		h.writeToolError(w, statusForBrokerError(code), code, message, requestID)
		return
	}

	if !result.Ok {
		message := strings.TrimSpace(result.Error)
		if message == "" {
			message = "tool call failed"
		}
		h.writeToolError(w, http.StatusBadGateway, BrokerErrorCodeOperationFailed, message, result.ID)
		return
	}

	resp := toolCallResponse{
		Ok:        result.Ok,
		Result:    result.Result,
		RequestID: result.ID,
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}

func (h *httpServer) writeToolError(w http.ResponseWriter, status int, code BrokerErrorCode, message string, requestID string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(toolCallResponse{
		Ok: false,
		Error: &toolCallError{
			Code:    string(code),
			Message: message,
		},
		RequestID: requestID,
	})
}

func statusForBrokerError(code BrokerErrorCode) int {
	switch code {
	case BrokerErrorCodeValidation:
		return http.StatusBadRequest
	case BrokerErrorCodePluginDisconnected:
		return http.StatusServiceUnavailable
	case BrokerErrorCodeTimeout:
		return http.StatusGatewayTimeout
	case BrokerErrorCodeCancelled:
		return http.StatusRequestTimeout
	default:
		return http.StatusBadGateway
	}
}

func contextWithTimeout(timeout time.Duration) (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), timeout)
}
