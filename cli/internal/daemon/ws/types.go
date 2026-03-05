package ws

type wsMessage struct {
	Type       string   `json:"type"`
	Project    string   `json:"project,omitempty"`
	Tools      []string `json:"tools,omitempty"`
	OwnerToken string   `json:"owner_token,omitempty"`
}

type toolInvokeMessage struct {
	Type string         `json:"type"`
	ID   string         `json:"id"`
	Tool string         `json:"tool"`
	Args map[string]any `json:"args"`
}

type toolResultMessage struct {
	Type      string         `json:"type"`
	ID        string         `json:"id"`
	Ok        bool           `json:"ok"`
	Result    map[string]any `json:"result,omitempty"`
	Error     string         `json:"error,omitempty"`
	ErrorCode string         `json:"error_code,omitempty"`
}

type InvokeResult struct {
	RequestID string
	OK        bool
	Result    map[string]any
	Error     string
	ErrorCode string
}

type pendingResult struct {
	result toolResultMessage
	err    error
}
