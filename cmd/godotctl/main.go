package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/shanepadgett/godotctl/internal/daemon"
	"github.com/spf13/cobra"
)

const (
	defaultWSAddr   = "127.0.0.1:6505"
	defaultHTTPAddr = "127.0.0.1:6506"
)

func main() {
	rootCmd := &cobra.Command{
		Use:          "godotctl",
		Short:        "CLI and daemon for the Godot bridge plugin",
		SilenceUsage: true,
	}

	rootCmd.AddCommand(newDaemonCommand())
	rootCmd.AddCommand(newStatusCommand())
	rootCmd.AddCommand(newToolsCommand())

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

type toolCallRequest struct {
	Tool      string         `json:"tool"`
	Args      map[string]any `json:"args"`
	TimeoutMS int            `json:"timeout_ms,omitempty"`
}

type toolCallResponse struct {
	Ok        bool           `json:"ok"`
	Result    map[string]any `json:"result,omitempty"`
	Error     string         `json:"error,omitempty"`
	RequestID string         `json:"request_id,omitempty"`
}

func newDaemonCommand() *cobra.Command {
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
			fmt.Printf("godotctl daemon listening (ws=%s http=%s)\n", defaultWSAddr, defaultHTTPAddr)
			return d.Start(ctx)
		},
	})

	daemonCmd.AddCommand(&cobra.Command{
		Use:   "stop",
		Short: "Stop daemon",
		RunE: func(cmd *cobra.Command, args []string) error {
			req, err := http.NewRequest(http.MethodPost, "http://"+defaultHTTPAddr+"/daemon/stop", nil)
			if err != nil {
				return err
			}

			client := http.Client{Timeout: 2 * time.Second}
			resp, err := client.Do(req)
			if err != nil {
				return fmt.Errorf("daemon is unavailable")
			}
			defer resp.Body.Close()

			if resp.StatusCode >= http.StatusBadRequest {
				body, _ := io.ReadAll(resp.Body)
				return fmt.Errorf("daemon stop failed: %s", string(body))
			}

			fmt.Println("daemon stopping")
			return nil
		},
	})

	return daemonCmd
}

func newStatusCommand() *cobra.Command {
	return &cobra.Command{
		Use:   "status",
		Short: "Show daemon and plugin status",
		RunE: func(cmd *cobra.Command, args []string) error {
			client := http.Client{Timeout: 2 * time.Second}
			resp, err := client.Get("http://" + defaultHTTPAddr + "/status")
			if err != nil {
				return fmt.Errorf("daemon is unavailable")
			}
			defer resp.Body.Close()

			if resp.StatusCode >= http.StatusBadRequest {
				return fmt.Errorf("status request failed: %s", resp.Status)
			}

			var status daemon.StatusResponse
			if err := json.NewDecoder(resp.Body).Decode(&status); err != nil {
				return fmt.Errorf("decode status response: %w", err)
			}

			if status.PluginConnected {
				fmt.Printf("daemon: running, plugin: connected (%s)\n", status.Project)
				return nil
			}

			fmt.Println("daemon: running, plugin: disconnected")
			return nil
		},
	}
}

func newToolsCommand() *cobra.Command {
	toolsCmd := &cobra.Command{
		Use:   "tools",
		Short: "Invoke plugin tools through the daemon",
	}

	toolsCmd.AddCommand(&cobra.Command{
		Use:   "ping",
		Short: "Send a minimal ping tool request",
		RunE: func(cmd *cobra.Command, args []string) error {
			response, err := callTool("ping", map[string]any{}, 3000)
			if err != nil {
				return err
			}

			if !response.Ok {
				return fmt.Errorf("tool failed: %s", response.Error)
			}

			message := "pong"
			if msg, ok := response.Result["message"].(string); ok && msg != "" {
				message = msg
			}

			fmt.Printf("tools ping ok: %s (request_id=%s)\n", message, response.RequestID)
			return nil
		},
	})

	return toolsCmd
}

func callTool(tool string, args map[string]any, timeoutMS int) (toolCallResponse, error) {
	body, err := json.Marshal(toolCallRequest{Tool: tool, Args: args, TimeoutMS: timeoutMS})
	if err != nil {
		return toolCallResponse{}, err
	}

	client := http.Client{Timeout: time.Duration(timeoutMS+1000) * time.Millisecond}
	resp, err := client.Post("http://"+defaultHTTPAddr+"/tools/call", "application/json", bytes.NewReader(body))
	if err != nil {
		return toolCallResponse{}, fmt.Errorf("daemon is unavailable")
	}
	defer resp.Body.Close()

	var response toolCallResponse
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return toolCallResponse{}, fmt.Errorf("decode tool response: %w", err)
	}

	if resp.StatusCode >= http.StatusBadRequest {
		if response.Error != "" {
			return toolCallResponse{}, errors.New(response.Error)
		}
		return toolCallResponse{}, fmt.Errorf("tool call failed: %s", resp.Status)
	}

	return response, nil
}
