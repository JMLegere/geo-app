# EarthNova Design Library

This directory is the public shared-design contract for EarthNova after the Phase 6 clean cutover. `ShadApp` owns the neutral root visual system; native Flutter/Material infrastructure remains only where it is required.

## Public vocabulary

Visual feature code imports only the public barrel:

```dart
import 'package:earth_nova/shared/design.dart';
```

The approved visual public vocabulary is `AppBadge`, `AppButton`, `AppCard`, `AppEmptyState`, `AppErrorState`, `AppFieldRow`, `AppNotice`, `AppStatGrid`, and `LoadingDots`. `Spacing` is the single shared layout vocabulary and lives in the foundations layer.

`DesignLibraryExample` is experimental and catalog-only. It is not a screen pattern.

`ProductActionSurface` remains a separate nonvisual product-action API/evidence boundary at `lib/shared/product/product_action_surface.dart`; it is not part of the visual design vocabulary or this barrel.

There are no `AppTheme`, `Earth*`, legacy-token, or design-export aliases. New reusable UI uses the canonical public vocabulary; feature code does not import internal design paths.

## Registry, inventory, and exceptions

The registry, public barrel, and visual native `product/design` contracts form one exact contract; `surface_inventory.dart` separately accounts for every app UI surface.

Explicit neutral exceptions remain documented rather than becoming a second design system:

- Flutter/Material runtime infrastructure and native controls where `shadcn_ui` has no equivalent;
- MapLibre, Flutter Canvas, and painters that preserve Map semantics;
- native icons, debug-only UI, and product-action evidence where they are required.

`ProductActionSurface` carries nonvisual product-action evidence; it does not introduce a visual style or design component.

## Phase boundary

Phase 6 is complete locally. Phase 7 rendered acceptance remains paused pending separate explicit authorization. Production deployment is not authorized.