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

func newInputMapEventAddCommand(deps shared.Deps) *cobra.Command {
	var actionName string
	var eventValue string
	var timeoutMS int

	cmd := &cobra.Command{
		Use:     "add",
		Short:   "Add one input event to an action",
		Example: "  godotctl project input-map event add --action ui_accept --event '{\"type\":\"key\",\"keycode\":4194309}'",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(actionName) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--action is required"))
			}
			if strings.TrimSpace(eventValue) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--event is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "project.input_map_event_add",
				Args: map[string]any{
					"action":     actionName,
					"event_json": eventValue,
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
				Text:    fmt.Sprintf("project input-map event add ok: %s (request_id=%s)", strings.TrimSpace(actionName), resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "input event added"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&actionName, "action", "", "Input action name")
	cmd.Flags().StringVar(&eventValue, "event", "", "Input event JSON")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}

func newInputMapEventRemoveCommand(deps shared.Deps) *cobra.Command {
	var actionName string
	var eventValue string
	var timeoutMS int

	cmd := &cobra.Command{
		Use:     "remove",
		Short:   "Remove one input event from an action",
		Example: "  godotctl project input-map event remove --action ui_accept --event '{\"type\":\"key\",\"keycode\":4194309}'",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(actionName) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--action is required"))
			}
			if strings.TrimSpace(eventValue) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--event is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "project.input_map_event_remove",
				Args: map[string]any{
					"action":     actionName,
					"event_json": eventValue,
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
				Text:    fmt.Sprintf("project input-map event remove ok: %s (request_id=%s)", strings.TrimSpace(actionName), resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "input event removed"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&actionName, "action", "", "Input action name")
	cmd.Flags().StringVar(&eventValue, "event", "", "Input event JSON")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}
