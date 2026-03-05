package client

import (
	"context"
	"encoding/json"
	"net/http"
	"net/url"
	"strings"

	clierrors "github.com/shanepadgett/godotctl/internal/cli/errors"
)

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
	defer func() {
		_ = resp.Body.Close()
	}()

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
