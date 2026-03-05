package main

import (
	"os"

	"github.com/shanepadgett/godotctl/internal/cli/app"
	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
)

func main() {
	rootCmd := app.NewRootCommand(os.Stdout, os.Stderr)
	if err := rootCmd.Execute(); err != nil {
		os.Exit(clierrors.ExitCode(err))
	}
}
