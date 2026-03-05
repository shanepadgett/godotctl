package projectcmd

import (
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	"github.com/spf13/cobra"
)

func New(deps shared.Deps) *cobra.Command {
	projectCmd := &cobra.Command{
		Use:   "project",
		Short: "Project operations through the daemon",
	}

	settingsCmd := &cobra.Command{
		Use:   "settings",
		Short: "Project settings operations",
	}
	settingsCmd.AddCommand(newSettingsGetCommand(deps))
	projectCmd.AddCommand(settingsCmd)

	inputMapCmd := &cobra.Command{
		Use:   "input-map",
		Short: "Input map operations",
	}
	inputMapCmd.AddCommand(newInputMapGetCommand(deps))
	projectCmd.AddCommand(inputMapCmd)

	return projectCmd
}
