# EarthNova Documentation Index

**Role: ROUTER.** This file classifies repository Markdown and directs readers to current authority. It does not define game rules itself.

## Authority Order

When sources conflict, do not blend them:

1. A current human-approved Outcome Contract authorizes and scopes non-trivial work.
2. [`CONTEXT.md`](../CONTEXT.md) governs resolved domain language and lifecycle invariants.
3. Accepted records in [`docs/adr/`](adr/) govern durable architecture and repository operations.
4. [`.agents/constraints.md`](../.agents/constraints.md) governs current implementation, data-continuity, quality, and deployment constraints.
5. Tests, SuperBDD, EAC catalogs, product registries, telemetry, and current code are implementation evidence.
6. Historical plans, designs, PRDs, mocks, QA records, and agent notes remain dated evidence only.

## What to Read

| Task | Read |
|---|---|
| Any non-trivial task | `AGENTS.md` → `CONTEXT.md` → accepted `docs/adr/` → `.agents/constraints.md` |
| Current domain language | `CONTEXT.md` |
| Durable architecture decision | Relevant accepted record in `docs/adr/` |
| Current system/deployment shape | `.agents/architecture.md` and `docs/runbook.md` |
| Current blockers or deliberately open rules | `.agents/questions.md` and the open areas in `CONTEXT.md` |
| Map implementation evidence | Latest relevant `.agents/discovery/` requirement plus current code/tests; use `docs/map-design.md` only as historical evidence |
| Adding a package | `docs/dependencies.md` |
| Beta or production operation | `docs/runbook.md` |
| Why an old implementation existed | Dated history in `.agents/context.md`, `.agents/decisions.md`, old plans, QA, or design documents |

## Document Roles

| Role | Meaning |
|---|---|
| `CANONICAL` | Governs current resolved domain or an accepted durable decision |
| `ROUTER` | Points readers to authority without defining domain truth |
| `CURRENT-SCOPED` | Current only for its explicitly named implementation or operational scope |
| `HISTORICAL-EVIDENCE` | Preserved dated evidence that cannot override current authority |
| `GENERATED/VENDOR` | Owned by tooling or a platform and not part of EarthNova domain authority |

## Complete Markdown Classification

Every Markdown file in the repository must match exactly one row below. A documentation contract test enforces this registry.

| Path or family | Role | Scope |
|---|---|---|
| `CONTEXT.md` | `CANONICAL` | Resolved EarthNova domain language and invariants |
| `docs/adr/*.md` | `CANONICAL` | Accepted durable decisions |
| `AGENTS.md`, `.agents/AGENTS.md`, `README.md`, `docs/INDEX.md` | `ROUTER` | Cold-start and retrieval routing |
| `.agents/constraints.md` | `CURRENT-SCOPED` | Hard implementation, data, quality, and deployment constraints |
| `.agents/architecture.md` | `CURRENT-SCOPED` | Observed current and explicitly transitional architecture |
| `.agents/context.md` | `CURRENT-SCOPED` | Append-only implementation/session history |
| `.agents/decisions.md` | `CURRENT-SCOPED` | Decision registry, including explicit supersessions |
| `.agents/questions.md` | `CURRENT-SCOPED` | Deliberately open questions and blockers |
| `.agents/discovery/2026-05-03-earthnova-map-domain-visual-requirements.md` | `CURRENT-SCOPED` | Approved map-domain and visual acceptance requirements |
| `docs/dependencies.md` | `CURRENT-SCOPED` | Package policy and dependency rationale |
| `docs/runbook.md` | `CURRENT-SCOPED` | Beta/production operations |
| `docs/frontend-usability-design-system.md` | `CURRENT-SCOPED` | Frontend usability and design-system rules |
| `docs/observability-interaction-coverage.md` | `CURRENT-SCOPED` | Interaction observability contract |
| `docs/ios-safari-maplibre.md` | `CURRENT-SCOPED` | Scoped platform compatibility evidence |
| `lib/shared/design/README.md` | `CURRENT-SCOPED` | Shared design-library usage |
| `2026-04-03-*.md` | `HISTORICAL-EVIDENCE` | Dated v3 planning and backlog |
| `docs/design.md`, `docs/map-design.md`, `docs/prd-game-systems*.md` | `HISTORICAL-EVIDENCE` | Prior product and implementation intent |
| `docs/eac-native-design-migration-plan.md`, `.agents/eac-native-design-migration-plan.md` | `HISTORICAL-EVIDENCE` | Completed/superseded migration planning |
| `docs/diagrams/**/*.md`, `docs/jtbd/**/*.md` | `HISTORICAL-EVIDENCE` | Prior diagrams and job analysis |
| `.agents/discovery/*.md` except the approved 2026-05-03 requirements | `HISTORICAL-EVIDENCE` | Dated discovery inputs |
| `.agents/mocks/**/*.md`, `.agents/qa/**/*.md`, `.agents/top-down/**/*.md` | `HISTORICAL-EVIDENCE` | Dated mock, QA, and planning evidence |
| `.claude/agent_notes/**/*.md`, `.opencode/plans/**/*.md` | `HISTORICAL-EVIDENCE` | Legacy agent notes and plans |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md` | `GENERATED/VENDOR` | Flutter platform asset guidance |

## Non-Markdown Evidence

- `features/*.feature` — executable behavioral evidence.
- `product/{capabilities,features,actions,workflows}.ts` — EAC product catalog evidence.
- `supabase/migrations/*.sql` — executable schema history.
- `supabase/schema.sql` — human-readable snapshot, not a migration.
- `test/**` — implementation and regression evidence.
