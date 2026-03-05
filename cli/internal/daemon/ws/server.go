package ws

import (
	"context"
	"errors"
	"net/http"
	"sync"

	"github.com/gorilla/websocket"
	"github.com/shanepadgett/godotctl/internal/daemon/broker"
	daemonstate "github.com/shanepadgett/godotctl/internal/daemon/state"
	"github.com/shanepadgett/godotctl/internal/protocol"
)

type Server struct {
	addr     string
	state    *daemonstate.Store
	server   *http.Server
	upgrader websocket.Upgrader

	connMu    sync.Mutex
	writeMu   sync.Mutex
	conn      *websocket.Conn
	pending   map[string]chan pendingResult
	pendingMu sync.Mutex
	requestID uint64
}

func New(addr string, state *daemonstate.Store) *Server {
	s := &Server{
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

func (s *Server) Start() error {
	err := s.server.ListenAndServe()
	if errors.Is(err, http.ErrServerClosed) {
		return nil
	}
	return err
}

func (s *Server) Shutdown() {
	ctx, cancel := context.WithTimeout(context.Background(), daemonstate.ShutdownTimeout())
	defer cancel()
	_ = s.server.Shutdown(ctx)

	s.connMu.Lock()
	defer s.connMu.Unlock()
	if s.conn != nil {
		_ = s.conn.Close()
		s.conn = nil
	}
	s.state.SetDisconnected()
	s.failAllPending(broker.New(protocol.BrokerErrorCodeOperationFailed, "daemon shutting down", nil, ""))
}
