# Agent Notes

This repo uses a single Godot project at the repository root:

- Godot project root: `.`
- Plugin source/test location: `addons/godot_bridge/`
- CLI source module: `cli/` (`cli/go.mod`)

When updating plugin code:

1. Edit files in `addons/godot_bridge/`.
2. Rebuild the CLI binary with `mise run build` when needed.
3. Restart Godot (or disable/enable plugin) to reload scripts.

> **IMPORTANT**: When running commands for this repo, always use Bash, NEVER PowerShell.

## CLI Execution

- For live CLI validation, run the built CLI directly from `bin/godotctl.exe` (for example, `./bin/godotctl.exe status --json`).
- Do not use `mise run cli --` for live validation commands.
- If the binary is missing or stale, rebuild with `mise run build` first.
- `mise` Go tasks target the module in `cli/`.

## Planning

- Whenever you are planning a new feature or enhancement, focus only on what is necessary, not fancy. Keep work simple and in scope.

## Documentation Maintenance

- When a CLI command is added, changed, or removed, update `docs/DOCUMENTATION.md` in the same change.
- Keep `docs/DOCUMENTATION.md` simple: command names, flags, and what each command does.

## Research

**ALWAYS** delegate to subagents to do codebase research. You waste token and your own ability to reason and think if all you do is read the entire codebase into your memory. And if you have multiple things to research based on topics, dispatch multiple simultaneous agents to get the research done faster in smaller chunks.
