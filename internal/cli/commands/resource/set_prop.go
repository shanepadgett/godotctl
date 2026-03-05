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

func newSetPropCommand(deps shared.Deps) *cobra.Command {
	var setPropPath string
	var setPropName string
	var setPropValue string
	var setPropTimeoutMS int

	setPropCmd := &cobra.Command{
		Use:     "set-prop",
		Short:   "Set a resource property from JSON value",
		Example: "  godotctl resource set-prop --path data/player.tres --prop resource_name --value '\"Player\"'",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(setPropPath) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--path is required"))
			}
			if strings.TrimSpace(setPropName) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--prop is required"))
			}
			if strings.TrimSpace(setPropValue) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--value is required"))
			}

			callReq := client.ToolCallRequest{
				Tool: "resource.set_prop",
				Args: map[string]any{
					"path":       setPropPath,
					"prop":       setPropName,
					"value_json": setPropValue,
				},
			}
			if setPropTimeoutMS > 0 {
				callReq.TimeoutMS = setPropTimeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "resource property set")
			resourcePath := shared.ToolResultDataString(resp.Result, "resource_path", strings.TrimSpace(setPropPath))
			propName := shared.ToolResultDataString(resp.Result, "property", strings.TrimSpace(setPropName))

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("resource set-prop ok: %s.%s (request_id=%s)", resourcePath, propName, resp.RequestID),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	setPropCmd.Flags().StringVar(&setPropPath, "path", "", "Resource path (project-relative)")
	setPropCmd.Flags().StringVar(&setPropName, "prop", "", "Property name")
	setPropCmd.Flags().StringVar(&setPropValue, "value", "", "Property value JSON (primitive or typed object)")
	setPropCmd.Flags().IntVar(&setPropTimeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return setPropCmd
}
