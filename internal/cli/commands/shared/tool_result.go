package shared

import "strings"

func ToolResultMessage(result map[string]any, fallback string) string {
	message := strings.TrimSpace(fallback)
	if message == "" {
		message = "operation completed"
	}

	if value, ok := result["message"].(string); ok {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			message = trimmed
		}
	}

	return message
}

func ToolResultData(result map[string]any) map[string]any {
	if value, ok := result["data"].(map[string]any); ok {
		return value
	}

	return nil
}

func ToolResultDataString(result map[string]any, key string, fallback string) string {
	value := strings.TrimSpace(fallback)
	if data := ToolResultData(result); data != nil {
		if raw, ok := data[key].(string); ok {
			if trimmed := strings.TrimSpace(raw); trimmed != "" {
				value = trimmed
			}
		}
	}

	return value
}

func ToolResultDataInt(result map[string]any, key string, fallback int) int {
	value := fallback
	if data := ToolResultData(result); data != nil {
		if converted, ok := anyToInt(data[key]); ok {
			value = converted
		}
	}

	return value
}

func anyToInt(value any) (int, bool) {
	switch n := value.(type) {
	case int:
		return n, true
	case int8:
		return int(n), true
	case int16:
		return int(n), true
	case int32:
		return int(n), true
	case int64:
		return int(n), true
	case uint:
		return int(n), true
	case uint8:
		return int(n), true
	case uint16:
		return int(n), true
	case uint32:
		return int(n), true
	case uint64:
		return int(n), true
	case float32:
		return int(n), true
	case float64:
		return int(n), true
	default:
		return 0, false
	}
}
