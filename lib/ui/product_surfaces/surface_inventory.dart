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
    path: 'lib/ui/product_surfaces/app/earth_nova_app.dart',
    category: DesignSurfaceCategory.appRoot,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Root Shad and Material composition with auth/session lifecycle.',
    designSystemNotes:
        'ShadApp is the root design authority; Material derives from its dark Shad theme for compatibility.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/app/app_readiness_gate.dart',
    category: DesignSurfaceCategory.appRoot,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose:
        'Authenticated readiness overlay that keeps the existing app shell painted while client state becomes usable.',
    designSystemNotes:
        'Phase 6 canonical readiness fallback: AppCard, AppButton, and AppNotice with ShadProgress keep the existing app shell painted while client state becomes usable.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/auth/screens/loading_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Authentication startup/loading route.',
    designSystemNotes:
        'Phase 6 canonical auth loading route: AppCard with LoadingDots preserves startup behavior without introducing product content.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/auth/screens/login_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Phone sign-in screen.',
    designSystemNotes:
        'Phase 2 neutral composition: AppCard, AppNotice, and AppButton with ShadInput, preserving the existing phone format and authentication flow.',
  ),
  DesignSurfaceDefinition(
    path:
        'lib/ui/product_surfaces/encounters/widgets/pending_encounter_layer.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Pending Encounter resolution layer above the Map.',
    designSystemNotes:
        'Phase 3 neutral ownership: AppCard, AppFieldRow, AppNotice, and AppButton preserve resolve/retry evidence while map gestures remain outside the card.',
  ),
  DesignSurfaceDefinition(
    path:
        'lib/ui/product_surfaces/identification/screens/identification_service_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose:
        'Player-facing Villager service flow for identifying an examined find.',
    designSystemNotes:
        'Phase 5 neutral composition uses AppCard, AppButton, AppNotice, and LoadingDots from the public design barrel while preserving exact Item identity, examination-before-identification, retained actions, and the distinct service flow.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/pack/screens/pack_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Player inventory/Pack surface.',
    designSystemNotes:
        'Phase 5 neutral Pack composition uses the public App vocabulary while preserving exact owned Item identity and the existing search, filter, sort, category, paging, and grid behavior.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/pack/widgets/species_card.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Owned species/item card used by Pack.',
    designSystemNotes:
        'Phase 5 neutral Pack card preserves examined-versus-identified disclosure, IUCN meaning, media fallback, and the distinct identification handoff without becoming a shared gameplay primitive.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/living_world/screens/town_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose:
        'Town directory for known Venues, introduced Villagers, and current Services.',
    designSystemNotes:
        'Phase 5 neutral Town composition uses public App panels, notices, and badges while preserving known-venue provenance, introduced Villagers, current Services, and map knowledge gates.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/home/screens/home_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Read-only Home identity surface for the authenticated Player.',
    designSystemNotes:
        'Phase 5 identity-only composition uses AppCard, AppNotice, AppFieldRow, and LoadingDots through the public design API; it preserves authenticated/read states and intentionally adds no Modules panel or CTA.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/living_world/widgets/venue_marker.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Map callout for known Town Venues.',
    designSystemNotes:
        'Phase 5 neutral marker composition uses AppBadge while preserving the known Town projection and its map knowledge gate; it introduces no Venue Visit trigger or new map interaction.',
  ),
  DesignSurfaceDefinition(
    path:
        'lib/ui/product_surfaces/living_world/screens/venue_detail_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose:
        'Venue detail page grouping known Villagers and their current Services.',
    designSystemNotes:
        'Phase 5 neutral Venue composition uses public App panels, notices, and badges while preserving known Town provenance, introduced Villagers, current Services, and no Venue Visit trigger.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/map/rendering/cell_overlay_painter.dart',
    category: DesignSurfaceCategory.painter,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Voronoi cell overlay and semantic Fog border renderer.',
    designSystemNotes:
        'Phase 4 Fog composition: FogRenderer owns the grayscale-safe four-state treatments while this painter preserves organic cell geometry, frontier seams, projections, and semantics.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/map/rendering/player_marker.dart',
    category: DesignSurfaceCategory.painter,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose:
        'Retained centered player marker and trust/eligibility ring painter.',
    designSystemNotes:
        'Phase 4 marker ownership: one marker system remains visible for trusted, low-confidence, and paused states; its additive ring communicates trust and eligibility without a second marker.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/map/screens/city_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'City territory detail route.',
    designSystemNotes:
        'Documented territory-route composition; migrate to territory detail composites when touched.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/map/screens/country_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Country territory detail route.',
    designSystemNotes:
        'Documented territory-route composition; migrate to territory detail composites when touched.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/map/screens/district_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'District territory detail route.',
    designSystemNotes:
        'Documented territory-route composition; migrate to territory detail composites when touched.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/map/screens/map_root_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.infrastructure,
    purpose: 'Map feature navigation root.',
    designSystemNotes:
        'Route wiring container; visual design belongs to child map screens/widgets.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/map/screens/map_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Primary GPS map gameplay screen.',
    designSystemNotes:
        'Phase 4 calibrated map composition: renderer semantics change only through the Fog, player-marker, and hierarchy visual owners; MapLibre, projections, geometry, routes, providers, and gestures remain unchanged.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/map/screens/province_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Province/state territory detail route.',
    designSystemNotes:
        'Documented territory-route composition; migrate to territory detail composites when touched.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/map/screens/world_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'World territory detail route.',
    designSystemNotes:
        'Documented territory-route composition; migrate to territory detail composites when touched.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/map/widgets/cell_detail_sheet.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Read-only map Cell detail sheet.',
    designSystemNotes:
        'Phase 3 neutral ownership: AppCard, AppBadge, AppFieldRow, and AppButton preserve Cell disclosure and known Venue action evidence.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/map/widgets/desktop_traversal_input.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Desktop keyboard and pointer focus boundary for the map.',
    designSystemNotes:
        'Input-only wrapper with no visual styling; it preserves the map composition.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/map/widgets/discovery_notification.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Map discovery acknowledgement notification.',
    designSystemNotes:
        'Phase 3 neutral ownership: public design notice chrome preserves the acknowledgement lifecycle and action telemetry.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/map/widgets/hierarchy_exploration_map.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Territory hierarchy exploration mini-map.',
    designSystemNotes:
        'Phase 4 neutral hierarchy renderer: grayscale-safe semantic progress hierarchy preserves child summary counts and fixed-tile presentation behavior.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/map/widgets/district_footprint_map.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'District-scope footprint map that draws real map-cell geometry.',
    designSystemNotes:
        'Phase 4 neutral hierarchy renderer: semantic present, explored, informed, and shrouded contrast preserves real organic cell topology, adjacent context, visit evidence, and projection geometry.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/map/widgets/hierarchy_header.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Territory hierarchy header and parent-scale navigation.',
    designSystemNotes:
        'Phase 3 neutral ownership: public design header chrome preserves hierarchy navigation evidence and uses State in player-facing copy.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/map/widgets/map_status_bar.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Map stats and status bar.',
    designSystemNotes:
        'Phase 3 neutral ownership: public design stats and status chrome preserves readiness and discovery state semantics.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/map/widgets/pinch_hint.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Map gesture hint overlay.',
    designSystemNotes:
        'Phase 3 neutral ownership: public design hint chrome preserves the existing gesture guidance without changing gesture handling.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/map/widgets/shimmer_cells.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Map Cell loading shimmer.',
    designSystemNotes:
        'Phase 3 neutral ownership: public design loading chrome preserves the existing Cell loading behavior and painter geometry.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/profile/screens/settings_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Settings/account route outside the gameplay destinations.',
    designSystemNotes:
        'Phase 2 neutral composition: AppCard, AppFieldRow, and AppButton with ShadSwitch and ShadDialog; Map and Pack content remain unchanged.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/debug/debug_gesture_overlay.dart',
    category: DesignSurfaceCategory.debugTool,
    status: DesignSurfaceStatus.debugOnly,
    purpose: 'Debug-only gesture and movement overlay.',
    designSystemNotes:
        'Debug surface, not player-facing UI; still inventoried to prevent unreviewed styling creep.',
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
    path: 'lib/shared/product/product_action_surface.dart',
    category: DesignSurfaceCategory.sharedWidget,
    status: DesignSurfaceStatus.infrastructure,
    purpose: 'Invisible EAC product-action evidence wrapper.',
    designSystemNotes:
        'Owns no visual styling; exists to make clickable UI action mapping explicit for EAC native design contracts.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/system/stub_screen.dart',
    category: DesignSurfaceCategory.sharedWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Temporary coming-soon screen for unimplemented tabs/routes.',
    designSystemNotes:
        'Phase 6 canonical neutral stub page with no product action; it preserves the route label and coming-soon message.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/ui/product_surfaces/app/tab_shell.dart',
    category: DesignSurfaceCategory.sharedWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose:
        'Two-destination Map and Pack shell with a separate Settings route.',
    designSystemNotes:
        'Canonical structural shell: Material layout with text-first ShadButton.ghost navigation and selected semantics; Map and Pack behavior remains unchanged.',
  ),
];

final publicDesignSurfacePaths = <String>{
  for (final surface in designSurfaceInventory) surface.path,
};
