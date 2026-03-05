package scenecmd

import (
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	"github.com/spf13/cobra"
)

func New(deps shared.Deps) *cobra.Command {
	sceneCmd := &cobra.Command{
		Use:   "scene",
		Short: "Scene operations through the daemon",
	}

	sceneCmd.AddCommand(newCreateCommand(deps))
	sceneCmd.AddCommand(newAddNodeCommand(deps))
	sceneCmd.AddCommand(newRemoveNodeCommand(deps))
	sceneCmd.AddCommand(newSetPropCommand(deps))
	sceneCmd.AddCommand(newTreeCommand(deps))

	return sceneCmd
}
