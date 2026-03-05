package daemoncmd

import (
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func newStopCommand(deps shared.Deps) *cobra.Command {
	var stopOwnerToken string

	stopCmd := &cobra.Command{
		Use:   "stop",
		Short: "Stop daemon",
		RunE: func(cmd *cobra.Command, _ []string) error {
			message, err := deps.Client.Stop(cmd.Context(), stopOwnerToken)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    message,
				Data: map[string]any{
					"message": message,
				},
			})
		},
	}

	stopCmd.Flags().StringVar(&stopOwnerToken, "owner-token", "", "Only stop if daemon owner token matches")

	return stopCmd
}
