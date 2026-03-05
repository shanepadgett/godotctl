package resourcecmd

import (
	"fmt"
	"strings"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func newRefsCommand(deps shared.Deps) *cobra.Command {
	var resourcePath string
	var fromPrefix string
	var maxRefs int
	var countOnly bool
	var timeoutMS int

	refsCmd := &cobra.Command{
		Use:     "refs",
		Short:   "List reverse references for a resource",
		Example: "  godotctl resource refs --path scenes/player.tscn",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(resourcePath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if maxRefs < 0 {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--max-refs must be >= 0"))
			}

			callReq := client.ToolCallRequest{
				Tool: "resource.refs",
				Args: map[string]any{
					"path":               resourcePath,
					"from_prefix":        strings.TrimSpace(fromPrefix),
					"include_references": !countOnly,
					"max_refs":           maxRefs,
				},
			}
			if timeoutMS > 0 {
				callReq.TimeoutMS = timeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "resource references listed")
			resolvedPath := shared.ToolResultDataString(resp.Result, "resource_path", strings.TrimSpace(resourcePath))
			count := shared.ToolResultDataInt(resp.Result, "count", 0)
			returnedCount := shared.ToolResultDataInt(resp.Result, "returned_count", 0)

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("resource refs ok: %s (references=%d returned=%d, request_id=%s)", resolvedPath, count, returnedCount, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	refsCmd.Flags().StringVar(&resourcePath, "path", "", "Project-relative resource path")
	refsCmd.Flags().StringVar(&fromPrefix, "from-prefix", "", "Optional source path prefix filter")
	refsCmd.Flags().IntVar(&maxRefs, "max-refs", 200, "Max returned reference rows (0 means no limit)")
	refsCmd.Flags().BoolVar(&countOnly, "count-only", false, "Return counts only without reference rows")
	refsCmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return refsCmd
}
