package runcmd

import (
	"fmt"
	"strings"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func newPropGetCommand(deps shared.Deps) *cobra.Command {
	var nodePath string
	var propName string
	var timeoutMS int

	cmd := &cobra.Command{
		Use:   "get",
		Short: "Get one runtime node property",
		RunE: func(cmd *cobra.Command, _ []string) error {
			trimmedNodePath := strings.TrimSpace(nodePath)
			if trimmedNodePath == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			trimmedPropName := strings.TrimSpace(propName)
			if trimmedPropName == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--prop is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "run.prop_get",
				Args: map[string]any{
					"node_path": trimmedNodePath,
					"property":  trimmedPropName,
				},
			}
			if timeoutMS > 0 {
				callReq.TimeoutMS = timeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("run prop get ok: %s.%s (request_id=%s)", trimmedNodePath, trimmedPropName, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "runtime property read"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&nodePath, "path", "", "Runtime node path")
	cmd.Flags().StringVar(&propName, "prop", "", "Runtime property name")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}

func newPropListCommand(deps shared.Deps) *cobra.Command {
	var nodePath string
	var maxRows int
	var timeoutMS int

	cmd := &cobra.Command{
		Use:   "list",
		Short: "List runtime node properties",
		RunE: func(cmd *cobra.Command, _ []string) error {
			trimmedNodePath := strings.TrimSpace(nodePath)
			if trimmedNodePath == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if maxRows < 0 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--max must be >= 0"))
			}

			callReq := client.ToolCallRequest{
				Tool: "run.prop_list",
				Args: map[string]any{
					"node_path": trimmedNodePath,
					"max":       maxRows,
				},
			}
			if timeoutMS > 0 {
				callReq.TimeoutMS = timeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			count := shared.ToolResultDataInt(resp.Result, "returned_count", 0)

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("run prop list ok: %s properties=%d (request_id=%s)", trimmedNodePath, count, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "runtime properties listed"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&nodePath, "path", "", "Runtime node path")
	cmd.Flags().IntVar(&maxRows, "max", 200, "Max returned property rows (0 means no limit)")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}
