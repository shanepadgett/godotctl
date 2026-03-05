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

	jsonCmd := &cobra.Command{
		Use:   "json",
		Short: "Structured JSON file operations",
	}
	jsonCmd.AddCommand(newJSONGetCommand(deps))
	jsonCmd.AddCommand(newJSONSetCommand(deps))
	jsonCmd.AddCommand(newJSONRemoveCommand(deps))
	fileCmd.AddCommand(jsonCmd)

	cfgCmd := &cobra.Command{
		Use:   "cfg",
		Short: "Structured config file operations",
	}
	cfgCmd.AddCommand(newCFGGetCommand(deps))
	cfgCmd.AddCommand(newCFGSetCommand(deps))
	cfgCmd.AddCommand(newCFGRemoveCommand(deps))
	fileCmd.AddCommand(cfgCmd)

	return fileCmd
}
