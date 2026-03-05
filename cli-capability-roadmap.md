# CLI Capability Roadmap

This file is the implementation roadmap.

Companion context: `game-persona-capability-map.md` defines personas and system coverage goals.

## 1) Roadmap Objective

Implement a deterministic, agent-friendly CLI capability set that can support objective development workflows for most popular game types in Godot.

This roadmap intentionally focuses on platform capabilities, not genre templates.

## 2) Current Baseline (already implemented)

- Connectivity and control plane:
  - `daemon start`, `daemon stop`, `status`, `tools list`, `tools ping`.
- Scene basics:
  - `scene create`, `scene add-node`, `scene remove-node`, `scene set-prop`, `scene tree`.
- Script basics:
  - `script create`, `script edit`, `script validate`, `script attach`.
- Project/file basics:
  - `project settings get`, `project input-map get`, `file list`, `file read`.
- Core guarantees in place:
  - Stable exit-code mapping (`0..4`), plugin `tool_code` passthrough, deterministic sorted list outputs in implemented commands.

## 3) Capability Gaps to Close

1. Discovery and introspection depth.
2. Scene/resource mutation breadth.
3. Project system mutation (not just read).
4. Runtime control and observability loop.
5. Validation/test scenario automation.
6. Performance diagnostics.
7. Export/package and release operations.
8. Final hardening and operator-safety features.

## 4) Milestones

## Milestone 1 - Discovery and Introspection

- [x] Add `tools describe [--tool]` with machine-readable args/result/error schemas.
- [x] Add `class describe --name` for Godot class metadata (properties, methods, signals, inheritance).
- [x] Add `scene inspect --scene` for deterministic node/signal/group/property snapshots.
- [x] Add `project graph` and `resource refs` for dependency and reverse-reference inspection.
- [x] Ensure outputs are sorted/stable and safe for automated diffing.

## Milestone 2 - Scene and Resource Authoring Breadth

- [ ] Add scene graph operations: rename, reparent, duplicate, instance-scene.
- [ ] Add signal wiring operations: `scene signal connect`, `scene signal disconnect`, `scene signal list`.
- [ ] Define deterministic signal identity tuple `(scene_path, from_node, signal, to_target, method, flags)` and idempotent semantics.
- [ ] Add group membership operations: add/remove/list.
- [ ] Add transform and common node configuration helpers.
- [ ] Add resource operations: create/get/set-prop/list where deterministic.

## Milestone 3 - Project Mutation and Data Operations

- [ ] Add `project settings set --key --value <json>`.
- [ ] Add full input-map CRUD (action create/delete, event add/remove, deadzone set).
- [ ] Add autoload management (list/add/remove).
- [ ] Add structured file mutation helpers for JSON/CFG/Tres-like workflows.
- [ ] Add import settings and reimport controls where Godot APIs allow deterministic behavior.

## Milestone 4 - Runtime Control and Observation Loop

- [ ] Add `run start`, `run stop`, `run status`.
- [ ] Add `run logs` with filter/follow options and stable record shape.
- [ ] Add `run screenshot` capture for artifact-based review.
- [ ] Add runtime tree/property inspection commands.
- [ ] Add runtime input injection commands for scripted scenarios.
- [ ] Add optional deterministic stepping (`run step`) for reproducible smoke runs.

## Milestone 5 - Validation and Scenario Execution

- [ ] Add `validate project` for cross-resource/scene/script consistency checks.
- [ ] Add `validate scene --scene` and `validate scripts` command coverage.
- [ ] Add signal validation in `validate scene --scene` (endpoints exist, method exists, signature compatibility, duplicate detection).
- [ ] Add stable signal diagnostic keys based on deterministic signal identity tuple.
- [ ] Add `test scenario run --name` for deterministic scripted play sequences.
- [ ] Add stable diagnostic taxonomy and structured evidence payloads.
- [ ] Add baseline regression suite for implemented command families.

## Milestone 6 - Performance and Diagnostics

- [ ] Add profile/stat capture commands (frame timing, memory, draw/physics indicators as available).
- [ ] Add request-correlated diagnostics (tie runtime events to command/request IDs).
- [ ] Add deterministic profile output suitable for diff-based comparisons.

## Milestone 7 - Build, Export, and Packaging

- [ ] Add `export presets list` and `export build --preset` workflows.
- [ ] Add package automation for addon + daemon binary artifacts.
- [ ] Add reproducible artifact metadata and integrity checks.
- [ ] Add verification commands for export readiness.

## Milestone 8 - Hardening and Operational Safety (carry-over, intentionally late)

These are release-hardening tasks and should land after core capabilities above.

- [ ] Keep deterministic error handling guarantees across all new tools and command families.
- [ ] Keep tool advertisement accurate and stable in plugin hello and `tools list`.
- [ ] Keep docs in sync with command surfaces in every change.
- [ ] Finalize plugin status indicator in editor UI.
- [ ] Persist daemon logs to `%LOCALAPPDATA%/godotctl/logs/daemon.log`.
- [ ] Expose plugin daemon settings (path, host/port, auto-start, reconnect policy).
- [ ] Finalize auto-start/reconnect behavior and diagnostics quality.
- [ ] Add safe mutation controls (`--dry-run`, `--diff`, and optional batch/transaction semantics where feasible).

## 5) Cross-Milestone Acceptance Rules

- Any new mutating command must include deterministic failure codes and stable JSON envelopes.
- Any list-like response must have deterministic ordering.
- Any command added/changed/removed must update `docs/DOCUMENTATION.md` in the same change.
- Plugin source of truth remains `addons/godot_bridge/`, then mirrored to `sample/addons/godot_bridge/`.

## 6) Immediate Next Action

- [ ] Start Milestone 2 signal tooling design (command contracts, identity tuple, error taxonomy).
- [ ] Define Milestone 5 signal validation contract and deterministic diagnostic key format.

## 7) Signal Validation Gating

- Treat signal support as inspection-only until Milestone 2 signal mutation commands and Milestone 5 validation coverage both land.
- Do not call signal workflows fully validated until all are true:
  - deterministic signal connect/disconnect/list commands are implemented,
  - `validate scene --scene` enforces signal endpoint/signature checks,
  - scenario test coverage includes both passing and failing signal cases.
- Interim checks should use `scene inspect` only for snapshot shape and deterministic ordering verification.
