package resourcecmd

import (
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	"github.com/spf13/cobra"
)

func New(deps shared.Deps) *cobra.Command {
	resourceCmd := &cobra.Command{
		Use:   "resource",
		Short: "Resource inspection operations through the daemon",
	}

	resourceCmd.AddCommand(newRefsCommand(deps))

	return resourceCmd
}
