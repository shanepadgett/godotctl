package client

import (
	"strings"

	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
	"github.com/shanepadgett/godotctl/internal/protocol"
)

func classifyToolError(toolErr *protocol.ToolCallError, fallback string) error {
	msg := ""
	code := ""
	toolCode := ""
	if toolErr != nil {
		msg = strings.TrimSpace(toolErr.Message)
		code = strings.TrimSpace(toolErr.Code)
		toolCode = strings.TrimSpace(toolErr.ToolCode)
	}

	if msg == "" {
		msg = fallback
	}

	newToolErr := func(kind clierrors.Kind, message string) error {
		return clierrors.NewTool(kind, message, toolCode)
	}

	switch code {
	case string(protocol.BrokerErrorCodeValidation):
		return newToolErr(clierrors.KindValidation, msg)
	case string(protocol.BrokerErrorCodePluginDisconnected):
		return newToolErr(clierrors.KindPluginDisconnected, msg)
	case string(protocol.BrokerErrorCodeTimeout), string(protocol.BrokerErrorCodeCancelled), string(protocol.BrokerErrorCodeOperationFailed):
		if toolCode == "INVALID_ARGS" {
			return newToolErr(clierrors.KindValidation, msg)
		}
		return newToolErr(clierrors.KindOperationFailed, msg)
	}

	lower := strings.ToLower(msg)
	if strings.Contains(lower, "plugin is not connected") {
		return newToolErr(clierrors.KindPluginDisconnected, msg)
	}

	if strings.Contains(lower, "daemon is unavailable") {
		return newToolErr(clierrors.KindDaemonUnavailable, msg)
	}

	if toolCode == "INVALID_ARGS" {
		return newToolErr(clierrors.KindValidation, msg)
	}

	return newToolErr(clierrors.KindOperationFailed, msg)
}
