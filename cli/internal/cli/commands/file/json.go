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

func newJSONGetCommand(deps shared.Deps) *cobra.Command {
	var path string
	var pointer string
	var timeoutMS int

	cmd := &cobra.Command{
		Use:     "get",
		Short:   "Read a JSON value by pointer",
		Example: "  godotctl file json get --path data/config.json --pointer /game/name",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(path) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "file.json_get",
				Args: map[string]any{
					"path":    path,
					"pointer": pointer,
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
				Text:    fmt.Sprintf("file json get ok: %s (request_id=%s)", strings.TrimSpace(path), resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "JSON value read"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&path, "path", "", "JSON file path")
	cmd.Flags().StringVar(&pointer, "pointer", "", "Optional JSON Pointer (empty means root)")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}

func newJSONSetCommand(deps shared.Deps) *cobra.Command {
	var path string
	var pointer string
	var value string
	var create bool
	var timeoutMS int

	cmd := &cobra.Command{
		Use:     "set",
		Short:   "Set a JSON value by pointer",
		Example: "  godotctl file json set --path data/config.json --pointer /game/name --value '\"Demo\"'",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(path) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if strings.TrimSpace(value) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--value is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "file.json_set",
				Args: map[string]any{
					"path":       path,
					"pointer":    pointer,
					"value_json": value,
					"create":     create,
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
				Text:    fmt.Sprintf("file json set ok: %s (request_id=%s)", strings.TrimSpace(path), resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "JSON value set"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&path, "path", "", "JSON file path")
	cmd.Flags().StringVar(&pointer, "pointer", "", "Optional JSON Pointer (empty means root)")
	cmd.Flags().StringVar(&value, "value", "", "JSON value payload")
	cmd.Flags().BoolVar(&create, "create", false, "Create the file if missing")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}

func newJSONRemoveCommand(deps shared.Deps) *cobra.Command {
	var path string
	var pointer string
	var timeoutMS int

	cmd := &cobra.Command{
		Use:     "remove",
		Short:   "Remove a JSON value by pointer",
		Example: "  godotctl file json remove --path data/config.json --pointer /game/name",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(path) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if strings.TrimSpace(pointer) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--pointer is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "file.json_remove",
				Args: map[string]any{
					"path":    path,
					"pointer": pointer,
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
				Text:    fmt.Sprintf("file json remove ok: %s (request_id=%s)", strings.TrimSpace(path), resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "JSON value removed"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&path, "path", "", "JSON file path")
	cmd.Flags().StringVar(&pointer, "pointer", "", "JSON Pointer")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}
