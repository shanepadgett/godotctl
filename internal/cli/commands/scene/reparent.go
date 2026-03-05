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

func newReparentCommand(deps shared.Deps) *cobra.Command {
	var reparentScenePath string
	var reparentNodePath string
	var reparentParentPath string
	var reparentIndex int
	var reparentTimeoutMS int

	reparentCmd := &cobra.Command{
		Use:     "reparent",
		Short:   "Move a node under a new parent",
		Example: "  godotctl scene reparent --scene scenes/player.tscn --path Sprite2D --parent .",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(reparentScenePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if strings.TrimSpace(reparentNodePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if strings.TrimSpace(reparentParentPath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--parent is required"))
			}
			if cmd.Flags().Changed("index") && reparentIndex < 0 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--index must be >= 0"))
			}

			args := map[string]any{
				"scene_path":  reparentScenePath,
				"node_path":   reparentNodePath,
				"parent_path": reparentParentPath,
			}
			if cmd.Flags().Changed("index") {
				args["index"] = reparentIndex
			}

			callReq := client.ToolCallRequest{
				Tool: "scene.reparent_node",
				Args: args,
			}
			if reparentTimeoutMS > 0 {
				callReq.TimeoutMS = reparentTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "node reparented")
			nodePath := shared.ToolResultDataString(resp.Result, "node_path", strings.TrimSpace(reparentNodePath))
			parentPath := shared.ToolResultDataString(resp.Result, "parent_path", strings.TrimSpace(reparentParentPath))
			index := shared.ToolResultDataInt(resp.Result, "index", reparentIndex)

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("scene reparent ok: %s (parent=%s index=%d, request_id=%s)", nodePath, parentPath, index, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	reparentCmd.Flags().StringVar(&reparentScenePath, "scene", "", "Scene path (project-relative .tscn path)")
	reparentCmd.Flags().StringVar(&reparentNodePath, "path", "", "Node path to move")
	reparentCmd.Flags().StringVar(&reparentParentPath, "parent", "", "New parent node path")
	reparentCmd.Flags().IntVar(&reparentIndex, "index", 0, "Optional destination child index")
	reparentCmd.Flags().IntVar(&reparentTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return reparentCmd
}
