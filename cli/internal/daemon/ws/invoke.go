package ws

import (
	"context"
	"errors"
	"fmt"
	"sync/atomic"
	"time"

	"github.com/shanepadgett/godotctl/internal/daemon/broker"
	"github.com/shanepadgett/godotctl/internal/protocol"
)

func (s *Server) InvokeTool(ctx context.Context, tool string, args map[string]any, timeout time.Duration) (InvokeResult, error) {
	conn := s.currentConn()
	if conn == nil {
		return InvokeResult{}, broker.New(protocol.BrokerErrorCodePluginDisconnected, "plugin is not connected", nil, "")
	}

	requestID := fmt.Sprintf("req_%d", atomic.AddUint64(&s.requestID, 1))
	pendingCh := make(chan pendingResult, 1)

	s.addPending(requestID, pendingCh)

	msg := toolInvokeMessage{
		Type: "tool_invoke",
		ID:   requestID,
		Tool: tool,
		Args: args,
	}
	if msg.Args == nil {
		msg.Args = map[string]any{}
	}
	if err := validateToolInvokeMessage(msg); err != nil {
		s.removePending(requestID)
		return InvokeResult{}, broker.New(protocol.BrokerErrorCodeValidation, "invalid tool invoke payload", err, requestID)
	}

	if err := s.writeJSON(conn, msg); err != nil {
		s.removePending(requestID)
		return InvokeResult{}, broker.New(protocol.BrokerErrorCodeOperationFailed, "send tool invoke", err, requestID)
	}

	timer := time.NewTimer(timeout)
	defer timer.Stop()

	select {
	case pending := <-pendingCh:
		if pending.err != nil {
			return InvokeResult{}, wrapPendingError(pending.err, requestID)
		}

		return InvokeResult{
			RequestID: pending.result.ID,
			OK:        pending.result.Ok,
			Result:    pending.result.Result,
			Error:     pending.result.Error,
			ErrorCode: pending.result.ErrorCode,
		}, nil
	case <-timer.C:
		s.removePending(requestID)
		return InvokeResult{}, broker.New(protocol.BrokerErrorCodeTimeout, "tool request timed out", nil, requestID)
	case <-ctx.Done():
		s.removePending(requestID)
		return InvokeResult{}, broker.New(protocol.BrokerErrorCodeCancelled, "tool request cancelled", ctx.Err(), requestID)
	}
}

func wrapPendingError(err error, requestID string) error {
	if err == nil {
		return broker.New(protocol.BrokerErrorCodeOperationFailed, "tool request failed", nil, requestID)
	}

	var brokerErr *broker.Error
	if errors.As(err, &brokerErr) {
		if brokerErr.RequestID == "" {
			brokerErr.RequestID = requestID
		}
		return brokerErr
	}

	return broker.New(protocol.BrokerErrorCodeOperationFailed, "tool request failed", err, requestID)
}
