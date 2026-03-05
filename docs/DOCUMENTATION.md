# Documentation

This file is the command reference for `godotctl`.

Use project-relative paths for command flags that take a project path (for example `scenes/player.tscn`).

## Global Flags

- `--json`
  - Output machine-readable JSON envelopes for success/failure.
  - On tool failures, `error.tool_code` may be present (for example `INVALID_ARGS`, `ALREADY_EXISTS`).

## Commands

### `godotctl daemon start`

- What it does:
  - Starts the local daemon process and serves WebSocket/HTTP endpoints.
- Flags:
  - `--owner-token <string>`: Owner token used for conditional daemon stop.

### `godotctl daemon stop`

- What it does:
  - Requests daemon shutdown.
- Flags:
  - `--owner-token <string>`: Only stop if daemon owner token matches.

### `godotctl status`

- What it does:
  - Shows daemon health and plugin connection state.
- Flags:
  - None.

### `godotctl tools list`

- What it does:
  - Lists tool names currently advertised by the connected plugin.
- Flags:
  - None.

### `godotctl tools ping`

- What it does:
  - Sends a minimal ping tool call through daemon -> plugin -> daemon.
- Flags:
  - None.

### `godotctl scene create`

- What it does:
  - Creates a scene file with a root node and saves it through Godot APIs.
- Flags:
  - `--scene <path>`: Scene path (project-relative `.tscn` path).
  - `--root <NodeClass>`: Root node class (for example `CharacterBody2D`).
  - `--name <NodeName>`: Root node name.
  - `--overwrite`: Overwrite target scene if it already exists.
  - `--open`: Open scene in editor after creation.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl scene create --scene scenes/player.tscn --root CharacterBody2D --name Player`

## Exit Codes

- `0`: Success
- `1`: Validation error
- `2`: Daemon unavailable
- `3`: Plugin disconnected
- `4`: Operation failed
