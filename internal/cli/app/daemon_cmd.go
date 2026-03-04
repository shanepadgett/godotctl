package app

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/shanepadgett/godotctl/internal/daemon"
	"github.com/spf13/cobra"
)

func (a *App) newDaemonCommand() *cobra.Command {
	var startOwnerToken string
	var stopOwnerToken string

	daemonCmd := &cobra.Command{
		Use:   "daemon",
		Short: "Manage the local daemon",
	}

	startCmd := &cobra.Command{
		Use:   "start",
		Short: "Start daemon",
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
			defer cancel()

			d := daemon.New(defaultWSAddr, defaultHTTPAddr, startOwnerToken)
			result := output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("godotctl daemon listening (ws=%s http=%s)", defaultWSAddr, defaultHTTPAddr),
				Data: map[string]any{
					"ws_addr":     defaultWSAddr,
					"http_addr":   defaultHTTPAddr,
					"owner_token": startOwnerToken,
				},
			}
			if err := a.presenter.Success(result); err != nil {
				return err
			}

			if err := d.Start(ctx); err != nil {
				return a.fail(cmd, err)
			}
			return nil
		},
	}
	startCmd.Flags().StringVar(&startOwnerToken, "owner-token", "", "Owner token used for conditional daemon stop")
	daemonCmd.AddCommand(startCmd)

	stopCmd := &cobra.Command{
		Use:   "stop",
		Short: "Stop daemon",
		RunE: func(cmd *cobra.Command, args []string) error {
			message, err := a.client.Stop(cmd.Context(), stopOwnerToken)
			if err != nil {
				return a.fail(cmd, err)
			}

			return a.presenter.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    message,
				Data: map[string]any{
					"message": message,
				},
			})
		},
	}
	stopCmd.Flags().StringVar(&stopOwnerToken, "owner-token", "", "Only stop if daemon owner token matches")
	daemonCmd.AddCommand(stopCmd)

	return daemonCmd
}
