package runcmd

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func newInputEventCommand(deps shared.Deps) *cobra.Command {
	var eventJSON string
	var timeoutMS int

	cmd := &cobra.Command{
		Use:   "event",
		Short: "Dispatch one runtime input event payload",
		RunE: func(cmd *cobra.Command, _ []string) error {
			trimmedEventJSON := strings.TrimSpace(eventJSON)
			if trimmedEventJSON == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--event is required"))
			}

			var payload any
			if err := json.Unmarshal([]byte(trimmedEventJSON), &payload); err != nil {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--event must be valid JSON object"))
			}
			eventPayload, ok := payload.(map[string]any)
			if !ok {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--event must be JSON object"))
			}

			callReq := client.ToolCallRequest{
				Tool: "run.input_event",
				Args: map[string]any{
					"event": eventPayload,
				},
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
				Text:    fmt.Sprintf("run input event ok (request_id=%s)", resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "runtime input event dispatched"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&eventJSON, "event", "", "Runtime input event JSON object payload")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}

func newInputActionPressCommand(deps shared.Deps) *cobra.Command {
	var action string
	var strength float64
	var timeoutMS int

	cmd := &cobra.Command{
		Use:   "press",
		Short: "Press one runtime input action",
		RunE: func(cmd *cobra.Command, _ []string) error {
			trimmedAction := strings.TrimSpace(action)
			if trimmedAction == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--action is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "run.input_action_press",
				Args: map[string]any{
					"action":   trimmedAction,
					"strength": strength,
				},
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
				Text:    fmt.Sprintf("run input action press ok: %s (request_id=%s)", trimmedAction, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "runtime input action pressed"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&action, "action", "", "Runtime input action name")
	cmd.Flags().Float64Var(&strength, "strength", 1.0, "Runtime input action strength")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}

func newInputActionReleaseCommand(deps shared.Deps) *cobra.Command {
	var action string
	var timeoutMS int

	cmd := &cobra.Command{
		Use:   "release",
		Short: "Release one runtime input action",
		RunE: func(cmd *cobra.Command, _ []string) error {
			trimmedAction := strings.TrimSpace(action)
			if trimmedAction == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--action is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "run.input_action_release",
				Args: map[string]any{
					"action": trimmedAction,
				},
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
				Text:    fmt.Sprintf("run input action release ok: %s (request_id=%s)", trimmedAction, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "runtime input action released"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&action, "action", "", "Runtime input action name")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}
