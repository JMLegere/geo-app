# Clean Architecture Migration — Decisions

## User Decisions (confirmed via question())
1. **Architecture**: Clean Architecture / Hexagonal — strict layering with dependency inversion
2. **Use case granularity**: One class per operation (verbose is correct)
3. **Shared entities**: Core domain entities in `core/domain/entities/`, used across features
4. **Per-feature DTOs**: Shared domain entities in core, per-feature DTOs in data layers (option A+C)
5. **Naming**: Service → Repository (standard Clean Architecture)
6. **IucnStatus**: Split — pure enum in domain, Color mapping via extension in shared
7. **Item serialization**: Extract ItemDto — Item becomes pure domain entity
8. **Game enums**: Split — pure enums in core/domain, emoji mapping via extensions in shared

## Codebase Inventory (25 source files, 17 test files)

### Models (4 files)
- `models/auth_state.dart` — AuthState, AuthStatus, UserProfile (116 lines)
- `models/item.dart` — Item, ItemCategory, ItemStatus, TaxonomicGroup refs (224 lines)
- `models/iucn_status.dart` — IucnStatus enum with Flutter Color (103 lines)
- `models/pack_filter_state.dart` — PackFilterState with filter logic (150 lines)

### Services (6 files)
- `services/auth_service.dart` — Abstract AuthService + AuthEvent sealed class (48 lines)
- `services/supabase_auth_service.dart` — SupabaseAuthService impl (163 lines)
- `services/mock_auth_service.dart` — MockAuthService impl (53 lines)
- `services/item_service.dart` — Abstract ItemService + SupabaseItemService + MockItemService (44 lines)
- `services/observability_service.dart` — ObservabilityService + hashPhone (85 lines)
- `services/supabase_bootstrap.dart` — SupabaseBootstrap.initialize (14 lines)

### Providers (3 files)
- `providers/auth_provider.dart` — AuthNotifier, authServiceProvider, observabilityProvider (100 lines)
- `providers/items_provider.dart` — ItemsNotifier, ItemsState, itemServiceProvider (96 lines)
- `providers/observable_notifier.dart` — ObservableNotifier base class (36 lines)

### Screens (5 files)
- `screens/login_screen.dart`
- `screens/loading_screen.dart`
- `screens/pack_screen.dart`
- `screens/settings_screen.dart`
- `screens/stub_screen.dart`

### Shared (4 files)
- `shared/app_theme.dart`
- `shared/constants.dart`
- `shared/design_tokens.dart`
- `shared/iconography.dart` — Contains TaxonomicGroup, Habitat, GameRegion, AppIcons enums

### Widgets (3 files)
- `widgets/loading_dots.dart`
- `widgets/species_card.dart`
- `widgets/tab_shell.dart`

### Tests (17 files)
- `test/app_test.dart`
- `test/models/` — auth_state_test, item_test, pack_filter_state_test
- `test/providers/` — auth_provider_test, items_provider_test, observable_notifier_test
- `test/services/` — auth_service_test, item_service_test, mock_auth_service_test, mock_supabase_client, observability_service_test
- `test/screens/` — login_screen_test, pack_screen_test
- `test/widgets/` — loading_dots_test, species_card_test
- `test/shared/` — app_theme_test, iconography_test

## Key Observations
- AuthService is ALREADY an abstract interface — just needs renaming to AuthRepository
- ItemService is ALREADY abstract — same
- Phone→email derivation logic in SupabaseAuthService._deriveEmail/_derivePassword is business logic that should move to use case
- Item.fromJson/toJson needs extraction to ItemDto
- IucnStatus imports flutter/material.dart for Color — needs splitting
- TaxonomicGroup/Habitat/GameRegion defined in iconography.dart with emoji — need splitting
- ItemCategory in item.dart references AppIcons — needs decoupling
