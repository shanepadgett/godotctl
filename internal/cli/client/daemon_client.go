package client

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
	"github.com/shanepadgett/godotctl/internal/daemon"
)

type DaemonClient struct {
	httpClient *http.Client
	baseURL    string
}

type ToolCallRequest struct {
	Tool      string         `json:"tool"`
	Args      map[string]any `json:"args"`
	TimeoutMS int            `json:"timeout_ms,omitempty"`
}

type ToolCallResponse struct {
	OK        bool           `json:"ok"`
	Result    map[string]any `json:"result,omitempty"`
	Error     string         `json:"error,omitempty"`
	RequestID string         `json:"request_id,omitempty"`
}

func New(baseAddr string) *DaemonClient {
	return &DaemonClient{
		httpClient: &http.Client{Timeout: 2 * time.Second},
		baseURL:    "http://" + baseAddr,
	}
}

func (c *DaemonClient) GetStatus(ctx context.Context) (daemon.StatusResponse, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/status", nil)
	if err != nil {
		return daemon.StatusResponse{}, clierrors.Wrap(clierrors.KindValidation, "build status request", err)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return daemon.StatusResponse{}, clierrors.Wrap(clierrors.KindDaemonUnavailable, "daemon is unavailable", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= http.StatusBadRequest {
		return daemon.StatusResponse{}, clierrors.New(clierrors.KindOperationFailed, fmt.Sprintf("status request failed: %s", resp.Status))
	}

	var status daemon.StatusResponse
	if err := json.NewDecoder(resp.Body).Decode(&status); err != nil {
		return daemon.StatusResponse{}, clierrors.Wrap(clierrors.KindOperationFailed, "decode status response", err)
	}

	return status, nil
}

func (c *DaemonClient) GetToolsList(ctx context.Context) (daemon.ToolsListResponse, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/tools/list", nil)
	if err != nil {
		return daemon.ToolsListResponse{}, clierrors.Wrap(clierrors.KindValidation, "build tools list request", err)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return daemon.ToolsListResponse{}, clierrors.Wrap(clierrors.KindDaemonUnavailable, "daemon is unavailable", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= http.StatusBadRequest {
		return daemon.ToolsListResponse{}, clierrors.New(clierrors.KindOperationFailed, fmt.Sprintf("tools list request failed: %s", resp.Status))
	}

	var tools daemon.ToolsListResponse
	if err := json.NewDecoder(resp.Body).Decode(&tools); err != nil {
		return daemon.ToolsListResponse{}, clierrors.Wrap(clierrors.KindOperationFailed, "decode tools list response", err)
	}

	return tools, nil
}

func (c *DaemonClient) Stop(ctx context.Context, ownerToken string) (string, error) {
	stopURL := c.baseURL + "/daemon/stop"
	if ownerToken != "" {
		stopURL += "?owner_token=" + url.QueryEscape(ownerToken)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, stopURL, nil)
	if err != nil {
		return "", clierrors.Wrap(clierrors.KindValidation, "build daemon stop request", err)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", clierrors.Wrap(clierrors.KindDaemonUnavailable, "daemon is unavailable", err)
	}
	defer resp.Body.Close()

	var stopResp struct {
		Ok      bool   `json:"ok"`
		Stopped bool   `json:"stopped"`
		Message string `json:"message"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&stopResp); err != nil {
		return "", clierrors.Wrap(clierrors.KindOperationFailed, "decode daemon stop response", err)
	}

	if resp.StatusCode >= http.StatusBadRequest {
		message := strings.TrimSpace(stopResp.Message)
		if message == "" {
			message = resp.Status
		}
		return "", clierrors.New(clierrors.KindOperationFailed, "daemon stop failed: "+message)
	}

	if stopResp.Message != "" {
		return stopResp.Message, nil
	}

	if stopResp.Stopped {
		return "daemon stopping", nil
	}

	return "daemon not stopped", nil
}

func (c *DaemonClient) CallTool(ctx context.Context, req ToolCallRequest) (ToolCallResponse, error) {
	if req.Tool == "" {
		return ToolCallResponse{}, clierrors.New(clierrors.KindValidation, "tool is required")
	}
	if req.Args == nil {
		req.Args = map[string]any{}
	}

	body, err := json.Marshal(req)
	if err != nil {
		return ToolCallResponse{}, clierrors.Wrap(clierrors.KindValidation, "encode tool request", err)
	}

	timeout := 6 * time.Second
	if req.TimeoutMS > 0 {
		timeout = time.Duration(req.TimeoutMS+1000) * time.Millisecond
	}

	httpClient := &http.Client{Timeout: timeout}
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/tools/call", bytes.NewReader(body))
	if err != nil {
		return ToolCallResponse{}, clierrors.Wrap(clierrors.KindValidation, "build tool request", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := httpClient.Do(httpReq)
	if err != nil {
		return ToolCallResponse{}, clierrors.Wrap(clierrors.KindDaemonUnavailable, "daemon is unavailable", err)
	}
	defer resp.Body.Close()

	var toolResp ToolCallResponse
	if err := json.NewDecoder(resp.Body).Decode(&toolResp); err != nil {
		return ToolCallResponse{}, clierrors.Wrap(clierrors.KindOperationFailed, "decode tool response", err)
	}

	if resp.StatusCode >= http.StatusBadRequest {
		return ToolCallResponse{}, classifyToolError(toolResp.Error, resp.Status)
	}

	if !toolResp.OK {
		return ToolCallResponse{}, classifyToolError(toolResp.Error, "tool call failed")
	}

	return toolResp, nil
}

func classifyToolError(message string, fallback string) error {
	msg := strings.TrimSpace(message)
	if msg == "" {
		msg = fallback
	}

	lower := strings.ToLower(msg)
	if strings.Contains(lower, "plugin is not connected") {
		return clierrors.New(clierrors.KindPluginDisconnected, msg)
	}

	if strings.Contains(lower, "daemon is unavailable") {
		return clierrors.New(clierrors.KindDaemonUnavailable, msg)
	}

	return clierrors.New(clierrors.KindOperationFailed, msg)
}
