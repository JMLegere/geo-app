# Frontend, Usability, and Design System Structure

Issue #596 extends the existing Shad foundation with one typed Dart semantic theme and shared material/interaction recipes. Shadcn remains the default; EarthNova overrides live inside this library.

## Canonical flow

```text
lib/main.dart (`ShadApp.custom`)
  -> lib/ui/design_system.dart
  -> foundations (`Spacing`) and canonical `App*` components
  -> feature screens/widgets
  -> registry, surface inventory, and contract checks
```

The design system is not a style suggestion. It is the place where reusable UI enters the app.

## Taxonomy

| Layer | Path | Purpose |
| --- | --- | --- |
| Foundations | `lib/ui/design_system/foundations/` | Internal conventions; `Spacing` and `AppDesignTheme` are the shared layout and visual vocabulary |
| Primitives | `lib/ui/design_system/primitives/` | Canonical small reusable atoms |
| Composites | `lib/ui/design_system/composites/` | Canonical reusable assembled UI |
| Patterns | `lib/ui/design_system/patterns/` | Canonical screen-allowed state patterns and catalog-only examples |
| Registry | `lib/ui/design_system/registry.dart` | Exact public-component contract |

Visual feature screens import the public API only:

```dart
import 'package:earth_nova/ui/design_system.dart';
```

Feature code must not import internal taxonomy paths such as
`ui/design_system/primitives/...`. Its approved visual public vocabulary is
`AppBadge`, `AppButton`, `AppCard`, `AppEmptyState`, `AppErrorState`,
`AppFieldRow`, `AppNotice`, `AppStatGrid`, and `LoadingDots`; `Spacing` is the
shared layout vocabulary. `DesignLibraryExample` is experimental and
catalog-only. `ProductActionSurface` remains a separate nonvisual
product-action API/evidence boundary at
`lib/shared/product/product_action_surface.dart`; it is not part of the visual
design vocabulary or public design barrel. AppDesignTheme resolves the approved overrides; AppText, AppProgress and AppActionRow extend the canonical vocabulary. There are no `AppTheme`, `Earth*`,
legacy-token, or design-export aliases.

## Usability rules

- Map and gameplay screens prioritize state legibility before ornament: marker/ring, current map cell, fog relationship, then secondary cues.
- Touch targets must stay at or above 44px.
- Visual variants are semantic (`tone`, `status`, `relationship`) instead of raw color/style props.
- Every app UI implementation outside `lib/ui/design_system/` must be documented in `designSurfaceInventory` with its purpose, category, status, and design-system notes before it ships.
- Patterns such as `DesignLibraryExample` are catalog/review artifacts and are not allowed directly in app screens.
- Native Flutter/Material infrastructure, MapLibre/Canvas/painters, native icons, debug-only UI, and nonvisual product-action evidence are explicit neutral exceptions when required; they remain inventoried and do not establish a second visual system.

## Enforcement

The first-pass enforcement lives in tests so it runs in normal Flutter CI:

| Check | File | What fails |
| --- | --- | --- |
| Design contract | `test/ui/design_system/design_contract_test.dart` | Public-barrel drift, retired aliases, undocumented app UI surfaces, or non-neutral exception paths |
| Registry parity | `test/ui/design_system/design_component_registry_test.dart` | Public components missing exact registry/inventory coverage |
| Widgetbook catalog | Widgetbook fixtures and visual checks | Named-state coverage after the design-system and product-surface contracts are settled |

Focused command:

```bash
mise exec -- flutter test --no-pub test/ui/design_system
```

For broader UI changes, run the focused feature/widget tests that cover the edited surface plus:

```bash
mise exec -- flutter analyze --no-pub
mise exec -- flutter test --no-pub --reporter=compact
```

## App UI surface rule

Every app UI implementation outside `lib/ui/design_system/` is part of the same
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
6. Consume design components through `package:earth_nova/ui/design_system.dart`.
