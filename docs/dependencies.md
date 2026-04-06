# EarthNova v3 — Dependencies

> Every package, why it's here, and why removed packages are gone.
> If a package isn't listed here, it doesn't belong in the project.

---

## Runtime Dependencies

| Package | Version | Why |
|---------|---------|-----|
| `flutter_riverpod` | `^3.2.1` | State management. `Notifier` pattern — immutable state, reactive providers, testable without framework. No `StateNotifier`, no `ChangeNotifier`. |
| `supabase_flutter` | `^2.12.0` | Backend client. Auth, database queries, realtime. Source of truth for all data. |
| `crypto` | `^3.0.6` | SHA-256 for `_derivePassword` (phone → Supabase password) and phone hashing in observability. Critical — must match v2 exactly. |
| `uuid` | `^4.5.3` | Session IDs in `ObservabilityService`. One UUID per app launch. |
| `intl` | `^0.20.2` | Date formatting in `SpeciesCard` footer. |
| `connectivity_plus` | `^6.x` | Network state detection. Powers `network.offline` / `network.online` observability events. Without it, connectivity failures are only detected reactively (fetch fails). |
| `maplibre_gl` | `^0.20.0` | Map rendering at GPS level. Real-world vector tiles + custom Voronoi polygon overlay. Overrides AGENTS.md ban — see `docs/map-design.md §14`. |
| `geolocator` | `^13.0.2` | GPS location provider. Adaptive update frequency, accuracy tracking for ring state detection. Overrides AGENTS.md ban — see `docs/map-design.md §14`. |

---

## Dev Dependencies

| Package | Version | Why |
|---------|---------|-----|
| `flutter_test` | SDK | Unit + widget testing. The only test framework — no mockito, no mocktail. All mocks are hand-written. |
| `flutter_lints` | `^6.0.0` | Base lint rules. Extended by `analysis_options.yaml`. |
| `flutter_launcher_icons` | `^0.14.3` | Generates platform app icons from `assets/icon/app_icon.png`. Run once after icon changes. |
| `flutter_native_splash` | `^2.4.4` | Generates native splash screen (`#0D1B2A` dark navy). Run once after splash changes. |

---

## Removed Packages (and Why)

These packages were in v1/v2 and are **not** in v3. Do not add them back without an explicit decision.

| Package | Removed because |
|---------|----------------|
| `drift` + `drift_dev` | Local SQLite ORM. Added schema management, code generation, repositories, and migration complexity. Drift was the source of most v2 complexity (32-column denormalized tables, `Value<T>` wrappers, build_runner). v3 reads directly from Supabase — no local cache for MVP. Offline support added later when it's actually needed. |
| `sqlite3` + `sqlite3_flutter_libs` | SQLite native bindings required by Drift. Gone with Drift. |
| `build_runner` | Code generation runner for Drift and Riverpod generators. No codegen in v3 — all models and providers are hand-written. Codegen adds hidden complexity (generated files, rebuild steps, stale output bugs). |
| `riverpod_generator` + `riverpod_annotation` | Riverpod codegen annotations. Replaced by hand-written `NotifierProvider`. Codegen hides the provider structure from AI agents and new developers. Manual providers are ~5 lines each and perfectly readable. |
| `geobase` | Geographic coordinate type library (`Geographic(lat:, lon:)`). Only needed when map/GPS features are active. Not needed for auth + pack MVP. Add back when map is built. |
| `h3_flutter_plus` | H3 hexagonal cell system (FFI). Replaced by Voronoi cells in v2. Not needed for MVP. Requires `LD_LIBRARY_PATH=.` hack in CI. |
| `maplibre_gl` | ~~Map rendering library. Not needed until map screen is built.~~ **Re-added as `maplibre_gl ^0.20.0`** — map system is now being built. See `docs/map-design.md §14`. |
| `geolocator` | ~~GPS location service. Not needed until map screen is built.~~ **Re-added as `geolocator ^13.0.2`** — map system is now being built. See `docs/map-design.md §14`. |
| `pedometer_2` | Step counting (native only, web stub). Removed in v2 simplification. Post-MVP feature. |
| `web` | Dart JS interop package for web-specific code (OPFS database reset). Not needed in v3 — no SQLite, no OPFS. |
| `shared_preferences` | Key-value storage. Not needed — no local persistence in MVP. If needed later, consider whether Supabase covers the use case first. |
| `image` | Image processing dev dependency (icon generation). Not needed — icon is pre-generated. |

---

## Considering Adding a Package?

Ask these questions first:

1. **Is it already in Supabase?** Auth, storage, realtime, edge functions cover a lot. Don't add a package for something Supabase already does.
2. **Is it deferred?** Many packages above are correct for post-MVP features. Don't add them until that feature is being built.
3. **Does it require codegen?** No. `build_runner` is not in the project. Hand-write it.
4. **Does it add native code or FFI?** Flag it — affects CI and web builds.
5. **What does it cost in bundle size?** Run `flutter build web` before and after. Web bundle must stay < 5MB gzipped.
6. **Write the ADR.** Any new package goes in the Key Decisions section of `AGENTS.md` with a one-line rationale.
