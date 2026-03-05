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

func newTransformApplyCommand(deps shared.Deps) *cobra.Command {
	var transformScenePath string
	var transformNodePath string
	var transformValue string
	var transformTimeoutMS int

	applyCmd := &cobra.Command{
		Use:     "apply",
		Short:   "Apply transform values to a node",
		Example: "  godotctl scene transform apply --scene scenes/player.tscn --path . --value '{\"position\":{\"type\":\"Vector2\",\"x\":10,\"y\":20}}'",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(transformScenePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if strings.TrimSpace(transformNodePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if strings.TrimSpace(transformValue) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--value is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "scene.transform_apply",
				Args: map[string]any{
					"scene_path": transformScenePath,
					"node_path":  transformNodePath,
					"value_json": transformValue,
				},
			}
			if transformTimeoutMS > 0 {
				callReq.TimeoutMS = transformTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "transform applied")
			nodePath := shared.ToolResultDataString(resp.Result, "node_path", strings.TrimSpace(transformNodePath))
			propertyCount := toolResultArrayLen(resp.Result, "properties")

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("scene transform apply ok: %s (properties=%d, request_id=%s)", nodePath, propertyCount, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	applyCmd.Flags().StringVar(&transformScenePath, "scene", "", "Scene path (project-relative .tscn path)")
	applyCmd.Flags().StringVar(&transformNodePath, "path", "", "Node path")
	applyCmd.Flags().StringVar(&transformValue, "value", "", "Transform value JSON object")
	applyCmd.Flags().IntVar(&transformTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return applyCmd
}
