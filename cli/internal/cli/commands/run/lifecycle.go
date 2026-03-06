package runcmd

import (
	"fmt"
	"strings"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func newStartCommand(deps shared.Deps) *cobra.Command {
	var scenePath string
	var timeoutMS int

	cmd := &cobra.Command{
		Use:   "start",
		Short: "Start runtime in editor",
		RunE: func(cmd *cobra.Command, _ []string) error {
			callReq := client.ToolCallRequest{
				Tool: "run.start",
				Args: map[string]any{},
			}
			if trimmedScenePath := strings.TrimSpace(scenePath); trimmedScenePath != "" {
				callReq.Args["scene_path"] = trimmedScenePath
			}
			if timeoutMS > 0 {
				callReq.TimeoutMS = timeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			text := fmt.Sprintf("run start ok (request_id=%s)", resp.RequestID)
			if trimmedScenePath := strings.TrimSpace(scenePath); trimmedScenePath != "" {
				text = fmt.Sprintf("run start ok: %s (request_id=%s)", trimmedScenePath, resp.RequestID)
			}

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    text,
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "runtime started"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&scenePath, "scene", "", "Optional scene path to run")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}

func newStopCommand(deps shared.Deps) *cobra.Command {
	var timeoutMS int

	cmd := &cobra.Command{
		Use:   "stop",
		Short: "Stop runtime in editor",
		RunE: func(cmd *cobra.Command, _ []string) error {
			callReq := client.ToolCallRequest{
				Tool: "run.stop",
				Args: map[string]any{},
			}
			if timeoutMS > 0 {
				callReq.TimeoutMS = timeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("run stop ok (request_id=%s)", resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "runtime stopped"),
				},
			})
		},
	}

	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}

func newStatusCommand(deps shared.Deps) *cobra.Command {
	var timeoutMS int

	cmd := &cobra.Command{
		Use:   "status",
		Short: "Read runtime status",
		RunE: func(cmd *cobra.Command, _ []string) error {
			callReq := client.ToolCallRequest{
				Tool: "run.status",
				Args: map[string]any{},
			}
			if timeoutMS > 0 {
				callReq.TimeoutMS = timeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("run status ok (request_id=%s)", resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "runtime status read"),
				},
			})
		},
	}

	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}
