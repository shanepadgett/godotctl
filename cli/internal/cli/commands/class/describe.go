package classcmd

import (
	"fmt"
	"strings"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func newDescribeCommand(deps shared.Deps) *cobra.Command {
	var className string
	var timeoutMS int
	var includeProperties bool
	var includeMethods bool
	var includeSignals bool
	var includeInheritors bool
	var includeAll bool

	describeCmd := &cobra.Command{
		Use:     "describe",
		Short:   "Describe one Godot class",
		Example: "  godotctl class describe --name CharacterBody2D",
		RunE: func(cmd *cobra.Command, _ []string) error {
			if strings.TrimSpace(className) == "" {
				return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "--name is required"))
			}

			if includeAll {
				includeProperties = true
				includeMethods = true
				includeSignals = true
				includeInheritors = true
			}

			callReq := client.ToolCallRequest{
				Tool: "class.describe",
				Args: map[string]any{
					"name":               className,
					"include_properties": includeProperties,
					"include_methods":    includeMethods,
					"include_signals":    includeSignals,
					"include_inheritors": includeInheritors,
				},
			}
			if timeoutMS > 0 {
				callReq.TimeoutMS = timeoutMS
			}

			resp, err := deps.Client.CallTool(cmd.Context(), callReq)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			resultMessage := shared.ToolResultMessage(resp.Result, "class metadata retrieved")
			resolvedName := shared.ToolResultDataString(resp.Result, "class_name", strings.TrimSpace(className))
			propertyCount := shared.ToolResultDataInt(resp.Result, "property_count", 0)
			methodCount := shared.ToolResultDataInt(resp.Result, "method_count", 0)
			signalCount := shared.ToolResultDataInt(resp.Result, "signal_count", 0)

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text: fmt.Sprintf(
					"class describe ok: %s (properties=%d, methods=%d, signals=%d, request_id=%s)",
					resolvedName,
					propertyCount,
					methodCount,
					signalCount,
					resp.RequestID,
				),
				Data: map[string]any{
					"request_id": resp.RequestID,
					"result":     resp.Result,
					"message":    resultMessage,
				},
			})
		},
	}

	describeCmd.Flags().StringVar(&className, "name", "", "Godot class name")
	describeCmd.Flags().BoolVar(&includeProperties, "include-properties", false, "Include detailed property metadata")
	describeCmd.Flags().BoolVar(&includeMethods, "include-methods", false, "Include detailed method metadata")
	describeCmd.Flags().BoolVar(&includeSignals, "include-signals", false, "Include detailed signal metadata")
	describeCmd.Flags().BoolVar(&includeInheritors, "include-inheritors", false, "Include direct inheritor class names")
	describeCmd.Flags().BoolVar(&includeAll, "full", false, "Include all optional metadata sections")
	describeCmd.Flags().IntVar(&timeoutMS, "timeout-ms", 0, "Tool call timeout in milliseconds")

	return describeCmd
}
