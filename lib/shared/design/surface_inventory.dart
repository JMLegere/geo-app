enum DesignSurfaceCategory {
  appRoot,
  featureScreen,
  featureWidget,
  sharedWidget,
  observabilityBoundary,
  debugTool,
  painter,
}

enum DesignSurfaceStatus {
  canonicalComposition,
  legacyLocalComposition,
  infrastructure,
  debugOnly,
}

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
    purpose: 'App bootstrap, providers, theme, and MaterialApp shell.',
    designSystemNotes:
        'Owns no product UI styling beyond applying AppTheme and route wiring.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/auth/presentation/screens/loading_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.legacyLocalComposition,
    purpose: 'Authentication startup/loading route.',
    designSystemNotes:
        'Legacy local composition; should graduate to canonical loading/empty-state primitives when touched.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/auth/presentation/screens/login_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.legacyLocalComposition,
    purpose: 'Phone sign-in screen.',
    designSystemNotes:
        'Legacy local composition; keep aligned with AppTheme until login form components exist in the design library.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/identification/presentation/screens/pack_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.legacyLocalComposition,
    purpose: 'Player inventory/Pack surface.',
    designSystemNotes:
        'Legacy local composition; migrate filters, cards, and empty states into documented design components incrementally.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/identification/presentation/widgets/species_card.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.legacyLocalComposition,
    purpose: 'Owned species/item card used by Pack.',
    designSystemNotes:
        'Legacy local card pattern; should become a registered composite before reuse outside Pack.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/living_world/presentation/screens/town_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose:
        'Town place directory for discovered character-owned local places.',
    designSystemNotes:
        'Composes EarthPanel, EarthFieldRow, and EarthTag; local screen layout only.',
  ),
  DesignSurfaceDefinition(
    path:
        'lib/features/living_world/presentation/widgets/npc_venue_marker.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.legacyLocalComposition,
    purpose: 'Map callout for discovered NPC venues.',
    designSystemNotes:
        'Map marker styling is documented here until map marker primitives are added to the design taxonomy.',
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
    status: DesignSurfaceStatus.legacyLocalComposition,
    purpose: 'City territory detail route.',
    designSystemNotes:
        'Legacy local composition shared with territory routes; migrate to territory detail composites when touched.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/screens/country_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.legacyLocalComposition,
    purpose: 'Country territory detail route.',
    designSystemNotes:
        'Legacy local composition shared with territory routes; migrate to territory detail composites when touched.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/screens/district_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.legacyLocalComposition,
    purpose: 'District territory detail route.',
    designSystemNotes:
        'Legacy local composition shared with territory routes; migrate to territory detail composites when touched.',
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
    status: DesignSurfaceStatus.legacyLocalComposition,
    purpose: 'Primary map gameplay screen.',
    designSystemNotes:
        'Legacy local composition; map hierarchy is governed by docs/map-design.md until map-specific design primitives exist.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/screens/province_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.legacyLocalComposition,
    purpose: 'Province/state territory detail route.',
    designSystemNotes:
        'Legacy local composition shared with territory routes; migrate to territory detail composites when touched.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/screens/world_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.legacyLocalComposition,
    purpose: 'World territory detail route.',
    designSystemNotes:
        'Legacy local composition shared with territory routes; migrate to territory detail composites when touched.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/widgets/cell_detail_sheet.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.legacyLocalComposition,
    purpose: 'Map-cell field-note/detail sheet.',
    designSystemNotes:
        'Known field-note pattern; migrate toward EarthPanel/EarthFieldRow composites when touched.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/widgets/discovery_notification.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.legacyLocalComposition,
    purpose: 'Map discovery acknowledgement notification.',
    designSystemNotes:
        'Legacy notification styling; should become a registered notice/toast pattern before reuse.',
  ),
  DesignSurfaceDefinition(
    path:
        'lib/features/map/presentation/widgets/hierarchy_exploration_map.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.legacyLocalComposition,
    purpose: 'Territory hierarchy exploration mini-map.',
    designSystemNotes:
        'Map-specific local composition; governed by map visual hierarchy until a map composite exists.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/widgets/hierarchy_header.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.legacyLocalComposition,
    purpose: 'Territory hierarchy header.',
    designSystemNotes:
        'Legacy local composition; candidate for a territory header composite.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/widgets/map_status_bar.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.legacyLocalComposition,
    purpose: 'Map stats/status bar.',
    designSystemNotes:
        'Legacy local composition; candidate for EarthStatGrid/EarthTag composition.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/widgets/pinch_hint.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.legacyLocalComposition,
    purpose: 'Map gesture hint overlay.',
    designSystemNotes:
        'Legacy local composition; should use canonical notice/hint component when available.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/map/presentation/widgets/shimmer_cells.dart',
    category: DesignSurfaceCategory.featureWidget,
    status: DesignSurfaceStatus.legacyLocalComposition,
    purpose: 'Map-cell loading shimmer.',
    designSystemNotes:
        'Legacy loading treatment; candidate for a registered loading primitive/pattern.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/features/profile/presentation/screens/settings_screen.dart',
    category: DesignSurfaceCategory.featureScreen,
    status: DesignSurfaceStatus.legacyLocalComposition,
    purpose: 'Settings/profile route.',
    designSystemNotes:
        'Legacy local composition; should use canonical panel/action primitives when touched.',
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
    status: DesignSurfaceStatus.legacyLocalComposition,
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
    status: DesignSurfaceStatus.legacyLocalComposition,
    purpose: 'Shared loading indicator.',
    designSystemNotes:
        'Legacy local widget; should be promoted to a registered loading primitive if reused broadly.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/shared/widgets/stub_screen.dart',
    category: DesignSurfaceCategory.sharedWidget,
    status: DesignSurfaceStatus.legacyLocalComposition,
    purpose: 'Temporary coming-soon screen for unimplemented tabs/routes.',
    designSystemNotes:
        'Legacy local composition; replace with canonical empty-state pattern when added.',
  ),
  DesignSurfaceDefinition(
    path: 'lib/shared/widgets/tab_shell.dart',
    category: DesignSurfaceCategory.sharedWidget,
    status: DesignSurfaceStatus.canonicalComposition,
    purpose: 'Four-tab app shell and navigation chrome.',
    designSystemNotes:
        'App chrome must stay text-first or use canonical EarthIcon/EarthGlyph only.',
  ),
];

final publicDesignSurfacePaths = <String>{
  for (final surface in designSurfaceInventory) surface.path,
};
