package scenecmd

import (
	"fmt"
	"strings"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func newRenameCommand(deps shared.Deps) *cobra.Command {
	var renameScenePath string
	var renameNodePath string
	var renameName string
	var renameTimeoutMS int

	renameCmd := &cobra.Command{
		Use:     "rename",
		Short:   "Rename a scene node",
		Example: "  godotctl scene rename --scene scenes/player.tscn --path Sprite2D --name PlayerSprite",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(renameScenePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if strings.TrimSpace(renameNodePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if strings.TrimSpace(renameName) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--name is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "scene.rename_node",
				Args: map[string]any{
					"scene_path": renameScenePath,
					"node_path":  renameNodePath,
					"name":       renameName,
				},
			}
			if renameTimeoutMS > 0 {
				callReq.TimeoutMS = renameTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "node renamed")
			nodePath := shared.ToolResultDataString(resp.Result, "node_path", strings.TrimSpace(renameNodePath))
			name := shared.ToolResultDataString(resp.Result, "name", strings.TrimSpace(renameName))

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("scene rename ok: %s (name=%s, request_id=%s)", nodePath, name, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	renameCmd.Flags().StringVar(&renameScenePath, "scene", "", "Scene path (project-relative .tscn path)")
	renameCmd.Flags().StringVar(&renameNodePath, "path", "", "Node path to rename")
	renameCmd.Flags().StringVar(&renameName, "name", "", "New node name")
	renameCmd.Flags().IntVar(&renameTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return renameCmd
}
