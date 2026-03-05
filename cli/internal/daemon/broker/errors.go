package broker

import (
	"errors"
	"fmt"
	"strings"

	"github.com/shanepadgett/godotctl/internal/protocol"
)

type Error struct {
	Code      protocol.BrokerErrorCode
	Message   string
	Err       error
	RequestID string
}

func (e *Error) Error() string {
	if e == nil {
		return ""
	}

	if e.Message == "" && e.Err == nil {
		return string(e.Code)
	}
	if e.Message == "" {
		return e.Err.Error()
	}
	if e.Err == nil {
		return e.Message
	}
	return fmt.Sprintf("%s: %v", e.Message, e.Err)
}

func (e *Error) Unwrap() error {
	if e == nil {
		return nil
	}
	return e.Err
}

func New(code protocol.BrokerErrorCode, message string, err error, requestID string) error {
	return &Error{Code: code, Message: strings.TrimSpace(message), Err: err, RequestID: requestID}
}

func Details(err error) (protocol.BrokerErrorCode, string, string) {
	var brokerErr *Error
	if errors.As(err, &brokerErr) {
		message := strings.TrimSpace(brokerErr.Message)
		if message == "" {
			message = strings.TrimSpace(err.Error())
		}
		if message == "" {
			message = "tool call failed"
		}

		code := brokerErr.Code
		if code == "" {
			code = protocol.BrokerErrorCodeOperationFailed
		}

		return code, message, brokerErr.RequestID
	}

	message := strings.TrimSpace(err.Error())
	if message == "" {
		message = "tool call failed"
	}

	return protocol.BrokerErrorCodeOperationFailed, message, ""
}
