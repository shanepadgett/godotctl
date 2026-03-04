# Agent Notes

This repo keeps two plugin copies during local testing:

- Source of truth: `addons/godot_bridge/`
- Test copy: `sample/addons/godot_bridge/`

When updating plugin code:

1. Edit files in `addons/godot_bridge/`.
2. Copy that folder to `sample/addons/godot_bridge/` (overwrite existing files).
3. Restart Godot (or disable/enable plugin) to reload scripts.

Do not use symlinks for the sample plugin copy; use a real folder copy.

> **IMPORTANT**: When running commands for this repo, always use Bash, NEVER PowerShell.
