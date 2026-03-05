package app

import (
	"fmt"
	"strings"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func (a *App) newFileCommand() *cobra.Command {
	fileCmd := &cobra.Command{
		Use:   "file",
		Short: "File operations through the daemon",
	}

	var listPath string
	var listRecursive bool
	var listTimeoutMS int

	listCmd := &cobra.Command{
		Use:     "list",
		Short:   "List project files and directories",
		Example: "  godotctl file list --path scripts --recursive",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(listPath) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
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

			resp, err := a.client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return a.fail(cmd, err)
			}

			resultMessage := toolResultMessage(resp.Result, "file list retrieved")
			resolvedPath := toolResultDataString(resp.Result, "path", strings.TrimSpace(listPath))
			count := toolResultDataInt(resp.Result, "count", 0)

			return a.presenter.Success(output.Result{
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
	fileCmd.AddCommand(listCmd)

	var readPath string
	var readTimeoutMS int

	readCmd := &cobra.Command{
		Use:     "read",
		Short:   "Read a project file as text",
		Example: "  godotctl file read --path scripts/player.gd",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(readPath) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
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

			resp, err := a.client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return a.fail(cmd, err)
			}

			resultMessage := toolResultMessage(resp.Result, "file read")
			resolvedPath := toolResultDataString(resp.Result, "path", strings.TrimSpace(readPath))
			byteCount := toolResultDataInt(resp.Result, "byte_count", 0)

			return a.presenter.Success(output.Result{
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
	fileCmd.AddCommand(readCmd)

	return fileCmd
}
