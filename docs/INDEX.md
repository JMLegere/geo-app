# Agent Context Index

Cross-cutting architecture docs. AGENTS.md files are per-directory; these are system-wide.

## What to Read First

| Task Type | Read These | Then |
|-----------|-----------|------|
| **Any task** | This file + `AGENTS.md` (root) + `target-architecture.md` | Relevant directory AGENTS.md |
| **Architecture / what to build** | `target-architecture.md` (definitive target state) | `roadmap.md`, `game-design.md` |
| **Game design work** | `game-design.md` + `AGENTS.md` (root) | Relevant feature AGENTS.md |
| **New feature** | `target-architecture.md` + `state.md` + `game-design.md` | `game-loop.md` if gameplay-related |
| **Bug fix** | `game-loop.md` (find the pipeline stage) | `state.md` (trace provider chain) |
| **State/provider work** | `state.md` | `target-architecture.md` (dependency rules) |
| **Database/model change** | `data-model.md` | `state.md` (what providers consume it) |
| **Build/deploy/infra** | `tech-stack.md` | — |
| **Auth/login work** | `auth-prerequisites.md` + `state.md` | Feature AGENTS.md |
| **Planning / what to build next** | `roadmap.md` + `game-design.md` | `target-architecture.md` |
| **Engine / observability** | `target-architecture.md` | `engine-architecture.md` (implementation details for existing phases) |
| **Item system / inventory** | `item-system-design.md` | `target-architecture.md` (server-authoritative context) |
| **Species stats / art / crowdsourcing** | `species-community-system.md` | `item-system-design.md` (item model context) |
| **Cell properties / events / borders** | `cell-properties-design.md` | `data-model.md` (persistence) + `game-loop.md` (integration) |
| **UI/widget work** | `target-architecture.md` (layer rules) | Feature AGENTS.md |
| **Test writing** | `test/AGENTS.md` | `data-model.md` (for fixtures) |

## File Inventory

| File | Lines | Purpose | Staleness Signal |
|------|-------|---------|------------------|
| `target-architecture.md` | ~700 | **DEFINITIVE** target state. 5 pillars, hardware budgets, directory structure, migration phases. Supersedes architecture.md, engine-architecture.md, ideal-architecture.md, current-architecture.md | Architecture decision changed, pillar redefined |
| `implementation-plan.md` | ~350 | Ordered implementation steps for target architecture. Phase 0→A→B→C→D with verification gates. | Phase completed, estimate revised, risk materialized |
| `game-design.md` | ~230 | Design vision, confirmed/tentative/deferred decisions, Current vs Target table | Design decision changed, new mechanic confirmed |
| `roadmap.md` | ~510 | Nested hierarchy: 15 initiatives → ~35 projects → ~120 issues, priority matrix, technical roadmap | Initiative added/completed, priority shift, new project scoped |
| `architecture.md` | ~115 | System topology, layer boundaries, feature dependency graph, glossary | New feature added without updating graph |
| `current-architecture.md` | ~220 | How the system works today — data flow, state, persistence, feature coupling | Architecture changes, for design jam reference |
| `engine-architecture.md` | ~380 | Event-driven engine target: observability, performance (10ms), resilience. GameEngine, event model, message bus, migration phases | Architecture direction changes, new event types, engine boundary shifts |
| `ideal-architecture.md` | ~370 | Server-authoritative design decisions, item model, daily seed, write queue (design decisions still apply; execution architecture superseded by engine-architecture.md) | Product direction changes, new technical requirements |
| `item-system-design.md` | ~345 | Item instance model (PoE/CryptoKitty), affixes, breeding, bundles, schema, migration plan | Item model design changes, new affix/breeding rules |
| `species-community-system.md` | ~450 | Crowdsourced species identity: triangle stat picker, running median, art voting, badges, species card UI | Community system design changes, voting/art rules |
| `game-loop.md` | ~113 | GPS-to-render pipeline, tick rates, event flow, streak rules | Pipeline stage added/changed |
| `state.md` | ~105 | All Riverpod providers, types, dependencies, cross-feature wiring | Provider added/renamed/re-wired |
| `data-model.md` | ~175 | Models, DB schema, persistence contracts, species JSON, ESA mapping | Model/table/field added or changed |
| `tech-stack.md` | ~115 | Framework versions, packages, build/deploy commands, CI status | Dependency upgraded or config changed |
| `cell-properties-design.md` | ~773 | Cell properties system: permanent layer (habitat, climate, location hierarchy), rotating events, map visualization (icons + Stellaris borders), resolution flow, persistence | Cell property rules changed, new event type, border rendering approach changed |
| `auth-prerequisites.md` | ~250 | Supabase dashboard, Google/Apple OAuth, dart-define setup | OAuth provider added/changed |

## Maintenance Rules

See `AGENTS.md` (root) > "Documentation Maintenance Protocol" for trigger rules.

**Core principle:** Overwrite stale content, never append. Keep files dense and current. Zero narrative fluff.
