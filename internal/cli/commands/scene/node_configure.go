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

func newNodeConfigureCommand(deps shared.Deps) *cobra.Command {
	var nodeConfigureScenePath string
	var nodeConfigureNodePath string
	var nodeConfigureConfig string
	var nodeConfigureTimeoutMS int

	configureCmd := &cobra.Command{
		Use:     "configure",
		Short:   "Apply multiple node property updates",
		Example: "  godotctl scene node configure --scene scenes/player.tscn --path . --config '{\"visible\":true}'",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(nodeConfigureScenePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if strings.TrimSpace(nodeConfigureNodePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if strings.TrimSpace(nodeConfigureConfig) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--config is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "scene.node_configure",
				Args: map[string]any{
					"scene_path":  nodeConfigureScenePath,
					"node_path":   nodeConfigureNodePath,
					"config_json": nodeConfigureConfig,
				},
			}
			if nodeConfigureTimeoutMS > 0 {
				callReq.TimeoutMS = nodeConfigureTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "node configured")
			nodePath := shared.ToolResultDataString(resp.Result, "node_path", strings.TrimSpace(nodeConfigureNodePath))
			propertyCount := toolResultArrayLen(resp.Result, "properties")

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("scene node configure ok: %s (properties=%d, request_id=%s)", nodePath, propertyCount, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	configureCmd.Flags().StringVar(&nodeConfigureScenePath, "scene", "", "Scene path (project-relative .tscn path)")
	configureCmd.Flags().StringVar(&nodeConfigureNodePath, "path", "", "Node path")
	configureCmd.Flags().StringVar(&nodeConfigureConfig, "config", "", "JSON object mapping property names to values")
	configureCmd.Flags().IntVar(&nodeConfigureTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return configureCmd
}
