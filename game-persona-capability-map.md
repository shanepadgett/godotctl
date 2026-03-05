# Game Persona Capability Map

This file is a product guide, not an implementation checklist.

Goal: define the game personas this platform should support, the systems those personas require, and the boundary between deterministic agent work and human judgment.

## 1) Platform Mission

Create an agent-friendly CLI + daemon + Godot plugin platform that can build and maintain most popular game types with deterministic operations and reliable validation loops.

## 2) Core Principles

- Deterministic by default: stable outputs, stable error taxonomy, reproducible command behavior.
- Agent-friendly workflows: machine-readable schemas, discoverable capabilities, composable commands.
- Human-in-the-loop where needed: subjective quality decisions stay human-owned.
- Genre-agnostic platform: tools should express engine capabilities, not game templates.

## 3) Personas and Required System Coverage

## FPS / TPS Shooter

- Core systems:
  - First/third person controller, weapons, projectiles/hitscan, enemy AI, HUD, encounter scripting.
- Heavy tooling demands:
  - Fast scene iteration, physics/collision editing, runtime observability, performance checks.

## RPG (party, quest, progression heavy)

- Core systems:
  - Quests, dialogue/state, inventory, stats/progression, save/load, large content graphs.
- Heavy tooling demands:
  - Data editing, graph introspection, content consistency validation, regression checks.

## ARPG (combat + loot loops)

- Core systems:
  - Ability systems, itemization, encounter pacing, spawn tables, progression tuning.
- Heavy tooling demands:
  - Deterministic data pipelines, combat simulation scenarios, telemetry and balancing loops.

## 2D Shooter (top-down / side-scrolling / bullet hell)

- Core systems:
  - Pattern spawning, wave logic, tight input loops, hit detection, score systems.
- Heavy tooling demands:
  - High-frequency runtime testing, scripted input playback, deterministic scenario validation.

## 2D Platformer / Metroidvania

- Core systems:
  - Movement feel variants, camera behavior, level gating, collectible progression.
- Heavy tooling demands:
  - Level authoring automation, tile/scene editing, traversal validation scenarios.

## Strategy / RTS / Tactics

- Core systems:
  - Unit behaviors, pathfinding, resources/economy, map systems, AI decision layers.
- Heavy tooling demands:
  - Batch authoring, simulation runs, map/content validation at scale.

## Survival / Crafting Sandbox

- Core systems:
  - Crafting graphs, world state persistence, resource spawning, systemic interactions.
- Heavy tooling demands:
  - Data graph editing, long-run simulation checks, persistence validation.

## Racing / Vehicle

- Core systems:
  - Vehicle controllers, tracks/checkpoints, timing, camera, tuning profiles.
- Heavy tooling demands:
  - Physics/property sweeps, replay-like scenario checks, performance instrumentation.

## Puzzle / Narrative Adventure

- Core systems:
  - State machines, triggers, dialogue branches, sequencing correctness.
- Heavy tooling demands:
  - Deterministic graph/state validation, scene trigger inspection, script diagnostics.

## 4) Shared Capability Families Needed Across Personas

All personas depend on the same capability families. Differences are in emphasis and scale.

1. Discovery and introspection
- Tool schema discovery, Godot class metadata, scene/resource/property inspection, dependency graphing.

2. Authoring and mutation
- Scene graph edits, resource creation/edits, project settings and input map mutation, file operations.

3. Runtime loop
- Start/stop play sessions, stream logs, inspect runtime trees/properties, capture screenshots, feed inputs.

4. Validation and test execution
- Static validators, deterministic scenario runner, regression checks, compile/parse diagnostics.

5. Performance and diagnostics
- Frame/memory instrumentation, hotspots, failure event capture with request correlation.

6. Build, export, and packaging
- Export automation, artifact generation, reproducible packaging, release validation.

## 5) Agent vs Human Ownership Boundary

## Agent-owned (deterministic)

- Structural edits and refactors.
- Repetitive content wiring and consistency corrections.
- Running validators/tests/scenarios and reporting failures with evidence.
- Parameter sweeps and proposal generation.

## Human-owned (subjective)

- Game feel and pacing approval.
- Visual/audio taste decisions and final art direction.
- Final balancing and creative intent sign-off.

## Shared workflow

- Agent proposes options with metrics.
- Human selects direction and acceptance thresholds.
- Agent executes selected path and verifies constraints.

## 6) Persona Coverage Definition of Done

The platform is persona-ready when each capability family can be executed through deterministic CLI workflows without manual editor clicking for objective tasks.

Human review remains required only for subjective gates (feel, style, fun, final balance).
