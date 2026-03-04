package app

import (
	"fmt"

	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func (a *App) newStatusCommand() *cobra.Command {
	return &cobra.Command{
		Use:   "status",
		Short: "Show daemon and plugin status",
		RunE: func(cmd *cobra.Command, args []string) error {
			status, err := a.client.GetStatus(cmd.Context())
			if err != nil {
				return a.fail(cmd, err)
			}

			text := "daemon: running, plugin: disconnected"
			if status.PluginConnected {
				text = fmt.Sprintf("daemon: running, plugin: connected (%s)", status.Project)
			}

			return a.presenter.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    text,
				Data:    status,
			})
		},
	}
}
