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

func newRemoveNodeCommand(deps shared.Deps) *cobra.Command {
	var removeScenePath string
	var removeNodePath string
	var removeTimeoutMS int

	removeNodeCmd := &cobra.Command{
		Use:     "remove-node",
		Short:   "Remove a node from a scene",
		Example: "  godotctl scene remove-node --scene scenes/player.tscn --path Sprite2D",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(removeScenePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if strings.TrimSpace(removeNodePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "scene.remove_node",
				Args: map[string]any{
					"scene_path": removeScenePath,
					"node_path":  removeNodePath,
				},
			}
			if removeTimeoutMS > 0 {
				callReq.TimeoutMS = removeTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "node removed")
			removedPath := shared.ToolResultDataString(resp.Result, "removed_path", strings.TrimSpace(removeNodePath))

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("scene remove-node ok: %s (request_id=%s)", removedPath, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	removeNodeCmd.Flags().StringVar(&removeScenePath, "scene", "", "Scene path (project-relative .tscn path)")
	removeNodeCmd.Flags().StringVar(&removeNodePath, "path", "", "Node path to remove (use . for root)")
	removeNodeCmd.Flags().IntVar(&removeTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return removeNodeCmd
}
