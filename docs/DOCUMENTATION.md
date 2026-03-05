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

### `godotctl scene add-node`

- What it does:
  - Loads a scene, adds a child node under a parent node path, and saves the scene.
- Flags:
  - `--scene <path>`: Scene path (project-relative `.tscn` path).
  - `--name <NodeName>`: New child node name.
  - `--type <NodeClass>`: Node class to instantiate (for example `Sprite2D`).
  - `--parent <NodePath>`: Parent node path (`.` means root).
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl scene add-node --scene scenes/player.tscn --name Sprite2D --type Sprite2D --parent .`

### `godotctl scene remove-node`

- What it does:
  - Loads a scene, removes one node by path, and saves the scene.
- Flags:
  - `--scene <path>`: Scene path (project-relative `.tscn` path).
  - `--path <NodePath>`: Node path to remove (`.` means root and is rejected).
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl scene remove-node --scene scenes/player.tscn --path Sprite2D`

### `godotctl scene set-prop`

- What it does:
  - Loads a scene, sets one node property from JSON input, and saves the scene.
- Flags:
  - `--scene <path>`: Scene path (project-relative `.tscn` path).
  - `--path <NodePath>`: Target node path (`.` means root).
  - `--prop <Property>`: Property name to set.
  - `--value <json>`: JSON primitive or typed object payload.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Typed object formats:
  - `Vector2`: `{"type":"Vector2","x":10,"y":20}`
  - `Vector3`: `{"type":"Vector3","x":1,"y":2,"z":3}`
  - `Color`: `{"type":"Color","r":1,"g":0.5,"b":0.25,"a":1}` (`a` optional)
  - `NodePath`: `{"type":"NodePath","value":"Player/Sprite2D"}`
- Example:
  - `godotctl scene set-prop --scene scenes/player.tscn --path . --prop position --value '{"type":"Vector2","x":10,"y":20}'`

### `godotctl scene tree`

- What it does:
  - Loads a scene and returns a deterministic node list (`path`, `name`, `type`, `child_count`).
- Flags:
  - `--scene <path>`: Scene path (project-relative `.tscn` path).
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl scene tree --scene scenes/player.tscn`

## Exit Codes

- `0`: Success
- `1`: Validation error
- `2`: Daemon unavailable
- `3`: Plugin disconnected
- `4`: Operation failed
