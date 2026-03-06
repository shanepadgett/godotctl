package app

import (
	"io"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	classcmd "github.com/shanepadgett/godotctl/internal/cli/commands/class"
	daemoncmd "github.com/shanepadgett/godotctl/internal/cli/commands/daemon"
	filecmd "github.com/shanepadgett/godotctl/internal/cli/commands/file"
	installbridgecmd "github.com/shanepadgett/godotctl/internal/cli/commands/installbridge"
	projectcmd "github.com/shanepadgett/godotctl/internal/cli/commands/project"
	resourcecmd "github.com/shanepadgett/godotctl/internal/cli/commands/resource"
	runcmd "github.com/shanepadgett/godotctl/internal/cli/commands/run"
	scenecmd "github.com/shanepadgett/godotctl/internal/cli/commands/scene"
	scriptcmd "github.com/shanepadgett/godotctl/internal/cli/commands/script"
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	statuscmd "github.com/shanepadgett/godotctl/internal/cli/commands/status"
	toolscmd "github.com/shanepadgett/godotctl/internal/cli/commands/tools"
	versioncmd "github.com/shanepadgett/godotctl/internal/cli/commands/version"
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

type BuildInfo struct {
	Version string
	Commit  string
	Date    string
}

func NewRootCommand(stdout io.Writer, stderr io.Writer, build BuildInfo) *cobra.Command {
	a := &App{
		client: client.New(defaultHTTPAddr),
		stdout: stdout,
		stderr: stderr,
	}

	if build.Version == "" {
		build.Version = "dev"
	}
	if build.Commit == "" {
		build.Commit = "none"
	}
	if build.Date == "" {
		build.Date = "unknown"
	}

	rootCmd := &cobra.Command{
		Use:           "godotctl",
		Short:         "CLI and daemon for the Godot bridge plugin",
		Version:       build.Version,
		SilenceUsage:  true,
		SilenceErrors: true,
		PersistentPreRun: func(_ *cobra.Command, _ []string) {
			a.presenter = output.NewPresenter(a.jsonMode, a.stdout, a.stderr)
		},
	}

	rootCmd.PersistentFlags().BoolVar(&a.jsonMode, "json", false, "Print machine-readable JSON output")

	deps := shared.Deps{
		Client: a.client,
		Presenter: func() output.Presenter {
			return a.presenter
		},
		WSAddr:   defaultWSAddr,
		HTTPAddr: defaultHTTPAddr,
	}

	rootCmd.AddCommand(daemoncmd.New(deps))
	rootCmd.AddCommand(statuscmd.New(deps))
	rootCmd.AddCommand(installbridgecmd.New(deps))
	rootCmd.AddCommand(toolscmd.New(deps))
	rootCmd.AddCommand(runcmd.New(deps))
	rootCmd.AddCommand(classcmd.New(deps))
	rootCmd.AddCommand(scenecmd.New(deps))
	rootCmd.AddCommand(scriptcmd.New(deps))
	rootCmd.AddCommand(projectcmd.New(deps))
	rootCmd.AddCommand(resourcecmd.New(deps))
	rootCmd.AddCommand(filecmd.New(deps))
	rootCmd.AddCommand(versioncmd.New(deps, build.Version, build.Commit, build.Date))

	return rootCmd
}
