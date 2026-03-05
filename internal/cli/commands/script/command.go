package scriptcmd

import (
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	"github.com/spf13/cobra"
)

func New(deps shared.Deps) *cobra.Command {
	scriptCmd := &cobra.Command{
		Use:   "script",
		Short: "Script operations through the daemon",
	}

	scriptCmd.AddCommand(newCreateCommand(deps))
	scriptCmd.AddCommand(newEditCommand(deps))
	scriptCmd.AddCommand(newValidateCommand(deps))
	scriptCmd.AddCommand(newAttachCommand(deps))

	return scriptCmd
}
