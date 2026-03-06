package runcmd

import (
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	"github.com/spf13/cobra"
)

func New(deps shared.Deps) *cobra.Command {
	runCmd := &cobra.Command{
		Use:   "run",
		Short: "Runtime play-mode operations through the daemon",
	}

	runCmd.AddCommand(newStartCommand(deps))
	runCmd.AddCommand(newStopCommand(deps))
	runCmd.AddCommand(newStatusCommand(deps))
	runCmd.AddCommand(newLogsCommand(deps))
	runCmd.AddCommand(newTreeCommand(deps))
	runCmd.AddCommand(newStepCommand(deps))

	propCmd := &cobra.Command{
		Use:   "prop",
		Short: "Runtime property operations",
	}
	propCmd.AddCommand(newPropGetCommand(deps))
	propCmd.AddCommand(newPropListCommand(deps))
	runCmd.AddCommand(propCmd)

	inputCmd := &cobra.Command{
		Use:   "input",
		Short: "Runtime input dispatch operations",
	}
	inputCmd.AddCommand(newInputEventCommand(deps))

	actionCmd := &cobra.Command{
		Use:   "action",
		Short: "Runtime input action operations",
	}
	actionCmd.AddCommand(newInputActionPressCommand(deps))
	actionCmd.AddCommand(newInputActionReleaseCommand(deps))
	inputCmd.AddCommand(actionCmd)

	runCmd.AddCommand(inputCmd)

	return runCmd
}
