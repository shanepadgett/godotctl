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

func newInputMapDeadzoneSetCommand(deps shared.Deps) *cobra.Command {
	var actionName string
	var value float64
	var timeoutMS int

	cmd := &cobra.Command{
		Use:     "set",
		Short:   "Set one input action deadzone",
		Example: "  godotctl project input-map deadzone set --action ui_accept --value 0.5",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(actionName) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--action is required"))
			}
			if value < 0 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--value must be >= 0"))
			}

			callReq := client.ToolCallRequest{
				Tool: "project.input_map_deadzone_set",
				Args: map[string]any{
					"action": actionName,
					"value":  value,
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
				Text:    fmt.Sprintf("project input-map deadzone set ok: %s (request_id=%s)", strings.TrimSpace(actionName), resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "input deadzone set"),
				},
			})
		},
	}

	cmd.Flags().StringVar(&actionName, "action", "", "Input action name")
	cmd.Flags().Float64Var(&value, "value", 0.5, "Deadzone value")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}
