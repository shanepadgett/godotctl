package projectcmd

import (
	"fmt"
	"strings"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func newAutoloadListCommand(deps shared.Deps) *cobra.Command {
	var name string
	var maxRows int
	var timeoutMS int

	cmd := &cobra.Command{
		Use:     "list",
		Short:   "List autoload entries",
		Example: "  godotctl project autoload list --json",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if maxRows < 0 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--max must be >= 0"))
			}

			callReq := client.ToolCallRequest{
				Tool: "project.autoload_list",
				Args: map[string]any{
					"name": strings.TrimSpace(name),
					"max":  maxRows,
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
				Text:    fmt.Sprintf("project autoload list ok: returned=%d (request_id=%s)", shared.ToolResultDataInt(resp.Result, "returned_count", 0), resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "autoloads listed"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&name, "name", "", "Optional autoload name filter")
	cmd.Flags().IntVar(&maxRows, "max", 200, "Max returned rows (0 means no limit)")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}

func newAutoloadAddCommand(deps shared.Deps) *cobra.Command {
	var name string
	var path string
	var singleton bool
	var index int
	var timeoutMS int

	cmd := &cobra.Command{
		Use:     "add",
		Short:   "Add an autoload entry",
		Example: "  godotctl project autoload add --name Globals --path scripts/globals.gd --singleton",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(name) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--name is required"))
			}
			if strings.TrimSpace(path) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if index < -1 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--index must be >= -1"))
			}

			args := map[string]any{
				"name":      name,
				"path":      path,
				"singleton": singleton,
			}
			if cmd.Flags().Changed("index") {
				args["index"] = index
			}

			callReq := client.ToolCallRequest{
				Tool: "project.autoload_add",
				Args: args,
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
				Text:    fmt.Sprintf("project autoload add ok: %s (request_id=%s)", strings.TrimSpace(name), resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "autoload added"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&name, "name", "", "Autoload name")
	cmd.Flags().StringVar(&path, "path", "", "Script or scene path")
	cmd.Flags().BoolVar(&singleton, "singleton", true, "Register as a singleton")
	cmd.Flags().IntVar(&index, "index", -1, "Optional order index")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}

func newAutoloadRemoveCommand(deps shared.Deps) *cobra.Command {
	var name string
	var timeoutMS int

	cmd := &cobra.Command{
		Use:     "remove",
		Short:   "Remove an autoload entry",
		Example: "  godotctl project autoload remove --name Globals",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(name) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--name is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "project.autoload_remove",
				Args: map[string]any{
					"name": name,
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
				Text:    fmt.Sprintf("project autoload remove ok: %s (request_id=%s)", strings.TrimSpace(name), resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "autoload removed"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&name, "name", "", "Autoload name")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}
