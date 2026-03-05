# Tech Stack

> Versions, packages, build commands, deploy pipeline, CI status.

---

## Runtime

| Tool | Version | Managed by |
|------|---------|------------|
| Flutter | 3.41.3 | `mise` (`mise.toml`) |
| Dart SDK | >=3.0.0 <4.0.0 | Bundled with Flutter |

```bash
# Activate Flutter via mise
eval "$(~/.local/bin/mise activate bash)"
```

---

## Dependencies

### Production

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_riverpod` | ^3.2.1 | State management (Notifier pattern) |
| `riverpod_annotation` | ^4.0.2 | Code-gen annotations for providers |
| `geobase` | ^1.5.0 | Geo types — `Geographic(lat:, lon:)` |
| `h3_flutter_plus` | ^1.0.0 | H3 spatial indexing (FFI — needs `LD_LIBRARY_PATH=.`) |
| `maplibre` | ^0.1.2 | Map rendering (josxha fork, NOT `maplibre_gl`) |
| `drift` | ^2.14.0 | SQLite ORM — offline-first persistence |
| `sqlite3_flutter_libs` | ^0.6.0+eol | SQLite native bindings |
| `supabase_flutter` | ^2.12.0 | Backend (conditional — requires `--dart-define`) |
| `geolocator` | ^13.0.2 | GPS stream (iOS + Android + Web) |
| `intl` | ^0.20.2 | Date/number formatting |
| `crypto` | ^3.0.6 | SHA-256 hashing (deterministic species seeding) |
| `web` | ^1.1.1 | Web platform interop |
| `shared_preferences` | ^2.3.0 | Lightweight key-value storage |

### Dev

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_lints` | ^6.0.0 | Lint rules (24 custom rules in `analysis_options.yaml`) |
| `build_runner` | ^2.4.0 | Code generation orchestrator |
| `drift_dev` | ^2.14.0 | Drift code gen (generates `*.g.dart`) |
| `riverpod_generator` | ^4.0.3 | Provider code gen |
| `flutter_launcher_icons` | ^0.14.3 | App icon generation |
| `flutter_native_splash` | ^2.4.4 | Splash screen generation |
| `image` | ^4.1.0 | Image processing (used by launcher_icons) |

---

## Build & Run

```bash
# Run tests (H3 FFI requires LD_LIBRARY_PATH)
LD_LIBRARY_PATH=. flutter test

# Static analysis (must report 0 issues)
flutter analyze

# Code generation (after Drift schema or Riverpod annotation changes)
flutter pub run build_runner build

# Build web
flutter build web

# Build web with Supabase
flutter build web \
  --dart-define=SUPABASE_URL=<url> \
  --dart-define=SUPABASE_ANON_KEY=<key>
```

---

## Deploy

**Target:** Web (Docker → nginx → port 8080)

```
Dockerfile: instrumentisto/flutter:3.41 → flutter build web → nginx:alpine
nginx.conf: SPA fallback (try_files → /index.html), gzip enabled
```

**Platform:** Railway (or any Docker host). Exposes port 8080.

**Supabase credentials:** Currently hardcoded in Dockerfile. Should use `--build-arg` instead.

---

## Linting

- Base: `package:flutter_lints/flutter.yaml`
- 24 custom rules enabled (see `analysis_options.yaml`)
- Excluded from analysis: `*.g.dart`, `*.freezed.dart`
- `missing_required_param` and `missing_return` promoted to errors
- `todo` comments ignored

---

## CI Status

**Stale.** `.github/workflows/ci.yml` runs Unity builds (from before Flutter migration). Does NOT run `flutter test` or `flutter analyze`. Needs complete rewrite for Flutter.

---

## Assets

| Asset | Path | Notes |
|-------|------|-------|
| Species data | `assets/species_data.json` | 32,752 IUCN records, ~6 MB |
| Fog shader | `shaders/fog.frag` | Fragment shader for fog overlay |
| App icon | `assets/icon/app_icon.png` | Adaptive icon, dark bg `#0D1B2A` |
