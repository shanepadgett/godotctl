package scenecmd

import "github.com/shanepadgett/godotctl/internal/cli/commands/shared"

func toolResultArrayLen(result map[string]any, key string) int {
	if data := shared.ToolResultData(result); data != nil {
		if rows, ok := data[key].([]any); ok {
			return len(rows)
		}
	}

	return 0
}
