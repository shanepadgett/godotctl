package client

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"time"

	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
	"github.com/shanepadgett/godotctl/internal/protocol"
)

func (c *DaemonClient) CallTool(ctx context.Context, req protocol.ToolCallRequest) (protocol.ToolCallResponse, error) {
	if req.Tool == "" {
		return protocol.ToolCallResponse{}, clierrors.New(clierrors.KindValidation, "tool is required")
	}
	if req.Args == nil {
		req.Args = map[string]any{}
	}

	body, err := json.Marshal(req)
	if err != nil {
		return protocol.ToolCallResponse{}, clierrors.Wrap(clierrors.KindValidation, "encode tool request", err)
	}

	timeout := 6 * time.Second
	if req.TimeoutMS > 0 {
		timeout = time.Duration(req.TimeoutMS+1000) * time.Millisecond
	}

	httpClient := &http.Client{Timeout: timeout}
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/tools/call", bytes.NewReader(body))
	if err != nil {
		return protocol.ToolCallResponse{}, clierrors.Wrap(clierrors.KindValidation, "build tool request", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := httpClient.Do(httpReq)
	if err != nil {
		return protocol.ToolCallResponse{}, clierrors.Wrap(clierrors.KindDaemonUnavailable, "daemon is unavailable", err)
	}
	defer func() {
		_ = resp.Body.Close()
	}()

	var toolResp protocol.ToolCallResponse
	if err := json.NewDecoder(resp.Body).Decode(&toolResp); err != nil {
		return protocol.ToolCallResponse{}, clierrors.Wrap(clierrors.KindOperationFailed, "decode tool response", err)
	}

	if resp.StatusCode >= http.StatusBadRequest {
		return protocol.ToolCallResponse{}, classifyToolError(toolResp.Error, resp.Status)
	}

	if !toolResp.OK {
		return protocol.ToolCallResponse{}, classifyToolError(toolResp.Error, "tool call failed")
	}

	return toolResp, nil
}
