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

func newSetPropCommand(deps shared.Deps) *cobra.Command {
	var setPropScenePath string
	var setPropNodePath string
	var setPropName string
	var setPropValue string
	var setPropTimeoutMS int

	setPropCmd := &cobra.Command{
		Use:     "set-prop",
		Short:   "Set a node property from JSON value",
		Example: "  godotctl scene set-prop --scene scenes/player.tscn --path . --prop position --value '{\"type\":\"Vector2\",\"x\":10,\"y\":20}'",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(setPropScenePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if strings.TrimSpace(setPropNodePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if strings.TrimSpace(setPropName) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--prop is required"))
			}
			if strings.TrimSpace(setPropValue) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--value is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "scene.set_prop",
				Args: map[string]any{
					"scene_path": setPropScenePath,
					"node_path":  setPropNodePath,
					"property":   setPropName,
					"value_json": setPropValue,
				},
			}
			if setPropTimeoutMS > 0 {
				callReq.TimeoutMS = setPropTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "property set")
			nodePath := shared.ToolResultDataString(resp.Result, "node_path", strings.TrimSpace(setPropNodePath))
			propertyName := shared.ToolResultDataString(resp.Result, "property", strings.TrimSpace(setPropName))

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("scene set-prop ok: %s (property=%s, request_id=%s)", nodePath, propertyName, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	setPropCmd.Flags().StringVar(&setPropScenePath, "scene", "", "Scene path (project-relative .tscn path)")
	setPropCmd.Flags().StringVar(&setPropNodePath, "path", "", "Node path (use . for root)")
	setPropCmd.Flags().StringVar(&setPropName, "prop", "", "Property name")
	setPropCmd.Flags().StringVar(&setPropValue, "value", "", "Property value JSON (primitive or typed object)")
	setPropCmd.Flags().IntVar(&setPropTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return setPropCmd
}
