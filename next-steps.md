# Next Steps

This checklist replaces completed Milestones A/B work and focuses on deterministic tool execution for Milestone C.

## Execution Rules

- Edit plugin code only in `addons/godot_bridge/`.
- After plugin edits, overwrite `sample/addons/godot_bridge/` with the source plugin folder.
- Use Bash commands only.
- Keep behavior deterministic:
  - normalize all project paths to `res://...`
  - sort all list outputs before returning
  - return stable error codes (no string-only branching)

## Milestone C1 - Contract and Plugin Architecture

- [x] Define one shared plugin tool result contract and implement it end-to-end.
  - Transport envelope remains `tool_result` with fields:
    - `type`, `id`, `ok`, `result` (when success), `error` (when failure)
  - Add optional `error_code` to `tool_result` when `ok=false`.
  - Standardize tool-level error codes:
    - `INVALID_ARGS`
    - `NOT_FOUND`
    - `ALREADY_EXISTS`
    - `TYPE_MISMATCH`
    - `IO_ERROR`
    - `EDITOR_STATE`
    - `INTERNAL`
  - Standardize success payload shape in `result`:
    - `code` (`"OK"`)
    - `message` (human-readable)
    - `data` (tool-specific object)
    - `diagnostics` (array; can be empty)
  - Update validators in:
    - `addons/godot_bridge/daemon_client.gd`
    - `internal/daemon/ws_server.go`
  - Update daemon HTTP error response to preserve plugin `error_code` in JSON (in an additional field, without breaking existing fields).
  - Keep existing CLI exit code mapping unchanged.

- [x] Refactor plugin tool execution into dispatcher + domain modules.
  - Create `addons/godot_bridge/tool_executor.gd`.
  - Create directory `addons/godot_bridge/tools/`.
  - Create files:
    - `addons/godot_bridge/tools/scene_tools.gd`
    - `addons/godot_bridge/tools/script_tools.gd` (stub)
    - `addons/godot_bridge/tools/project_tools.gd` (stub)
    - `addons/godot_bridge/tools/file_tools.gd` (stub)
  - Move ping handling from `addons/godot_bridge/daemon_client.gd` into `tool_executor.gd`.
  - `daemon_client.gd` should only:
    - manage socket lifecycle
    - parse/validate messages
    - delegate tool calls to executor
  - Executor API:
    - `list_tools() -> Array[String]`
    - `execute(tool: String, args: Dictionary) -> Dictionary` (returns normalized success/failure payload)
  - Include `tools` list in plugin `hello` payload from `list_tools()`.

- [x] Add shared deterministic helpers for tool modules.
  - Create `addons/godot_bridge/tools/tool_utils.gd` with helpers for:
    - path normalization to `res://`
    - `.tscn` extension enforcement
    - sorted string arrays
    - class validation (must instantiate and inherit from `Node` where required)
    - property preflight validation (existence + assignability checks before `set`)
  - Ensure handlers use helpers instead of duplicating validation logic.

## Milestone C2 - Scene Create Vertical Slice

- [x] Add `scene` command group and `scene create` CLI command.
  - Create `internal/cli/app/scene_cmd.go`.
  - Register command in `internal/cli/app/root.go`.
  - Command shape:
    - `godotctl scene create --scene <project-relative>.tscn --root <NodeClass> --name <NodeName> [--overwrite] [--open] [--timeout-ms <ms>]`
  - Send tool call:
    - `tool`: `scene.create`
    - `args`: `scene_path`, `root_type`, `root_name`, `overwrite`, `open_in_editor`
  - Text output (success) should include scene path and request id.
  - JSON output should include full returned data and request id.

- [x] Implement `scene.create` handler in plugin.
  - Implement in `addons/godot_bridge/tools/scene_tools.gd`.
  - Validation rules:
    - `scene_path`: required, normalized, `.tscn` required
    - `root_type`: required, valid class, Node-derived
    - `root_name`: required, non-empty
    - if target exists and `overwrite=false`, return `ALREADY_EXISTS`
  - Save flow:
    - instantiate root node
    - set deterministic root name
    - pack with `PackedScene.pack(root)`
    - save with `ResourceSaver.save(packed, scene_path)`
  - Post-save:
    - refresh editor filesystem safely
    - if `open_in_editor=true`, open created scene
  - Success `result.data` fields:
    - `scene_path`
    - `root_type`
    - `root_name`
    - `saved` (bool)
    - `opened` (bool)
    - `filesystem_refreshed` (bool)

- [x] Update tool advertisement and list behavior.
  - Ensure plugin `hello` advertises at least:
    - `ping`
    - `scene.create`
  - Ensure `godotctl tools list` shows advertised tools when connected.
  - Preserve disconnected output behavior.

## Milestone C3 - Hardening and Documentation

- [x] Preserve deterministic error handling in CLI/daemon bridge.
  - Keep existing high-level exit codes:
    - validation -> 1
    - daemon unavailable -> 2
    - plugin disconnected -> 3
    - operation failed -> 4
  - Include plugin `error_code` in JSON failure output so scripts can branch without parsing free-form messages.

- [x] Keep plugin copies in sync for local testing.
  - After plugin changes:
    - copy `addons/godot_bridge/` to `sample/addons/godot_bridge/` (overwrite)
  - Reload plugin in Godot (restart editor or disable/enable plugin).

- [x] Update docs for new command and contract.
  - Update `README.md` with `scene create` usage and examples.
  - Update `godot-cli-plan.md` only if command names/payloads changed from plan.

## Verification Checklist (must pass before marking Milestone C complete)

- [x] `mise run build`
- [x] `go test ./...`
- [x] `mise run copy-addon`
- [x] Open sample project in Godot and confirm daemon/plugin connect.
- [x] `bin/godotctl.exe tools list`
- [x] `bin/godotctl.exe tools ping --json`
- [x] `bin/godotctl.exe scene create --scene scenes/test_player.tscn --root CharacterBody2D --name Player`
- [x] Repeat previous command without `--overwrite` and confirm deterministic failure (`ALREADY_EXISTS`).
- [x] Repeat with `--overwrite` and confirm deterministic success.
