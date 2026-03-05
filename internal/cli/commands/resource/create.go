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

func newCreateCommand(deps shared.Deps) *cobra.Command {
	var createPath string
	var createType string
	var createOverwrite bool
	var createTimeoutMS int

	createCmd := &cobra.Command{
		Use:     "create",
		Short:   "Create a resource file",
		Example: "  godotctl resource create --path data/player.tres --type Resource",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(createPath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if strings.TrimSpace(createType) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--type is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "resource.create",
				Args: map[string]any{
					"path":      createPath,
					"type":      createType,
					"overwrite": createOverwrite,
				},
			}
			if createTimeoutMS > 0 {
				callReq.TimeoutMS = createTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "resource created")
			resourcePath := shared.ToolResultDataString(resp.Result, "resource_path", strings.TrimSpace(createPath))

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("resource create ok: %s (request_id=%s)", resourcePath, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	createCmd.Flags().StringVar(&createPath, "path", "", "Resource path (project-relative)")
	createCmd.Flags().StringVar(&createType, "type", "", "Resource class name")
	createCmd.Flags().BoolVar(&createOverwrite, "overwrite", false, "Overwrite existing resource")
	createCmd.Flags().IntVar(&createTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return createCmd
}
