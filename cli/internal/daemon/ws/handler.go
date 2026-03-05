package ws

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gorilla/websocket"
)

func (s *Server) handleWS(w http.ResponseWriter, r *http.Request) {
	conn, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("ws upgrade failed: %v", err)
		return
	}

	s.setActiveConn(conn)
	defer s.clearActiveConn(conn)

	conn.SetPongHandler(func(string) error {
		return nil
	})

	if err := conn.SetReadDeadline(time.Time{}); err != nil {
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
