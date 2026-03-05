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
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if strings.TrimSpace(createRootType) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--root is required"))
			}
			if strings.TrimSpace(createRootName) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--name is required"))
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

			resp, err := a.client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return a.fail(cmd, err)
			}

			resultMessage := toolResultMessage(resp.Result, "scene created")
			createdPath := toolResultDataString(resp.Result, "scene_path", strings.TrimSpace(createScenePath))

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

	createCmd.Flags().StringVar(&createScenePath, "scene", "", "Scene path (project-relative .tscn path)")
	createCmd.Flags().StringVar(&createRootType, "root", "", "Root node type")
	createCmd.Flags().StringVar(&createRootName, "name", "", "Root node name")
	createCmd.Flags().BoolVar(&createOverwrite, "overwrite", false, "Overwrite existing scene")
	createCmd.Flags().BoolVar(&createOpenInEditor, "open", false, "Open scene in editor after create")
	createCmd.Flags().IntVar(&createTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")
	sceneCmd.AddCommand(createCmd)

	var addScenePath string
	var addNodeName string
	var addNodeType string
	var addParentPath string
	var addTimeoutMS int

	addNodeCmd := &cobra.Command{
		Use:     "add-node",
		Short:   "Add a node under a parent path",
		Example: "  godotctl scene add-node --scene scenes/player.tscn --name Sprite2D --type Sprite2D --parent .",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(addScenePath) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if strings.TrimSpace(addNodeName) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--name is required"))
			}
			if strings.TrimSpace(addNodeType) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--type is required"))
			}
			if strings.TrimSpace(addParentPath) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--parent is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "scene.add_node",
				Args: map[string]any{
					"scene_path":  addScenePath,
					"node_name":   addNodeName,
					"node_type":   addNodeType,
					"parent_path": addParentPath,
				},
			}
			if addTimeoutMS > 0 {
				callReq.TimeoutMS = addTimeoutMS
			}

			resp, err := a.client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return a.fail(cmd, err)
			}

			resultMessage := toolResultMessage(resp.Result, "node added")
			nodePath := toolResultDataString(resp.Result, "node_path", strings.TrimSpace(addNodeName))

			return a.presenter.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("scene add-node ok: %s (request_id=%s)", nodePath, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	addNodeCmd.Flags().StringVar(&addScenePath, "scene", "", "Scene path (project-relative .tscn path)")
	addNodeCmd.Flags().StringVar(&addNodeName, "name", "", "Node name to add")
	addNodeCmd.Flags().StringVar(&addNodeType, "type", "", "Node class to instantiate")
	addNodeCmd.Flags().StringVar(&addParentPath, "parent", "", "Parent node path (use . for root)")
	addNodeCmd.Flags().IntVar(&addTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")
	sceneCmd.AddCommand(addNodeCmd)

	var removeScenePath string
	var removeNodePath string
	var removeTimeoutMS int

	removeNodeCmd := &cobra.Command{
		Use:     "remove-node",
		Short:   "Remove a node from a scene",
		Example: "  godotctl scene remove-node --scene scenes/player.tscn --path Sprite2D",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(removeScenePath) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if strings.TrimSpace(removeNodePath) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "scene.remove_node",
				Args: map[string]any{
					"scene_path": removeScenePath,
					"node_path":  removeNodePath,
				},
			}
			if removeTimeoutMS > 0 {
				callReq.TimeoutMS = removeTimeoutMS
			}

			resp, err := a.client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return a.fail(cmd, err)
			}

			resultMessage := toolResultMessage(resp.Result, "node removed")
			removedPath := toolResultDataString(resp.Result, "removed_path", strings.TrimSpace(removeNodePath))

			return a.presenter.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("scene remove-node ok: %s (request_id=%s)", removedPath, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	removeNodeCmd.Flags().StringVar(&removeScenePath, "scene", "", "Scene path (project-relative .tscn path)")
	removeNodeCmd.Flags().StringVar(&removeNodePath, "path", "", "Node path to remove (use . for root)")
	removeNodeCmd.Flags().IntVar(&removeTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")
	sceneCmd.AddCommand(removeNodeCmd)

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
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if strings.TrimSpace(setPropNodePath) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if strings.TrimSpace(setPropName) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--prop is required"))
			}
			if strings.TrimSpace(setPropValue) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--value is required"))
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

			resp, err := a.client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return a.fail(cmd, err)
			}

			resultMessage := toolResultMessage(resp.Result, "property set")
			nodePath := toolResultDataString(resp.Result, "node_path", strings.TrimSpace(setPropNodePath))
			propertyName := toolResultDataString(resp.Result, "property", strings.TrimSpace(setPropName))

			return a.presenter.Success(output.Result{
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
	sceneCmd.AddCommand(setPropCmd)

	var treeScenePath string
	var treeTimeoutMS int

	treeCmd := &cobra.Command{
		Use:     "tree",
		Short:   "List scene nodes with deterministic paths",
		Example: "  godotctl scene tree --scene scenes/player.tscn",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(treeScenePath) == "" {
				return a.fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
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

			resp, err := a.client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return a.fail(cmd, err)
			}

			resultMessage := toolResultMessage(resp.Result, "scene tree ready")
			listedPath := toolResultDataString(resp.Result, "scene_path", strings.TrimSpace(treeScenePath))
			nodeCount := 0
			if data := toolResultData(resp.Result); data != nil {
				if nodes, ok := data["nodes"].([]any); ok {
					nodeCount = len(nodes)
				}
			}

			return a.presenter.Success(output.Result{
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
	sceneCmd.AddCommand(treeCmd)

	return sceneCmd
}

func toolResultMessage(result map[string]any, fallback string) string {
	message := strings.TrimSpace(fallback)
	if message == "" {
		message = "operation completed"
	}

	if value, ok := result["message"].(string); ok {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			message = trimmed
		}
	}

	return message
}

func toolResultData(result map[string]any) map[string]any {
	if value, ok := result["data"].(map[string]any); ok {
		return value
	}

	return nil
}

func toolResultDataString(result map[string]any, key string, fallback string) string {
	value := strings.TrimSpace(fallback)
	if data := toolResultData(result); data != nil {
		if raw, ok := data[key].(string); ok {
			if trimmed := strings.TrimSpace(raw); trimmed != "" {
				value = trimmed
			}
		}
	}

	return value
}

func toolResultDataInt(result map[string]any, key string, fallback int) int {
	value := fallback
	if data := toolResultData(result); data != nil {
		if converted, ok := anyToInt(data[key]); ok {
			value = converted
		}
	}

	return value
}

func anyToInt(value any) (int, bool) {
	switch n := value.(type) {
	case int:
		return n, true
	case int8:
		return int(n), true
	case int16:
		return int(n), true
	case int32:
		return int(n), true
	case int64:
		return int(n), true
	case uint:
		return int(n), true
	case uint8:
		return int(n), true
	case uint16:
		return int(n), true
	case uint32:
		return int(n), true
	case uint64:
		return int(n), true
	case float32:
		return int(n), true
	case float64:
		return int(n), true
	default:
		return 0, false
	}
}
