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
	daemonCmd := &cobra.Command{
		Use:   "daemon",
		Short: "Manage the local daemon",
	}

	daemonCmd.AddCommand(&cobra.Command{
		Use:   "start",
		Short: "Start daemon",
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
			defer cancel()

			d := daemon.New(defaultWSAddr, defaultHTTPAddr)
			result := output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("godotctl daemon listening (ws=%s http=%s)", defaultWSAddr, defaultHTTPAddr),
				Data: map[string]any{
					"ws_addr":   defaultWSAddr,
					"http_addr": defaultHTTPAddr,
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
	})

	daemonCmd.AddCommand(&cobra.Command{
		Use:   "stop",
		Short: "Stop daemon",
		RunE: func(cmd *cobra.Command, args []string) error {
			message, err := a.client.Stop(cmd.Context())
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
	})

	return daemonCmd
}
