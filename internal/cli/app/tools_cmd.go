package app

import (
	"fmt"

	"github.com/shanepadgett/godotctl/internal/cli/client"
	"github.com/shanepadgett/godotctl/internal/cli/output"
	"github.com/spf13/cobra"
)

func (a *App) newToolsCommand() *cobra.Command {
	toolsCmd := &cobra.Command{
		Use:   "tools",
		Short: "Invoke plugin tools through the daemon",
	}

	toolsCmd.AddCommand(&cobra.Command{
		Use:   "ping",
		Short: "Send a minimal ping tool request",
		RunE: func(cmd *cobra.Command, args []string) error {
			response, err := a.client.CallTool(cmd.Context(), client.ToolCallRequest{
				Tool:      "ping",
				Args:      map[string]any{},
				TimeoutMS: 3000,
			})
			if err != nil {
				return a.fail(cmd, err)
			}

			message := "pong"
			if msg, ok := response.Result["message"].(string); ok && msg != "" {
				message = msg
			}

			return a.presenter.Success(output.Result{
				Command: cmd.CommandPath(),
				Text:    fmt.Sprintf("tools ping ok: %s (request_id=%s)", message, response.RequestID),
				Data: map[string]any{
					"request_id": response.RequestID,
					"message":    message,
				},
			})
		},
	})

	return toolsCmd
}

func (a *App) fail(cmd *cobra.Command, err error) error {
	_ = a.presenter.Failure(cmd.CommandPath(), err)
	return err
}
