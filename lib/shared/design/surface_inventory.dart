enum DesignSurfaceCategory {
  appRoot,
  featureScreen,
  featureWidget,
  sharedWidget,
  observabilityBoundary,
  debugTool,
  painter,
}

enum DesignSurfaceStatus { canonicalComposition, infrastructure, debugOnly }

class DesignSurfaceDefinition {
  const DesignSurfaceDefinition({
    required this.path,
    required this.category,
    required this.status,
    required this.purpose,
    required this.designSystemNotes,
  });

  final String path;
  final DesignSurfaceCategory category;
  final DesignSurfaceStatus status;
  final String purpose;
  final String designSystemNotes;
}

const designSurfaceInventory = <DesignSurfaceDefinition>[
  DesignSurfaceDefinition(
    path: 'lib/main.dart',
    category: DesignSurfaceCategory.appRoot,
    status: DesignSurfaceStatus.infrastructure,
    purpose: 'App bootstrap, providers, Shad root theme, and Material shell.',
    designSystemNotes:
        'ShadApp is the root design authority; Material derives from its dark Shad theme for compatibility.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/app/readiness/app_readiness_gate.dart',
    category: DesignSurfaceCategory.appRoot,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose:
        'Authenticated readiness overlay that keeps the existing app shell painted while client state becomes usable.',
    designSystemNotes:
        'Phase 2 neutral composition: AppCard, AppButton, and AppNotice with ShadProgress. Map and Pack content remain pending later phases.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/auth/presentation/screens/loading_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Authentication startup/loading route.',
    designSystemNotes:
        'Phase 2 neutral composition: AppCard with the existing LoadingDots; no gameplay content is introduced here.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/auth/presentation/screens/login_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Phone sign-in screen.',
    designSystemNotes:
        'Phase 2 neutral composition: AppCard, AppNotice, and AppButton with ShadInput, preserving the existing phone format and authentication flow.',
  ),
  DesignSurfaceDefinition(
    path:
        'lib/features/encounters/presentation/widgets/pending_encounter_layer.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Pending Encounter resolution layer above the Map.',
    designSystemNotes:
        'Phase 3 neutral ownership: AppCard, AppFieldRow, AppNotice, and AppButton preserve resolve/retry evidence while map gestures remain outside the card.',
  ),
  DesignSurfaceDefinition(
    path:
        'lib/features/identification/presentation/screens/identification_service_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose:
        'Player-facing Villager service flow for identifying an examined find.',
    designSystemNotes:
        'Composes shared panels, notices, action controls, and app theme tokens for the identification service flow.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/pack/presentation/screens/pack_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Player inventory/Pack surface.',
    designSystemNotes:
        'Documented local composition; migrate filters, cards, and empty states into documented design components incrementally.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/pack/presentation/widgets/species_card.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Owned species/item card used by Pack.',
    designSystemNotes:
        'Documented Pack card pattern; should become a registered composite before reuse outside Pack.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/living_world/presentation/screens/town_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose:
        'Town directory for known Venues, introduced Villagers, and current Services.',
    designSystemNotes:
        'Town composes shared design panels, notices, tags, and app theme tokens.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/home/presentation/screens/home_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Read-only Home identity surface for the authenticated Player.',
    designSystemNotes:
        'Home composes shared design panels, notices, field rows, and app theme tokens through the public design API.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/living_world/presentation/widgets/venue_marker.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Map callout for known Town Venues.',
    designSystemNotes:
        'Map marker styling is documented here until map marker primitives are added to the design taxonomy.',
  ),
  DesignSurfaceDefinition(
    path:
        'lib/features/living_world/presentation/screens/venue_detail_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose:
        'Venue detail page grouping known Villagers and their current Services.',
    designSystemNotes:
        'Dedicated Venue page composes shared design panels, notices, tags, and app theme tokens.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/painters/cell_overlay_painter.dart',
    category: DesignSurfaceCategory.painter,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Voronoi cell overlay and border renderer.',
    designSystemNotes:
        'Painter-owned geometry/visual hierarchy; governed by map design docs rather than reusable widget taxonomy.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/painters/player_marker.dart',
    category: DesignSurfaceCategory.painter,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Trusted player marker and accuracy ring painter.',
    designSystemNotes:
        'Painter-owned marker/ring hierarchy; tokens should remain aligned with AppTheme.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/screens/city_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'City territory detail route.',
    designSystemNotes:
        'Documented territory-route composition; migrate to territory detail composites when touched.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/screens/country_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Country territory detail route.',
    designSystemNotes:
        'Documented territory-route composition; migrate to territory detail composites when touched.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/screens/district_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'District territory detail route.',
    designSystemNotes:
        'Documented territory-route composition; migrate to territory detail composites when touched.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/screens/map_root_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.infrastructure,
    purpose: 'Map feature navigation root.',
    designSystemNotes:
        'Route wiring container; visual design belongs to child map screens/widgets.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/screens/map_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Primary GPS map gameplay screen.',
    designSystemNotes:
        'Phase 3 neutral ownership: readiness, status, reward, and disclosure chrome uses the public design barrel; MapLibre, projections, geometry, and painters remain unchanged.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/screens/province_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Province/state territory detail route.',
    designSystemNotes:
        'Documented territory-route composition; migrate to territory detail composites when touched.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/screens/world_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'World territory detail route.',
    designSystemNotes:
        'Documented territory-route composition; migrate to territory detail composites when touched.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/widgets/cell_detail_sheet.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Read-only map Cell detail sheet.',
    designSystemNotes:
        'Phase 3 neutral ownership: AppCard, AppBadge, AppFieldRow, and AppButton preserve Cell disclosure and known Venue action evidence.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/widgets/desktop_traversal_input.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Desktop keyboard and pointer focus boundary for the map.',
    designSystemNotes:
        'Input-only wrapper with no visual styling; it preserves the map composition.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/widgets/discovery_notification.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Map discovery acknowledgement notification.',
    designSystemNotes:
        'Phase 3 neutral ownership: public design notice chrome preserves the acknowledgement lifecycle and action telemetry.',
  ),
  DesignSurfaceDefinition(
    path:
        'lib/features/map/presentation/widgets/hierarchy_exploration_map.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Territory hierarchy exploration mini-map.',
    designSystemNotes:
        'Map-specific local composition; governed by map visual hierarchy until a map composite exists.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/widgets/district_footprint_map.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'District-scope footprint map that draws real map-cell geometry.',
    designSystemNotes:
        'Map-specific painter composition; keeps district scope visually connected to GPS-level cells while adjacent districts remain faded context.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/widgets/hierarchy_header.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Territory hierarchy header and parent-scale navigation.',
    designSystemNotes:
        'Phase 3 neutral ownership: public design header chrome preserves hierarchy navigation evidence and uses State in player-facing copy.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/widgets/map_status_bar.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Map stats and status bar.',
    designSystemNotes:
        'Phase 3 neutral ownership: public design stats and status chrome preserves readiness and discovery state semantics.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/widgets/pinch_hint.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Map gesture hint overlay.',
    designSystemNotes:
        'Phase 3 neutral ownership: public design hint chrome preserves the existing gesture guidance without changing gesture handling.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/widgets/shimmer_cells.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Map Cell loading shimmer.',
    designSystemNotes:
        'Phase 3 neutral ownership: public design loading chrome preserves the existing Cell loading behavior and painter geometry.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/profile/presentation/screens/settings_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Settings/account route outside the gameplay destinations.',
    designSystemNotes:
        'Phase 2 neutral composition: AppCard, AppFieldRow, and AppButton with ShadSwitch and ShadDialog; Map and Pack content remain unchanged.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/shared/debug/debug_gesture_overlay.dart',
    category: DesignSurfaceCategory.debugTool,
    status: DesignSurfaceStatus.debugOnly,
    purpose: 'Debug-only gesture and movement overlay.',
    designSystemNotes:
        'Debug surface, not player-facing UI; still inventoried to prevent unreviewed styling creep.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/shared/observability/widgets/error_boundary_retry.dart',
    category: DesignSurfaceCategory.observabilityBoundary,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Error fallback with retry affordance.',
    designSystemNotes:
        'Infrastructure UI; should move to EarthNotice/EarthActionButton composition when touched.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/shared/observability/widgets/observable_screen.dart',
    category: DesignSurfaceCategory.observabilityBoundary,
    status: DesignSurfaceStatus.infrastructure,
    purpose: 'Screen lifecycle observability wrapper.',
    designSystemNotes:
        'Owns no styling except delegating to error fallback when needed.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/shared/widgets/loading_dots.dart',
    category: DesignSurfaceCategory.sharedWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Shared loading indicator.',
    designSystemNotes:
        'Documented local widget; should be promoted to a registered loading primitive if reused broadly.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/shared/product/product_action_surface.dart',
    category: DesignSurfaceCategory.sharedWidget,
    status: DesignSurfaceStatus.infrastructure,
    purpose: 'Invisible EAC product-action evidence wrapper.',
    designSystemNotes:
        'Owns no visual styling; exists to make clickable UI action mapping explicit for EAC native design contracts.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/shared/widgets/stub_screen.dart',
    category: DesignSurfaceCategory.sharedWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Temporary coming-soon screen for unimplemented tabs/routes.',
    designSystemNotes:
        'Documented local composition; replace with canonical empty-state pattern when added.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/shared/widgets/tab_shell.dart',
    category: DesignSurfaceCategory.sharedWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose:
        'Two-destination Map and Pack shell with a separate Settings route.',
    designSystemNotes:
        'Phase 2 neutral chrome: Material structural shell with text-first ShadButton.ghost navigation and selected semantics. Map and Pack content remain pending later phases.',
  ),
];

final publicDesignSurfacePaths = <String>{
  for (final surface in designSurfaceInventory) surface.path,
};
