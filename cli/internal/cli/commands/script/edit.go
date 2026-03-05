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

func newEditCommand(deps shared.Deps) *cobra.Command {
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
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if editFindText == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--find is required"))
			}
			if !cmd.Flags().Changed("replace") {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--replace is required"))
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

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "script edited")
			scriptPath := shared.ToolResultDataString(resp.Result, "script_path", strings.TrimSpace(editScriptPath))
			matchCount := shared.ToolResultDataInt(resp.Result, "match_count", 0)
			replacedCount := shared.ToolResultDataInt(resp.Result, "replaced_count", 0)

			return deps.Success(output.Result{
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

	return editCmd
}
