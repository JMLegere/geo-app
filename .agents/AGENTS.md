# EarthNova Project Memory — Retrieval Guide

**Role: ROUTER.** `.agents/` contains current project memory and dated working evidence. It does not outrank the repository authority chain.

## Authority Before Project Memory

1. Read root `AGENTS.md` for authorization and conflict rules.
2. Read `CONTEXT.md` for resolved domain language.
3. Read accepted `docs/adr/` records for durable decisions.
4. Read `.agents/constraints.md` for current hard implementation and deployment invariants.
5. Use the remaining `.agents/` files as scoped current memory or dated evidence according to the table below.

## File Roles

| File or family | Role | Purpose |
|---|---|---|
| `AGENTS.md` | `ROUTER` | This retrieval guide |
| `constraints.md` | `CURRENT-SCOPED` | Hard implementation, data, quality, and deployment invariants |
| `architecture.md` | `CURRENT-SCOPED` | Observed current and explicitly transitional architecture |
| `questions.md` | `CURRENT-SCOPED` | Deliberately open questions and blockers |
| `decisions.md` | `CURRENT-SCOPED` | Decision registry, including explicit supersessions |
| `context.md` | `CURRENT-SCOPED` | Append-only implementation/session history |
| `discovery/2026-05-03-earthnova-map-domain-visual-requirements.md` | `CURRENT-SCOPED` | Approved map-domain and visual requirements |
| Other `discovery/`, `mocks/`, `qa/`, and `top-down/` Markdown | `HISTORICAL-EVIDENCE` | Dated research, mocks, verification, and plans |
| `eac-native-design-migration-plan.md` | `HISTORICAL-EVIDENCE` | Prior migration planning |

## Retrieval Guide

| Situation | Read |
|---|---|
| Before any code change | Root authority chain, then `constraints.md` |
| Current architecture or deployment shape | `architecture.md`, then live code/config |
| Why an inherited implementation existed | `decisions.md` and relevant dated `context.md` entries |
| Starting a task with possible blockers | `questions.md` |
| Map-domain or visual acceptance | The approved 2026-05-03 discovery requirements |
| Historical comparison | Relevant dated discovery, mock, QA, or top-down artifact |

## Maintenance

- Update `context.md` after each objective implementation phase.
- Keep unresolved decisions in `questions.md`; move resolved decisions into `decisions.md` with rationale and authority links.
- Mark superseded decisions rather than rewriting history.
- Update `architecture.md` only from current repository/runtime evidence.
- Never let project memory silently override `CONTEXT.md`, an accepted ADR, or a current approved Outcome Contract.
