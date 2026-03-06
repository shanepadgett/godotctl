package versioncmd

import (
	"fmt"

	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func New(deps shared.Deps, version string, commit string, date string) *cobra.Command {
	return &cobra.Command{
		Use:   "version",
		Short: "Show CLI version information",
		RunE: func(cmd *cobra.Command, _ []string) error {
			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("godotctl %s (commit=%s, date=%s)", version, commit, date),
				Data: map[string]any{
					"version": version,
					"commit":  commit,
					"date":    date,
				},
			})
		},
	}
}
