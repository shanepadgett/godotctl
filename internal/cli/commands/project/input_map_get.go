package projectcmd

import (
	"fmt"
	"strings"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func newInputMapGetCommand(deps shared.Deps) *cobra.Command {
	var inputAction string
	var inputTimeoutMS int

	inputMapGetCmd := &cobra.Command{
		Use:     "get",
		Short:   "Get input map actions and events",
		Example: "  godotctl project input-map get --action ui_accept",
		RunE: func(cmd *cobra.Command, _ []string) error {
			callReq := client.ToolCallRequest{
				Tool: "project.input_map_get",
				Args: map[string]any{
					"action": inputAction,
				},
			}
			if inputTimeoutMS > 0 {
				callReq.TimeoutMS = inputTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "project input map retrieved")
			requestedAction := shared.ToolResultDataString(resp.Result, "requested_action", strings.TrimSpace(inputAction))
			actionCount := shared.ToolResultDataInt(resp.Result, "count", 0)
			totalEventCount := shared.ToolResultDataInt(resp.Result, "total_event_count", 0)

			text := fmt.Sprintf("project input-map get ok: actions=%d events=%d (request_id=%s)", actionCount, totalEventCount, resp.RequestID)
			if requestedAction != "" {
				text = fmt.Sprintf("project input-map get ok: %s (events=%d, request_id=%s)", requestedAction, totalEventCount, resp.RequestID)
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

	inputMapGetCmd.Flags().StringVar(&inputAction, "action", "", "Optional input action name")
	inputMapGetCmd.Flags().IntVar(&inputTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return inputMapGetCmd
}
