package daemoncmd

import (
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	"github.com/spf13/cobra"
)

func New(deps shared.Deps) *cobra.Command {
	daemonCmd := &cobra.Command{
		Use:   "daemon",
		Short: "Manage the local daemon",
	}

	daemonCmd.AddCommand(newStartCommand(deps))
	daemonCmd.AddCommand(newStopCommand(deps))

	return daemonCmd
}
