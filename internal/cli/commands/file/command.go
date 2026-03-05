package filecmd

import (
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	"github.com/spf13/cobra"
)

func New(deps shared.Deps) *cobra.Command {
	fileCmd := &cobra.Command{
		Use:   "file",
		Short: "File operations through the daemon",
	}

	fileCmd.AddCommand(newListCommand(deps))
	fileCmd.AddCommand(newReadCommand(deps))

	return fileCmd
}
