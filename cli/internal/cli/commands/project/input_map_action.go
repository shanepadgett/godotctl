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

func newInputMapActionCreateCommand(deps shared.Deps) *cobra.Command {
	var actionName string
	var deadzone float64
	var timeoutMS int

	cmd := &cobra.Command{
		Use:     "create",
		Short:   "Create one input action",
		Example: "  godotctl project input-map action create --action ui_accept --deadzone 0.5",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(actionName) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--action is required"))
			}
			if deadzone < 0 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--deadzone must be >= 0"))
			}

			callReq := client.ToolCallRequest{
				Tool: "project.input_map_action_create",
				Args: map[string]any{
					"action":   actionName,
					"deadzone": deadzone,
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
				Text:    fmt.Sprintf("project input-map action create ok: %s (request_id=%s)", strings.TrimSpace(actionName), resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "input action created"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&actionName, "action", "", "Input action name")
	cmd.Flags().Float64Var(&deadzone, "deadzone", 0.5, "Action deadzone")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}

func newInputMapActionDeleteCommand(deps shared.Deps) *cobra.Command {
	var actionName string
	var timeoutMS int

	cmd := &cobra.Command{
		Use:     "delete",
		Short:   "Delete one input action",
		Example: "  godotctl project input-map action delete --action ui_accept",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(actionName) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--action is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "project.input_map_action_delete",
				Args: map[string]any{
					"action": actionName,
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
				Text:    fmt.Sprintf("project input-map action delete ok: %s (request_id=%s)", strings.TrimSpace(actionName), resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "input action deleted"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&actionName, "action", "", "Input action name")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}
