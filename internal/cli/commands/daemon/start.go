package daemoncmd

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/shanepadgett/godotctl/internal/daemon"
	"github.com/spf13/cobra"
)

func newStartCommand(deps shared.Deps) *cobra.Command {
	var startOwnerToken string

	startCmd := &cobra.Command{
		Use:   "start",
		Short: "Start daemon",
		RunE: func(cmd *cobra.Command, _ []string) error {
			ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
			defer cancel()

			d := daemon.New(deps.WSAddr, deps.HTTPAddr, startOwnerToken)
			result := output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("godotctl daemon listening (ws=%s http=%s)", deps.WSAddr, deps.HTTPAddr),
				Data: map[string]any{
					"ws_addr":     deps.WSAddr,
					"http_addr":   deps.HTTPAddr,
					"owner_token": startOwnerToken,
				},
			}
			if err := deps.Success(result); err != nil {
				return err
			}

			if err := d.Start(ctx); err != nil {
				return deps.Fail(cmd, err)
			}
			return nil
		},
	}

	startCmd.Flags().StringVar(&startOwnerToken, "owner-token", "", "Owner token used for conditional daemon stop")

	return startCmd
}
