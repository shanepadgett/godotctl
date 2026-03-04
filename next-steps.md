# Next Steps

- [x] Add CLI output modes and exit codes in `cmd/godotctl/main.go`.
  - Add a global `--json` flag for machine-readable output.
  - Standardize command responses so each command can print either concise text or JSON.
  - Return the planned exit codes (`0` success, `1` validation error, `2` daemon unavailable, `3` plugin disconnected, `4` operation failed).

- [x] Add `godotctl tools list` and daemon-backed tool capability reporting.
  - Implement a `tools list` CLI command in `cmd/godotctl/main.go`.
  - Add a daemon endpoint or status payload field that returns available tool names.
  - Include plugin connection awareness so output clearly distinguishes connected vs disconnected states.

- [x] Expand daemon status details to match the plan in `internal/daemon`.
  - Extend `/status` to include pending request count and connected-since timestamp.
  - Update state tracking in `internal/daemon/state.go` to store and expose these values.
  - Keep status response shape stable for both human and JSON CLI output.

- [x] Harden request broker behavior in `internal/daemon/ws_server.go` and `internal/daemon/http_server.go`.
  - Normalize timeout handling so HTTP and WebSocket errors map to clear operation failures.
  - Ensure cancelled/expired requests are removed from pending state consistently.
  - Return structured error messages that the CLI can map to the correct exit code.

- [ ] Lock down the daemon-plugin wire protocol before scene tools.
  - Validate required fields for `hello`, `tool_invoke`, and `tool_result` messages.
  - Handle unknown message types explicitly with safe logging and no crashes.
  - Keep ping/pong behavior stable as the baseline connectivity check.

- [ ] Start Milestone C with the first scene command path.
  - Implement `scene create` end-to-end (CLI -> daemon -> plugin handler).
  - Save scene files using Godot APIs and return structured success/error payloads.
  - Keep command/argument names aligned with `godot-cli-plan.md` so future scene commands follow the same pattern.
