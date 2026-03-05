package projectcmd

import (
	"fmt"
	"strings"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func newSettingsGetCommand(deps shared.Deps) *cobra.Command {
	var settingsKey string
	var settingsTimeoutMS int

	settingsGetCmd := &cobra.Command{
		Use:     "get",
		Short:   "Get project settings",
		Example: "  godotctl project settings get --key application/config/name",
		RunE: func(cmd *cobra.Command, _ []string) error {
			callReq := client.ToolCallRequest{
				Tool: "project.settings_get",
				Args: map[string]any{
					"key": settingsKey,
				},
			}
			if settingsTimeoutMS > 0 {
				callReq.TimeoutMS = settingsTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "project settings retrieved")
			requestedKey := shared.ToolResultDataString(resp.Result, "requested_key", strings.TrimSpace(settingsKey))
			count := shared.ToolResultDataInt(resp.Result, "count", 0)

			text := fmt.Sprintf("project settings get ok: settings=%d (request_id=%s)", count, resp.RequestID)
			if requestedKey != "" {
				text = fmt.Sprintf("project settings get ok: %s (request_id=%s)", requestedKey, resp.RequestID)
			}

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    text,
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	settingsGetCmd.Flags().StringVar(&settingsKey, "key", "", "Optional project setting key")
	settingsGetCmd.Flags().IntVar(&settingsTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return settingsGetCmd
}
