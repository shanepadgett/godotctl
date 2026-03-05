package httpserver

import (
	"encoding/json"
	"net/http"
)

func (h *Server) handleStop(w http.ResponseWriter, r *http.Request) {
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
