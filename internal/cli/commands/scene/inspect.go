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

func newInspectCommand(deps shared.Deps) *cobra.Command {
	var inspectScenePath string
	var inspectNodePath string
	var inspectTimeoutMS int
	var includeProperties bool
	var includePropertyValues bool
	var includeConnections bool
	var includeSignalNames bool
	var maxProperties int

	inspectCmd := &cobra.Command{
		Use:     "inspect",
		Short:   "Inspect scene nodes with optional details",
		Example: "  godotctl scene inspect --scene scenes/player.tscn",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(inspectScenePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if includePropertyValues && !includeProperties {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--include-property-values requires --include-properties"))
			}
			if maxProperties < 0 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--max-properties must be >= 0"))
			}

			callReq := client.ToolCallRequest{
				Tool: "scene.inspect",
				Args: map[string]any{
					"scene_path":              inspectScenePath,
					"node_path":               inspectNodePath,
					"include_properties":      includeProperties,
					"include_property_values": includePropertyValues,
					"include_connections":     includeConnections,
					"include_signal_names":    includeSignalNames,
					"max_properties":          maxProperties,
				},
			}
			if inspectTimeoutMS > 0 {
				callReq.TimeoutMS = inspectTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "scene inspect ready")
			listedPath := shared.ToolResultDataString(resp.Result, "scene_path", strings.TrimSpace(inspectScenePath))
			nodeCount := shared.ToolResultDataInt(resp.Result, "node_count", 0)
			connectionCount := shared.ToolResultDataInt(resp.Result, "connection_count", 0)

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text: fmt.Sprintf(
					"scene inspect ok: %s (nodes=%d, connections=%d, request_id=%s)",
					listedPath,
					nodeCount,
					connectionCount,
					resp.RequestID,
				),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	inspectCmd.Flags().StringVar(&inspectScenePath, "scene", "", "Scene path (project-relative .tscn path)")
	inspectCmd.Flags().StringVar(&inspectNodePath, "node", "", "Optional node path to inspect one subtree")
	inspectCmd.Flags().BoolVar(&includeProperties, "include-properties", false, "Include per-node property snapshots")
	inspectCmd.Flags().BoolVar(&includePropertyValues, "include-property-values", false, "Include property values (requires --include-properties)")
	inspectCmd.Flags().BoolVar(&includeConnections, "include-connections", false, "Include signal connection rows")
	inspectCmd.Flags().BoolVar(&includeSignalNames, "include-signal-names", false, "Include per-node signal name lists")
	inspectCmd.Flags().IntVar(&maxProperties, "max-properties", 16, "Max properties per node (0 means no limit)")
	inspectCmd.Flags().IntVar(&inspectTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return inspectCmd
}
