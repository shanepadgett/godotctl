package httpserver

import (
	"context"
	"errors"
	"net/http"

	daemonstate "github.com/shanepadgett/godotctl/internal/daemon/state"
	"github.com/shanepadgett/godotctl/internal/daemon/ws"
)

type Server struct {
	addr   string
	state  *daemonstate.Store
	ws     *ws.Server
	server *http.Server
}

func New(addr string, state *daemonstate.Store, wsServer *ws.Server) *Server {
	h := &Server{addr: addr, state: state, ws: wsServer}

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

func (h *Server) Start() error {
	err := h.server.ListenAndServe()
	if errors.Is(err, http.ErrServerClosed) {
		return nil
	}
	return err
}

func (h *Server) Shutdown() {
	ctx, cancel := context.WithTimeout(context.Background(), daemonstate.ShutdownTimeout())
	defer cancel()
	_ = h.server.Shutdown(ctx)
}
