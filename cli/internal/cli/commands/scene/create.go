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

func newCreateCommand(deps shared.Deps) *cobra.Command {
	var createScenePath string
	var createRootType string
	var createRootName string
	var createOverwrite bool
	var createOpenInEditor bool
	var createTimeoutMS int

	createCmd := &cobra.Command{
		Use:     "create",
		Short:   "Create a new scene file",
		Example: "  godotctl scene create --scene scenes/player.tscn --root CharacterBody2D --name Player",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(createScenePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if strings.TrimSpace(createRootType) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--root is required"))
			}
			if strings.TrimSpace(createRootName) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--name is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "scene.create",
				Args: map[string]any{
					"scene_path":     createScenePath,
					"root_type":      createRootType,
					"root_name":      createRootName,
					"overwrite":      createOverwrite,
					"open_in_editor": createOpenInEditor,
				},
			}
			if createTimeoutMS > 0 {
				callReq.TimeoutMS = createTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "scene created")
			createdPath := shared.ToolResultDataString(resp.Result, "scene_path", strings.TrimSpace(createScenePath))

			return deps.Success(output.Result{
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

	createCmd.Flags().StringVar(&createScenePath, "scene", "", "Scene path (project-relative .tscn path)")
	createCmd.Flags().StringVar(&createRootType, "root", "", "Root node type")
	createCmd.Flags().StringVar(&createRootName, "name", "", "Root node name")
	createCmd.Flags().BoolVar(&createOverwrite, "overwrite", false, "Overwrite existing scene")
	createCmd.Flags().BoolVar(&createOpenInEditor, "open", false, "Open scene in editor after create")
	createCmd.Flags().IntVar(&createTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return createCmd
}
