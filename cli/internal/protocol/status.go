package protocol

type StatusResponse struct {
	Daemon          bool    `json:"daemon"`
	PluginConnected bool    `json:"plugin_connected"`
	Project         string  `json:"project,omitempty"`
	PendingRequests int     `json:"pending_requests"`
	ConnectedSince  *string `json:"connected_since"`
	OwnerToken      string  `json:"owner_token,omitempty"`
}

type ToolsListResponse struct {
	Daemon          bool     `json:"daemon"`
	PluginConnected bool     `json:"plugin_connected"`
	Project         string   `json:"project,omitempty"`
	Tools           []string `json:"tools"`
	OwnerToken      string   `json:"owner_token,omitempty"`
}
