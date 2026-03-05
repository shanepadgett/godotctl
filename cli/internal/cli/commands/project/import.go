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

func newImportGetCommand(deps shared.Deps) *cobra.Command {
	var path string
	var key string
	var prefix string
	var includeValues bool
	var maxProperties int
	var timeoutMS int

	cmd := &cobra.Command{
		Use:     "get",
		Short:   "Inspect import metadata for one asset",
		Example: "  godotctl project import get --path icon.svg --include-values",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(path) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if strings.TrimSpace(key) != "" && strings.TrimSpace(prefix) != "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--key and --prefix cannot be used together"))
			}
			if maxProperties < 0 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--max-properties must be >= 0"))
			}

			callReq := client.ToolCallRequest{
				Tool: "project.import_get",
				Args: map[string]any{
					"path":           path,
					"key":            key,
					"prefix":         prefix,
					"include_values": includeValues,
					"max_properties": maxProperties,
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
				Text:    fmt.Sprintf("project import get ok: %s (returned=%d, request_id=%s)", strings.TrimSpace(path), shared.ToolResultDataInt(resp.Result, "returned_count", 0), resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "import metadata listed"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&path, "path", "", "Source asset path")
	cmd.Flags().StringVar(&key, "key", "", "Optional import property key (section/name)")
	cmd.Flags().StringVar(&prefix, "prefix", "", "Optional import property key prefix")
	cmd.Flags().BoolVar(&includeValues, "include-values", false, "Include property values")
	cmd.Flags().IntVar(&maxProperties, "max-properties", 200, "Max returned properties (0 means no limit)")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}

func newImportSetCommand(deps shared.Deps) *cobra.Command {
	var path string
	var key string
	var value string
	var timeoutMS int

	cmd := &cobra.Command{
		Use:     "set",
		Short:   "Set one import metadata property",
		Example: "  godotctl project import set --path icon.svg --key params/compress/mode --value '1'",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(path) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if strings.TrimSpace(key) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--key is required"))
			}
			if strings.TrimSpace(value) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--value is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "project.import_set",
				Args: map[string]any{
					"path":       path,
					"key":        key,
					"value_json": value,
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
				Text:    fmt.Sprintf("project import set ok: %s (%s, request_id=%s)", strings.TrimSpace(path), strings.TrimSpace(key), resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "import property set"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&path, "path", "", "Source asset path")
	cmd.Flags().StringVar(&key, "key", "", "Import property key (section/name)")
	cmd.Flags().StringVar(&value, "value", "", "Property value JSON")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}

func newImportReimportCommand(deps shared.Deps) *cobra.Command {
	var path string
	var timeoutMS int

	cmd := &cobra.Command{
		Use:     "reimport",
		Short:   "Reimport one asset",
		Example: "  godotctl project import reimport --path icon.svg",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(path) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "project.import_reimport",
				Args: map[string]any{
					"path": path,
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
				Text:    fmt.Sprintf("project import reimport ok: %s (request_id=%s)", strings.TrimSpace(path), resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "asset reimported"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&path, "path", "", "Source asset path")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}
