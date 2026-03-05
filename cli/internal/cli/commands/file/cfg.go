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

func newCFGGetCommand(deps shared.Deps) *cobra.Command {
	var path string
	var section string
	var key string
	var timeoutMS int

	cmd := &cobra.Command{
		Use:     "get",
		Short:   "Read config values from a CFG-style file",
		Example: "  godotctl file cfg get --path addons/godot_bridge/plugin.cfg --section plugin --key name",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(path) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if strings.TrimSpace(key) != "" && strings.TrimSpace(section) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--section is required when --key is set"))
			}

			callReq := client.ToolCallRequest{
				Tool: "file.cfg_get",
				Args: map[string]any{
					"path":    path,
					"section": section,
					"key":     key,
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
				Text:    fmt.Sprintf("file cfg get ok: %s (returned=%d, request_id=%s)", strings.TrimSpace(path), shared.ToolResultDataInt(resp.Result, "returned_count", 0), resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "config values listed"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&path, "path", "", "Config file path")
	cmd.Flags().StringVar(&section, "section", "", "Optional section name")
	cmd.Flags().StringVar(&key, "key", "", "Optional key name")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}

func newCFGSetCommand(deps shared.Deps) *cobra.Command {
	var path string
	var section string
	var key string
	var value string
	var create bool
	var timeoutMS int

	cmd := &cobra.Command{
		Use:     "set",
		Short:   "Set one value in a CFG-style file",
		Example: "  godotctl file cfg set --path addons/godot_bridge/plugin.cfg --section plugin --key name --value '\"Bridge\"'",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(path) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if strings.TrimSpace(section) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--section is required"))
			}
			if strings.TrimSpace(key) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--key is required"))
			}
			if strings.TrimSpace(value) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--value is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "file.cfg_set",
				Args: map[string]any{
					"path":       path,
					"section":    section,
					"key":        key,
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
				Text:    fmt.Sprintf("file cfg set ok: %s (%s/%s, request_id=%s)", strings.TrimSpace(path), strings.TrimSpace(section), strings.TrimSpace(key), resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "config value set"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&path, "path", "", "Config file path")
	cmd.Flags().StringVar(&section, "section", "", "Section name")
	cmd.Flags().StringVar(&key, "key", "", "Key name")
	cmd.Flags().StringVar(&value, "value", "", "Value JSON")
	cmd.Flags().BoolVar(&create, "create", false, "Create the file if missing")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}

func newCFGRemoveCommand(deps shared.Deps) *cobra.Command {
	var path string
	var section string
	var key string
	var timeoutMS int

	cmd := &cobra.Command{
		Use:     "remove",
		Short:   "Remove one section or key from a CFG-style file",
		Example: "  godotctl file cfg remove --path addons/godot_bridge/plugin.cfg --section plugin --key name",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(path) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if strings.TrimSpace(section) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--section is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "file.cfg_remove",
				Args: map[string]any{
					"path":    path,
					"section": section,
					"key":     key,
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
				Text:    fmt.Sprintf("file cfg remove ok: %s (request_id=%s)", strings.TrimSpace(path), resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "config value removed"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&path, "path", "", "Config file path")
	cmd.Flags().StringVar(&section, "section", "", "Section name")
	cmd.Flags().StringVar(&key, "key", "", "Optional key name")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}
