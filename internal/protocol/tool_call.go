package protocol

type ToolCallRequest struct {
	Tool      string         `json:"tool"`
	Args      map[string]any `json:"args"`
	TimeoutMS int            `json:"timeout_ms,omitempty"`
}

type ToolCallResponse struct {
	OK        bool           `json:"ok"`
	Result    map[string]any `json:"result,omitempty"`
	Error     *ToolCallError `json:"error,omitempty"`
	RequestID string         `json:"request_id,omitempty"`
}

type ToolCallError struct {
	Code     string `json:"code"`
	Message  string `json:"message"`
	ToolCode string `json:"tool_code,omitempty"`
}
