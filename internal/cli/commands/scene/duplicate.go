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

func newDuplicateCommand(deps shared.Deps) *cobra.Command {
	var duplicateScenePath string
	var duplicateNodePath string
	var duplicateParentPath string
	var duplicateName string
	var duplicateTimeoutMS int

	duplicateCmd := &cobra.Command{
		Use:     "duplicate",
		Short:   "Duplicate a node under a parent",
		Example: "  godotctl scene duplicate --scene scenes/player.tscn --path Sprite2D --parent .",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(duplicateScenePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if strings.TrimSpace(duplicateNodePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if strings.TrimSpace(duplicateParentPath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--parent is required"))
			}

			args := map[string]any{
				"scene_path":  duplicateScenePath,
				"node_path":   duplicateNodePath,
				"parent_path": duplicateParentPath,
			}
			if strings.TrimSpace(duplicateName) != "" {
				args["name"] = duplicateName
			}

			callReq := client.ToolCallRequest{
				Tool: "scene.duplicate_node",
				Args: args,
			}
			if duplicateTimeoutMS > 0 {
				callReq.TimeoutMS = duplicateTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "node duplicated")
			nodePath := shared.ToolResultDataString(resp.Result, "node_path", "")
			if nodePath == "" {
				nodePath = strings.TrimSpace(duplicateNodePath)
			}

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("scene duplicate ok: %s (request_id=%s)", nodePath, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	duplicateCmd.Flags().StringVar(&duplicateScenePath, "scene", "", "Scene path (project-relative .tscn path)")
	duplicateCmd.Flags().StringVar(&duplicateNodePath, "path", "", "Node path to duplicate")
	duplicateCmd.Flags().StringVar(&duplicateParentPath, "parent", "", "Parent node path for duplicate")
	duplicateCmd.Flags().StringVar(&duplicateName, "name", "", "Optional duplicate node name override")
	duplicateCmd.Flags().IntVar(&duplicateTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return duplicateCmd
}
