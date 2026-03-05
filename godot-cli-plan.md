# Godot CLI + Daemon Build Plan

## 1. Product Goal

Build a Windows-first local toolchain that lets you drive Godot editor operations from a command line tool.

The final system has three parts:

- A Godot editor plugin that executes scene, script, and project operations.
- A local daemon that brokers requests and tracks connection state.
- A CLI (`godotctl.exe`) for human and script-driven commands.

The CLI should feel fast and scriptable, while all project mutations still run through Godot APIs inside the editor.

## 2. End-State Behavior

When the editor opens a project with the plugin enabled:

- The plugin starts and attempts to connect to a local daemon.
- If daemon is not running, plugin can launch `godotctl.exe daemon` and retry connection.
- CLI commands (`godotctl scene add-node ...`) are sent to daemon.
- Daemon forwards the request to plugin.
- Plugin executes the tool in editor context and returns structured results.
- CLI prints compact output for terminal usage.

## 3. Runtime Architecture

### 3.1 Processes

- `Godot Editor` process
- `godotctl.exe` daemon process
- `godotctl.exe` CLI invocation process (short-lived)

### 3.2 Communication Paths

- Plugin <-> Daemon: WebSocket on `127.0.0.1:6505`
- CLI <-> Daemon: local HTTP JSON API on `127.0.0.1:6506`

This split keeps plugin messaging real-time and keeps CLI usage simple for shell scripting.

### 3.3 Execution Model

- Daemon owns request IDs, inflight tracking, timeout handling, and connection state.
- Plugin owns all Godot-side execution and file/resource save behavior.
- CLI is stateless: parse args, call daemon, print result, exit.

## 4. Godot Plugin Design

### 4.1 Plugin Responsibilities

- Start on editor load and register status indicator in toolbar.
- Maintain WebSocket client connection to daemon.
- Auto-reconnect with backoff.
- Optionally auto-start daemon if first connection fails.
- Route incoming tool calls to operation handlers.
- Return success/error payloads with request ID.
- Refresh filesystem and edited scene when operations modify project content.

### 4.2 Plugin Modules

- `plugin.gd`
  - lifecycle (`_enter_tree`, `_exit_tree`)
  - UI status label
  - daemon launch and connection bootstrap
- `daemon_client.gd`
  - WebSocket connect/poll/reconnect
  - message parse/serialize
- `tool_executor.gd`
  - tool name -> handler mapping
  - shared validation and error wrapping
- `tools/scene_tools.gd`
  - create/read/update scene operations
- `tools/script_tools.gd`
  - script create/edit/validate/attach
- `tools/project_tools.gd`
  - project settings, tree dump, editor state
- `tools/file_tools.gd`
  - list/read/search helpers

### 4.3 Plugin Data Rules

- All paths normalized to `res://` before execution.
- Node paths support `.` for root and relative child paths.
- Scene writes use `PackedScene.pack` + `ResourceSaver.save`.
- Node/resource property sets validate compatibility before write.
- Results always include `ok: true|false` and a clear message.

## 5. Daemon Design (Go)

### 5.1 Daemon Responsibilities

- Start WebSocket server for plugin connection.
- Accept one active plugin session at a time.
- Start local HTTP API for CLI commands.
- Translate CLI requests into plugin tool invokes.
- Track pending requests with timeout and cancellation.
- Report health and connection status.
- Persist lightweight logs for troubleshooting.

### 5.2 Core Daemon Services

- `ConnectionManager`
  - plugin connect/disconnect
  - ping/pong keepalive
- `RequestBroker`
  - request ID generation
  - inflight map
  - timeout completion
- `ToolGateway`
  - validates command payload shape
  - forwards to plugin
  - normalizes response/error format
- `StatusService`
  - current project path
  - connected since timestamp
  - pending request count

### 5.3 Daemon API (for CLI)

- `GET /status`
- `POST /tools/call`
- `POST /daemon/stop`

`POST /tools/call` body:

- `tool`: string
- `args`: object
- `timeout_ms`: optional int

Response:

- `ok`: bool
- `result`: object (on success)
- `error`: string (on failure)
- `request_id`: string

## 6. CLI Design (Go)

### 6.1 CLI Responsibilities

- Parse command-line args and flags.
- Ensure daemon is reachable.
- Invoke daemon API and render output.
- Provide both human-readable and JSON output modes.
- Accept project-relative paths and normalize them before execution.

### 6.2 Top-Level Commands

- `godotctl daemon start`
- `godotctl daemon stop`
- `godotctl status`
- `godotctl tools list`

### 6.3 Scene Commands

- `godotctl scene create --scene scenes/player.tscn --root CharacterBody2D --name Player`
- `godotctl scene add-node --scene ... --name Sprite2D --type Sprite2D --parent .`
- `godotctl scene remove-node --scene ... --path Sprite2D`
- `godotctl scene set-prop --scene ... --path Sprite2D --prop position --value '{"type":"Vector2","x":100,"y":200}'`
- `godotctl scene tree --scene scenes/player.tscn`

### 6.4 Script Commands

- `godotctl script create --path scripts/player.gd --base CharacterBody2D`
- `godotctl script edit --path ... --find "old" --replace "new"`
- `godotctl script validate --path ...`
- `godotctl script attach --scene ... --node . --script scripts/player.gd`

### 6.5 Project and File Commands

- `godotctl project settings get`
- `godotctl project input-map get`
- `godotctl file list --path .`
- `godotctl file read --path scripts/player.gd`

### 6.6 Output Modes

- default: concise text
- `--json`: machine-readable output for automation
- exit codes:
  - `0` success
  - `1` validation error
  - `2` daemon unavailable
  - `3` plugin disconnected
  - `4` operation failed

## 7. Wire Protocol Between Daemon and Plugin

### 7.1 Message Types

- `hello` (plugin -> daemon)
- `tool_invoke` (daemon -> plugin)
- `tool_result` (plugin -> daemon)
- `ping` and `pong`

### 7.2 Example Tool Invoke

```json
{
  "type": "tool_invoke",
  "id": "req_123",
  "tool": "add_node",
  "args": {
    "scene_path": "res://scenes/player.tscn",
    "node_name": "Sprite2D",
    "node_type": "Sprite2D",
    "parent_path": "."
  }
}
```

### 7.3 Example Tool Result

```json
{
  "type": "tool_result",
  "id": "req_123",
  "ok": true,
  "result": {
    "message": "Added Sprite2D"
  }
}
```

## 8. Startup and Lifecycle Flow

1. User opens Godot project.
2. Plugin loads and attempts daemon connection.
3. If unreachable, plugin launches daemon executable and retries.
4. Plugin sends `hello` with project metadata.
5. User runs CLI command.
6. CLI calls daemon HTTP endpoint.
7. Daemon forwards request to plugin and waits for response.
8. Daemon returns result to CLI.
9. CLI prints output and exits.

## 9. Packaging Plan

### 9.1 Binary Packaging

Ship `godotctl.exe` inside plugin directory:

- `addons/godot_bridge/bin/godotctl.exe`

### 9.2 Plugin Configuration

Plugin stores daemon settings in project/editor settings:

- daemon path
- websocket host/port
- auto-start enabled
- reconnect policy

### 9.3 Logging Locations

- Daemon log: `%LOCALAPPDATA%/godotctl/logs/daemon.log`
- Plugin log: Godot editor output panel

## 10. Implementation Milestones

### Milestone A: Connectivity Base

- Daemon WebSocket server
- Plugin WebSocket client
- handshake, ping/pong, status display

### Milestone B: CLI Control Plane

- daemon start/stop/status
- CLI to daemon HTTP bridge
- consistent output and exit codes

### Milestone C: Scene Operation Path

- scene create/add/remove/set-prop
- save/reload correctness in editor
- full end-to-end tests from CLI

### Milestone D: Script and Project Operations

- script create/edit/validate/attach
- project settings and file utilities

### Milestone E: Packaging and Stability

- packaged binary in plugin
- auto-start behavior finalized
- logs and failure diagnostics polished

## 11. Build Completion Criteria

The build is complete when:

- Opening Godot with plugin enabled reliably establishes daemon connectivity.
- CLI commands perform real scene/script/project operations through plugin handlers.
- Output is predictable for both human and scripted usage.
- Connection loss, timeout, and invalid argument cases return clear errors.
- Packaged plugin + binary can be copied to a new project and work with minimal setup.
