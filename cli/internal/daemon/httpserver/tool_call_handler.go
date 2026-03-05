package httpserver

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/shanepadgett/godotctl/internal/daemon/broker"
	"github.com/shanepadgett/godotctl/internal/protocol"
)

func (h *Server) handleToolCall(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	var req protocol.ToolCallRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.writeToolError(w, http.StatusBadRequest, protocol.BrokerErrorCodeValidation, "invalid request body", "", "")
		return
	}

	if req.Tool == "" {
		h.writeToolError(w, http.StatusBadRequest, protocol.BrokerErrorCodeValidation, "tool is required", "", "")
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
		code, message, requestID := broker.Details(err)
		h.writeToolError(w, statusForBrokerError(code), code, message, requestID, "")
		return
	}

	if !result.OK {
		message := strings.TrimSpace(result.Error)
		if message == "" {
			message = "tool call failed"
		}
		h.writeToolError(w, http.StatusBadGateway, protocol.BrokerErrorCodeOperationFailed, message, result.RequestID, strings.TrimSpace(result.ErrorCode))
		return
	}

	resp := protocol.ToolCallResponse{
		OK:        result.OK,
		Result:    result.Result,
		RequestID: result.RequestID,
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}
