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

func newAttachCommand(deps shared.Deps) *cobra.Command {
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
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if strings.TrimSpace(attachNodePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--node is required"))
			}
			if strings.TrimSpace(attachScriptPath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--script is required"))
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

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "script attached")
			scenePath := shared.ToolResultDataString(resp.Result, "scene_path", strings.TrimSpace(attachScenePath))
			nodePath := shared.ToolResultDataString(resp.Result, "node_path", strings.TrimSpace(attachNodePath))
			scriptPath := shared.ToolResultDataString(resp.Result, "script_path", strings.TrimSpace(attachScriptPath))

			return deps.Success(output.Result{
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

	return attachCmd
}
