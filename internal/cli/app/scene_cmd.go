package app

import (
	"fmt"
	"strings"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func (a *App) newSceneCommand() *cobra.Command {
	sceneCmd := &cobra.Command{
		Use:   "scene",
		Short: "Scene operations through the daemon",
	}

	var scenePath string
	var rootType string
	var rootName string
	var overwrite bool
	var openInEditor bool
	var timeoutMS int

	createCmd := &cobra.Command{
		Use:     "create",
		Short:   "Create a new scene file",
		Example: "  godotctl scene create --scene scenes/player.tscn --root CharacterBody2D --name Player",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(scenePath) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if strings.TrimSpace(rootType) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--root is required"))
			}
			if strings.TrimSpace(rootName) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--name is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "scene.create",
				Args: map[string]any{
					"scene_path":     scenePath,
					"root_type":      rootType,
					"root_name":      rootName,
					"overwrite":      overwrite,
					"open_in_editor": openInEditor,
				},
			}
			if timeoutMS > 0 {
				callReq.TimeoutMS = timeoutMS
			}

			resp, err := a.client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return a.fail(cmd, err)
			}

			resultMessage := "scene created"
			if value, ok := resp.Result["message"].(string); ok {
				if trimmed := strings.TrimSpace(value); trimmed != "" {
					resultMessage = trimmed
				}
			}

			createdPath := strings.TrimSpace(scenePath)
			if data, ok := resp.Result["data"].(map[string]any); ok {
				if pathValue, ok := data["scene_path"].(string); ok {
					if trimmed := strings.TrimSpace(pathValue); trimmed != "" {
						createdPath = trimmed
					}
				}
			}

			return a.presenter.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("scene create ok: %s (request_id=%s)", createdPath, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	createCmd.Flags().StringVar(&scenePath, "scene", "", "Scene path (project-relative .tscn path)")
	createCmd.Flags().StringVar(&rootType, "root", "", "Root node type")
	createCmd.Flags().StringVar(&rootName, "name", "", "Root node name")
	createCmd.Flags().BoolVar(&overwrite, "overwrite", false, "Overwrite existing scene")
	createCmd.Flags().BoolVar(&openInEditor, "open", false, "Open scene in editor after create")
	createCmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	sceneCmd.AddCommand(createCmd)

	return sceneCmd
}
