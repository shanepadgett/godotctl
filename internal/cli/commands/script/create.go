package scriptcmd

import (
	"fmt"
	"strings"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func newCreateCommand(deps shared.Deps) *cobra.Command {
	var createScriptPath string
	var createBaseClass string
	var createClassName string
	var createOverwrite bool
	var createTimeoutMS int

	createCmd := &cobra.Command{
		Use:     "create",
		Short:   "Create a script file from template",
		Example: "  godotctl script create --path scripts/player.gd --base CharacterBody2D",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(createScriptPath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if strings.TrimSpace(createBaseClass) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--base is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "script.create",
				Args: map[string]any{
					"script_path": createScriptPath,
					"base_class":  createBaseClass,
					"class_name":  createClassName,
					"overwrite":   createOverwrite,
				},
			}
			if createTimeoutMS > 0 {
				callReq.TimeoutMS = createTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "script created")
			scriptPath := shared.ToolResultDataString(resp.Result, "script_path", strings.TrimSpace(createScriptPath))

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("script create ok: %s (request_id=%s)", scriptPath, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	createCmd.Flags().StringVar(&createScriptPath, "path", "", "Script path (project-relative .gd path)")
	createCmd.Flags().StringVar(&createBaseClass, "base", "", "Base class for extends")
	createCmd.Flags().StringVar(&createClassName, "class-name", "", "Optional global class_name")
	createCmd.Flags().BoolVar(&createOverwrite, "overwrite", false, "Overwrite existing script")
	createCmd.Flags().IntVar(&createTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return createCmd
}
