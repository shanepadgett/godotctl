package app

import (
	"io"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

const (
	defaultWSAddr   = "127.0.0.1:6505"
	defaultHTTPAddr = "127.0.0.1:6506"
)

type App struct {
	jsonMode  bool
	presenter output.Presenter
	client    *client.DaemonClient
	stdout    io.Writer
	stderr    io.Writer
}

func NewRootCommand(stdout io.Writer, stderr io.Writer) *cobra.Command {
	a := &App{
		client: client.New(defaultHTTPAddr),
		stdout: stdout,
		stderr: stderr,
	}

	rootCmd := &cobra.Command{
		Use:           "godotctl",
		Short:         "CLI and daemon for the Godot bridge plugin",
		SilenceUsage:  true,
		SilenceErrors: true,
		PersistentPreRun: func(_ *cobra.Command, _ []string) {
			a.presenter = output.NewPresenter(a.jsonMode, a.stdout, a.stderr)
		},
	}

	rootCmd.PersistentFlags().BoolVar(&a.jsonMode, "json", false, "Print machine-readable JSON output")

	rootCmd.AddCommand(a.newDaemonCommand())
	rootCmd.AddCommand(a.newStatusCommand())
	rootCmd.AddCommand(a.newToolsCommand())

	return rootCmd
}
