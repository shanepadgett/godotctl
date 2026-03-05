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

## Planning

- Whenever you are planning a new feature or enhancement, focus only on what is necessary, not fancy. Keep work simple and in scope.

## Documentation Maintenance

- When a CLI command is added, changed, or removed, update `docs/DOCUMENTATION.md` in the same change.
- Keep `docs/DOCUMENTATION.md` simple: command names, flags, and what each command does.

## Research

**ALWAYS** delegate to subagents to do codebase research. You waste token and your own ability to reason and think if all you do is read the entire codebase into your memory. And if you have multiple things to research based on topics, dispatch multiple simultaneous agents to get the research done faster in smaller chunks.
