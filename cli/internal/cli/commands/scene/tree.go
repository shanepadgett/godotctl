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

func newTreeCommand(deps shared.Deps) *cobra.Command {
	var treeScenePath string
	var treeTimeoutMS int

	treeCmd := &cobra.Command{
		Use:     "tree",
		Short:   "List scene nodes with deterministic paths",
		Example: "  godotctl scene tree --scene scenes/player.tscn",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(treeScenePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "scene.tree",
				Args: map[string]any{
					"scene_path": treeScenePath,
				},
			}
			if treeTimeoutMS > 0 {
				callReq.TimeoutMS = treeTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "scene tree ready")
			listedPath := shared.ToolResultDataString(resp.Result, "scene_path", strings.TrimSpace(treeScenePath))
			nodeCount := 0
			if data := shared.ToolResultData(resp.Result); data != nil {
				if nodes, ok := data["nodes"].([]any); ok {
					nodeCount = len(nodes)
				}
			}

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("scene tree ok: %s (nodes=%d, request_id=%s)", listedPath, nodeCount, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	treeCmd.Flags().StringVar(&treeScenePath, "scene", "", "Scene path (project-relative .tscn path)")
	treeCmd.Flags().IntVar(&treeTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return treeCmd
}
