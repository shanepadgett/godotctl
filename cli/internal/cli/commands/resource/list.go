package resourcecmd

import (
	"fmt"
	"strings"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func newListCommand(deps shared.Deps) *cobra.Command {
	var listPath string
	var listIncludeValues bool
	var listMaxProperties int
	var listTimeoutMS int

	listCmd := &cobra.Command{
		Use:     "list",
		Short:   "List deterministic resource properties",
		Example: "  godotctl resource list --path data/player.tres --include-values --max-properties 50",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(listPath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if listMaxProperties < 0 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--max-properties must be >= 0"))
			}

			callReq := client.ToolCallRequest{
				Tool: "resource.list",
				Args: map[string]any{
					"path":           listPath,
					"include_values": listIncludeValues,
					"max_properties": listMaxProperties,
				},
			}
			if listTimeoutMS > 0 {
				callReq.TimeoutMS = listTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "resource properties listed")
			resourcePath := shared.ToolResultDataString(resp.Result, "resource_path", strings.TrimSpace(listPath))
			count := shared.ToolResultDataInt(resp.Result, "count", 0)
			returnedCount := shared.ToolResultDataInt(resp.Result, "returned_count", 0)

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("resource list ok: %s (properties=%d returned=%d, request_id=%s)", resourcePath, count, returnedCount, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	listCmd.Flags().StringVar(&listPath, "path", "", "Resource path (project-relative)")
	listCmd.Flags().BoolVar(&listIncludeValues, "include-values", false, "Include serialized property values")
	listCmd.Flags().IntVar(&listMaxProperties, "max-properties", 200, "Max returned property rows (0 means no limit)")
	listCmd.Flags().IntVar(&listTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return listCmd
}
