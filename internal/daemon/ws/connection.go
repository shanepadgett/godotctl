package ws

import (
	"github.com/gorilla/websocket"
	"github.com/shanepadgett/godotctl/internal/daemon/broker"
	"github.com/shanepadgett/godotctl/internal/protocol"
)

func (s *Server) setActiveConn(conn *websocket.Conn) {
	s.connMu.Lock()
	defer s.connMu.Unlock()

	if s.conn != nil {
		_ = s.conn.Close()
	}
	s.conn = conn
}

func (s *Server) clearActiveConn(conn *websocket.Conn) {
	s.connMu.Lock()
	defer s.connMu.Unlock()

	if s.conn == conn {
		s.conn = nil
		s.state.SetDisconnected()
		s.failAllPending(broker.New(protocol.BrokerErrorCodePluginDisconnected, "plugin disconnected", nil, ""))
	}
}

func (s *Server) currentConn() *websocket.Conn {
	s.connMu.Lock()
	defer s.connMu.Unlock()
	return s.conn
}

func (s *Server) writeJSON(conn *websocket.Conn, v any) error {
	s.writeMu.Lock()
	defer s.writeMu.Unlock()
	return conn.WriteJSON(v)
}
