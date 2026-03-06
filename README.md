# godotctl

`godotctl` is a local CLI + daemon + Godot editor plugin that lets terminal commands trigger editor operations.

## Requirements

- Windows, macOS, or Linux
- Go 1.25.x (managed via `mise` in this repo)
- Godot 4.6 / 4.6.1

## Repository Layout

- Repo root is the Godot project (`project.godot`) used for addon development and testing.
- Plugin source of truth: `addons/godot_bridge/`.
- CLI Go module: `cli/` (`cli/go.mod`).
- Built CLI binary for local development: `bin/godotctl.exe`.

## Install (User)

Install from latest GitHub release (bash):

```bash
curl -fsSL https://raw.githubusercontent.com/shanepadgett/godotctl/main/scripts/install.sh | bash
```

Install from latest GitHub release (PowerShell):

```powershell
irm https://raw.githubusercontent.com/shanepadgett/godotctl/main/scripts/install.ps1 | iex
```

From a shell opened anywhere inside your Godot project, install the bundled addon:

```bash
godotctl install-bridge
```

If `addons/godot_bridge` already exists, rerun with `--force` to overwrite:

```bash
godotctl install-bridge --force
```

Open the project in Godot and enable the plugin in `Project Settings -> Plugins`.

The plugin will try to connect to a local daemon and can auto-start it if available.
Auto-start resolves `godotctl` from PATH first, then falls back to `res://bin/godotctl.exe` and `res://bin/godotctl`.

If you prefer building from source instead of installing from release artifacts:

```bash
mise run build
```

## Get Running

Start daemon manually if needed:

```bash
godotctl daemon start
```

Then in another shell:

```bash
godotctl status
godotctl tools list
godotctl tools ping
```

## Release Process

- Manual trigger: run `.github/workflows/release.yml` with GitHub Actions `workflow_dispatch`.
- Versioning rules:
  - `major`: any commit with `!` in the conventional commit header or a `BREAKING CHANGE:` footer.
  - `minor`: any commit with `feat:`.
  - `patch`: everything else.
- First-tag baseline when no existing release tags: `0.0.0` (default bump then applies).
- Artifacts are published via GoReleaser for:
  - `windows/amd64`, `windows/arm64`
  - `linux/amd64`, `linux/arm64`
  - `darwin/amd64`, `darwin/arm64`

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
