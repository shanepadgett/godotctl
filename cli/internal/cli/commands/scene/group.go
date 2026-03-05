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

func newGroupAddCommand(deps shared.Deps) *cobra.Command {
	var groupAddScenePath string
	var groupAddNodePath string
	var groupAddGroup string
	var groupAddTimeoutMS int

	addCmd := &cobra.Command{
		Use:     "add",
		Short:   "Add one node to one group",
		Example: "  godotctl scene group add --scene scenes/player.tscn --path . --group player",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(groupAddScenePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if strings.TrimSpace(groupAddNodePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if strings.TrimSpace(groupAddGroup) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--group is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "scene.group_add",
				Args: map[string]any{
					"scene_path": groupAddScenePath,
					"node_path":  groupAddNodePath,
					"group":      groupAddGroup,
				},
			}
			if groupAddTimeoutMS > 0 {
				callReq.TimeoutMS = groupAddTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "group membership added")
			nodePath := shared.ToolResultDataString(resp.Result, "node_path", strings.TrimSpace(groupAddNodePath))
			group := shared.ToolResultDataString(resp.Result, "group", strings.TrimSpace(groupAddGroup))

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("scene group add ok: %s -> %s (request_id=%s)", nodePath, group, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	addCmd.Flags().StringVar(&groupAddScenePath, "scene", "", "Scene path (project-relative .tscn path)")
	addCmd.Flags().StringVar(&groupAddNodePath, "path", "", "Node path")
	addCmd.Flags().StringVar(&groupAddGroup, "group", "", "Group name")
	addCmd.Flags().IntVar(&groupAddTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return addCmd
}

func newGroupRemoveCommand(deps shared.Deps) *cobra.Command {
	var groupRemoveScenePath string
	var groupRemoveNodePath string
	var groupRemoveGroup string
	var groupRemoveTimeoutMS int

	removeCmd := &cobra.Command{
		Use:     "remove",
		Short:   "Remove one node from one group",
		Example: "  godotctl scene group remove --scene scenes/player.tscn --path . --group player",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(groupRemoveScenePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if strings.TrimSpace(groupRemoveNodePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if strings.TrimSpace(groupRemoveGroup) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--group is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "scene.group_remove",
				Args: map[string]any{
					"scene_path": groupRemoveScenePath,
					"node_path":  groupRemoveNodePath,
					"group":      groupRemoveGroup,
				},
			}
			if groupRemoveTimeoutMS > 0 {
				callReq.TimeoutMS = groupRemoveTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "group membership removed")
			nodePath := shared.ToolResultDataString(resp.Result, "node_path", strings.TrimSpace(groupRemoveNodePath))
			group := shared.ToolResultDataString(resp.Result, "group", strings.TrimSpace(groupRemoveGroup))

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("scene group remove ok: %s -> %s (request_id=%s)", nodePath, group, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	removeCmd.Flags().StringVar(&groupRemoveScenePath, "scene", "", "Scene path (project-relative .tscn path)")
	removeCmd.Flags().StringVar(&groupRemoveNodePath, "path", "", "Node path")
	removeCmd.Flags().StringVar(&groupRemoveGroup, "group", "", "Group name")
	removeCmd.Flags().IntVar(&groupRemoveTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return removeCmd
}

func newGroupListCommand(deps shared.Deps) *cobra.Command {
	var groupListScenePath string
	var groupListNodePath string
	var groupListMax int
	var groupListTimeoutMS int

	listCmd := &cobra.Command{
		Use:     "list",
		Short:   "List group memberships in a scene",
		Example: "  godotctl scene group list --scene scenes/player.tscn",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(groupListScenePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if groupListMax < 0 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--max must be >= 0"))
			}

			args := map[string]any{
				"scene_path": groupListScenePath,
				"max":        groupListMax,
			}
			if value := strings.TrimSpace(groupListNodePath); value != "" {
				args["node_path"] = value
			}

			callReq := client.ToolCallRequest{
				Tool: "scene.group_list",
				Args: args,
			}
			if groupListTimeoutMS > 0 {
				callReq.TimeoutMS = groupListTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "group memberships listed")
			listedPath := shared.ToolResultDataString(resp.Result, "scene_path", strings.TrimSpace(groupListScenePath))
			count := shared.ToolResultDataInt(resp.Result, "count", 0)
			returnedCount := shared.ToolResultDataInt(resp.Result, "returned_count", 0)

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("scene group list ok: %s (groups=%d returned=%d, request_id=%s)", listedPath, count, returnedCount, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	listCmd.Flags().StringVar(&groupListScenePath, "scene", "", "Scene path (project-relative .tscn path)")
	listCmd.Flags().StringVar(&groupListNodePath, "path", "", "Optional node path scope")
	listCmd.Flags().IntVar(&groupListMax, "max", 0, "Max returned rows (0 means no limit)")
	listCmd.Flags().IntVar(&groupListTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return listCmd
}
