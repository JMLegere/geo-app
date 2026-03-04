# Shared Layer

Cross-feature UI utilities and game constants. No business logic, no state management. Everything in `lib/shared/` is pure presentation or configuration that features/ can depend on.

---

## File Inventory

### constants.dart

Game-balance constants and tuning parameters. All magic numbers live here.

**Categories:** Species/habitat/IUCN counts, fog-of-war parameters (detection radius, density values), season config, map defaults (Fredericton, NB), Voronoi grid parameters (lazy + legacy), camera settings (zoom, follow distance), rubber-band marker interpolation, debug logging flags.

**Convention:** Never hardcode game-balance values in features/. Import from here.

### app_theme.dart

Material 3 theme definitions for dark and light modes. IUCN rarity badge colors.

**Public API:** `AppTheme.dark()`, `AppTheme.light()`, `AppTheme.rarityColor(IucnStatus)`, `AppTheme.onRarityColor(IucnStatus)`.

**Imports from core/:** `core/models/iucn_status.dart` — needed for rarity color mapping.

### habitat_colors.dart

Three-color palettes for each habitat (primary, secondary, accent).

**Public API:** `HabitatPalette`, `HabitatColors.of(Habitat)`, `HabitatColors.primaryFor(Habitat)`, `HabitatColors.accentFor(Habitat)`.

**Imports from core/:** `core/models/habitat.dart` — needed for habitat enum.

### widgets/error_boundary.dart

Error boundary widget that catches Flutter framework errors and displays fallback UI.

**Public API:** `ErrorBoundary` (wraps subtrees to catch build errors), `DefaultErrorFallback` (friendly "Something went wrong" screen with retry button).

**Convention:** Wrap major screens to gracefully degrade on unexpected errors. Only one ErrorBoundary per active route (FlutterError.onError is global).

### widgets/empty_state_widget.dart

Reusable empty-state placeholder with emoji, title, subtitle, and optional CTA button.

**Public API:** `EmptyStateWidget` — centered empty state with icon, title, subtitle, action button.

**Usage:** Journal screens, sanctuary screens, any list that can be empty.

---

## Dependency Rules

### Allowed Imports

**shared/ MAY import from:** `core/models/` (for enums used in theming: IucnStatus, Habitat), `package:flutter/material.dart`, Dart standard library.

**Why core/models/ is allowed:** `app_theme.dart` needs `IucnStatus` for rarity color mapping, `habitat_colors.dart` needs `Habitat` for palette lookup. These are pure value objects with no side effects. The dependency is one-way: core/ never imports from shared/.

### Forbidden Imports

**shared/ MUST NOT import from:** `features/` (shared/ is a dependency of features/, not the reverse), `core/state/` (no Riverpod providers), `core/persistence/` (no database access), `core/services/` (no business logic).

---

## Conventions

### Theme Usage

Always use `AppTheme.dark()` and `AppTheme.light()` in `MaterialApp`. Never hardcode colors in widgets. Use `Theme.of(context).colorScheme.*` or `AppTheme.rarityColor()`.

### Constants Usage

Import constants by name: `import 'package:fog_of_world/shared/constants.dart';`. Never use magic numbers. If a value appears twice, it belongs in `constants.dart`.

### Error Boundaries

Wrap feature screens at the route level: `ErrorBoundary(onError: (details) => DefaultErrorFallback(...), child: MapScreen())`.

### Empty States

Use `EmptyStateWidget` for all empty lists: `EmptyStateWidget(icon: '🔬', title: 'No species discovered yet', subtitle: 'Start exploring!')`.

---

## Gotchas

**Theme Color Access:** Use `Theme.of(context).colorScheme.primary` or `AppTheme.rarityColor(species.iucnStatus)`. Don't access `AppTheme.primary` directly or hardcode colors.

**Constants Naming:** All constants use `k` prefix and camelCase: `kDetectionRadiusMeters`, `kDefaultZoom`.

**Error Boundary Scope:** Only one `ErrorBoundary` per route. Don't nest multiple boundaries — `FlutterError.onError` is global.

**Habitat Colors:** Use `HabitatColors.of(habitat)` for full palette, not `Habitat.colorHex` (legacy single-color string).
