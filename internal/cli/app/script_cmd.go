package app

import (
	"fmt"
	"strings"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func (a *App) newScriptCommand() *cobra.Command {
	scriptCmd := &cobra.Command{
		Use:   "script",
		Short: "Script operations through the daemon",
	}

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
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if strings.TrimSpace(createBaseClass) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--base is required"))
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

			resp, err := a.client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return a.fail(cmd, err)
			}

			resultMessage := toolResultMessage(resp.Result, "script created")
			scriptPath := toolResultDataString(resp.Result, "script_path", strings.TrimSpace(createScriptPath))

			return a.presenter.Success(output.Result{
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
	scriptCmd.AddCommand(createCmd)

	var editScriptPath string
	var editFindText string
	var editReplaceText string
	var editTimeoutMS int

	editCmd := &cobra.Command{
		Use:     "edit",
		Short:   "Replace literal text in a script",
		Example: "  godotctl script edit --path scripts/player.gd --find pass --replace 'print(\"ready\")'",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(editScriptPath) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if editFindText == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--find is required"))
			}
			if !cmd.Flags().Changed("replace") {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--replace is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "script.edit",
				Args: map[string]any{
					"script_path":  editScriptPath,
					"find_text":    editFindText,
					"replace_text": editReplaceText,
				},
			}
			if editTimeoutMS > 0 {
				callReq.TimeoutMS = editTimeoutMS
			}

			resp, err := a.client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return a.fail(cmd, err)
			}

			resultMessage := toolResultMessage(resp.Result, "script edited")
			scriptPath := toolResultDataString(resp.Result, "script_path", strings.TrimSpace(editScriptPath))
			matchCount := toolResultDataInt(resp.Result, "match_count", 0)
			replacedCount := toolResultDataInt(resp.Result, "replaced_count", 0)

			return a.presenter.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("script edit ok: %s (matches=%d, replaced=%d, request_id=%s)", scriptPath, matchCount, replacedCount, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	editCmd.Flags().StringVar(&editScriptPath, "path", "", "Script path (project-relative .gd path)")
	editCmd.Flags().StringVar(&editFindText, "find", "", "Literal text to replace")
	editCmd.Flags().StringVar(&editReplaceText, "replace", "", "Replacement text (can be empty)")
	editCmd.Flags().IntVar(&editTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")
	scriptCmd.AddCommand(editCmd)

	var validateScriptPath string
	var validateTimeoutMS int

	validateCmd := &cobra.Command{
		Use:     "validate",
		Short:   "Validate GDScript parse/compile state",
		Example: "  godotctl script validate --path scripts/player.gd",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(validateScriptPath) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "script.validate",
				Args: map[string]any{
					"script_path": validateScriptPath,
				},
			}
			if validateTimeoutMS > 0 {
				callReq.TimeoutMS = validateTimeoutMS
			}

			resp, err := a.client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return a.fail(cmd, err)
			}

			resultMessage := toolResultMessage(resp.Result, "script validated")
			scriptPath := toolResultDataString(resp.Result, "script_path", strings.TrimSpace(validateScriptPath))
			valid := false
			diagnosticsCount := 0
			if data := toolResultData(resp.Result); data != nil {
				if value, ok := data["valid"].(bool); ok {
					valid = value
				}
				if diagnostics, ok := data["diagnostics"].([]any); ok {
					diagnosticsCount = len(diagnostics)
				}
			}

			return a.presenter.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("script validate ok: %s (valid=%t, diagnostics=%d, request_id=%s)", scriptPath, valid, diagnosticsCount, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	validateCmd.Flags().StringVar(&validateScriptPath, "path", "", "Script path (project-relative .gd path)")
	validateCmd.Flags().IntVar(&validateTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")
	scriptCmd.AddCommand(validateCmd)

	var attachScenePath string
	var attachNodePath string
	var attachScriptPath string
	var attachOverwrite bool
	var attachTimeoutMS int

	attachCmd := &cobra.Command{
		Use:     "attach",
		Short:   "Attach a script to a scene node",
		Example: "  godotctl script attach --scene scenes/player.tscn --node . --script scripts/player.gd",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(attachScenePath) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if strings.TrimSpace(attachNodePath) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--node is required"))
			}
			if strings.TrimSpace(attachScriptPath) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--script is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "script.attach",
				Args: map[string]any{
					"scene_path":  attachScenePath,
					"node_path":   attachNodePath,
					"script_path": attachScriptPath,
					"overwrite":   attachOverwrite,
				},
			}
			if attachTimeoutMS > 0 {
				callReq.TimeoutMS = attachTimeoutMS
			}

			resp, err := a.client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return a.fail(cmd, err)
			}

			resultMessage := toolResultMessage(resp.Result, "script attached")
			scenePath := toolResultDataString(resp.Result, "scene_path", strings.TrimSpace(attachScenePath))
			nodePath := toolResultDataString(resp.Result, "node_path", strings.TrimSpace(attachNodePath))
			scriptPath := toolResultDataString(resp.Result, "script_path", strings.TrimSpace(attachScriptPath))

			return a.presenter.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("script attach ok: %s -> %s:%s (request_id=%s)", scriptPath, scenePath, nodePath, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	attachCmd.Flags().StringVar(&attachScenePath, "scene", "", "Scene path (project-relative .tscn path)")
	attachCmd.Flags().StringVar(&attachNodePath, "node", "", "Node path (use . for root)")
	attachCmd.Flags().StringVar(&attachScriptPath, "script", "", "Script path (project-relative .gd path)")
	attachCmd.Flags().BoolVar(&attachOverwrite, "overwrite", false, "Replace existing node script")
	attachCmd.Flags().IntVar(&attachTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")
	scriptCmd.AddCommand(attachCmd)

	return scriptCmd
}
