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
	settingsCmd.AddCommand(newSettingsSetCommand(deps))
	projectCmd.AddCommand(settingsCmd)

	inputMapCmd := &cobra.Command{
		Use:   "input-map",
		Short: "Input map operations",
	}
	inputMapCmd.AddCommand(newInputMapGetCommand(deps))
	actionCmd := &cobra.Command{
		Use:   "action",
		Short: "Input action operations",
	}
	actionCmd.AddCommand(newInputMapActionCreateCommand(deps))
	actionCmd.AddCommand(newInputMapActionDeleteCommand(deps))
	inputMapCmd.AddCommand(actionCmd)

	eventCmd := &cobra.Command{
		Use:   "event",
		Short: "Input event operations",
	}
	eventCmd.AddCommand(newInputMapEventAddCommand(deps))
	eventCmd.AddCommand(newInputMapEventRemoveCommand(deps))
	inputMapCmd.AddCommand(eventCmd)

	deadzoneCmd := &cobra.Command{
		Use:   "deadzone",
		Short: "Input deadzone operations",
	}
	deadzoneCmd.AddCommand(newInputMapDeadzoneSetCommand(deps))
	inputMapCmd.AddCommand(deadzoneCmd)
	projectCmd.AddCommand(inputMapCmd)

	autoloadCmd := &cobra.Command{
		Use:   "autoload",
		Short: "Autoload operations",
	}
	autoloadCmd.AddCommand(newAutoloadListCommand(deps))
	autoloadCmd.AddCommand(newAutoloadAddCommand(deps))
	autoloadCmd.AddCommand(newAutoloadRemoveCommand(deps))
	projectCmd.AddCommand(autoloadCmd)

	importCmd := &cobra.Command{
		Use:   "import",
		Short: "Import metadata operations",
	}
	importCmd.AddCommand(newImportGetCommand(deps))
	importCmd.AddCommand(newImportSetCommand(deps))
	importCmd.AddCommand(newImportReimportCommand(deps))
	projectCmd.AddCommand(importCmd)

	projectCmd.AddCommand(newGraphCommand(deps))

	return projectCmd
}
