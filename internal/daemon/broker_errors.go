package daemon

import (
	"errors"
	"fmt"
	"strings"
)

type BrokerErrorCode string

const (
	BrokerErrorCodeValidation         BrokerErrorCode = "validation_error"
	BrokerErrorCodePluginDisconnected BrokerErrorCode = "plugin_disconnected"
	BrokerErrorCodeTimeout            BrokerErrorCode = "timeout"
	BrokerErrorCodeCancelled          BrokerErrorCode = "cancelled"
	BrokerErrorCodeOperationFailed    BrokerErrorCode = "operation_failed"
)

type BrokerError struct {
	Code      BrokerErrorCode
	Message   string
	Err       error
	RequestID string
}

func (e *BrokerError) Error() string {
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

func (e *BrokerError) Unwrap() error {
	if e == nil {
		return nil
	}
	return e.Err
}

func newBrokerError(code BrokerErrorCode, message string, err error, requestID string) error {
	return &BrokerError{Code: code, Message: strings.TrimSpace(message), Err: err, RequestID: requestID}
}

func brokerErrorDetails(err error) (BrokerErrorCode, string, string) {
	var brokerErr *BrokerError
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
			code = BrokerErrorCodeOperationFailed
		}

		return code, message, brokerErr.RequestID
	}

	message := strings.TrimSpace(err.Error())
	if message == "" {
		message = "tool call failed"
	}

	return BrokerErrorCodeOperationFailed, message, ""
}
