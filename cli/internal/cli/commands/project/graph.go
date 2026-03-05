package projectcmd

import (
	"fmt"
	"strings"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func newGraphCommand(deps shared.Deps) *cobra.Command {
	var graphRootPath string
	var graphPrefix string
	var includeNodes bool
	var includeEdges bool
	var includeAll bool
	var maxNodes int
	var maxEdges int
	var graphTimeoutMS int

	graphCmd := &cobra.Command{
		Use:   "graph",
		Short: "Build deterministic project dependency graph",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if maxNodes < 0 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--max-nodes must be >= 0"))
			}
			if maxEdges < 0 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--max-edges must be >= 0"))
			}

			if includeAll {
				includeNodes = true
				includeEdges = true
			}

			callReq := client.ToolCallRequest{
				Tool: "project.graph",
				Args: map[string]any{
					"root_path":     strings.TrimSpace(graphRootPath),
					"path_prefix":   strings.TrimSpace(graphPrefix),
					"include_nodes": includeNodes,
					"include_edges": includeEdges,
					"max_nodes":     maxNodes,
					"max_edges":     maxEdges,
				},
			}
			if graphTimeoutMS > 0 {
				callReq.TimeoutMS = graphTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "project graph ready")
			nodeCount := shared.ToolResultDataInt(resp.Result, "node_count", 0)
			edgeCount := shared.ToolResultDataInt(resp.Result, "edge_count", 0)
			returnedNodeCount := shared.ToolResultDataInt(resp.Result, "returned_node_count", 0)
			returnedEdgeCount := shared.ToolResultDataInt(resp.Result, "returned_edge_count", 0)

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("project graph ok: nodes=%d edges=%d returned_nodes=%d returned_edges=%d (request_id=%s)", nodeCount, edgeCount, returnedNodeCount, returnedEdgeCount, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	graphCmd.Flags().StringVar(&graphRootPath, "root", "res://", "Optional graph root path (defaults to res://)")
	graphCmd.Flags().StringVar(&graphPrefix, "prefix", "", "Optional path prefix filter for nodes/edges")
	graphCmd.Flags().BoolVar(&includeNodes, "include-nodes", false, "Include node rows in result payload")
	graphCmd.Flags().BoolVar(&includeEdges, "include-edges", false, "Include edge rows in result payload")
	graphCmd.Flags().BoolVar(&includeAll, "full", false, "Include both nodes and edges in result payload")
	graphCmd.Flags().IntVar(&maxNodes, "max-nodes", 200, "Max returned nodes (0 means no limit)")
	graphCmd.Flags().IntVar(&maxEdges, "max-edges", 200, "Max returned edges (0 means no limit)")
	graphCmd.Flags().IntVar(&graphTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return graphCmd
}
