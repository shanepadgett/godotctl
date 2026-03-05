package toolscmd

import (
	"fmt"
	"strings"

	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func newListCommand(deps shared.Deps) *cobra.Command {
	return &cobra.Command{
		Use:   "list",
		Short: "List available plugin tools",
		RunE: func(cmd *cobra.Command, _ []string) error {
			tools, err := deps.Client.GetToolsList(cmd.Context())
			if err != nil {
				return deps.Fail(cmd, err)
			}

			text := "tools unavailable: plugin disconnected"
			if tools.PluginConnected {
				names := "none"
				if len(tools.Tools) > 0 {
					names = strings.Join(tools.Tools, ", ")
				}

				if tools.Project != "" {
					text = fmt.Sprintf("tools available (project=%s): %s", tools.Project, names)
				} else {
					text = fmt.Sprintf("tools available: %s", names)
				}
			}

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    text,
				Data:    tools,
			})
		},
	}
}
