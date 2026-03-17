# Shared Layer

Cross-feature UI utilities, design system, and game constants. No business logic, no state management. Everything in `lib/shared/` is pure presentation or configuration that features/ can depend on.

---

## Design System

Three-layer architecture: **tokens** (raw values) → **theme extension** (theme-aware semantics) → **shared components** (reusable widgets).

### design_tokens.dart

Centralized visual constants. Every widget should reference these instead of inline literals.

| Token class | Values | Usage |
|-------------|--------|-------|
| `Spacing` | xxs(2)..giant(64), pre-built EdgeInsets + SizedBox gaps | `Spacing.lg`, `Spacing.paddingCard`, `Spacing.gapMd` |
| `Radii` | xs(4)..pill(100), pre-built BorderRadius objects | `Radii.xxxl`, `Radii.borderXxxl` |
| `Shadows` | soft, medium, elevated, elevatedDark | `Shadows.medium` |
| `Durations` | instant(100ms)..markerPulse(2s) | `Durations.slow` |
| `AppCurves` | standard, slideIn, fadeIn, bounce | `AppCurves.slideIn` |
| `Blurs` | statusBar(12), frostedGlass(20), subtle(8) | `Blurs.frostedGlass` |
| `Opacities` | frosted, border, habitat gradient, badge | `Opacities.frostedDark` |
| `ComponentSizes` | notificationIcon(44), buttonHeight(52), etc. | `ComponentSizes.buttonHeight` |

**Convention:** Game-balance constants stay in `constants.dart`. Visual-only values go here.

### earth_nova_theme.dart

`ThemeExtension<EarthNovaTheme>` for game-specific theme-aware properties.

**Instance properties (vary dark/light):** `frostedGlassTint`, `frostedGlassBorder`, `frostedNotificationTint`, `frostedNotificationBorder`, `cardShadow`, `elevatedShadow`, `successColor`, `successContainerColor`.

**Static helpers (theme-independent):** `rarityColor(IucnStatus)`, `onRarityColor(IucnStatus)`, `rarityLabel(IucnStatus)`, `habitatEmojis`.

**Access patterns:**
```dart
// Via BuildContext extension (preferred)
context.earthNova.frostedGlassTint
context.earthNova.successColor

// Via static accessor
EarthNovaTheme.of(context)

// Static helpers (no context needed)
EarthNovaTheme.rarityColor(IucnStatus.endangered)
```

**Registered in:** `AppTheme.dark()` and `AppTheme.light()` via `extensions: [EarthNovaTheme.dark(colorScheme)]`.

### widgets/frosted_glass_container.dart

Reusable frosted-glass container with backdrop blur. Theme-aware tint/border via `EarthNovaTheme`.

**Variants:** Default (status bars, panels) vs `isNotification: true` (toasts). `bottomBorderOnly: true` for flush-to-edge bars.

### widgets/rarity_badge.dart

Compact IUCN rarity badge pill. Replaces 3 former duplicate `_RarityBadge` implementations.

**Sizes:** `RarityBadgeSize.small` (9px, grid cards) and `.medium` (10px, toasts/detail sheets).

### widgets/habitat_gradient.dart

Habitat-keyed gradient `BoxDecoration` builders. Single source of truth via `HabitatColors`.

**API:** `HabitatGradient.card(habitat)` (higher opacity), `.tile(habitat)` (lower opacity), `.emoji(habitat)`.

---

## File Inventory

### constants.dart

Game-balance constants and tuning parameters. All magic numbers live here.

**Categories:** Species/habitat/IUCN counts, fog-of-war parameters (detection radius, density values), season config, map defaults (Fredericton, NB), Voronoi grid parameters (lazy + legacy), camera settings (zoom, follow distance), rubber-band marker interpolation, debug logging flags.

**Convention:** Never hardcode game-balance values in features/. Import from here.

### app_theme.dart

Material 3 theme definitions for dark and light modes. Registers `EarthNovaTheme` extension.

**Public API:** `AppTheme.dark()`, `AppTheme.light()`, `AppTheme.rarityColor(IucnStatus)`, `AppTheme.onRarityColor(IucnStatus)`.

**Note:** `AppTheme.rarityColor()` and `EarthNovaTheme.rarityColor()` return identical values. Both are kept for backward compatibility.

### habitat_colors.dart

Three-color palettes for each habitat (primary, secondary, accent).

**Public API:** `HabitatPalette`, `HabitatColors.of(Habitat)`, `HabitatColors.primaryFor(Habitat)`, `HabitatColors.accentFor(Habitat)`.

### widgets/error_boundary.dart

Error boundary widget that catches Flutter framework errors and displays fallback UI.

**Public API:** `ErrorBoundary`, `DefaultErrorFallback`.

**`onError` signature:** `Widget Function(FlutterErrorDetails details, VoidCallback reset)` — the `reset` callback clears the error and re-renders the child subtree. Pass it to a "Try Again" button.

**Convention:** Wrap major screens at the route level. Only one ErrorBoundary per active route. Never nest multiple boundaries in an IndexedStack — `FlutterError.onError` is global, so all boundaries catch the same error (cascade bug).

### widgets/empty_state_widget.dart

Reusable empty-state placeholder with emoji, title, subtitle, and optional CTA button.

**Public API:** `EmptyStateWidget`.

**Usage:** Journal screens, sanctuary screens, any list that can be empty.

### widgets/tab_shell.dart

4-tab `IndexedStack` shell (Map | Home | Town | Pack). Moved from `features/navigation/`. Renders persistent tab bar with `NavigationBar` + lazy tab initialization.

**Note:** Tab state (selected index) lives in `core/state/tab_index_provider.dart` — shell reads/writes via `tabIndexProvider`.

### widgets/town_placeholder_screen.dart

Placeholder screen for the Town tab (not yet implemented). Moved from `features/navigation/`.

---

## Dependency Rules

### Allowed Imports

**shared/ MAY import from:** `core/models/` (for enums used in theming: IucnStatus, Habitat), `package:flutter/material.dart`, Dart standard library.

**Why core/models/ is allowed:** `app_theme.dart` needs `IucnStatus` for rarity color mapping, `habitat_colors.dart` needs `Habitat` for palette lookup. These are pure value objects with no side effects. The dependency is one-way: core/ never imports from shared/.

### Forbidden Imports

**shared/ MUST NOT import from:** `features/`, `core/state/`, `core/persistence/`, `core/services/`.

---

## Conventions

### Design System Usage (MANDATORY)

1. **Never hardcode colors in widgets.** Use `Theme.of(context).colorScheme.*`, `context.earthNova.*`, or static helpers.
2. **Never use magic numbers.** Use `Spacing.*`, `Radii.*`, `Blurs.*`, `Opacities.*`, `ComponentSizes.*`.
3. **Never duplicate rarity/habitat helpers.** Use `RarityBadge`, `HabitatGradient`, `EarthNovaTheme` statics.
4. **Never inline frosted glass logic.** Use `FrostedGlassContainer`.

### Theme Usage

Always use `AppTheme.dark()` and `AppTheme.light()` in `MaterialApp`. Access theme via `Theme.of(context).colorScheme.*` or `context.earthNova.*`.

### Constants Usage

Import constants by name: `import 'package:earth_nova/shared/constants.dart';`. Never use magic numbers. If a value appears twice, it belongs in `constants.dart` (game balance) or `design_tokens.dart` (visual).

---

## Gotchas

**Spacing.gapXs vs Spacing.xs:** `gapXs` is a pre-built `SizedBox` widget (use standalone in `children: []`). `xs` is a raw `double` (use in `SizedBox(height: Spacing.xs)` or `EdgeInsets`).

**Theme Color Access:** Use `Theme.of(context).colorScheme.primary` or `context.earthNova.successColor`. Don't access `AppTheme.primary` directly.

**HabitatGradient.tile() returns BoxDecoration:** Access the gradient via `.gradient` if you need to combine with other decoration properties.

**Error Boundary Scope:** Only one `ErrorBoundary` per route. Don't nest multiple boundaries (especially in IndexedStack) — `FlutterError.onError` is global, causing all boundaries to catch the same error.

**Habitat Colors:** Use `HabitatColors.of(habitat)` for full palette, not `Habitat.colorHex` (legacy).
