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

func newValidateCommand(deps shared.Deps) *cobra.Command {
	var validateScriptPath string
	var validateTimeoutMS int

	validateCmd := &cobra.Command{
		Use:     "validate",
		Short:   "Validate GDScript parse/compile state",
		Example: "  godotctl script validate --path scripts/player.gd",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(validateScriptPath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
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

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "script validated")
			scriptPath := shared.ToolResultDataString(resp.Result, "script_path", strings.TrimSpace(validateScriptPath))
			valid := false
			diagnosticsCount := 0
			if data := shared.ToolResultData(resp.Result); data != nil {
				if value, ok := data["valid"].(bool); ok {
					valid = value
				}
				if diagnostics, ok := data["diagnostics"].([]any); ok {
					diagnosticsCount = len(diagnostics)
				}
			}

			return deps.Success(output.Result{
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

	return validateCmd
}
