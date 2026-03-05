package client

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"

	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
	"github.com/shanepadgett/godotctl/internal/protocol"
)

func (c *DaemonClient) GetToolsList(ctx context.Context) (protocol.ToolsListResponse, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/tools/list", nil)
	if err != nil {
		return protocol.ToolsListResponse{}, clierrors.Wrap(clierrors.KindValidation, "build tools list request", err)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return protocol.ToolsListResponse{}, clierrors.Wrap(clierrors.KindDaemonUnavailable, "daemon is unavailable", err)
	}
	defer func() {
		_ = resp.Body.Close()
	}()

	if resp.StatusCode >= http.StatusBadRequest {
		return protocol.ToolsListResponse{}, clierrors.New(clierrors.KindOperationFailed, fmt.Sprintf("tools list request failed: %s", resp.Status))
	}

	var tools protocol.ToolsListResponse
	if err := json.NewDecoder(resp.Body).Decode(&tools); err != nil {
		return protocol.ToolsListResponse{}, clierrors.Wrap(clierrors.KindOperationFailed, "decode tools list response", err)
	}

	return tools, nil
}
