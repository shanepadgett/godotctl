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

- [x] Keep CLI and tool contracts deterministic: stable envelopes, stable tool codes, stable ordering.

### 2.1) Command Surface (CLI -> Tool)

- [x] Scene graph operations:
  - `scene rename --scene --path --name` -> `scene.rename_node`
  - `scene reparent --scene --path --parent [--index <int>]` -> `scene.reparent_node`
  - `scene duplicate --scene --path --parent [--name <string>]` -> `scene.duplicate_node`
  - `scene instance-scene --scene --source-scene --parent [--name <string>]` -> `scene.instance_scene`
- [x] Signal wiring operations:
  - `scene signal connect --scene --from --signal --to --method [--flags <int>]` -> `scene.signal_connect`
  - `scene signal disconnect --scene --from --signal --to --method [--flags <int>]` -> `scene.signal_disconnect`
  - `scene signal list --scene [--from] [--signal] [--to] [--method] [--max <int>]` -> `scene.signal_list`
- [x] Group membership operations:
  - `scene group add --scene --path --group` -> `scene.group_add`
  - `scene group remove --scene --path --group` -> `scene.group_remove`
  - `scene group list --scene [--path] [--max <int>]` -> `scene.group_list`
- [x] Transform/configuration helpers:
  - `scene transform apply --scene --path --value <json>` -> `scene.transform_apply`
  - `scene node configure --scene --path --config <json>` -> `scene.node_configure`
- [x] Resource operations:
  - `resource create --path --type [--overwrite]` -> `resource.create`
  - `resource get --path --prop` -> `resource.get`
  - `resource set-prop --path --prop --value <json>` -> `resource.set_prop`
  - `resource list --path [--include-values] [--max-properties <int>]` -> `resource.list`

### 2.2) Deterministic Contracts

- [x] Use canonical scene/resource paths and canonical node paths (`.` for root).
- [x] Define deterministic signal identity tuple `(scene_path, from_node, signal, to_target, method, flags)`.
- [x] Sort signal list responses lexicographically by the identity tuple field order.
- [x] Keep signal and group mutation idempotent:
  - connect/add existing -> success with `changed: false`
  - disconnect/remove missing -> success with `changed: false`
- [x] Initial signal target scope is in-scene node-path targets only; reject non-deterministic external object references.
- [x] Keep max-limit behavior deterministic (`0` means no limit, return truncation metadata when truncated).

### 2.3) Result Shapes

- [x] Mutation responses include stable fields:
  - `scene_path` or `resource_path`
  - operation-specific canonical paths/keys
  - `changed`, `saved`, `filesystem_refreshed`
- [x] List/read responses include deterministic arrays and stable counters:
  - `count`, `returned_count`, `truncated`
- [x] Duplicate/instance/create responses include created canonical path/name and collision outcome.

### 2.4) Error Taxonomy (Reuse Existing Codes)

- [x] Keep existing tool code set only: `INVALID_ARGS`, `NOT_FOUND`, `ALREADY_EXISTS`, `TYPE_MISMATCH`, `IO_ERROR`, `EDITOR_STATE`, `INTERNAL`.
- [x] Error mapping rules:
  - `INVALID_ARGS`: invalid names, invalid flags, root-op restrictions, reparent cycles, invalid target scope.
  - `NOT_FOUND`: missing scene/node/signal/group/resource/property/method.
  - `ALREADY_EXISTS`: sibling name collisions, create without overwrite.
  - `TYPE_MISMATCH`: incompatible class/value/method target.
  - `IO_ERROR`: load/pack/save failures.
  - `EDITOR_STATE`: editor refresh/open failures after mutation.

### 2.5) Implementation Layout

- [x] CLI command wiring under `cli/internal/cli/commands/scene/` and `cli/internal/cli/commands/resource/`.
- [x] Plugin handlers under `addons/godot_bridge/tools/scene/` and `addons/godot_bridge/tools/resource/`.
- [x] Register all new tools in `addons/godot_bridge/tools/registry.gd`.
- [x] Define/update machine-readable contracts in `addons/godot_bridge/tools/misc/describe_tool.gd`.
- [x] Reuse shared load/mutate/save/finalize patterns used by existing scene/script tooling.
- [x] Keep plugin source of truth in `addons/godot_bridge/` in the root Godot project.

### 2.6) Delivery Phases

- [x] Phase A: shared canonicalization helpers + schema stubs.
- [x] Phase B: scene graph operations.
- [x] Phase C: signal list/connect/disconnect with identity tuple + idempotency.
- [x] Phase D: group add/remove/list.
- [x] Phase E: transform/configuration helpers (minimal common subset only).
- [x] Phase F: resource create/get/set-prop/list.
- [x] Phase G: deterministic regression checks + docs sync.

### 2.7) Milestone 2 Exit Criteria

- [x] All Milestone 2 commands are available in CLI, registry, and `tools describe`.
- [x] All list-like responses are deterministically sorted and diff-safe.
- [x] Signal/group idempotent semantics are implemented and documented.
- [x] Stable envelope + exit-code behavior remains unchanged.
- [x] `docs/DOCUMENTATION.md` is updated for every command/flag in this milestone.

## Milestone 3 - Project Mutation and Data Operations

- [x] Add `project settings set --key --value <json>`.
- [x] Add full input-map CRUD (action create/delete, event add/remove, deadzone set).
- [x] Add autoload management (list/add/remove).
- [x] Add structured file mutation helpers for JSON/CFG/Tres-like workflows.
- [x] Add import settings and reimport controls where Godot APIs allow deterministic behavior.

## Milestone 4 - Runtime Control and Observation Loop

- [x] Add `run start`, `run stop`, `run status`.
- [x] Add `run logs` with filter/follow options and stable record shape.
- [x] Add `run screenshot` capture for artifact-based review.
- [x] Add runtime tree/property inspection commands.
- [x] Add runtime input injection commands for scripted scenarios.
- [x] Add optional deterministic stepping (`run step`) for reproducible smoke runs.

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
- Plugin source of truth remains `addons/godot_bridge/` in the root Godot project.

## 6) Immediate Next Action

- [x] Start Milestone 2 Phase A: add schema stubs + registry placeholders for all planned Milestone 2 tools.
- [x] Implement Milestone 2 Phase B and Phase C first (scene graph + signal wiring).
- [ ] Define Milestone 5 signal validation contract and deterministic diagnostic key format.

## 7) Signal Validation Gating

- Treat signal support as inspection-only until Milestone 2 signal mutation commands and Milestone 5 validation coverage both land.
- Do not call signal workflows fully validated until all are true:
  - deterministic signal connect/disconnect/list commands are implemented,
  - `validate scene --scene` enforces signal endpoint/signature checks,
  - scenario test coverage includes both passing and failing signal cases.
- Interim checks should use `scene inspect` only for snapshot shape and deterministic ordering verification.
