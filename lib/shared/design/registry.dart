enum DesignComponentCategory { primitive, composite, pattern }

enum DesignComponentStatus { canonical, experimental, deprecated }

class DesignComponentDefinition {
  const DesignComponentDefinition({
    required this.name,
    required this.category,
    required this.status,
    required this.purpose,
    required this.allowedInScreens,
  });

  final String name;
  final DesignComponentCategory category;
  final DesignComponentStatus status;
  final String purpose;
  final bool allowedInScreens;
}

const designComponentRegistry = <DesignComponentDefinition>[
  DesignComponentDefinition(
    name: 'EarthActionButton',
    category: DesignComponentCategory.primitive,
    status: DesignComponentStatus.canonical,
    purpose:
        'Token-backed primary/secondary/neutral action button with usable touch target defaults.',
    allowedInScreens: true,
  ),
  DesignComponentDefinition(
    name: 'EarthMetaText',
    category: DesignComponentCategory.primitive,
    status: DesignComponentStatus.canonical,
    purpose:
        'Compact uppercase metadata line for field-note labels, provenance, and screen context.',
    allowedInScreens: true,
  ),
  DesignComponentDefinition(
    name: 'EarthNotice',
    category: DesignComponentCategory.primitive,
    status: DesignComponentStatus.canonical,
    purpose:
        'Inline status/info/warning box with semantic tone instead of ad hoc containers.',
    allowedInScreens: true,
  ),
  DesignComponentDefinition(
    name: 'EarthTag',
    category: DesignComponentCategory.primitive,
    status: DesignComponentStatus.canonical,
    purpose:
        'Compact status/tag chip for terrain, rarity, filters, and technical labels.',
    allowedInScreens: true,
  ),
  DesignComponentDefinition(
    name: 'EarthFieldRow',
    category: DesignComponentCategory.composite,
    status: DesignComponentStatus.canonical,
    purpose:
        'Label/value row for map-cell details, Pack provenance, settings, and diagnostics.',
    allowedInScreens: true,
  ),
  DesignComponentDefinition(
    name: 'EarthPanel',
    category: DesignComponentCategory.composite,
    status: DesignComponentStatus.canonical,
    purpose:
        'Bounded field-note panel with consistent heading, border, spacing, and action placement.',
    allowedInScreens: true,
  ),
  DesignComponentDefinition(
    name: 'EarthStatGrid',
    category: DesignComponentCategory.composite,
    status: DesignComponentStatus.canonical,
    purpose:
        'Compact two-column stat block for progress, territory, and diagnostic summaries.',
    allowedInScreens: true,
  ),
  DesignComponentDefinition(
    name: 'DesignLibraryExample',
    category: DesignComponentCategory.pattern,
    status: DesignComponentStatus.experimental,
    purpose:
        'Build/test catalog example for reviewing the design API without Storybook ceremony.',
    allowedInScreens: false,
  ),
];

final designTaxonomy =
    <DesignComponentCategory, List<DesignComponentDefinition>>{
  DesignComponentCategory.primitive: designComponentRegistry
      .where((component) =>
          component.category == DesignComponentCategory.primitive)
      .toList(growable: false),
  DesignComponentCategory.composite: designComponentRegistry
      .where((component) =>
          component.category == DesignComponentCategory.composite)
      .toList(growable: false),
  DesignComponentCategory.pattern: designComponentRegistry
      .where(
          (component) => component.category == DesignComponentCategory.pattern)
      .toList(growable: false),
};
