package installbridgecmd

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"github.com/shanepadgett/godotctl/internal/addonbundle"
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func New(deps shared.Deps) *cobra.Command {
	var force bool

	cmd := &cobra.Command{
		Use:   "install-bridge",
		Short: "Install bundled godot_bridge addon into the current Godot project",
		RunE: func(cmd *cobra.Command, _ []string) error {
			cwd, err := os.Getwd()
			if err != nil {
				return deps.Fail(cmd, clierrors.Wrap(clierrors.KindOperationFailed, "resolve current directory", err))
			}

			projectRoot, err := findProjectRoot(cwd)
			if err != nil {
				return deps.Fail(cmd, err)
			}

			result, err := addonbundle.Install(projectRoot, force)
			if err != nil {
				if errors.Is(err, addonbundle.ErrAddonExists) {
					return deps.Fail(cmd, clierrors.New(clierrors.KindValidation, "addons/godot_bridge already exists; rerun with --force to overwrite"))
				}
				return deps.Fail(cmd, clierrors.Wrap(clierrors.KindOperationFailed, "install addon", err))
			}

			status := "installed"
			if result.Overwritten {
				status = "overwritten"
			}

			return deps.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("%s godot_bridge addon at %s (%d files)", status, result.AddonPath, result.FileCount),
				Data: map[string]any{
					"project_root": projectRoot,
					"addon_path":   result.AddonPath,
					"file_count":   result.FileCount,
					"overwritten":  result.Overwritten,
				},
			})
		},
	}

	cmd.Flags().BoolVar(&force, "force", false, "Overwrite existing addons/godot_bridge directory")

	return cmd
}

func findProjectRoot(startPath string) (string, error) {
	current := filepath.Clean(startPath)

	for {
		projectFile := filepath.Join(current, "project.godot")
		info, err := os.Stat(projectFile)
		if err == nil {
			if info.IsDir() {
				return "", clierrors.New(clierrors.KindValidation, "project.godot is a directory, expected a file")
			}
			return current, nil
		}
		if !os.IsNotExist(err) {
			return "", clierrors.Wrap(clierrors.KindOperationFailed, "check project.godot", err)
		}

		parent := filepath.Dir(current)
		if parent == current {
			break
		}
		current = parent
	}

	return "", clierrors.New(clierrors.KindValidation, "could not find a Godot project root (project.godot) from current directory")
}
