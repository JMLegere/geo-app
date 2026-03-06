# Agent Context Index

Cross-cutting architecture docs. AGENTS.md files are per-directory; these are system-wide.

## What to Read First

| Task Type | Read These | Then |
|-----------|-----------|------|
| **Any task** | This file + `AGENTS.md` (root) | Relevant directory AGENTS.md |
| **Game design work** | `game-design.md` + `AGENTS.md` (root) | Relevant feature AGENTS.md |
| **New feature** | `architecture.md` + `state.md` + `game-design.md` | `game-loop.md` if gameplay-related |
| **Bug fix** | `game-loop.md` (find the pipeline stage) | `state.md` (trace provider chain) |
| **State/provider work** | `state.md` | `architecture.md` (dependency rules) |
| **Database/model change** | `data-model.md` | `state.md` (what providers consume it) |
| **Build/deploy/infra** | `tech-stack.md` | — |
| **Auth/login work** | `auth-prerequisites.md` + `state.md` | Feature AGENTS.md |
| **Planning / what to build next** | `roadmap.md` + `game-design.md` | `architecture.md` (dependency graph) |
| **UI/widget work** | `architecture.md` (layer rules) | Feature AGENTS.md |
| **Test writing** | `test/AGENTS.md` | `data-model.md` (for fixtures) |

## File Inventory

| File | Lines | Purpose | Staleness Signal |
|------|-------|---------|------------------|
| `game-design.md` | ~230 | Design vision, confirmed/tentative/deferred decisions, Current vs Target table | Design decision changed, new mechanic confirmed |
| `roadmap.md` | ~370 | Nested hierarchy: 15 initiatives → ~35 projects → ~120 issues, priority matrix | Initiative added/completed, priority shift, new project scoped |
| `architecture.md` | ~95 | System topology, layer boundaries, feature dependency graph, glossary | New feature added without updating graph |
| `game-loop.md` | ~100 | GPS-to-render pipeline, tick rates, event flow, streak rules | Pipeline stage added/changed |
| `state.md` | ~100 | All Riverpod providers, types, dependencies, cross-feature wiring | Provider added/renamed/re-wired |
| `data-model.md` | ~140 | Models, DB schema, persistence contracts, species JSON, ESA mapping | Model/table/field added or changed |
| `tech-stack.md` | ~115 | Framework versions, packages, build/deploy commands | Dependency upgraded or config changed |
| `auth-prerequisites.md` | ~60 | Supabase dashboard, Google/Apple OAuth, dart-define setup | OAuth provider added/changed |

## Maintenance Rules

See `AGENTS.md` (root) > "Documentation Maintenance Protocol" for trigger rules.

**Core principle:** Overwrite stale content, never append. Keep files dense and current. Zero narrative fluff.
