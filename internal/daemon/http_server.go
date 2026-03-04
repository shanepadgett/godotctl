package daemon

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
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
	Error     string         `json:"error,omitempty"`
	RequestID string         `json:"request_id,omitempty"`
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

	h.state.Stop()
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{"ok": true, "message": "daemon stopping"})
}

func (h *httpServer) handleToolCall(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	var req toolCallRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		_ = json.NewEncoder(w).Encode(toolCallResponse{Ok: false, Error: "invalid request body"})
		return
	}

	if req.Tool == "" {
		w.WriteHeader(http.StatusBadRequest)
		_ = json.NewEncoder(w).Encode(toolCallResponse{Ok: false, Error: "tool is required"})
		return
	}

	if req.Args == nil {
		req.Args = map[string]any{}
	}

	timeout := 5 * time.Second
	if req.TimeoutMS > 0 {
		timeout = time.Duration(req.TimeoutMS) * time.Millisecond
	}

	result, err := h.ws.InvokeTool(req.Tool, req.Args, timeout)
	if err != nil {
		w.WriteHeader(http.StatusBadGateway)
		_ = json.NewEncoder(w).Encode(toolCallResponse{Ok: false, Error: err.Error()})
		return
	}

	resp := toolCallResponse{
		Ok:        result.Ok,
		Result:    result.Result,
		Error:     result.Error,
		RequestID: result.ID,
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}

func contextWithTimeout(timeout time.Duration) (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), timeout)
}
