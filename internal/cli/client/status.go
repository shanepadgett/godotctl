package client

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"

	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
	"github.com/shanepadgett/godotctl/internal/protocol"
)

func (c *DaemonClient) GetStatus(ctx context.Context) (protocol.StatusResponse, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/status", nil)
	if err != nil {
		return protocol.StatusResponse{}, clierrors.Wrap(clierrors.KindValidation, "build status request", err)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return protocol.StatusResponse{}, clierrors.Wrap(clierrors.KindDaemonUnavailable, "daemon is unavailable", err)
	}
	defer func() {
		_ = resp.Body.Close()
	}()

	if resp.StatusCode >= http.StatusBadRequest {
		return protocol.StatusResponse{}, clierrors.New(clierrors.KindOperationFailed, fmt.Sprintf("status request failed: %s", resp.Status))
	}

	var status protocol.StatusResponse
	if err := json.NewDecoder(resp.Body).Decode(&status); err != nil {
		return protocol.StatusResponse{}, clierrors.Wrap(clierrors.KindOperationFailed, "decode status response", err)
	}

	return status, nil
}
