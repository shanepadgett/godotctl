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

func newInstanceSceneCommand(deps shared.Deps) *cobra.Command {
	var instanceScenePath string
	var instanceSourceScenePath string
	var instanceParentPath string
	var instanceName string
	var instanceTimeoutMS int

	instanceCmd := &cobra.Command{
		Use:     "instance-scene",
		Short:   "Instance a source scene as a child node",
		Example: "  godotctl scene instance-scene --scene scenes/player.tscn --source-scene scenes/effects/hit.tscn --parent .",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(instanceScenePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if strings.TrimSpace(instanceSourceScenePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--source-scene is required"))
			}
			if strings.TrimSpace(instanceParentPath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--parent is required"))
			}

			args := map[string]any{
				"scene_path":        instanceScenePath,
				"source_scene_path": instanceSourceScenePath,
				"parent_path":       instanceParentPath,
			}
			if strings.TrimSpace(instanceName) != "" {
				args["name"] = instanceName
			}

			callReq := client.ToolCallRequest{
				Tool: "scene.instance_scene",
				Args: args,
			}
			if instanceTimeoutMS > 0 {
				callReq.TimeoutMS = instanceTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "scene instanced")
			nodePath := shared.ToolResultDataString(resp.Result, "node_path", strings.TrimSpace(instanceParentPath))

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("scene instance-scene ok: %s (request_id=%s)", nodePath, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	instanceCmd.Flags().StringVar(&instanceScenePath, "scene", "", "Scene path (project-relative .tscn path)")
	instanceCmd.Flags().StringVar(&instanceSourceScenePath, "source-scene", "", "Source scene path to instance")
	instanceCmd.Flags().StringVar(&instanceParentPath, "parent", "", "Parent node path for instance")
	instanceCmd.Flags().StringVar(&instanceName, "name", "", "Optional created node name override")
	instanceCmd.Flags().IntVar(&instanceTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return instanceCmd
}
