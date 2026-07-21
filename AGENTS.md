# Agent Guidance — EarthNova v3

**Role: ROUTER.** This file defines repository working rules and directs agents to current authority; it is not the domain glossary.

> Welcoming real-world exploration game with a humane player surface and a rigorous, inspectable systems core.
> Start with `CONTEXT.md` for resolved domain language and `docs/adr/` for accepted durable decisions. Older design documents are dated evidence only unless the authority order below explicitly reconfirms them.

## Current Authority Order — 2026-07-20 Reboot

When repository sources disagree, do not blend them:

1. A current explicit human instruction and a human-approved GitHub Issue Outcome Contract define what non-trivial work is authorized and scoped. Repository files and EAC checks do not authorize work by themselves.
2. `CONTEXT.md` is canonical for resolved EarthNova domain language, identities, relationships, and lifecycle invariants.
3. Accepted records in `docs/adr/` are canonical for durable architecture and repository-operating decisions.
4. `.agents/constraints.md` contains hard current implementation, data-continuity, quality, and deployment invariants until an approved migration explicitly changes them.
5. Executable tests, SuperBDD scenarios, EAC catalogs, product registries, telemetry, and current code are evidence of implemented behavior. Keep them aligned, but do not let them silently overwrite the glossary or ADRs.
6. `docs/design.md`, `docs/map-design.md`, `docs/prd-game-systems*.md`, backlog files, and the older Key Decisions below are historical, aspirational, or current-implementation evidence. They are not governing reboot truth unless a current approved artifact explicitly reconfirms them.

Raise a conflict against the higher-authority source instead of guessing. Preserve existing player behavior and data until an approved issue authorizes a migration.

---

## Quick Reference

| Key | Value |
|-----|-------|
| Framework | Flutter 3.41.3 (Dart) |
| State | Riverpod 3.2.1 — `Notifier` pattern |
| Backend | Supabase — source of truth, no local SQLite |
| Auth | Phone → derived email+password — NO OTP |
| Prod URL | https://geo-app-production-47b0.up.railway.app |
| Supabase | `bfaczcsrpfcbijoaeckb` |
| Domain glossary | `CONTEXT.md` |
| Architecture decisions | `docs/adr/` |
| Runbook | `docs/runbook.md` |
| Historical backlog | `2026-04-03-backlog.md` — evidence only; not current authorization |

**Run commands:**
```bash
eval "$(~/.local/bin/mise activate bash)"  # activate toolchain
flutter test                                # run tests
flutter analyze                             # lint + type check
just                                        # list all tasks
npm run superbdd:cucumber                  # execute SuperBDD Cucumber scenarios
```

---

## How to Work

### Read First (every session)
1. `CONTEXT.md` — frozen current domain language and explicitly open areas
2. `docs/adr/` — accepted architecture and repository-operating decisions
3. `.agents/constraints.md` — hard current implementation and deployment invariants
4. `docs/design.md` and relevant focused docs — current/legacy evidence to reconcile, not automatic reboot authority
5. `docs/dependencies.md` — before adding any package
6. `docs/runbook.md` — before any beta or production operation

### Everything as Code

Nothing is tribal knowledge. Every decision, constraint, and procedure is a file in the repo.

| File | What it codifies |
|------|-----------------|
| `CONTEXT.md` | Canonical resolved domain language and lifecycle invariants |
| `docs/adr/` | Accepted durable architecture and repository-operating decisions |
| `docs/design.md` | Current/legacy product and implementation evidence to reconcile against the reboot foundation |
| `docs/frontend-usability-design-system.md` | Enforced frontend/design-system taxonomy, usability rules, registry checks |
| `docs/dependencies.md` | Every package + why removed packages are gone |
| `docs/runbook.md` | Deploy, Supabase ops, incident response |
| `AGENTS.md` | How to work, key decisions |
| `mise.toml` | Pinned Flutter + Supabase CLI + Terraform versions |
| `supabase/migrations/` | Full schema history |
| `Justfile` | Every runnable command |
| `.lefthook.yml` | Pre-commit hooks (analyze + test) |
| `.env.example` | All required environment variables |
| `2026-04-03-backlog.md` | Historical post-MVP evidence — not current authorization or target truth |
| `product/design/**/*.atom|molecule|organism|template|page` | Native EAC design/product-surface contracts — authoritative over Dart registry prose |

### TDD — No Exceptions

1. Write the failing test first. Watch it fail.
2. Write the minimal code to make it pass.
3. Refactor under green.
4. Every public method, every state transition, every error path has a test.
5. No "simple" changes ship without a test.

Tests live in `test/`, mirror `lib/` structure, use `flutter_test` only. No mockito, no mocktail.

### SuperBDD as Executable Evidence

For product behavior, gameplay rules, UI flows, payload contracts, and state-model changes, use SuperBDD as executable behavioral evidence—not as work authorization or self-proving product truth.

1. Read the relevant `features/*.feature` scenarios and `product/*.ts` catalog entries before coding in that behavior.
2. If implemented behavior, terminology, ownership, or a player-visible contract changes, update the relevant scenarios/catalog in the same approved change.
3. Derive target domain and architecture from `CONTEXT.md`, accepted ADRs, approved outcomes, and observed behavior; use scenarios to preserve and verify the intended behavior rather than inventing the architecture.
4. Treat the catalog layers intentionally:
   - **Capabilities** = game-system ownership
   - **Features** = concrete app surfaces / data models
   - **Actions** = player interactions
   - **Workflows** = stateful mutation paths
5. When product truth or feature behavior changes, `mise exec -- eac check` is required alongside relevant focused tests. EAC verifies integrity and traceability; it does not authorize or behaviorally certify the change.
6. Native EAC design contracts govern their scoped product-surface entities; Dart registries are Flutter runtime projections and must stay parity-tested. Neither may contradict higher-authority domain or architecture decisions.

### Frontend / Design System

Reusable UI belongs in `lib/shared/design/`, following the enforced taxonomy:
`foundations → primitives → composites → patterns → feature screens`.

1. Feature screens import shared design components from `package:earth_nova/shared/design.dart` only.
2. Do not import internal design taxonomy paths (`shared/design/primitives`, `shared/design/composites`, etc.) from app code.
3. New reusable UI must be added to the correct taxonomy folder, `designComponentRegistry`, and a native `product/design` atom/molecule/organism contract.
4. App-level screens and repeated feature widgets should use product-language native page/template/molecule contracts (`ExplorationMap`, `PlayerPack`, `TownDirectory`, etc.), not implementation-only names.
5. Raw clickables (`GestureDetector`, `InkWell`, Material buttons) must expose action evidence via `ProductActionSurface` or `ObservableInteraction`, or carry an explicit `eac-clickable-owner-logs` / `eac-clickable-ignore` reason.
6. Design widgets expose semantic variants/tone props, not raw color/style/padding escape hatches.
7. For design-library changes, run `mise exec -- flutter test --no-pub test/shared/design` plus the affected widget/feature tests.


### Observability — Every State Transition

Every `Notifier` extends `ObservableNotifier<T>`. Every state change calls `transition(newState, 'event.name')` — not `state = newState`. Skipping the log is a bug.

```dart
class FooNotifier extends ObservableNotifier<FooState> {
  @override ObservabilityService get obs => ref.watch(observabilityProvider);
  @override String get category => 'foo';
}
```

### Vertical Slices

Build one complete, user-verifiable feature slice end-to-end (model → application logic → adapter → screen → focused test) before starting another. Keep slices local and explicit; beta or production promotion is a separate human-authorized action.

---

## Key Decisions

The table below records inherited v3 implementation decisions and constraints. Preserve them during behavior-preserving work unless an approved migration explicitly supersedes them, but do not treat them as the target reboot architecture when they conflict with `CONTEXT.md` or an accepted ADR.

| Decision | What | Why |
|----------|------|-----|
| **Nuke and rebuild** | All v2 Dart code deleted, v3 built from scratch | App broken for weeks, root cause unknown, complexity exceeded value |
| **No OTP** | Phone → `SHA-256(phone:earthnova-beta-2026)` → Supabase email+password | OTP requires SMS provider, adds state (pending/verified), never worked reliably |
| **No local SQLite** | Supabase is the only data store for MVP | Drift added 32-column denormalized tables, codegen, repositories, migrations — the primary source of v2 complexity. Offline support is post-MVP. |
| **No codegen** | Hand-written providers and models only. No `build_runner`. | Codegen hides structure from agents and developers, adds rebuild steps, produces stale output bugs |
| **v3 tables alongside old** | New `v3_*` tables, old tables untouched | Beta users have data. Old tables stay until v3 is confirmed stable. |
| **Observability from day 1** | `ObservableNotifier`, `runZonedGuarded`, `FlutterError.onError` | v2 outage ran undetected for weeks — no structured logging |
| **2-frame sprite animation** | Real art frames from enrichment pipeline, not programmatic | Real frames from enrichment; `icon_url_frame2` null = static until enriched |
| **All cell visits** | `v3_cell_visits` records every visit, no UNIQUE constraint | Full history enables fog, counts, streaks, achievements from raw rows |
| **Clean Architecture** | Strict layering (domain ← data ← presentation), one use case per operation, domain entities pure Dart | Long-term extensibility for 10 feature domains (A-I + S), offline readiness, testability |
| **Executable SuperBDD harness** | `@cucumber/cucumber` runs selected SuperBDD `.feature` files via `npm run superbdd:cucumber` | Makes BDD executable without adding Flutter runtime packages or codegen |

---

## Forbidden Patterns

- **`state = newState`** in a Notifier — use `transition(newState, 'event')` instead
- **`extends Notifier<`** — all notifiers MUST extend `ObservableNotifier<T>`. A grep test in `test/providers/observable_notifier_test.dart` enforces this at CI time.
- **`StateNotifier`** — use `Notifier` pattern only
- **Drift / SQLite** — not in v3. Do not add back.
- **`build_runner` / codegen** — hand-write everything
- **`maplibre`, `geolocator`, `geobase`, `h3_flutter_plus`** — post-MVP. Do not add back yet.
- **`dynamic` casts, unchecked `as`** — use sealed classes and pattern matching
- **Raw phone numbers in logs** — always SHA-256 hash before logging
- **`debugPrint` for structured events** — use `ObservabilityService.log()`
- **`import 'package:flutter'` in `core/domain/` or `features/*/domain/`** — domain is pure Dart
- **Notifiers calling repositories directly** — use cases are the API
- **`fromJson`/`toJson` on domain entities** — use DTOs in data layer
- **`AuthService` / `ItemService`** — renamed to `AuthRepository` / `ItemRepository`
- **Emoji or Color on domain enums** — use shared/extensions

---

## Supabase

| Item | Value |
|------|-------|
| Project ref | `bfaczcsrpfcbijoaeckb` |
| v3 tables | `v3_profiles`, `v3_items`, `v3_cell_visits`, `v3_write_queue` |
| Old tables | `profiles`, `item_instances`, `cell_progress` — untouched, data preserved |
| Logs | `telemetry_logs`, `telemetry_spans` — query for debugging, see `docs/runbook.md` |
| Auth | `auth.users` — email is `<digits>@earthnova.app` |

---

## Naming Conventions

| Thing | Pattern | Example |
|-------|---------|---------|
| Provider | `fooProvider` | `authProvider`, `itemsProvider` |
| Notifier | `FooNotifier` | `AuthNotifier` |
| Service | `FooService` | Reserved for domain services with cross-entity logic (not data access) |
| Repository | `FooRepository` / `SupabaseFooRepository` | `AuthRepository` / `SupabaseAuthRepository` — data access interface + implementation |
| Use Case | `VerbNoun` | `SignInWithPhone`, `FetchItems` — one operation, one class |
| DTO | `FooDto` | `ItemDto`, `UserProfileDto` — JSON serialization in data layer |
| State | `FooState` | `AuthState`, `ItemsState` |
| Screen | `FooScreen` | `LoginScreen`, `PackScreen` |
| Widget | descriptive noun | `ItemSlotWidget`, `RarityBadge` |
| Test file | mirrors source | `test/providers/auth_provider_test.dart` |

---

## When You're Unsure

1. Read `CONTEXT.md` for resolved domain language and open areas.
2. Read the relevant accepted record in `docs/adr/`.
3. Check `.agents/constraints.md` for current invariants and protection boundaries.
4. Inspect focused legacy docs, scenarios, tests, telemetry, and current code as evidence of what exists.
5. Check `docs/dependencies.md` before adding anything and `docs/runbook.md` before any environment operation.
6. If higher-authority sources still leave a material product or architecture choice open, surface that one decision instead of guessing.
