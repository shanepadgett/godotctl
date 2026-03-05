package app

import (
	"fmt"
	"strings"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func (a *App) newProjectCommand() *cobra.Command {
	projectCmd := &cobra.Command{
		Use:   "project",
		Short: "Project operations through the daemon",
	}

	settingsCmd := &cobra.Command{
		Use:   "settings",
		Short: "Project settings operations",
	}

	var settingsKey string
	var settingsTimeoutMS int

	settingsGetCmd := &cobra.Command{
		Use:     "get",
		Short:   "Get project settings",
		Example: "  godotctl project settings get --key application/config/name",
		RunE: func(cmd *cobra.Command, _ []string) error {
			callReq := client.ToolCallRequest{
				Tool: "project.settings_get",
				Args: map[string]any{
					"key": settingsKey,
				},
			}
			if settingsTimeoutMS > 0 {
				callReq.TimeoutMS = settingsTimeoutMS
			}

			resp, err := a.client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return a.fail(cmd, err)
			}

			resultMessage := toolResultMessage(resp.Result, "project settings retrieved")
			requestedKey := toolResultDataString(resp.Result, "requested_key", strings.TrimSpace(settingsKey))
			count := toolResultDataInt(resp.Result, "count", 0)

			text := fmt.Sprintf("project settings get ok: settings=%d (request_id=%s)", count, resp.RequestID)
			if requestedKey != "" {
				text = fmt.Sprintf("project settings get ok: %s (request_id=%s)", requestedKey, resp.RequestID)
			}

			return a.presenter.Success(output.Result{
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
	settingsGetCmd.Flags().IntVar(&settingsTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")
	settingsCmd.AddCommand(settingsGetCmd)
	projectCmd.AddCommand(settingsCmd)

	inputMapCmd := &cobra.Command{
		Use:   "input-map",
		Short: "Input map operations",
	}

	var inputAction string
	var inputTimeoutMS int

	inputMapGetCmd := &cobra.Command{
		Use:     "get",
		Short:   "Get input map actions and events",
		Example: "  godotctl project input-map get --action ui_accept",
		RunE: func(cmd *cobra.Command, _ []string) error {
			callReq := client.ToolCallRequest{
				Tool: "project.input_map_get",
				Args: map[string]any{
					"action": inputAction,
				},
			}
			if inputTimeoutMS > 0 {
				callReq.TimeoutMS = inputTimeoutMS
			}

			resp, err := a.client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return a.fail(cmd, err)
			}

			resultMessage := toolResultMessage(resp.Result, "project input map retrieved")
			requestedAction := toolResultDataString(resp.Result, "requested_action", strings.TrimSpace(inputAction))
			actionCount := toolResultDataInt(resp.Result, "count", 0)
			totalEventCount := toolResultDataInt(resp.Result, "total_event_count", 0)

			text := fmt.Sprintf("project input-map get ok: actions=%d events=%d (request_id=%s)", actionCount, totalEventCount, resp.RequestID)
			if requestedAction != "" {
				text = fmt.Sprintf("project input-map get ok: %s (events=%d, request_id=%s)", requestedAction, totalEventCount, resp.RequestID)
			}

			return a.presenter.Success(output.Result{
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

	inputMapGetCmd.Flags().StringVar(&inputAction, "action", "", "Optional input action name")
	inputMapGetCmd.Flags().IntVar(&inputTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")
	inputMapCmd.AddCommand(inputMapGetCmd)
	projectCmd.AddCommand(inputMapCmd)

	return projectCmd
}
