# godotctl

Scaffold for a Windows-first Godot editor bridge:

- `godotctl` CLI + daemon (Go)
- `godot_bridge` editor plugin (GDScript)

Current scaffold goal is connectivity validation only:

- daemon starts and exposes local WS/HTTP endpoints
- plugin connects over WebSocket and logs to Godot output on successful handshake

## Layout

- `cmd/godotctl` - CLI entrypoint
- `internal/daemon` - daemon runtime (HTTP + WebSocket)
- `addons/godot_bridge` - Godot editor plugin

## Build

This repo uses `mise` for tool versions (Go 1.25.x).

```bash
mise exec -- go build -o bin/godotctl.exe ./cmd/godotctl
```

Or use the built-in mise task (also copies binary to `addons/godot_bridge/bin/godotctl.exe`):

```bash
mise run build
```

## Run CLI via mise

You can run the CLI directly with the `cli` task and pass command args after `--`:

```bash
mise run cli -- status
mise run cli -- tools list
```

## Sample Project Tasks

Copy the addon into the sample project:

```bash
mise run copy-addon
```

Launch the sample project in Godot 4.6 (runs `build` + `copy-addon` first):

```bash
mise run launch-sample
```

Launch detached (returns terminal immediately):

```bash
mise run launch-sample-detached
```

Set `GODOT46_EXE` before running launch:

```bash
export GODOT46_EXE="/c/Tools/Godot_v4.6-stable_win64.exe"
```

Or create a local `.env` (loaded by `mise.toml`) from `.env.example`.

Use forward slashes in `.env` on Windows, for example:

```dotenv
GODOT46_EXE=C:/Godot/4_6_1/Godot_v4.6.1-stable_win64.exe
```

## Run Daemon

```bash
bin/godotctl.exe daemon start
```

Daemon endpoints:

- WebSocket: `ws://127.0.0.1:6505/ws`
- HTTP status: `http://127.0.0.1:6506/status`

In another shell:

```bash
bin/godotctl.exe status
```

Once plugin is connected:

```bash
bin/godotctl.exe tools ping
```

Expected output:

`tools ping ok: pong from godot_bridge (request_id=req_1)`

## Auto-start Behavior (Plugin)

When the plugin can't reach the daemon, it will try to launch it with:

- `res://addons/godot_bridge/bin/godotctl.exe`
- `godotctl.exe` from `PATH`
- `godotctl` from `PATH`

Launch attempts are throttled (cooldown + reconnect backoff) to avoid log spam.

## Test in Godot

1. Copy `addons/godot_bridge/` into a Godot project.
2. Open the project in Godot.
3. Enable plugin in `Project Settings -> Plugins`.
4. Watch Godot Output for:

`godot_bridge: connected to daemon`

If project name is set, it logs:

`godot_bridge: connected to daemon for project '<name>'`

When running `godotctl tools ping`, Godot output should also show:

`godot_bridge: received tools.ping request`
