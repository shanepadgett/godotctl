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

func newAddNodeCommand(deps shared.Deps) *cobra.Command {
	var addScenePath string
	var addNodeName string
	var addNodeType string
	var addParentPath string
	var addTimeoutMS int

	addNodeCmd := &cobra.Command{
		Use:     "add-node",
		Short:   "Add a node under a parent path",
		Example: "  godotctl scene add-node --scene scenes/player.tscn --name Sprite2D --type Sprite2D --parent .",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(addScenePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if strings.TrimSpace(addNodeName) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--name is required"))
			}
			if strings.TrimSpace(addNodeType) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--type is required"))
			}
			if strings.TrimSpace(addParentPath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--parent is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "scene.add_node",
				Args: map[string]any{
					"scene_path":  addScenePath,
					"node_name":   addNodeName,
					"node_type":   addNodeType,
					"parent_path": addParentPath,
				},
			}
			if addTimeoutMS > 0 {
				callReq.TimeoutMS = addTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "node added")
			nodePath := shared.ToolResultDataString(resp.Result, "node_path", strings.TrimSpace(addNodeName))

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("scene add-node ok: %s (request_id=%s)", nodePath, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	addNodeCmd.Flags().StringVar(&addScenePath, "scene", "", "Scene path (project-relative .tscn path)")
	addNodeCmd.Flags().StringVar(&addNodeName, "name", "", "Node name to add")
	addNodeCmd.Flags().StringVar(&addNodeType, "type", "", "Node class to instantiate")
	addNodeCmd.Flags().StringVar(&addParentPath, "parent", "", "Parent node path (use . for root)")
	addNodeCmd.Flags().IntVar(&addTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return addNodeCmd
}
