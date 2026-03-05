package toolscmd

import (
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	"github.com/spf13/cobra"
)

func New(deps shared.Deps) *cobra.Command {
	toolsCmd := &cobra.Command{
		Use:   "tools",
		Short: "Invoke plugin tools through the daemon",
	}

	toolsCmd.AddCommand(newListCommand(deps))
	toolsCmd.AddCommand(newPingCommand(deps))

	return toolsCmd
}
