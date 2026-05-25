# Frontend, Usability, and Design System Structure

EarthNova uses the same enforcement shape as the `main-website` repo, adapted for Flutter.

## Canonical flow

```text
docs/design.md + docs/map-design.md + .agents/decisions.md
  -> lib/shared/theme/app_theme.dart
  -> lib/shared/theme/design_tokens.dart
  -> lib/shared/design/{foundations,primitives,composites,patterns}
  -> feature screens/widgets
  -> test/shared/design/* contract checks
```

The design system is not a style suggestion. It is the place where reusable UI enters the app.

## Taxonomy

| Layer | Path | Purpose |
| --- | --- | --- |
| Foundations | `lib/shared/design/foundations/` | Internal helpers and conventions, not a screen API |
| Primitives | `lib/shared/design/primitives/` | Small reusable atoms like action buttons, icons, tags, metadata, notices |
| Composites | `lib/shared/design/composites/` | Assembled field-note units like panels, field rows, stat grids |
| Patterns | `lib/shared/design/patterns/` | Larger examples/catalog shapes, not direct app-screen dependencies |
| Registry | `lib/shared/design/registry.dart` | Formal component inventory with category/status/screen policy |

Feature screens import the public API only:

```dart
import 'package:earth_nova/shared/design.dart';
```

They must not import internal taxonomy paths such as `shared/design/primitives/...`.

## Usability rules

- Map and gameplay screens prioritize state legibility before ornament: marker/ring, current map cell, fog relationship, then secondary cues.
- Touch targets must stay at or above 44px; canonical actions use `ComponentSizes.buttonHeight`.
- Visual variants are semantic (`tone`, `status`, `relationship`) instead of raw color/style props.
- Every app UI implementation outside `lib/shared/design/` must be documented in `designSurfaceInventory` with its purpose, category, status, and design-system notes before it ships.
- Patterns such as `DesignLibraryExample` are catalog/review artifacts and are not allowed directly in app screens.
- High-level app chrome should use canonical design icons (`EarthIcon` / `EarthGlyph`) instead of raw `Icons.*`, emoji glyphs, or legacy `AppIcons` strings.

## Enforcement

The first-pass enforcement lives in tests so it runs in normal Flutter CI:

| Check | File | What fails |
| --- | --- | --- |
| Design contract | `test/shared/design/design_contract_test.dart` | Missing artifacts, internal design imports from app code, public API drift, undocumented app UI surfaces, raw style escape hatches in design widgets, raw app-chrome icons/emoji outside the design stack |
| Registry parity | `test/shared/design/design_component_registry_test.dart` | Exported taxonomy widgets missing registry entries, duplicate/stale entries, empty categories |
| Widget smoke/usability | `test/shared/design/design_library_widget_test.dart` | Catalog render breakage and action touch-target regressions |

Focused command:

```bash
mise exec -- flutter test --no-pub test/shared/design
```

For broader UI changes, run the focused feature/widget tests that cover the edited surface plus:

```bash
mise exec -- flutter analyze --no-pub
mise exec -- flutter test --no-pub --reporter=compact
```

## App UI surface rule

Every app UI implementation outside `lib/shared/design/` is part of the same
design system and must be listed in `designSurfaceInventory` with purpose,
category, status, and design-system notes. There is no separate exception
path: if a screen, widget, painter, debug overlay, or observability fallback
exists, it is documented as part of the design system and must pass the shared
design contract.

When a screen or widget is touched for real product work:

1. Reuse an existing design component if it fits.
2. If the UI shape is reusable, add/extend the correct design taxonomy component first.
3. Add the component to `designComponentRegistry`.
4. Document the consuming screen/widget in `designSurfaceInventory` if it is not itself a design component.
5. Add or update focused widget/contract coverage.
6. Consume design components through `package:earth_nova/shared/design.dart`.
