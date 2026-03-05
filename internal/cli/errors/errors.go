package clierrors

import (
	"errors"
	"fmt"
	"strings"
)

const (
	CodeSuccess            = 0
	CodeValidationError    = 1
	CodeDaemonUnavailable  = 2
	CodePluginDisconnected = 3
	CodeOperationFailed    = 4
)

type Kind string

const (
	KindValidation         Kind = "validation_error"
	KindDaemonUnavailable  Kind = "daemon_unavailable"
	KindPluginDisconnected Kind = "plugin_disconnected"
	KindOperationFailed    Kind = "operation_failed"
)

type Error struct {
	Kind     Kind
	Message  string
	Err      error
	ToolCode string
}

func (e *Error) Error() string {
	if e.Message == "" && e.Err == nil {
		return string(e.Kind)
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
	return e.Err
}

func New(kind Kind, message string) error {
	return &Error{Kind: kind, Message: message}
}

func NewTool(kind Kind, message string, toolCode string) error {
	return &Error{Kind: kind, Message: message, ToolCode: strings.TrimSpace(toolCode)}
}

func Wrap(kind Kind, message string, err error) error {
	return &Error{Kind: kind, Message: message, Err: err}
}

func ToolCodeOf(err error) string {
	if err == nil {
		return ""
	}

	var typed *Error
	if errors.As(err, &typed) {
		return strings.TrimSpace(typed.ToolCode)
	}

	return ""
}

func KindOf(err error) Kind {
	if err == nil {
		return ""
	}

	var typed *Error
	if errors.As(err, &typed) {
		return typed.Kind
	}

	if looksLikeValidationError(err.Error()) {
		return KindValidation
	}

	return KindOperationFailed
}

func ExitCode(err error) int {
	if err == nil {
		return CodeSuccess
	}

	switch KindOf(err) {
	case KindValidation:
		return CodeValidationError
	case KindDaemonUnavailable:
		return CodeDaemonUnavailable
	case KindPluginDisconnected:
		return CodePluginDisconnected
	default:
		return CodeOperationFailed
	}
}

func looksLikeValidationError(message string) bool {
	lower := strings.ToLower(strings.TrimSpace(message))
	if lower == "" {
		return false
	}

	validationPatterns := []string{
		"unknown command",
		"unknown flag",
		"required flag",
		"accepts",
		"requires",
		"invalid argument",
		"invalid value",
		"must be",
	}

	for _, pattern := range validationPatterns {
		if strings.Contains(lower, pattern) {
			return true
		}
	}

	return false
}
