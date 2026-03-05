package classcmd

import (
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	"github.com/spf13/cobra"
)

func New(deps shared.Deps) *cobra.Command {
	classCmd := &cobra.Command{
		Use:   "class",
		Short: "Class metadata operations through the daemon",
	}

	classCmd.AddCommand(newDescribeCommand(deps))

	return classCmd
}
