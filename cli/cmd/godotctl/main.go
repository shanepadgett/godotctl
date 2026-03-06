package main

import (
	"os"

	"github.com/shanepadgett/godotctl/internal/cli/app"
	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
)

var (
	version = "dev"
	commit  = "none"
	date    = "unknown"
)

func main() {
	rootCmd := app.NewRootCommand(os.Stdout, os.Stderr, app.BuildInfo{
		Version: version,
		Commit:  commit,
		Date:    date,
	})
	if err := rootCmd.Execute(); err != nil {
		os.Exit(clierrors.ExitCode(err))
	}
}
