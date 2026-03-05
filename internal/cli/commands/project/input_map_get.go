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

func newInputMapGetCommand(deps shared.Deps) *cobra.Command {
	var inputAction string
	var inputPrefix string
	var includeEvents bool
	var countOnly bool
	var maxActions int
	var maxEvents int
	var inputTimeoutMS int

	inputMapGetCmd := &cobra.Command{
		Use:     "get",
		Short:   "Get input map actions and events",
		Example: "  godotctl project input-map get --action ui_accept",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if maxActions < 0 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--max-actions must be >= 0"))
			}
			if maxEvents < 0 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--max-events must be >= 0"))
			}
			if countOnly && includeEvents {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--include-events cannot be used with --count-only"))
			}

			trimmedAction := strings.TrimSpace(inputAction)
			trimmedPrefix := strings.TrimSpace(inputPrefix)
			if trimmedAction != "" && trimmedPrefix != "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--action and --prefix cannot be used together"))
			}

			includeActions := !countOnly
			effectiveIncludeEvents := includeEvents
			if trimmedAction != "" && includeActions && !cmd.Flags().Changed("include-events") {
				effectiveIncludeEvents = true
			}

			callReq := client.ToolCallRequest{
				Tool: "project.input_map_get",
				Args: map[string]any{
					"action":          trimmedAction,
					"prefix":          trimmedPrefix,
					"include_actions": includeActions,
					"include_events":  effectiveIncludeEvents,
					"max_actions":     maxActions,
					"max_events":      maxEvents,
				},
			}
			if inputTimeoutMS > 0 {
				callReq.TimeoutMS = inputTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "project input map retrieved")
			requestedAction := shared.ToolResultDataString(resp.Result, "requested_action", trimmedAction)
			actionCount := shared.ToolResultDataInt(resp.Result, "count", 0)
			returnedActionCount := shared.ToolResultDataInt(resp.Result, "returned_count", 0)
			totalEventCount := shared.ToolResultDataInt(resp.Result, "total_event_count", 0)
			returnedEventCount := shared.ToolResultDataInt(resp.Result, "returned_event_count", 0)

			text := fmt.Sprintf("project input-map get ok: actions=%d events=%d returned_actions=%d returned_events=%d (request_id=%s)", actionCount, totalEventCount, returnedActionCount, returnedEventCount, resp.RequestID)
			if requestedAction != "" {
				text = fmt.Sprintf("project input-map get ok: %s (events=%d returned_events=%d, request_id=%s)", requestedAction, totalEventCount, returnedEventCount, resp.RequestID)
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

	inputMapGetCmd.Flags().StringVar(&inputAction, "action", "", "Optional input action name")
	inputMapGetCmd.Flags().StringVar(&inputPrefix, "prefix", "", "Optional action name prefix filter")
	inputMapGetCmd.Flags().BoolVar(&includeEvents, "include-events", false, "Include summarized input events in action rows")
	inputMapGetCmd.Flags().BoolVar(&countOnly, "count-only", false, "Return counts only without action rows")
	inputMapGetCmd.Flags().IntVar(&maxActions, "max-actions", 200, "Max returned action rows (0 means no limit)")
	inputMapGetCmd.Flags().IntVar(&maxEvents, "max-events", 200, "Max returned events per action (0 means no limit)")
	inputMapGetCmd.Flags().IntVar(&inputTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return inputMapGetCmd
}
