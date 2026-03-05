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

### `godotctl script create`

- What it does:
  - Creates a `.gd` script file from a deterministic template source.
- Flags:
  - `--path <path>`: Script path (project-relative `.gd` path).
  - `--base <BaseClass>`: Base class used in `extends`.
  - `--class-name <Name>`: Optional `class_name` declaration.
  - `--overwrite`: Overwrite target script if it already exists.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl script create --path scripts/player.gd --base CharacterBody2D`

### `godotctl script edit`

- What it does:
  - Reads a script file, performs literal replace-all, and writes the result.
- Flags:
  - `--path <path>`: Script path (project-relative `.gd` path).
  - `--find <text>`: Literal text to search for.
  - `--replace <text>`: Replacement text (can be empty).
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl script edit --path scripts/player.gd --find pass --replace 'print("ready")'`

### `godotctl script validate`

- What it does:
  - Validates script parse/compile state and returns `valid` plus diagnostics.
- Flags:
  - `--path <path>`: Script path (project-relative `.gd` path).
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl script validate --path scripts/player.gd --json`

### `godotctl script attach`

- What it does:
  - Loads a scene, resolves a node path, attaches a script, and saves the scene.
- Flags:
  - `--scene <path>`: Scene path (project-relative `.tscn` path).
  - `--node <NodePath>`: Target node path (`.` means root).
  - `--script <path>`: Script path (project-relative `.gd` path).
  - `--overwrite`: Replace an existing script already attached on the node.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl script attach --scene scenes/player.tscn --node . --script scripts/player.gd`

### `godotctl project settings get`

- What it does:
  - Returns one project setting by key, or a deterministic sorted list of public project settings.
- Flags:
  - `--key <setting>`: Optional project setting key (for example `application/config/name`).
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl project settings get --key application/config/name --json`

### `godotctl project input-map get`

- What it does:
  - Returns input actions and deterministic event summaries from the project input map.
- Flags:
  - `--action <name>`: Optional action name (for example `ui_accept`).
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl project input-map get --json`

### `godotctl file list`

- What it does:
  - Lists files/directories under a project path in stable sorted order.
- Flags:
  - `--path <path>`: Project-relative path to a directory.
  - `--recursive`: Recursively include nested files/directories.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl file list --path scripts --json`

### `godotctl file read`

- What it does:
  - Reads a project file as text and returns file contents plus byte count.
- Flags:
  - `--path <path>`: Project-relative path to a file.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl file read --path scripts/player.gd --json`

## Exit Codes

- `0`: Success
- `1`: Validation error
- `2`: Daemon unavailable
- `3`: Plugin disconnected
- `4`: Operation failed
