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

func newSettingsGetCommand(deps shared.Deps) *cobra.Command {
	var settingsKey string
	var settingsPrefix string
	var settingsIncludeValues bool
	var settingsCountOnly bool
	var settingsMax int
	var settingsTimeoutMS int

	settingsGetCmd := &cobra.Command{
		Use:     "get",
		Short:   "Get project settings",
		Example: "  godotctl project settings get --key application/config/name",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if settingsMax < 0 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--max-settings must be >= 0"))
			}

			trimmedKey := strings.TrimSpace(settingsKey)
			trimmedPrefix := strings.TrimSpace(settingsPrefix)
			if trimmedKey != "" && trimmedPrefix != "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--key and --prefix cannot be used together"))
			}

			if settingsCountOnly && settingsIncludeValues {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--include-values cannot be used with --count-only"))
			}

			includeSettings := !settingsCountOnly
			includeValues := settingsIncludeValues
			if trimmedKey != "" && includeSettings && !cmd.Flags().Changed("include-values") {
				includeValues = true
			}

			callReq := client.ToolCallRequest{
				Tool: "project.settings_get",
				Args: map[string]any{
					"key":              trimmedKey,
					"prefix":           trimmedPrefix,
					"include_settings": includeSettings,
					"include_values":   includeValues,
					"max_settings":     settingsMax,
				},
			}
			if settingsTimeoutMS > 0 {
				callReq.TimeoutMS = settingsTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "project settings retrieved")
			requestedKey := shared.ToolResultDataString(resp.Result, "requested_key", trimmedKey)
			count := shared.ToolResultDataInt(resp.Result, "count", 0)
			returnedCount := shared.ToolResultDataInt(resp.Result, "returned_count", 0)

			text := fmt.Sprintf("project settings get ok: settings=%d returned=%d (request_id=%s)", count, returnedCount, resp.RequestID)
			if requestedKey != "" {
				text = fmt.Sprintf("project settings get ok: %s (returned=%d, request_id=%s)", requestedKey, returnedCount, resp.RequestID)
			}

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    text,
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	settingsGetCmd.Flags().StringVar(&settingsKey, "key", "", "Optional project setting key")
	settingsGetCmd.Flags().StringVar(&settingsPrefix, "prefix", "", "Optional setting key prefix filter")
	settingsGetCmd.Flags().BoolVar(&settingsIncludeValues, "include-values", false, "Include serialized setting values")
	settingsGetCmd.Flags().BoolVar(&settingsCountOnly, "count-only", false, "Return counts only without setting rows")
	settingsGetCmd.Flags().IntVar(&settingsMax, "max-settings", 200, "Max returned setting rows (0 means no limit)")
	settingsGetCmd.Flags().IntVar(&settingsTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return settingsGetCmd
}
