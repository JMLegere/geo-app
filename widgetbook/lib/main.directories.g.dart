// dart format width=80
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering

// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AppGenerator
// **************************************************************************

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:earth_nova_widgetbook/use_cases/design_system/design_system_use_cases.dart'
    as _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases;
import 'package:earth_nova_widgetbook/use_cases/product_surfaces/app/app_readiness_gate_use_cases.dart'
    as _earth_nova_widgetbook_use_cases_product_surfaces_app_app_readiness_gate_use_cases;
import 'package:earth_nova_widgetbook/use_cases/product_surfaces/app/earth_nova_app_use_cases.dart'
    as _earth_nova_widgetbook_use_cases_product_surfaces_app_earth_nova_app_use_cases;
import 'package:earth_nova_widgetbook/use_cases/product_surfaces/auth/auth_use_cases.dart'
    as _earth_nova_widgetbook_use_cases_product_surfaces_auth_auth_use_cases;
import 'package:earth_nova_widgetbook/use_cases/product_surfaces/debug/debug_gesture_overlay_use_cases.dart'
    as _earth_nova_widgetbook_use_cases_product_surfaces_debug_debug_gesture_overlay_use_cases;
import 'package:earth_nova_widgetbook/use_cases/product_surfaces/encounters/pending_encounter_layer_use_cases.dart'
    as _earth_nova_widgetbook_use_cases_product_surfaces_encounters_pending_encounter_layer_use_cases;
import 'package:earth_nova_widgetbook/use_cases/product_surfaces/home/home_screen_use_cases.dart'
    as _earth_nova_widgetbook_use_cases_product_surfaces_home_home_screen_use_cases;
import 'package:earth_nova_widgetbook/use_cases/product_surfaces/identification/identification_service_screen_use_cases.dart'
    as _earth_nova_widgetbook_use_cases_product_surfaces_identification_identification_service_screen_use_cases;
import 'package:earth_nova_widgetbook/use_cases/product_surfaces/living_world/living_world_use_cases.dart'
    as _earth_nova_widgetbook_use_cases_product_surfaces_living_world_living_world_use_cases;
import 'package:earth_nova_widgetbook/use_cases/product_surfaces/map/map_use_cases.dart'
    as _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases;
import 'package:earth_nova_widgetbook/use_cases/product_surfaces/pack/pack_screen_use_cases.dart'
    as _earth_nova_widgetbook_use_cases_product_surfaces_pack_pack_screen_use_cases;
import 'package:earth_nova_widgetbook/use_cases/product_surfaces/pack/species_card_use_cases.dart'
    as _earth_nova_widgetbook_use_cases_product_surfaces_pack_species_card_use_cases;
import 'package:earth_nova_widgetbook/use_cases/product_surfaces/profile/settings_screen_use_cases.dart'
    as _earth_nova_widgetbook_use_cases_product_surfaces_profile_settings_screen_use_cases;
import 'package:earth_nova_widgetbook/use_cases/product_surfaces/system/system_use_cases.dart'
    as _earth_nova_widgetbook_use_cases_product_surfaces_system_system_use_cases;
import 'package:widgetbook/widgetbook.dart' as _widgetbook;

final directories = <_widgetbook.WidgetbookNode>[
  _widgetbook.WidgetbookCategory(
    name: 'Design System',
    children: [
      _widgetbook.WidgetbookFolder(
        name: 'Composites',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'AppActionRow',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .appActionRowHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AppCard',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .appCardHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AppChoiceMenu',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .appChoiceMenuHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AppCollectionGrid',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .appCollectionGridHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AppFieldRow',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .appFieldRowHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AppItemCard',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .appItemCardHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AppRibbon',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .appRibbonHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AppStatGrid',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .appStatGridHappyPath,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Feedback',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'ErrorBoundaryRetry',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .errorBoundaryRetryHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'LoadingDots',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .loadingDotsHappyPath,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Patterns',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'AppEmptyState',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .appEmptyStateHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AppErrorState',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .appErrorStateHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AppFilterSheet',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .appFilterSheetHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AppInspectionPanel',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .appInspectionPanelHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'DesignLibraryExample',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .designLibraryExampleHappyPath,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Primitives',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'AppBadge',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .appBadgeHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AppButton',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .appButtonHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AppIconButton',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .appIconButtonHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AppNavButton',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .appNavButtonHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AppNotice',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .appNoticeHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AppProgress',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .appProgressHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AppSearchField',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .appSearchFieldHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AppText',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .appTextHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'AppToggleChip',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_design_system_design_system_use_cases
                        .appToggleChipHappyPath,
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  _widgetbook.WidgetbookCategory(
    name: 'Product Surfaces',
    children: [
      _widgetbook.WidgetbookFolder(
        name: 'App',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'AppReadinessGate',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_app_app_readiness_gate_use_cases
                        .appReadinessGateHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '10 Hydrating',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_app_app_readiness_gate_use_cases
                        .appReadinessGateHydrating,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '20 Syncing',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_app_app_readiness_gate_use_cases
                        .appReadinessGateSyncing,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '30 Degraded',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_app_app_readiness_gate_use_cases
                        .appReadinessGateDegraded,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '40 Failed',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_app_app_readiness_gate_use_cases
                        .appReadinessGateFailed,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'EarthNovaApp',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_app_earth_nova_app_use_cases
                        .earthNovaAppHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '10 Restoring Session',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_app_earth_nova_app_use_cases
                        .earthNovaAppRestoringSession,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '20 Authentication Error',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_app_earth_nova_app_use_cases
                        .earthNovaAppAuthenticationError,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '30 Preparing World',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_app_earth_nova_app_use_cases
                        .earthNovaAppPreparingWorld,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Auth',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'LoadingScreen',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_auth_auth_use_cases
                        .loadingScreenHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'LoginScreen',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_auth_auth_use_cases
                        .loginScreenHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '10 Submitting',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_auth_auth_use_cases
                        .loginScreenSubmitting,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '20 Submit Error',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_auth_auth_use_cases
                        .loginScreenSubmitError,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Debug',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'DebugGestureOverlay',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_debug_debug_gesture_overlay_use_cases
                        .debugGestureOverlayHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '10 Player Controls',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_debug_debug_gesture_overlay_use_cases
                        .debugGestureOverlayPlayerControls,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '20 Collapsed',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_debug_debug_gesture_overlay_use_cases
                        .debugGestureOverlayCollapsed,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Encounters',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'PendingEncounterLayer',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_encounters_pending_encounter_layer_use_cases
                        .pendingEncounterReady,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '01 Resolving',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_encounters_pending_encounter_layer_use_cases
                        .pendingEncounterResolving,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '02 Resolution Failure',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_encounters_pending_encounter_layer_use_cases
                        .pendingEncounterFailure,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '03 No Pending — Expected Absence',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_encounters_pending_encounter_layer_use_cases
                        .pendingEncounterNone,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '04 Loading — Expected Absence',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_encounters_pending_encounter_layer_use_cases
                        .pendingEncounterLoading,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '05 Load Error — Expected Absence',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_encounters_pending_encounter_layer_use_cases
                        .pendingEncounterLoadError,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '06 Resolved — Expected Absence',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_encounters_pending_encounter_layer_use_cases
                        .pendingEncounterResolved,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Home',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'HomeScreen',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_home_home_screen_use_cases
                        .homeScreenHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '10 Loading',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_home_home_screen_use_cases
                        .homeScreenLoading,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '20 Load Error',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_home_home_screen_use_cases
                        .homeScreenLoadError,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Identification',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'IdentificationServiceScreen',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_identification_identification_service_screen_use_cases
                        .identificationServiceHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '01 Preparing',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_identification_identification_service_screen_use_cases
                        .identificationServicePreparing,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '02 Preparation Error',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_identification_identification_service_screen_use_cases
                        .identificationServicePreparationError,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '03 Hold To Reveal',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_identification_identification_service_screen_use_cases
                        .identificationServiceHoldToReveal,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '04 Committing (Start, Then Hold)',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_identification_identification_service_screen_use_cases
                        .identificationServiceCommitting,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '05 Commit Error',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_identification_identification_service_screen_use_cases
                        .identificationServiceCommitError,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '06 Identified Result',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_identification_identification_service_screen_use_cases
                        .identificationServiceResult,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Living World',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'TownScreen',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_living_world_living_world_use_cases
                        .townScreenHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '10 Loading',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_living_world_living_world_use_cases
                        .townScreenLoading,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '20 Load Error',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_living_world_living_world_use_cases
                        .townScreenLoadError,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '30 Empty',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_living_world_living_world_use_cases
                        .townScreenEmpty,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '40 Venue Without Villagers',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_living_world_living_world_use_cases
                        .townScreenVenueWithoutVillagers,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '50 Multiple Venues',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_living_world_living_world_use_cases
                        .townScreenMultipleVenues,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'VenueDetailScreen',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_living_world_living_world_use_cases
                        .venueDetailScreenHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '10 No Villagers',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_living_world_living_world_use_cases
                        .venueDetailScreenNoVillagers,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'VenueMarker',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_living_world_living_world_use_cases
                        .venueMarkerHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '10 Glyph Only',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_living_world_living_world_use_cases
                        .venueMarkerGlyphOnly,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '20 Long Label',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_living_world_living_world_use_cases
                        .venueMarkerLongLabel,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Map',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'CellDetailSheet',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .cellDetailSheetHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Informed',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .cellDetailSheetInformed,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Shrouded',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .cellDetailSheetShrouded,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'CellOverlayPainter',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .cellOverlayPainterHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Explored',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .cellOverlayPainterExplored,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Informed',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .cellOverlayPainterInformed,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Shrouded',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .cellOverlayPainterShrouded,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Wide Geometry',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .cellOverlayPainterWide,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'CityScreen',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .cityScreenHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'CountryScreen',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .countryScreenHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'DiscoveryNotification',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .discoveryNotificationHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'DistrictFootprintMap',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .districtFootprintMapHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Geometry Unavailable',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .districtFootprintMapUnavailable,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'DistrictScreen',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .districtScreenHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Error',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .districtScreenError,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'HierarchyExplorationMap',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .hierarchyExplorationMapHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Expected Absence',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .hierarchyExplorationMapEmpty,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'HierarchyHeader',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .hierarchyHeaderHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Back Navigation',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .hierarchyHeaderBack,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'MapCellKnowledgeLegend',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .mapCellKnowledgeLegendHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'MapRootScreen',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .mapRootCell,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'District Territory',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .mapRootDistrict,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'MapScreen',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .mapScreenHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Dart Renderer Fallback',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .mapScreenDartFallback,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Debug Ring',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .mapScreenDebugRing,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Error',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .mapScreenError,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Loading',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .mapScreenLoading,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Paused Discovery',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .mapScreenPaused,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Refreshing',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .mapScreenRefreshing,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'MapStatusBar',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .mapStatusBarHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Pending Visits',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .mapStatusBarPending,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'PinchHint',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .pinchHintHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Upper Boundary',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .pinchHintUpperBoundary,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'PlayerMarker',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .playerMarkerHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Ring',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .playerMarkerRing,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'ProvinceScreen',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .provinceScreenHappyPath,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'ShimmerCells',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .shimmerCellsHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'Wide Geometry',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .shimmerCellsWide,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'WorldScreen',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_map_map_use_cases
                        .worldScreenHappyPath,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Pack',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'PackScreen',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_pack_pack_screen_use_cases
                        .packScreenHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '01 Empty Pack',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_pack_pack_screen_use_cases
                        .packScreenEmpty,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '02 Loading',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_pack_pack_screen_use_cases
                        .packScreenLoading,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '03 Load Error',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_pack_pack_screen_use_cases
                        .packScreenError,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '04 Fauna Filter Zero',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_pack_pack_screen_use_cases
                        .packScreenCategoryZero,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'SpeciesCard',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_pack_species_card_use_cases
                        .speciesCardHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '01 Examined Unidentified',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_pack_species_card_use_cases
                        .speciesCardExaminedUnidentified,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '02 Unexamined Item',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_pack_species_card_use_cases
                        .speciesCardUnexamined,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'Profile',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'SettingsScreen',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_profile_settings_screen_use_cases
                        .settingsScreenHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '10 Developer Mode Enabled',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_profile_settings_screen_use_cases
                        .settingsScreenDeveloperModeEnabled,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '20 Desktop Controls Available',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_profile_settings_screen_use_cases
                        .settingsScreenDesktopControlsAvailable,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '30 Sign Out Dialog',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_profile_settings_screen_use_cases
                        .settingsScreenSignOutDialog,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'System',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'StubScreen',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_system_system_use_cases
                        .stubScreenHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '10 Long Label',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_system_system_use_cases
                        .stubScreenLongLabel,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'TabShell',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '00 Happy Path',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_system_system_use_cases
                        .tabShellHappyPath,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '10 Debug Controls',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_system_system_use_cases
                        .tabShellDebugControls,
              ),
              _widgetbook.WidgetbookUseCase(
                name: '20 Desktop Settings Access',
                builder:
                    _earth_nova_widgetbook_use_cases_product_surfaces_system_system_use_cases
                        .tabShellDesktopSettingsAccess,
              ),
            ],
          ),
        ],
      ),
    ],
  ),
];
