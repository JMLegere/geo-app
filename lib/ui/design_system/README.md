# EarthNova Design System

This directory is the canonical, repo-enforced reusable design system for EarthNova.

It turns the current game UI language into maintained code:

```text
docs/design.md + docs/map-design.md + .agents/decisions.md
  -> lib/ui/design_system/foundations/app_design_theme.dart
  -> lib/ui/design_system/{foundations,primitives,composites,patterns,feedback,adapters}
  -> lib/ui/product_surfaces/
```

## Design language

The current visual grammar is:

- cozy field-guide / GPS exploration
- dark navy surfaces with teal, amber, and soft-green accents
- strong marker/fog/map-cell hierarchy before decorative map detail
- compact metadata, status tags, and field-note panels
- medium-intensity acknowledgement instead of reward spam
- touch targets at or above 44px
- route code consumes named design components, not raw style choices

## Taxonomy

```text
foundations -> primitives -> composites -> product surfaces
```

- `foundations/` — small helpers and conventions. Not a screen API.
- `primitives/` — small reusable UI atoms: action button, metadata text, tag, notice.
- `composites/` — composed layout/content units: panel, field row, stat grid.
- `feedback/` — shared loading and recovery UI.
- `adapters/` — domain-to-visual icon and status mappings.

## Ownership rules

1. Shared colors, typography, spacing, motion, and component metrics are owned by `lib/ui/design_system/foundations/app_design_theme.dart` and `spacing.dart`.
2. Product surfaces import design components from the public `package:earth_nova/ui/design_system.dart` API.
3. Product surfaces must not import internal design-system paths like `ui/design_system/primitives`.
4. Design widgets expose semantic variant/tone props instead of raw `Color`, `TextStyle`, `EdgeInsets`, or decoration escape hatches.
5. New reusable UI must be added in the right taxonomy folder first, then consumed by product surfaces.
6. Every exported design widget must be listed in `designComponentRegistry` with category, status, purpose, and screen-usage policy.
7. Every visual source in `lib/ui/product_surfaces/` must be listed in `lib/ui/product_surfaces/surface_inventory.dart`.
8. Widgetbook consumes this public API after the design-system and product-surface contracts are settled; it does not define a second component architecture.

## Public API

Product surfaces import from `lib/ui/design_system.dart` only:

```dart
import 'package:earth_nova/ui/design_system.dart';
```

Do not import from internal files:

```dart
import 'package:earth_nova/ui/design_system/primitives/index.dart';
```

## Enforcement

The repository enforces the design library through:

- `test/ui/design_system/design_contract_test.dart` — structure, public import path, product-surface inventory, and no raw style escape hatches.
- `test/ui/design_system/design_component_registry_test.dart` — registry/API/taxonomy parity.
- Widgetbook catalog, fixture-safety, and visual-golden tests — named-state coverage and preserved rendering.
- `flutter test` / CI — runs these checks with the rest of the suite.

Reusable components live here; app-specific visual implementations live in `lib/ui/product_surfaces/`. Nonvisual providers, state, domain logic, data access, observability wrappers, and input-only adapters remain outside the UI layer.

## Adding a component

1. Add or reuse a foundation in `lib/ui/design_system/foundations/`.
2. Add the widget in the correct taxonomy folder.
3. Export it from that folder's `index.dart` and from `lib/ui/design_system/index.dart` through the taxonomy barrel.
4. Add it to `lib/ui/design_system/registry.dart` with `category`, `status`, `purpose`, and `allowedInScreens`.
5. Add the required named-state Widgetbook stories and visual baselines.
6. Run `mise exec -- flutter test --no-pub test/ui/design_system` and the focused consumer tests.

## Adding a product surface

Add a new screen, widget, painter, debug overlay, or render adapter under its
domain in `lib/ui/product_surfaces/`, then add it to
`lib/ui/product_surfaces/surface_inventory.dart` and cover its meaningful
states in Widgetbook. Do not put providers, domain logic, data access, or
input-only wrappers in the UI tree.
