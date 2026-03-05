package filecmd

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
	var listRecursive bool
	var listTimeoutMS int

	listCmd := &cobra.Command{
		Use:     "list",
		Short:   "List project files and directories",
		Example: "  godotctl file list --path scripts --recursive",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(listPath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "file.list",
				Args: map[string]any{
					"path":      listPath,
					"recursive": listRecursive,
				},
			}
			if listTimeoutMS > 0 {
				callReq.TimeoutMS = listTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "file list retrieved")
			resolvedPath := shared.ToolResultDataString(resp.Result, "path", strings.TrimSpace(listPath))
			count := shared.ToolResultDataInt(resp.Result, "count", 0)

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("file list ok: %s (entries=%d, recursive=%t, request_id=%s)", resolvedPath, count, listRecursive, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	listCmd.Flags().StringVar(&listPath, "path", "", "Path to list (project-relative)")
	listCmd.Flags().BoolVar(&listRecursive, "recursive", false, "List recursively")
	listCmd.Flags().IntVar(&listTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return listCmd
}
