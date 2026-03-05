package scenecmd

import (
	"github.com/shanepadgett/godotctl/internal/cli/commands/shared"
	"github.com/spf13/cobra"
)

func New(deps shared.Deps) *cobra.Command {
	sceneCmd := &cobra.Command{
		Use:   "scene",
		Short: "Scene operations through the daemon",
	}

	sceneCmd.AddCommand(newCreateCommand(deps))
	sceneCmd.AddCommand(newAddNodeCommand(deps))
	sceneCmd.AddCommand(newRemoveNodeCommand(deps))
	sceneCmd.AddCommand(newRenameCommand(deps))
	sceneCmd.AddCommand(newReparentCommand(deps))
	sceneCmd.AddCommand(newDuplicateCommand(deps))
	sceneCmd.AddCommand(newInstanceSceneCommand(deps))
	sceneCmd.AddCommand(newSetPropCommand(deps))
	sceneCmd.AddCommand(newTreeCommand(deps))
	sceneCmd.AddCommand(newInspectCommand(deps))

	signalCmd := &cobra.Command{
		Use:   "signal",
		Short: "Scene signal connection operations",
	}
	signalCmd.AddCommand(newSignalConnectCommand(deps))
	signalCmd.AddCommand(newSignalDisconnectCommand(deps))
	signalCmd.AddCommand(newSignalListCommand(deps))
	sceneCmd.AddCommand(signalCmd)

	groupCmd := &cobra.Command{
		Use:   "group",
		Short: "Scene group membership operations",
	}
	groupCmd.AddCommand(newGroupAddCommand(deps))
	groupCmd.AddCommand(newGroupRemoveCommand(deps))
	groupCmd.AddCommand(newGroupListCommand(deps))
	sceneCmd.AddCommand(groupCmd)

	transformCmd := &cobra.Command{
		Use:   "transform",
		Short: "Scene transform operations",
	}
	transformCmd.AddCommand(newTransformApplyCommand(deps))
	sceneCmd.AddCommand(transformCmd)

	nodeCmd := &cobra.Command{
		Use:   "node",
		Short: "Scene node configuration operations",
	}
	nodeCmd.AddCommand(newNodeConfigureCommand(deps))
	sceneCmd.AddCommand(nodeCmd)

	return sceneCmd
}
