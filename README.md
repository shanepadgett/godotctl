# godotctl

`godotctl` is a local CLI + daemon + Godot editor plugin that lets terminal commands trigger editor operations.

## Requirements

- Windows-first workflow (cross-platform shell commands still work in Bash)
- Go 1.25.x (managed via `mise` in this repo)
- Godot 4.6 / 4.6.1

## Repository Layout

- Repo root is the Godot project (`project.godot`) used for addon development and testing.
- Plugin source of truth: `addons/godot_bridge/`.
- CLI Go module: `cli/` (`cli/go.mod`).
- Built CLI binary: `bin/godotctl.exe`.

## Install (User)

Build the CLI binary:

```bash
mise run build
```

Copy `addons/godot_bridge/` into your Godot project.

Open the project in Godot and enable the plugin in `Project Settings -> Plugins`.

The plugin will try to connect to a local daemon and can auto-start it if available.
Auto-start resolves `godotctl` from PATH first, then falls back to `res://bin/godotctl.exe`.

## Get Running

Start daemon manually if needed:

```bash
bin/godotctl.exe daemon start
```

Then in another shell:

```bash
bin/godotctl.exe status
bin/godotctl.exe tools list
bin/godotctl.exe tools ping
```

## Development

- Build CLI binary:

```bash
mise run build
```

- Run full validation (format, tests, vet, lint, deadcode):

```bash
mise run validate
```

- Launch root project in the editor:

```bash
mise run launch-editor
```

- Launch root project detached:

```bash
mise run launch-editor-detached
```

Set `GODOT46_EXE` before launch (or create a local `.env` from `.env.example`):

```dotenv
GODOT46_EXE=C:/Godot/4_6_1/Godot_v4.6.1-stable_win64.exe
```

## Command Reference

For CLI command/flag reference, see `docs/DOCUMENTATION.md`.
