package runcmd

import (
	"fmt"
	"strings"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func newLogsCommand(deps shared.Deps) *cobra.Command {
	var cursor int
	var maxRows int
	var level string
	var contains string
	var follow bool
	var followMS int
	var timeoutMS int

	cmd := &cobra.Command{
		Use:   "logs",
		Short: "List captured runtime logs",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if cursor < 0 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--cursor must be >= 0"))
			}
			if maxRows < 0 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--max must be >= 0"))
			}
			if followMS < 0 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--follow-ms must be >= 0"))
			}

			args := map[string]any{
				"cursor":   cursor,
				"max":      maxRows,
				"level":    strings.TrimSpace(level),
				"contains": strings.TrimSpace(contains),
			}
			if follow {
				args["follow_window_msec"] = followMS
			}

			callReq := client.ToolCallRequest{
				Tool: "run.logs",
				Args: args,
			}
			if timeoutMS > 0 {
				callReq.TimeoutMS = timeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			count := shared.ToolResultDataInt(resp.Result, "returned_count", 0)
			nextCursor := shared.ToolResultDataInt(resp.Result, "next_cursor", cursor)

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("run logs ok: rows=%d next_cursor=%d (request_id=%s)", count, nextCursor, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "runtime logs listed"),
				},
			})
		},
	}

	cmd.Flags().IntVar(&cursor, "cursor", 0, "Return logs with cursor greater than this value")
	cmd.Flags().IntVar(&maxRows, "max", 200, "Max returned log rows (0 means no limit)")
	cmd.Flags().StringVar(&level, "level", "", "Optional exact lowercase level filter")
	cmd.Flags().StringVar(&contains, "contains", "", "Optional log message substring filter")
	cmd.Flags().BoolVar(&follow, "follow", false, "Enable polling window for incremental log streaming")
	cmd.Flags().IntVar(&followMS, "follow-ms", 1000, "Polling window in milliseconds when --follow is enabled")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}

func newTreeCommand(deps shared.Deps) *cobra.Command {
	var maxRows int
	var timeoutMS int

	cmd := &cobra.Command{
		Use:   "tree",
		Short: "List runtime tree snapshot nodes",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if maxRows < 0 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--max must be >= 0"))
			}

			callReq := client.ToolCallRequest{
				Tool: "run.tree",
				Args: map[string]any{
					"max": maxRows,
				},
			}
			if timeoutMS > 0 {
				callReq.TimeoutMS = timeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			count := shared.ToolResultDataInt(resp.Result, "returned_count", 0)

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("run tree ok: nodes=%d (request_id=%s)", count, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "runtime tree listed"),
				},
			})
		},
	}

	cmd.Flags().IntVar(&maxRows, "max", 200, "Max returned node rows (0 means no limit)")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}

func newStepCommand(deps shared.Deps) *cobra.Command {
	var frames int
	var timeoutMS int

	cmd := &cobra.Command{
		Use:   "step",
		Short: "Step runtime forward by frame count",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if frames < 1 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--frames must be >= 1"))
			}

			callReq := client.ToolCallRequest{
				Tool: "run.step",
				Args: map[string]any{
					"frames": frames,
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
				Text:    fmt.Sprintf("run step ok: frames=%d (request_id=%s)", frames, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    shared.ToolResultMessage(resp.Result, "runtime step dispatched"),
				},
			})
		},
	}

	cmd.Flags().IntVar(&frames, "frames", 1, "Frame count to step (1-120)")
	cmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return cmd
}
