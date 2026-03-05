# Next Steps

This checklist starts after Milestone C completion and covers the remaining basic tools from `godot-cli-plan.md`.

## Execution Rules

- Edit plugin code only in `addons/godot_bridge/`.
- After plugin edits, overwrite `sample/addons/godot_bridge/` with the source plugin folder.
- Use Bash commands only.
- CLI flags should use project-relative paths; plugin handlers must normalize to `res://...`.
- Keep behavior deterministic:
  - sort all list outputs before returning
  - return stable `error_code` values (no message-based branching)
  - keep command result shapes stable in both text and `--json`
- When a CLI command is added, changed, or removed, update `docs/DOCUMENTATION.md` in the same change.

## Milestone D1 - Scene Editing Basics

- [x] Implement `scene add-node` end-to-end (CLI -> daemon -> plugin).
  - CLI command:
    - `godotctl scene add-node --scene <path>.tscn --name <NodeName> --type <NodeClass> --parent <NodePath> [--timeout-ms <ms>]`
  - Tool call:
    - `tool`: `scene.add_node`
    - `args`: `scene_path`, `node_name`, `node_type`, `parent_path`
  - Plugin behavior:
    - load scene, instantiate root, resolve `parent_path` (`.` means root)
    - validate `node_type` is Node-derived
    - fail with `ALREADY_EXISTS` on name collision under parent
    - add child with deterministic name and owner so it serializes
    - pack/save + filesystem refresh
  - Success `result.data`:
    - `scene_path`, `node_path`, `parent_path`, `node_type`, `saved`, `filesystem_refreshed`

- [x] Implement `scene remove-node` end-to-end.
  - CLI command:
    - `godotctl scene remove-node --scene <path>.tscn --path <NodePath> [--timeout-ms <ms>]`
  - Tool call:
    - `tool`: `scene.remove_node`
    - `args`: `scene_path`, `node_path`
  - Plugin behavior:
    - load scene and resolve `node_path`
    - reject removing root (`.`) with `INVALID_ARGS`
    - fail with `NOT_FOUND` for missing node
    - remove node, free it, save scene, refresh filesystem
  - Success `result.data`:
    - `scene_path`, `removed_path`, `saved`, `filesystem_refreshed`

- [x] Implement `scene set-prop` end-to-end.
  - CLI command:
    - `godotctl scene set-prop --scene <path>.tscn --path <NodePath> --prop <Property> --value <json> [--timeout-ms <ms>]`
  - Tool call:
    - `tool`: `scene.set_prop`
    - `args`: `scene_path`, `node_path`, `property`, `value_json`
  - Plugin behavior:
    - parse `value_json` as JSON
    - support primitives plus typed objects for common Godot values (`Vector2`, `Vector3`, `Color`, `NodePath`)
    - validate property existence + assignability before `set`
    - save + refresh
  - Failures:
    - `INVALID_ARGS` (bad JSON or unsupported typed payload)
    - `NOT_FOUND` (node/property)
    - `TYPE_MISMATCH` (property type mismatch)

- [x] Implement `scene tree` end-to-end.
  - CLI command:
    - `godotctl scene tree --scene <path>.tscn [--timeout-ms <ms>]`
  - Tool call:
    - `tool`: `scene.tree`
    - `args`: `scene_path`
  - Plugin behavior:
    - load scene and return deterministic traversal payload
  - Success `result.data`:
    - `scene_path`, `nodes` (each item: `path`, `name`, `type`, `child_count`)

- [x] Update tool registration and CLI wiring for all scene commands.
  - Register new subcommands in `internal/cli/app/scene_cmd.go`.
  - Advertise tools in `addons/godot_bridge/tools/scene_tools.gd` list.
  - Ensure `tools list` shows `scene.create`, `scene.add_node`, `scene.remove_node`, `scene.set_prop`, `scene.tree`.

## Milestone D2 - Script Basics

- [ ] Implement `script create` end-to-end.
  - CLI command:
    - `godotctl script create --path <path>.gd --base <BaseClass> [--class-name <Name>] [--overwrite] [--timeout-ms <ms>]`
  - Tool call:
    - `tool`: `script.create`
    - `args`: `script_path`, `base_class`, `class_name`, `overwrite`
  - Plugin behavior:
    - create parent directories if needed
    - generate deterministic template source
    - fail with `ALREADY_EXISTS` if file exists and no overwrite
    - save + filesystem refresh

- [ ] Implement `script edit` end-to-end.
  - CLI command:
    - `godotctl script edit --path <path>.gd --find <text> --replace <text> [--timeout-ms <ms>]`
  - Tool call:
    - `tool`: `script.edit`
    - `args`: `script_path`, `find_text`, `replace_text`
  - Plugin behavior:
    - read file, do literal replace-all, write file
    - return deterministic counts (`match_count`, `replaced_count`)

- [ ] Implement `script validate` end-to-end.
  - CLI command:
    - `godotctl script validate --path <path>.gd [--timeout-ms <ms>]`
  - Tool call:
    - `tool`: `script.validate`
    - `args`: `script_path`
  - Plugin behavior:
    - parse/compile script for syntax validity
    - return `valid` and diagnostics details

- [ ] Implement `script attach` end-to-end.
  - CLI command:
    - `godotctl script attach --scene <path>.tscn --node <NodePath> --script <path>.gd [--overwrite] [--timeout-ms <ms>]`
  - Tool call:
    - `tool`: `script.attach`
    - `args`: `scene_path`, `node_path`, `script_path`, `overwrite`
  - Plugin behavior:
    - load scene and script resource
    - resolve node and attach script
    - if script exists and overwrite is false, return `ALREADY_EXISTS`
    - save + refresh

- [ ] Add `script` command group in CLI.
  - Create `internal/cli/app/script_cmd.go`.
  - Register in `internal/cli/app/root.go`.

## Milestone D3 - Project and File Basics

- [ ] Implement `project settings get` end-to-end.
  - CLI command:
    - `godotctl project settings get [--key <setting>] [--timeout-ms <ms>]`
  - Tool call:
    - `tool`: `project.settings_get`
    - `args`: `key`
  - Plugin behavior:
    - if `key` provided, return one setting or `NOT_FOUND`
    - if omitted, return deterministic sorted list/map of public settings

- [ ] Implement `project input-map get` end-to-end.
  - CLI command:
    - `godotctl project input-map get [--action <name>] [--timeout-ms <ms>]`
  - Tool call:
    - `tool`: `project.input_map_get`
    - `args`: `action`
  - Plugin behavior:
    - return deterministic action list and event summaries

- [ ] Implement `file list` end-to-end.
  - CLI command:
    - `godotctl file list --path <project-relative-path> [--recursive] [--timeout-ms <ms>]`
  - Tool call:
    - `tool`: `file.list`
    - `args`: `path`, `recursive`
  - Plugin behavior:
    - list directories/files under `res://` path
    - return sorted entries (stable order)

- [ ] Implement `file read` end-to-end.
  - CLI command:
    - `godotctl file read --path <project-relative-path> [--timeout-ms <ms>]`
  - Tool call:
    - `tool`: `file.read`
    - `args`: `path`
  - Plugin behavior:
    - read file contents and return text + byte count
    - return `NOT_FOUND` for missing path

- [ ] Add `project` and `file` command groups in CLI.
  - Create `internal/cli/app/project_cmd.go`.
  - Create `internal/cli/app/file_cmd.go`.
  - Register both in `internal/cli/app/root.go`.

## Milestone D4 - Hardening, Docs, and Consistency

- [ ] Keep error handling deterministic for all new tools.
  - Preserve top-level exit code mapping (`0..4`).
  - Preserve plugin `error_code` in JSON as `error.tool_code`.
  - Ensure `INVALID_ARGS` maps to validation exit code `1`.

- [ ] Keep tool advertisement accurate.
  - New tools must appear in plugin `hello` `tools` list.
  - `godotctl tools list` output remains sorted and stable.

- [ ] Keep docs in sync with implemented commands.
  - Update `docs/DOCUMENTATION.md` for each new command and flag.
  - Keep `README.md` simple and only link to docs for command reference.
  - Update `godot-cli-plan.md` only if command names/payloads change.

## Verification Checklist (must pass before marking Milestone D complete)

- [x] `mise run build`
- [x] `go test ./...`
- [x] `mise run copy-addon`
- [x] Open sample project in Godot and confirm daemon/plugin connect.
- [x] `bin/godotctl.exe tools list`
- [x] `bin/godotctl.exe scene create --scene scenes/tools_e2e.tscn --root CharacterBody2D --name Player`
- [x] `bin/godotctl.exe scene add-node --scene scenes/tools_e2e.tscn --name Sprite2D --type Sprite2D --parent .`
- [x] `bin/godotctl.exe scene tree --scene scenes/tools_e2e.tscn --json`
- [x] `bin/godotctl.exe scene set-prop --scene scenes/tools_e2e.tscn --path . --prop position --value '{"type":"Vector2","x":10,"y":20}'`
- [x] `bin/godotctl.exe scene remove-node --scene scenes/tools_e2e.tscn --path Sprite2D`
- [x] Repeat previous remove command and confirm deterministic failure (`NOT_FOUND`).
- [ ] `bin/godotctl.exe script create --path scripts/tools_e2e.gd --base CharacterBody2D`
- [ ] `bin/godotctl.exe script validate --path scripts/tools_e2e.gd --json`
- [ ] `bin/godotctl.exe script edit --path scripts/tools_e2e.gd --find "pass" --replace "print(\"ready\")"`
- [ ] `bin/godotctl.exe script attach --scene scenes/tools_e2e.tscn --node . --script scripts/tools_e2e.gd`
- [ ] `bin/godotctl.exe project settings get --key application/config/name --json`
- [ ] `bin/godotctl.exe project input-map get --json`
- [ ] `bin/godotctl.exe file list --path scripts --json`
- [ ] `bin/godotctl.exe file read --path scripts/tools_e2e.gd --json`
- [ ] Confirm `docs/DOCUMENTATION.md` includes every command and flag implemented above.
