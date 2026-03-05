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

func newSignalConnectCommand(deps shared.Deps) *cobra.Command {
	var signalConnectScenePath string
	var signalConnectFrom string
	var signalConnectSignal string
	var signalConnectTo string
	var signalConnectMethod string
	var signalConnectFlags int
	var signalConnectTimeoutMS int

	connectCmd := &cobra.Command{
		Use:     "connect",
		Short:   "Connect a scene signal to a target method",
		Example: "  godotctl scene signal connect --scene scenes/player.tscn --from . --signal ready --to . --method _on_ready",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(signalConnectScenePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if strings.TrimSpace(signalConnectFrom) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--from is required"))
			}
			if strings.TrimSpace(signalConnectSignal) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--signal is required"))
			}
			if strings.TrimSpace(signalConnectTo) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--to is required"))
			}
			if strings.TrimSpace(signalConnectMethod) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--method is required"))
			}
			if cmd.Flags().Changed("flags") && signalConnectFlags < 0 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--flags must be >= 0"))
			}

			args := map[string]any{
				"scene_path": signalConnectScenePath,
				"from_node":  signalConnectFrom,
				"signal":     signalConnectSignal,
				"to_target":  signalConnectTo,
				"method":     signalConnectMethod,
			}
			if cmd.Flags().Changed("flags") {
				args["flags"] = signalConnectFlags
			}

			callReq := client.ToolCallRequest{
				Tool: "scene.signal_connect",
				Args: args,
			}
			if signalConnectTimeoutMS > 0 {
				callReq.TimeoutMS = signalConnectTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "signal connected")
			fromNode := shared.ToolResultDataString(resp.Result, "from_node", strings.TrimSpace(signalConnectFrom))
			signalName := shared.ToolResultDataString(resp.Result, "signal", strings.TrimSpace(signalConnectSignal))
			toTarget := shared.ToolResultDataString(resp.Result, "to_target", strings.TrimSpace(signalConnectTo))
			methodName := shared.ToolResultDataString(resp.Result, "method", strings.TrimSpace(signalConnectMethod))

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text: fmt.Sprintf(
					"scene signal connect ok: %s.%s -> %s.%s (request_id=%s)",
					fromNode,
					signalName,
					toTarget,
					methodName,
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

	connectCmd.Flags().StringVar(&signalConnectScenePath, "scene", "", "Scene path (project-relative .tscn path)")
	connectCmd.Flags().StringVar(&signalConnectFrom, "from", "", "Source node path")
	connectCmd.Flags().StringVar(&signalConnectSignal, "signal", "", "Signal name")
	connectCmd.Flags().StringVar(&signalConnectTo, "to", "", "Target node path")
	connectCmd.Flags().StringVar(&signalConnectMethod, "method", "", "Target method name")
	connectCmd.Flags().IntVar(&signalConnectFlags, "flags", 0, "Optional connection flags")
	connectCmd.Flags().IntVar(&signalConnectTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return connectCmd
}

func newSignalDisconnectCommand(deps shared.Deps) *cobra.Command {
	var signalDisconnectScenePath string
	var signalDisconnectFrom string
	var signalDisconnectSignal string
	var signalDisconnectTo string
	var signalDisconnectMethod string
	var signalDisconnectFlags int
	var signalDisconnectTimeoutMS int

	disconnectCmd := &cobra.Command{
		Use:     "disconnect",
		Short:   "Disconnect a scene signal target method",
		Example: "  godotctl scene signal disconnect --scene scenes/player.tscn --from . --signal ready --to . --method _on_ready",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(signalDisconnectScenePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if strings.TrimSpace(signalDisconnectFrom) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--from is required"))
			}
			if strings.TrimSpace(signalDisconnectSignal) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--signal is required"))
			}
			if strings.TrimSpace(signalDisconnectTo) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--to is required"))
			}
			if strings.TrimSpace(signalDisconnectMethod) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--method is required"))
			}
			if cmd.Flags().Changed("flags") && signalDisconnectFlags < 0 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--flags must be >= 0"))
			}

			args := map[string]any{
				"scene_path": signalDisconnectScenePath,
				"from_node":  signalDisconnectFrom,
				"signal":     signalDisconnectSignal,
				"to_target":  signalDisconnectTo,
				"method":     signalDisconnectMethod,
			}
			if cmd.Flags().Changed("flags") {
				args["flags"] = signalDisconnectFlags
			}

			callReq := client.ToolCallRequest{
				Tool: "scene.signal_disconnect",
				Args: args,
			}
			if signalDisconnectTimeoutMS > 0 {
				callReq.TimeoutMS = signalDisconnectTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "signal disconnected")
			fromNode := shared.ToolResultDataString(resp.Result, "from_node", strings.TrimSpace(signalDisconnectFrom))
			signalName := shared.ToolResultDataString(resp.Result, "signal", strings.TrimSpace(signalDisconnectSignal))
			toTarget := shared.ToolResultDataString(resp.Result, "to_target", strings.TrimSpace(signalDisconnectTo))
			methodName := shared.ToolResultDataString(resp.Result, "method", strings.TrimSpace(signalDisconnectMethod))

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text: fmt.Sprintf(
					"scene signal disconnect ok: %s.%s -> %s.%s (request_id=%s)",
					fromNode,
					signalName,
					toTarget,
					methodName,
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

	disconnectCmd.Flags().StringVar(&signalDisconnectScenePath, "scene", "", "Scene path (project-relative .tscn path)")
	disconnectCmd.Flags().StringVar(&signalDisconnectFrom, "from", "", "Source node path")
	disconnectCmd.Flags().StringVar(&signalDisconnectSignal, "signal", "", "Signal name")
	disconnectCmd.Flags().StringVar(&signalDisconnectTo, "to", "", "Target node path")
	disconnectCmd.Flags().StringVar(&signalDisconnectMethod, "method", "", "Target method name")
	disconnectCmd.Flags().IntVar(&signalDisconnectFlags, "flags", 0, "Optional connection flags")
	disconnectCmd.Flags().IntVar(&signalDisconnectTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return disconnectCmd
}

func newSignalListCommand(deps shared.Deps) *cobra.Command {
	var signalListScenePath string
	var signalListFrom string
	var signalListSignal string
	var signalListTo string
	var signalListMethod string
	var signalListMax int
	var signalListTimeoutMS int

	listCmd := &cobra.Command{
		Use:     "list",
		Short:   "List signal connections in a scene",
		Example: "  godotctl scene signal list --scene scenes/player.tscn",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(signalListScenePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--scene is required"))
			}
			if signalListMax < 0 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--max must be >= 0"))
			}

			args := map[string]any{
				"scene_path": signalListScenePath,
				"max":        signalListMax,
			}
			if value := strings.TrimSpace(signalListFrom); value != "" {
				args["from_node"] = value
			}
			if value := strings.TrimSpace(signalListSignal); value != "" {
				args["signal"] = value
			}
			if value := strings.TrimSpace(signalListTo); value != "" {
				args["to_target"] = value
			}
			if value := strings.TrimSpace(signalListMethod); value != "" {
				args["method"] = value
			}

			callReq := client.ToolCallRequest{
				Tool: "scene.signal_list",
				Args: args,
			}
			if signalListTimeoutMS > 0 {
				callReq.TimeoutMS = signalListTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "signal connections listed")
			listedPath := shared.ToolResultDataString(resp.Result, "scene_path", strings.TrimSpace(signalListScenePath))
			count := shared.ToolResultDataInt(resp.Result, "count", 0)
			returnedCount := shared.ToolResultDataInt(resp.Result, "returned_count", 0)

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("scene signal list ok: %s (connections=%d returned=%d, request_id=%s)", listedPath, count, returnedCount, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	listCmd.Flags().StringVar(&signalListScenePath, "scene", "", "Scene path (project-relative .tscn path)")
	listCmd.Flags().StringVar(&signalListFrom, "from", "", "Optional source node path filter")
	listCmd.Flags().StringVar(&signalListSignal, "signal", "", "Optional signal filter")
	listCmd.Flags().StringVar(&signalListTo, "to", "", "Optional target node path filter")
	listCmd.Flags().StringVar(&signalListMethod, "method", "", "Optional method filter")
	listCmd.Flags().IntVar(&signalListMax, "max", 0, "Max returned rows (0 means no limit)")
	listCmd.Flags().IntVar(&signalListTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return listCmd
}
