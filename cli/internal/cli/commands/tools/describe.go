package toolscmd

import (
	"fmt"
	"strings"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func newDescribeCommand(deps shared.Deps) *cobra.Command {
	var describeTool string
	var describeTimeoutMS int

	describeCmd := &cobra.Command{
		Use:     "describe",
		Short:   "Describe available tool schemas",
		Example: "  godotctl tools describe --tool scene.create",
		RunE: func(cmd *cobra.Command, _ []string) error {
			callReq := client.ToolCallRequest{
				Tool: "tools.describe",
				Args: map[string]any{
					"tool": describeTool,
				},
			}
			if describeTimeoutMS > 0 {
				callReq.TimeoutMS = describeTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "tool schemas described")
			requestedTool := shared.ToolResultDataString(resp.Result, "requested_tool", strings.TrimSpace(describeTool))
			count := shared.ToolResultDataInt(resp.Result, "count", 0)

			text := fmt.Sprintf("tools describe ok: tools=%d (request_id=%s)", count, resp.RequestID)
			if requestedTool != "" {
				text = fmt.Sprintf("tools describe ok: %s (request_id=%s)", requestedTool, resp.RequestID)
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

	describeCmd.Flags().StringVar(&describeTool, "tool", "", "Optional tool name filter")
	describeCmd.Flags().IntVar(&describeTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return describeCmd
}
