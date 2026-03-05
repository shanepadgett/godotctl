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

func newSettingsSetCommand(deps shared.Deps) *cobra.Command {
	var settingKey string
	var settingValue string
	var timeoutMS int

	cmd := &cobra.Command{
		Use:     "set",
		Short:   "Set one project setting from JSON value",
		Example: "  godotctl project settings set --key application/config/name --value '\"My Game\"'",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(settingKey) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--key is required"))
			}
			if strings.TrimSpace(settingValue) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--value is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "project.settings_set",
				Args: map[string]any{
					"key":        settingKey,
					"value_json": settingValue,
				},
			}
			if timeoutMS > 0 {
				callReq.TimeoutMS = timeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "project setting set")
			resolvedKey := shared.ToolResultDataString(resp.Result, "key", strings.TrimSpace(settingKey))

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("project settings set ok: %s (request_id=%s)", resolvedKey, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	cmd.Flags().StringVar(&settingKey, "key", "", "Project setting key")
	cmd.Flags().StringVar(&settingValue, "value", "", "Setting value JSON")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}
