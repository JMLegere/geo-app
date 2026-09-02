# Frontend, Usability, and Design System Structure

EarthNova uses the same enforcement shape as the `main-website` repo, adapted for Flutter.

## Canonical flow

```text
lib/main.dart (`ShadApp.custom`)
  -> lib/shared/design.dart
  -> foundations (`Spacing`) and canonical `App*` components
  -> feature screens/widgets
  -> registry, surface inventory, and contract checks
```

The design system is not a style suggestion. It is the place where reusable UI enters the app.

## Taxonomy

| Layer | Path | Purpose |
| --- | --- | --- |
| Foundations | `lib/shared/design/foundations/` | Internal conventions; `Spacing` is the shared layout vocabulary |
| Primitives | `lib/shared/design/primitives/` | Canonical small reusable atoms |
| Composites | `lib/shared/design/composites/` | Canonical reusable assembled UI |
| Patterns | `lib/shared/design/patterns/` | Canonical screen-allowed state patterns and catalog-only examples |
| Registry and inventory | `lib/shared/design/{registry,surface_inventory}.dart` | Exact public-component and app-surface contracts |

Visual feature screens import the public API only:

```dart
import 'package:earth_nova/shared/design.dart';
```

Feature code must not import internal taxonomy paths such as
`shared/design/primitives/...`. Its approved visual public vocabulary is
`AppBadge`, `AppButton`, `AppCard`, `AppEmptyState`, `AppErrorState`,
`AppFieldRow`, `AppNotice`, `AppStatGrid`, and `LoadingDots`; `Spacing` is the
shared layout vocabulary. `DesignLibraryExample` is experimental and
catalog-only. `ProductActionSurface` remains a separate nonvisual
product-action API/evidence boundary at
`lib/shared/product/product_action_surface.dart`; it is not part of the visual
design vocabulary or public design barrel. There are no `AppTheme`, `Earth*`,
legacy-token, or design-export aliases.

## Usability rules

- Map and gameplay screens prioritize state legibility before ornament: marker/ring, current map cell, fog relationship, then secondary cues.
- Touch targets must stay at or above 44px.
- Visual variants are semantic (`tone`, `status`, `relationship`) instead of raw color/style props.
- Every app UI implementation outside `lib/shared/design/` must be documented in `designSurfaceInventory` with its purpose, category, status, and design-system notes before it ships.
- Patterns such as `DesignLibraryExample` are catalog/review artifacts and are not allowed directly in app screens.
- Native Flutter/Material infrastructure, MapLibre/Canvas/painters, native icons, debug-only UI, and nonvisual product-action evidence are explicit neutral exceptions when required; they remain inventoried and do not establish a second visual system.

## Enforcement

The first-pass enforcement lives in tests so it runs in normal Flutter CI:

| Check | File | What fails |
| --- | --- | --- |
| Design contract | `test/shared/design/design_contract_test.dart` | Public-barrel drift, retired aliases, undocumented app UI surfaces, or non-neutral exception paths |
| Registry parity | `test/shared/design/design_component_registry_test.dart` | Public components missing exact registry/inventory coverage |
| Widget smoke/usability | `test/shared/design/design_library_widget_test.dart` | Canonical component rendering and action touch-target regressions |

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
category, status, and design-system notes. Native, Map, painter, debug, and
observability exceptions remain explicit inventory entries and pass their
applicable contracts.

When a screen or widget is touched for real product work:

1. Reuse an existing design component if it fits.
2. If the UI shape is reusable, add/extend the correct design taxonomy component first.
3. Add the component to `designComponentRegistry`.
4. Document the consuming screen/widget in `designSurfaceInventory` if it is not itself a design component.
5. Add or update focused widget/contract coverage.
6. Consume design components through `package:earth_nova/shared/design.dart`.
