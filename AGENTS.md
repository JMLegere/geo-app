# Agent Guidance — EarthNova v3

> Friendly, social geogame. Real world GPS + fog-of-war + 32,752 IUCN species + sanctuary building.
> See `docs/design.md` for the full product and architecture spec.

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
| Design doc | `docs/design.md` |
| Runbook | `docs/runbook.md` |
| Backlog | `2026-04-03-backlog.md` |

**Run commands:**
```bash
eval "$(~/.local/bin/mise activate bash)"  # activate toolchain
flutter test                                # run tests
flutter analyze                             # lint + type check
just                                        # list all tasks
```

---

## How to Work

### Read First (every session)
1. `docs/design.md` — product spec, architecture, data model, screen designs, acceptance criteria
2. Key Decisions below — settled choices, do not re-litigate
3. `docs/dependencies.md` — before adding any package
4. `docs/runbook.md` — before any prod operation

### Everything as Code

Nothing is tribal knowledge. Every decision, constraint, and procedure is a file in the repo.

| File | What it codifies |
|------|-----------------|
| `docs/design.md` | Product spec, architecture, screens, acceptance criteria |
| `docs/dependencies.md` | Every package + why removed packages are gone |
| `docs/runbook.md` | Deploy, Supabase ops, incident response |
| `AGENTS.md` | How to work, key decisions |
| `mise.toml` | Pinned Flutter + Supabase CLI + Terraform versions |
| `supabase/migrations/` | Full schema history |
| `Justfile` | Every runnable command |
| `.lefthook.yml` | Pre-commit hooks (analyze + test) |
| `.env.example` | All required environment variables |
| `2026-04-03-backlog.md` | Post-MVP features — do not build these yet |

### TDD — No Exceptions

1. Write the failing test first. Watch it fail.
2. Write the minimal code to make it pass.
3. Refactor under green.
4. Every public method, every state transition, every error path has a test.
5. No "simple" changes ship without a test.

Tests live in `test/`, mirror `lib/` structure, use `flutter_test` only. No mockito, no mocktail.

### Observability — Every State Transition

Every `Notifier` extends `ObservableNotifier<T>`. Every state change calls `transition(newState, 'event.name')` — not `state = newState`. Skipping the log is a bug.

```dart
class FooNotifier extends ObservableNotifier<FooState> {
  @override ObservabilityService get obs => ref.watch(observabilityProvider);
  @override String get category => 'foo';
}
```

### Vertical Slices

Build one complete feature end-to-end (model → service → provider → screen → test) before starting the next. Nothing is half-done. Each slice ships to prod before the next starts.

---

## Key Decisions

These are settled. Do not revisit without explicit instruction from the user.

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

1. Read `docs/design.md` — it probably has the answer
2. Check Key Decisions above — it may be settled
3. Check `docs/dependencies.md` — before adding anything
4. Check `2026-04-03-backlog.md` — it may be a post-MVP item
5. Ask the user — don't guess on architecture
