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

func newGetCommand(deps shared.Deps) *cobra.Command {
	var getPath string
	var getProp string
	var getTimeoutMS int

	getCmd := &cobra.Command{
		Use:     "get",
		Short:   "Get one resource property",
		Example: "  godotctl resource get --path data/player.tres --prop resource_name",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(getPath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if strings.TrimSpace(getProp) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--prop is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "resource.get",
				Args: map[string]any{
					"path": getPath,
					"prop": getProp,
				},
			}
			if getTimeoutMS > 0 {
				callReq.TimeoutMS = getTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "resource property retrieved")
			resourcePath := shared.ToolResultDataString(resp.Result, "resource_path", strings.TrimSpace(getPath))
			propName := shared.ToolResultDataString(resp.Result, "property", strings.TrimSpace(getProp))

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("resource get ok: %s.%s (request_id=%s)", resourcePath, propName, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	getCmd.Flags().StringVar(&getPath, "path", "", "Resource path (project-relative)")
	getCmd.Flags().StringVar(&getProp, "prop", "", "Property name")
	getCmd.Flags().IntVar(&getTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return getCmd
}
