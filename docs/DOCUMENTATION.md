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

### `godotctl version`

- What it does:
  - Shows CLI build version, commit, and build date metadata.
- Flags:
  - None.
- Example:
  - `godotctl version --json`

### `godotctl install-bridge`

- What it does:
  - Detects the current Godot project root by searching upward for `project.godot`.
  - Installs the bundled `addons/godot_bridge` addon into that project.
- Flags:
  - `--force`: Overwrite an existing `addons/godot_bridge` directory.
- Notes:
  - Fails when run outside a Godot project.
  - Requires `--force` when the addon directory already exists.
- Example:
  - `godotctl install-bridge --force`

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

### `godotctl tools describe`

- What it does:
  - Returns machine-readable tool argument/result/error schemas.
- Flags:
  - `--tool <name>`: Optional tool name to describe one tool schema.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl tools describe --tool scene.create --json`

### `godotctl run start`

- What it does:
  - Starts project runtime in the editor, optionally with one scene override.
- Notes:
  - Runtime bridge inspection/input commands require `res://addons/godot_bridge/runtime_bridge.gd` to be loaded by the running game (for example as an autoload).
- Flags:
  - `--scene <path>`: Optional project-relative scene path to run.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.

### `godotctl run stop`

- What it does:
  - Stops project runtime in the editor.
- Flags:
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.

### `godotctl run status`

- What it does:
  - Returns stable runtime status fields from the editor runtime bridge.
- Flags:
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.

### `godotctl run logs`

- What it does:
  - Lists captured runtime/editor log rows with optional cursor/filter/follow controls.
- Flags:
  - `--cursor <int>`: Return logs with cursor greater than this value.
  - `--max <int>`: Max returned log rows (`0` means no limit, default `200`).
  - `--level <string>`: Optional exact lowercase log level filter.
  - `--contains <string>`: Optional log message substring filter.
  - `--follow`: Enable polling window behavior for incremental log streaming.
  - `--follow-ms <int>`: Polling window in milliseconds when `--follow` is enabled.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.

### `godotctl run tree`

- What it does:
  - Lists runtime tree snapshot nodes in deterministic order.
- Notes:
  - Returns `EDITOR_STATE` when the runtime bridge is not attached.
- Flags:
  - `--max <int>`: Max returned node rows (`0` means no limit, default `200`).
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.

### `godotctl run prop get`

- What it does:
  - Returns one runtime node property value from the latest snapshot.
- Flags:
  - `--path <NodePath>`: Runtime node path.
  - `--prop <Property>`: Runtime property name.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.

### `godotctl run prop list`

- What it does:
  - Lists runtime node properties from the latest snapshot.
- Flags:
  - `--path <NodePath>`: Runtime node path.
  - `--max <int>`: Max returned property rows (`0` means no limit, default `200`).
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.

### `godotctl run input event`

- What it does:
  - Dispatches one runtime input event payload object.
- Flags:
  - `--event <json>`: Runtime input event JSON object payload.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.

### `godotctl run input action press`

- What it does:
  - Dispatches one runtime input action press.
- Flags:
  - `--action <name>`: Runtime input action name.
  - `--strength <float>`: Optional action strength (default `1.0`).
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.

### `godotctl run input action release`

- What it does:
  - Dispatches one runtime input action release.
- Flags:
  - `--action <name>`: Runtime input action name.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.

### `godotctl run step`

- What it does:
  - Dispatches one deterministic runtime step command.
- Flags:
  - `--frames <int>`: Number of frames to step.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.

### `godotctl class describe`

- What it does:
  - Returns Godot class metadata with progressive disclosure.
  - Summary counts are always returned; detailed properties/methods/signals/inheritors are opt-in.
- Flags:
  - `--name <ClassName>`: Godot class name (for example `CharacterBody2D`).
  - `--include-properties`: Include detailed property metadata.
  - `--include-methods`: Include detailed method metadata.
  - `--include-signals`: Include detailed signal metadata.
  - `--include-inheritors`: Include direct inheritor class names.
  - `--full`: Include all optional detailed sections.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl class describe --name CharacterBody2D --json`
  - `godotctl class describe --name CharacterBody2D --full --json`

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

### `godotctl scene rename`

- What it does:
  - Loads a scene, renames one node by path, and saves the scene.
- Flags:
  - `--scene <path>`: Scene path (project-relative `.tscn` path).
  - `--path <NodePath>`: Node path to rename.
  - `--name <NodeName>`: New node name.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl scene rename --scene scenes/player.tscn --path Sprite2D --name PlayerSprite`

### `godotctl scene reparent`

- What it does:
  - Loads a scene, moves one node under a new parent path, and saves the scene.
- Flags:
  - `--scene <path>`: Scene path (project-relative `.tscn` path).
  - `--path <NodePath>`: Node path to move.
  - `--parent <NodePath>`: Destination parent node path.
  - `--index <int>`: Optional destination child index under the parent.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl scene reparent --scene scenes/player.tscn --path Sprite2D --parent .`

### `godotctl scene duplicate`

- What it does:
  - Loads a scene, duplicates one source node under a parent path, and saves the scene.
- Flags:
  - `--scene <path>`: Scene path (project-relative `.tscn` path).
  - `--path <NodePath>`: Source node path to duplicate.
  - `--parent <NodePath>`: Parent node path for the duplicate.
  - `--name <NodeName>`: Optional duplicate node name override.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl scene duplicate --scene scenes/player.tscn --path Sprite2D --parent .`

### `godotctl scene instance-scene`

- What it does:
  - Loads a scene, instances another scene under a parent path, and saves the scene.
- Flags:
  - `--scene <path>`: Scene path (project-relative `.tscn` path).
  - `--source-scene <path>`: Source `.tscn` path to instance.
  - `--parent <NodePath>`: Parent node path for the instanced root.
  - `--name <NodeName>`: Optional created node name override.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl scene instance-scene --scene scenes/player.tscn --source-scene scenes/effects/hit.tscn --parent .`

### `godotctl scene signal connect`

- What it does:
  - Loads a scene, connects one signal from a source node to an in-scene target node method, and saves the scene.
- Flags:
  - `--scene <path>`: Scene path (project-relative `.tscn` path).
  - `--from <NodePath>`: Source node path.
  - `--signal <SignalName>`: Signal name.
  - `--to <NodePath>`: Target node path.
  - `--method <MethodName>`: Target method name.
  - `--flags <int>`: Optional connection flags.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl scene signal connect --scene scenes/player.tscn --from . --signal ready --to . --method _on_ready`

### `godotctl scene signal disconnect`

- What it does:
  - Loads a scene, disconnects one signal target method, and saves the scene when changed.
- Flags:
  - `--scene <path>`: Scene path (project-relative `.tscn` path).
  - `--from <NodePath>`: Source node path.
  - `--signal <SignalName>`: Signal name.
  - `--to <NodePath>`: Target node path.
  - `--method <MethodName>`: Target method name.
  - `--flags <int>`: Optional connection flags filter.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl scene signal disconnect --scene scenes/player.tscn --from . --signal ready --to . --method _on_ready`

### `godotctl scene signal list`

- What it does:
  - Loads a scene and returns deterministic in-scene signal connection rows.
- Flags:
  - `--scene <path>`: Scene path (project-relative `.tscn` path).
  - `--from <NodePath>`: Optional source node path filter.
  - `--signal <SignalName>`: Optional signal name filter.
  - `--to <NodePath>`: Optional target node path filter.
  - `--method <MethodName>`: Optional method name filter.
  - `--max <int>`: Max returned connection rows (`0` means no limit).
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl scene signal list --scene scenes/player.tscn --json`

### `godotctl scene group add`

- What it does:
  - Loads a scene, adds one node to one group, and saves the scene when changed.
- Flags:
  - `--scene <path>`: Scene path (project-relative `.tscn` path).
  - `--path <NodePath>`: Node path.
  - `--group <GroupName>`: Group name.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl scene group add --scene scenes/player.tscn --path . --group player`

### `godotctl scene group remove`

- What it does:
  - Loads a scene, removes one node from one group, and saves the scene when changed.
- Flags:
  - `--scene <path>`: Scene path (project-relative `.tscn` path).
  - `--path <NodePath>`: Node path.
  - `--group <GroupName>`: Group name.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl scene group remove --scene scenes/player.tscn --path . --group player`

### `godotctl scene group list`

- What it does:
  - Loads a scene and returns deterministic group membership rows.
- Flags:
  - `--scene <path>`: Scene path (project-relative `.tscn` path).
  - `--path <NodePath>`: Optional node path scope.
  - `--max <int>`: Max returned rows (`0` means no limit).
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl scene group list --scene scenes/player.tscn --json`

### `godotctl scene transform apply`

- What it does:
  - Loads a scene, applies a JSON transform object to one node, and saves the scene when changed.
- Flags:
  - `--scene <path>`: Scene path (project-relative `.tscn` path).
  - `--path <NodePath>`: Node path.
  - `--value <json>`: Transform JSON object.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl scene transform apply --scene scenes/player.tscn --path . --value '{"position":{"type":"Vector2","x":10,"y":20}}'`

### `godotctl scene node configure`

- What it does:
  - Loads a scene, applies a JSON property map to one node, and saves the scene when changed.
- Flags:
  - `--scene <path>`: Scene path (project-relative `.tscn` path).
  - `--path <NodePath>`: Node path.
  - `--config <json>`: JSON object mapping property names to values.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl scene node configure --scene scenes/player.tscn --path . --config '{"visible":true}'`

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

### `godotctl scene inspect`

- What it does:
  - Loads a scene and returns deterministic snapshots of node paths and groups.
  - Supports progressive disclosure flags for properties, signal names, and signal connections to keep payloads smaller on large scenes.
- Flags:
  - `--scene <path>`: Scene path (project-relative `.tscn` path).
  - `--node <path>`: Optional node path to inspect a single subtree.
  - `--include-properties`: Include per-node property snapshots.
  - `--include-property-values`: Include serialized property values (requires `--include-properties`).
  - `--include-connections`: Include signal connection rows.
  - `--include-signal-names`: Include per-node signal names.
  - `--max-properties <int>`: Max properties per node when included (`0` means no limit, default `16`).
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl scene inspect --scene scenes/player.tscn --json`
  - `godotctl scene inspect --scene scenes/player.tscn --node Enemies --include-connections --json`
  - `godotctl scene inspect --scene scenes/player.tscn --include-properties --max-properties 8 --json`

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
  - Supports progressive disclosure for large projects: filter by prefix, count-only mode, and optional value payloads.
- Flags:
  - `--key <setting>`: Optional project setting key (for example `application/config/name`).
  - `--prefix <prefix>`: Optional setting key prefix filter (for example `application/config`).
  - `--include-values`: Include serialized setting values in rows.
  - `--count-only`: Return counts only without setting rows.
  - `--max-settings <int>`: Max returned setting rows (`0` means no limit, default `200`).
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Notes:
  - `--key` and `--prefix` cannot be used together.
  - `--count-only` and `--include-values` cannot be used together.
  - When `--key` is set, values are included by default unless `--count-only` is used.
- Example:
  - `godotctl project settings get --key application/config/name --json`
  - `godotctl project settings get --prefix application --max-settings 50 --json`

### `godotctl project settings set`

- What it does:
  - Sets one project setting from a JSON value and saves `project.godot` when changed.
- Flags:
  - `--key <setting>`: Project setting key (for example `application/config/name`).
  - `--value <json>`: JSON primitive, object, array, or supported typed value payload.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl project settings set --key application/config/name --value '"My Game"' --json`

### `godotctl project input-map get`

- What it does:
  - Returns input actions from the project input map with deterministic ordering.
  - Supports progressive disclosure with action-prefix filtering, count-only mode, and action/event limits.
  - Event rows include a canonical `event_key`, typed `event` payload, and summary text when `--include-events` is enabled.
- Flags:
  - `--action <name>`: Optional action name (for example `ui_accept`).
  - `--prefix <prefix>`: Optional action name prefix filter.
  - `--include-events`: Include summarized event rows per action.
  - `--count-only`: Return counts only without action rows.
  - `--max-actions <int>`: Max returned action rows (`0` means no limit, default `200`).
  - `--max-events <int>`: Max returned events per action (`0` means no limit, default `200`).
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Notes:
  - `--action` and `--prefix` cannot be used together.
  - `--count-only` and `--include-events` cannot be used together.
  - When `--action` is set, events are included by default unless `--count-only` is used.
- Example:
  - `godotctl project input-map get --json`
  - `godotctl project input-map get --prefix ui_ --include-events --max-actions 20 --max-events 10 --json`

### `godotctl project input-map action create`

- What it does:
  - Creates one input action with a deadzone and no events.
- Flags:
  - `--action <name>`: Input action name.
  - `--deadzone <float>`: Action deadzone (default `0.5`).
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl project input-map action create --action ui_accept --deadzone 0.5 --json`

### `godotctl project input-map action delete`

- What it does:
  - Deletes one input action when present.
- Flags:
  - `--action <name>`: Input action name.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl project input-map action delete --action ui_accept --json`

### `godotctl project input-map event add`

- What it does:
  - Adds one typed input event to one input action.
- Flags:
  - `--action <name>`: Input action name.
  - `--event <json>`: Typed event JSON payload.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Supported event types:
  - `key`: `{"type":"key","keycode":4194309}`
  - `mouse_button`: `{"type":"mouse_button","button_index":1}`
  - `joypad_button`: `{"type":"joypad_button","device":0,"button_index":0}`
  - `joypad_motion`: `{"type":"joypad_motion","device":0,"axis":0,"axis_value":1.0}`
- Example:
  - `godotctl project input-map event add --action ui_accept --event '{"type":"key","keycode":4194309}' --json`

### `godotctl project input-map event remove`

- What it does:
  - Removes one typed input event from one input action when present.
- Flags:
  - `--action <name>`: Input action name.
  - `--event <json>`: Typed event JSON payload.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl project input-map event remove --action ui_accept --event '{"type":"key","keycode":4194309}' --json`

### `godotctl project input-map deadzone set`

- What it does:
  - Sets one input action deadzone.
- Flags:
  - `--action <name>`: Input action name.
  - `--value <float>`: Deadzone value.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl project input-map deadzone set --action ui_accept --value 0.5 --json`

### `godotctl project autoload list`

- What it does:
  - Lists project autoload entries in deterministic order.
- Flags:
  - `--name <name>`: Optional autoload name filter.
  - `--max <int>`: Max returned rows (`0` means no limit, default `200`).
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl project autoload list --json`

### `godotctl project autoload add`

- What it does:
  - Adds one autoload entry from a script or scene path.
- Flags:
  - `--name <name>`: Autoload name.
  - `--path <path>`: Project-relative script or scene path.
  - `--singleton`: Register as a singleton (default `true`).
  - `--index <int>`: Optional autoload order index.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl project autoload add --name Globals --path scripts/globals.gd --singleton --json`

### `godotctl project autoload remove`

- What it does:
  - Removes one autoload entry by name when present.
- Flags:
  - `--name <name>`: Autoload name.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl project autoload remove --name Globals --json`

### `godotctl project import get`

- What it does:
  - Returns deterministic rows from one asset's `.import` metadata file.
- Flags:
  - `--path <path>`: Source asset path, not the `.import` path.
  - `--key <section/name>`: Optional exact import property key.
  - `--prefix <prefix>`: Optional import property key prefix.
  - `--include-values`: Include serialized values.
  - `--max-properties <int>`: Max returned property rows (`0` means no limit, default `200`).
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl project import get --path icon.svg --include-values --json`

### `godotctl project import set`

- What it does:
  - Sets one import metadata property and saves the `.import` file when changed.
  - Does not automatically reimport the asset.
- Flags:
  - `--path <path>`: Source asset path, not the `.import` path.
  - `--key <section/name>`: Import property key.
  - `--value <json>`: JSON value payload.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl project import set --path icon.svg --key params/compress/mode --value '1' --json`

### `godotctl project import reimport`

- What it does:
  - Reimports one source asset through Godot after import metadata changes.
- Flags:
  - `--path <path>`: Source asset path.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl project import reimport --path icon.svg --json`

### `godotctl project graph`

- What it does:
  - Scans project resources and returns deterministic graph counts.
  - Uses progressive disclosure: node/edge rows are opt-in to keep large-project payloads smaller.
- Flags:
  - `--root <path>`: Optional graph root path (defaults to `res://`).
  - `--prefix <path>`: Optional path prefix filter for nodes/edges.
  - `--include-nodes`: Include node rows in output.
  - `--include-edges`: Include edge rows in output.
  - `--full`: Include both nodes and edges.
  - `--max-nodes <int>`: Max returned node rows (`0` means no limit, default `200`).
  - `--max-edges <int>`: Max returned edge rows (`0` means no limit, default `200`).
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl project graph --json`
  - `godotctl project graph --prefix scenes/stress --include-edges --max-edges 200 --json`

### `godotctl resource create`

- What it does:
  - Creates a resource file from one Resource class type.
- Flags:
  - `--path <path>`: Project-relative resource path to create.
  - `--type <ClassName>`: Resource class to instantiate.
  - `--overwrite`: Overwrite existing file at target path.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl resource create --path data/player.tres --type Resource`

### `godotctl resource get`

- What it does:
  - Loads one resource and returns one property value.
- Flags:
  - `--path <path>`: Project-relative resource path.
  - `--prop <Property>`: Property name.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl resource get --path data/player.tres --prop resource_name --json`

### `godotctl resource set-prop`

- What it does:
  - Loads one resource, sets one property from JSON input, and saves when changed.
- Flags:
  - `--path <path>`: Project-relative resource path.
  - `--prop <Property>`: Property name to set.
  - `--value <json>`: JSON primitive or typed object payload.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl resource set-prop --path data/player.tres --prop resource_name --value '"Player"'`

### `godotctl resource list`

- What it does:
  - Loads one resource and returns deterministic property rows.
- Flags:
  - `--path <path>`: Project-relative resource path.
  - `--include-values`: Include serialized property values.
  - `--max-properties <int>`: Max returned property rows (`0` means no limit, default `200`).
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl resource list --path data/player.tres --include-values --json`

### `godotctl resource refs`

- What it does:
  - Returns deterministic reverse references to one project resource path.
  - Supports progressive disclosure with source-prefix filtering, count-only mode, and row limits.
- Flags:
  - `--path <path>`: Project-relative resource path to inspect.
  - `--from-prefix <path>`: Optional source path prefix filter.
  - `--count-only`: Return counts only without reference rows.
  - `--max-refs <int>`: Max returned reference rows (`0` means no limit, default `200`).
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl resource refs --path scenes/player.tscn --json`
  - `godotctl resource refs --path scripts/stress/shared_ai.gd --from-prefix scenes/stress --max-refs 25 --json`

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

### `godotctl file json get`

- What it does:
  - Reads one JSON value by JSON Pointer (`""` means the whole document).
- Flags:
  - `--path <path>`: Project-relative `.json` file path.
  - `--pointer <json-pointer>`: Optional JSON Pointer.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl file json get --path data/config.json --pointer /game/name --json`

### `godotctl file json set`

- What it does:
  - Sets one JSON value by JSON Pointer and saves the file when changed.
- Flags:
  - `--path <path>`: Project-relative `.json` file path.
  - `--pointer <json-pointer>`: Optional JSON Pointer.
  - `--value <json>`: JSON value payload.
  - `--create`: Create the file if missing.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl file json set --path data/config.json --pointer /game/name --value '"Demo"' --json`

### `godotctl file json remove`

- What it does:
  - Removes one JSON value by JSON Pointer when present.
- Flags:
  - `--path <path>`: Project-relative `.json` file path.
  - `--pointer <json-pointer>`: JSON Pointer to remove.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl file json remove --path data/config.json --pointer /game/name --json`

### `godotctl file cfg get`

- What it does:
  - Reads deterministic section/key rows from a `.cfg`-style file.
- Flags:
  - `--path <path>`: Project-relative `.cfg` path.
  - `--section <name>`: Optional section filter.
  - `--key <name>`: Optional key filter (requires `--section`).
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl file cfg get --path addons/godot_bridge/plugin.cfg --section plugin --key name --json`

### `godotctl file cfg set`

- What it does:
  - Sets one value in a `.cfg`-style file and saves when changed.
- Flags:
  - `--path <path>`: Project-relative `.cfg` path.
  - `--section <name>`: Section name.
  - `--key <name>`: Key name.
  - `--value <json>`: JSON value payload.
  - `--create`: Create the file if missing.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl file cfg set --path addons/godot_bridge/plugin.cfg --section plugin --key name --value '"Bridge"' --json`

### `godotctl file cfg remove`

- What it does:
  - Removes one section or one key from a `.cfg`-style file when present.
- Flags:
  - `--path <path>`: Project-relative `.cfg` path.
  - `--section <name>`: Section name.
  - `--key <name>`: Optional key name. If omitted, removes the whole section.
  - `--timeout-ms <int>`: Tool request timeout override in milliseconds.
- Example:
  - `godotctl file cfg remove --path addons/godot_bridge/plugin.cfg --section plugin --key name --json`

## Exit Codes

- `0`: Success
- `1`: Validation error
- `2`: Daemon unavailable
- `3`: Plugin disconnected
- `4`: Operation failed
