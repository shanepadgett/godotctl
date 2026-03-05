package statuscmd

import (
	"fmt"

	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func New(deps shared.Deps) *cobra.Command {
	return &cobra.Command{
		Use:   "status",
		Short: "Show daemon and plugin status",
		RunE: func(cmd *cobra.Command, _ []string) error {
			status, err := deps.Client.GetStatus(cmd.Context())
			if err != nil {
				return deps.Fail(cmd, err)
			}

			text := "daemon: running, plugin: disconnected"
			if status.PluginConnected {
				text = fmt.Sprintf("daemon: running, plugin: connected (%s)", status.Project)
			}

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    text,
				Data:    status,
			})
		},
	}
}
