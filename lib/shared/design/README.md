# EarthNova Design Library

This directory is the canonical, repo-enforced design library for EarthNova.

It turns the current game UI language into maintained code:

```text
docs/design.md + docs/map-design.md + .agents/decisions.md
  -> lib/shared/theme/{app_theme,design_tokens}.dart
  -> lib/shared/design/{foundations,primitives,composites,patterns}
  -> feature screens and shared widgets
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
foundations -> primitives -> composites -> patterns -> feature screens
```

- `foundations/` — small helpers and conventions. Not a screen API.
- `primitives/` — small reusable UI atoms: action button, metadata text, tag, notice.
- `composites/` — composed layout/content units: panel, field row, stat grid.
- `patterns/` — larger reusable examples/catalog shapes. Current pattern: `DesignLibraryExample`.

## Ownership rules

1. Brand colors and Material theme values are owned by `lib/shared/theme/app_theme.dart`.
2. Spacing, radii, durations, curves, and component sizes are owned by `lib/shared/theme/design_tokens.dart`.
3. Feature screens import design components from the public `package:earth_nova/shared/design.dart` API.
4. Feature screens must not import internal taxonomy paths like `shared/design/primitives`.
5. Design widgets expose semantic variant/tone props instead of raw `Color`, `TextStyle`, `EdgeInsets`, or decoration escape hatches.
6. New reusable UI must be added in the right taxonomy folder first, then consumed by features.
7. Every exported design widget must be listed in `designComponentRegistry` with category, status, purpose, and screen-usage policy.
8. Every app UI file outside the design taxonomy must be listed in `designSurfaceInventory` with category, status, purpose, and design-system notes.
9. Any change to design components or app UI inventory must pass the shared design tests.

## Public API

Screens import from `lib/shared/design.dart` only:

```dart
import 'package:earth_nova/shared/design.dart';
```

Do not import from internal files:

```dart
import 'package:earth_nova/shared/design/primitives/index.dart';
```

## Enforcement

The repository enforces the design library through:

- `test/shared/design/design_contract_test.dart` — structure, public import path, app UI surface inventory, no raw style escape hatches.
- `test/shared/design/design_component_registry_test.dart` — registry/API/taxonomy parity.
- `test/shared/design/design_library_widget_test.dart` — render smoke and touch-target coverage.
- `flutter test` / CI — runs these checks with the rest of the suite.

The first pass establishes the structure. Existing older feature widgets may still carry local styling until migrated, but new reusable UI should enter through this design library.

## Adding a component

1. Add or reuse tokens in `lib/shared/theme/`.
2. Add the widget in the correct taxonomy folder.
3. Export it from that folder's `index.dart` and from `lib/shared/design/index.dart` through the taxonomy barrel.
4. Add it to `lib/shared/design/registry.dart` with `category`, `status`, `purpose`, and `allowedInScreens`.
5. Add representative usage in `DesignLibraryExample` when helpful.
6. Run `mise exec -- flutter test --no-pub test/shared/design` and the focused consumer tests.

## Adding app UI outside the design taxonomy

Any new screen, feature widget, shared widget, debug overlay, observability
fallback, or painter outside `lib/shared/design/` must be added to
`designSurfaceInventory`. The inventory is intentionally strict: validation fails
if a Flutter UI class exists without a design-system entry explaining why it
exists and how it relates to the canonical design language.
