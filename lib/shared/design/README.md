# EarthNova Design Library

This directory is the public shared-design contract for EarthNova. Phase 1 establishes a neutral dark Shad foundation; `ShadApp` owns the root theme and Material derives compatibility values from that theme.

## Public vocabulary

Feature code imports only the public barrel:

```dart
import 'package:earth_nova/shared/design.dart';
```

Canonical reusable components are:

- primitives: `AppButton`, `AppBadge`, `AppNotice`, `LoadingDots`
- composites: `AppCard`, `AppFieldRow`, `AppStatGrid`
- patterns: `AppEmptyState`, `AppErrorState`

`DesignLibraryExample` is experimental and catalog-only. It is not a screen pattern.

New `app_*.dart` components use Shad primitives directly. They must not import legacy `AppTheme`, `design_tokens`, or Earth component implementations.

## Temporary Earth boundary

Existing `Earth*` components remain exported and operational only to preserve current callers. They are deprecated, are not aliases for `App*`, and remain temporary until authorized surface waves migrate their callers. Phase 1 does not migrate feature screens, shells, authentication, readiness, routes, or gameplay surfaces.

## Registry and native contracts

Every public shared component is listed in `registry.dart` with category, status, purpose, and screen policy. The registry must exactly match the public component discovery and one native `product/design` atom, molecule, or organism contract.

The native contracts also cover product-specific exceptions that are not shared design components:

- `ProductActionSurface` in `lib/shared/product/`
- feature/product molecules, organisms, pages, and templates under `product/design/`

Those contracts describe product surfaces and interaction evidence; they are not additions to the shared `App*` vocabulary.

## Inventory

Every app UI file outside `lib/shared/design/` is listed in `surface_inventory.dart`. The root records Shad as the authority. Feature-surface notes remain pending until their explicitly authorized migration waves.

## Phase boundary

Phase 1 stops after the neutral foundation, public contracts, catalog primitive, and inventory alignment. Phase 2+ decides and authorizes individual feature-surface migrations.