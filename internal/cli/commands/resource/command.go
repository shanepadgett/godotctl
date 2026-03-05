package resourcecmd

import (
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	"github.com/spf13/cobra"
)

func New(deps shared.Deps) *cobra.Command {
	resourceCmd := &cobra.Command{
		Use:   "resource",
		Short: "Resource operations through the daemon",
	}

	resourceCmd.AddCommand(newCreateCommand(deps))
	resourceCmd.AddCommand(newGetCommand(deps))
	resourceCmd.AddCommand(newSetPropCommand(deps))
	resourceCmd.AddCommand(newListCommand(deps))
	resourceCmd.AddCommand(newRefsCommand(deps))

	return resourceCmd
}
