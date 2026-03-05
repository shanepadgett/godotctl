package httpserver

import (
	"encoding/json"
	"net/http"

	"github.com/shanepadgett/godotctl/internal/protocol"
)

func (h *Server) writeToolError(w http.ResponseWriter, status int, code protocol.BrokerErrorCode, message string, requestID string, toolCode string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(protocol.ToolCallResponse{
		OK: false,
		Error: &protocol.ToolCallError{
			Code:     string(code),
			Message:  message,
			ToolCode: toolCode,
		},
		RequestID: requestID,
	})
}

func statusForBrokerError(code protocol.BrokerErrorCode) int {
	switch code {
	case protocol.BrokerErrorCodeValidation:
		return http.StatusBadRequest
	case protocol.BrokerErrorCodePluginDisconnected:
		return http.StatusServiceUnavailable
	case protocol.BrokerErrorCodeTimeout:
		return http.StatusGatewayTimeout
	case protocol.BrokerErrorCodeCancelled:
		return http.StatusRequestTimeout
	default:
		return http.StatusBadGateway
	}
}
