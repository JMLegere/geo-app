# lib/ — EarthNova v2

Flat architecture. See /AGENTS.md for project-wide rules.

## Structure
- `engine/` — Pure Dart game loop + event stream (`GameEngine`, `EngineRunner`)
- `domain/` — Game rules (cells, fog, species, items, seed, world)
- `data/` — Drift schema, repos, sync, location services
- `models/` — Immutable value objects
- `providers/` — 20 Riverpod providers
- `screens/` — 8 screens
- `widgets/` — Map rendering, UI components
- `shared/` — Constants, theme, design tokens
