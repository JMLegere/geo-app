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
| Primitives | `lib/shared/design/primitives/` | Small reusable atoms like action buttons, tags, metadata, notices |
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
- New route-specific UI starts as local feature code; reusable UI graduates into the design taxonomy and registry.
- Patterns such as `DesignLibraryExample` are catalog/review artifacts and are not allowed directly in app screens.

## Enforcement

The first-pass enforcement lives in tests so it runs in normal Flutter CI:

| Check | File | What fails |
| --- | --- | --- |
| Design contract | `test/shared/design/design_contract_test.dart` | Missing artifacts, internal design imports from app code, public API drift, raw style escape hatches in design widgets |
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

## Migration rule

Existing pre-library feature widgets may still carry local styling. Do not churn them only to satisfy architecture. When a screen or widget is touched for real product work:

1. Reuse an existing design component if it fits.
2. If the UI shape is reusable, add/extend the correct design taxonomy component first.
3. Add the component to `designComponentRegistry`.
4. Add or update focused widget/contract coverage.
5. Consume it through `package:earth_nova/shared/design.dart`.
