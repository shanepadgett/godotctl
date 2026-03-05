package toolscmd

import (
	"fmt"
	"strings"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func newPingCommand(deps shared.Deps) *cobra.Command {
	return &cobra.Command{
		Use:   "ping",
		Short: "Send a minimal ping tool request",
		RunE: func(cmd *cobra.Command, _ []string) error {
			response, err := deps.Client.CallTool(cmd.Context(), client.ToolCallRequest{
				Tool:      "ping",
				Args:      map[string]any{},
				TimeoutMS: 3000,
			})
			if err != nil {
				return deps.Fail(cmd, err)
			}

			message := "pong"
			if msg, ok := response.Result["message"].(string); ok && strings.TrimSpace(msg) != "" {
				message = strings.TrimSpace(msg)
			}

			if data, ok := response.Result["data"].(map[string]any); ok {
				if msg, ok := data["message"].(string); ok && strings.TrimSpace(msg) != "" {
					message = strings.TrimSpace(msg)
				}
			}

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("tools ping ok: %s (request_id=%s)", message, response.RequestID),
				Data: map[string]any{
					"request_id": response.RequestID,
					"message":    message,
					"result":     response.Result,
				},
			})
		},
	}
}
