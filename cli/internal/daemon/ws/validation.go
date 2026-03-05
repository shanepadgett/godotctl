package ws

import (
	"fmt"
	"sort"
	"strings"
)

func validateHelloMessage(msg wsMessage) error {
	if strings.TrimSpace(msg.Type) != "hello" {
		return fmt.Errorf("type must be hello")
	}

	for i, tool := range msg.Tools {
		if strings.TrimSpace(tool) == "" {
			return fmt.Errorf("tools[%d] must be non-empty", i)
		}
	}

	return nil
}

func validateToolInvokeMessage(msg toolInvokeMessage) error {
	if strings.TrimSpace(msg.Type) != "tool_invoke" {
		return fmt.Errorf("type must be tool_invoke")
	}
	if strings.TrimSpace(msg.ID) == "" {
		return fmt.Errorf("id is required")
	}
	if strings.TrimSpace(msg.Tool) == "" {
		return fmt.Errorf("tool is required")
	}
	if msg.Args == nil {
		return fmt.Errorf("args is required")
	}

	return nil
}

func validateToolResultMessage(msg toolResultMessage) error {
	if strings.TrimSpace(msg.Type) != "tool_result" {
		return fmt.Errorf("type must be tool_result")
	}
	if strings.TrimSpace(msg.ID) == "" {
		return fmt.Errorf("id is required")
	}

	hasResult := msg.Result != nil
	hasError := strings.TrimSpace(msg.Error) != ""
	hasErrorCode := strings.TrimSpace(msg.ErrorCode) != ""

	if msg.Ok {
		if !hasResult {
			return fmt.Errorf("result is required when ok=true")
		}
		if hasError {
			return fmt.Errorf("error must be empty when ok=true")
		}
		if hasErrorCode {
			return fmt.Errorf("error_code must be empty when ok=true")
		}
		return nil
	}

	if !hasError {
		return fmt.Errorf("error is required when ok=false")
	}
	if hasResult {
		return fmt.Errorf("result must be empty when ok=false")
	}

	return nil
}

func normalizeTools(tools []string) []string {
	if len(tools) == 0 {
		return []string{"ping"}
	}

	normalized := make([]string, 0, len(tools))
	seen := make(map[string]struct{}, len(tools))
	for _, tool := range tools {
		name := strings.TrimSpace(tool)
		if name == "" {
			continue
		}
		if _, ok := seen[name]; ok {
			continue
		}
		seen[name] = struct{}{}
		normalized = append(normalized, name)
	}

	if len(normalized) == 0 {
		return []string{"ping"}
	}

	sort.Strings(normalized)

	return normalized
}
