package client

import (
	"net/http"
	"time"
)

type DaemonClient struct {
	httpClient *http.Client
	baseURL    string
}

func New(baseAddr string) *DaemonClient {
	return &DaemonClient{
		httpClient: &http.Client{Timeout: 2 * time.Second},
		baseURL:    "http://" + baseAddr,
	}
}
