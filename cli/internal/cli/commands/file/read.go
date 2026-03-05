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

func newReadCommand(deps shared.Deps) *cobra.Command {
	var readPath string
	var readTimeoutMS int

	readCmd := &cobra.Command{
		Use:     "read",
		Short:   "Read a project file as text",
		Example: "  godotctl file read --path scripts/player.gd",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(readPath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "file.read",
				Args: map[string]any{
					"path": readPath,
				},
			}
			if readTimeoutMS > 0 {
				callReq.TimeoutMS = readTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "file read")
			resolvedPath := shared.ToolResultDataString(resp.Result, "path", strings.TrimSpace(readPath))
			byteCount := shared.ToolResultDataInt(resp.Result, "byte_count", 0)

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("file read ok: %s (bytes=%d, request_id=%s)", resolvedPath, byteCount, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	readCmd.Flags().StringVar(&readPath, "path", "", "Path to read (project-relative)")
	readCmd.Flags().IntVar(&readTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return readCmd
}
