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

// Runtime projection of native `product/design` contracts for Flutter widgets.
// Keep this list in parity with EAC atom/molecule/organism contracts; do not
// treat it as the standalone source of truth.
const designComponentRegistry = <DesignComponentDefinition>[
  DesignComponentDefinition(
    name: 'AppBadge',
    category: DesignComponentCategory.primitive,
    status: DesignComponentStatus.canonical,
    purpose: 'Neutral Shad status badge for concise semantic labels.',
    allowedInScreens: true,
  ),
  DesignComponentDefinition(
    name: 'AppButton',
    category: DesignComponentCategory.primitive,
    status: DesignComponentStatus.canonical,
    purpose: 'Neutral Shad button for player-visible actions.',
    allowedInScreens: true,
  ),
  DesignComponentDefinition(
    name: 'AppCard',
    category: DesignComponentCategory.composite,
    status: DesignComponentStatus.canonical,
    purpose: 'Neutral Shad surface grouping related content and actions.',
    allowedInScreens: true,
  ),
  DesignComponentDefinition(
    name: 'AppEmptyState',
    category: DesignComponentCategory.pattern,
    status: DesignComponentStatus.canonical,
    purpose: 'Reusable screen-allowed empty-result pattern.',
    allowedInScreens: true,
  ),
  DesignComponentDefinition(
    name: 'AppErrorState',
    category: DesignComponentCategory.pattern,
    status: DesignComponentStatus.canonical,
    purpose: 'Reusable screen-allowed recoverable-error pattern.',
    allowedInScreens: true,
  ),
  DesignComponentDefinition(
    name: 'AppFieldRow',
    category: DesignComponentCategory.composite,
    status: DesignComponentStatus.canonical,
    purpose: 'Neutral Shad label/value row for compact details.',
    allowedInScreens: true,
  ),
  DesignComponentDefinition(
    name: 'AppNotice',
    category: DesignComponentCategory.primitive,
    status: DesignComponentStatus.canonical,
    purpose: 'Neutral Shad inline status or informational notice.',
    allowedInScreens: true,
  ),
  DesignComponentDefinition(
    name: 'AppStatGrid',
    category: DesignComponentCategory.composite,
    status: DesignComponentStatus.canonical,
    purpose: 'Neutral Shad grid for compact statistical summaries.',
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
  DesignComponentDefinition(
    name: 'EarthActionButton',
    category: DesignComponentCategory.primitive,
    status: DesignComponentStatus.deprecated,
    purpose:
        'Temporary legacy action button until authorized surface waves migrate callers.',
    allowedInScreens: true,
  ),
  DesignComponentDefinition(
    name: 'EarthFieldRow',
    category: DesignComponentCategory.composite,
    status: DesignComponentStatus.deprecated,
    purpose:
        'Temporary legacy label/value row until authorized surface waves migrate callers.',
    allowedInScreens: true,
  ),
  DesignComponentDefinition(
    name: 'EarthIcon',
    category: DesignComponentCategory.primitive,
    status: DesignComponentStatus.deprecated,
    purpose:
        'Temporary legacy icon wrapper until authorized surface waves migrate callers.',
    allowedInScreens: true,
  ),
  DesignComponentDefinition(
    name: 'EarthMetaText',
    category: DesignComponentCategory.primitive,
    status: DesignComponentStatus.deprecated,
    purpose:
        'Temporary legacy metadata text until authorized surface waves migrate callers.',
    allowedInScreens: true,
  ),
  DesignComponentDefinition(
    name: 'EarthNotice',
    category: DesignComponentCategory.primitive,
    status: DesignComponentStatus.deprecated,
    purpose:
        'Temporary legacy notice until authorized surface waves migrate callers.',
    allowedInScreens: true,
  ),
  DesignComponentDefinition(
    name: 'EarthPanel',
    category: DesignComponentCategory.composite,
    status: DesignComponentStatus.deprecated,
    purpose:
        'Temporary legacy panel until authorized surface waves migrate callers.',
    allowedInScreens: true,
  ),
  DesignComponentDefinition(
    name: 'EarthStatGrid',
    category: DesignComponentCategory.composite,
    status: DesignComponentStatus.deprecated,
    purpose:
        'Temporary legacy stat grid until authorized surface waves migrate callers.',
    allowedInScreens: true,
  ),
  DesignComponentDefinition(
    name: 'EarthTag',
    category: DesignComponentCategory.primitive,
    status: DesignComponentStatus.deprecated,
    purpose:
        'Temporary legacy tag until authorized surface waves migrate callers.',
    allowedInScreens: true,
  ),
  DesignComponentDefinition(
    name: 'LoadingDots',
    category: DesignComponentCategory.primitive,
    status: DesignComponentStatus.canonical,
    purpose: 'Neutral Shad loading indicator for asynchronous waiting states.',
    allowedInScreens: true,
  ),
];

final designTaxonomy =
    <DesignComponentCategory, List<DesignComponentDefinition>>{
      DesignComponentCategory.primitive: designComponentRegistry
          .where(
            (component) =>
                component.category == DesignComponentCategory.primitive,
          )
          .toList(growable: false),
      DesignComponentCategory.composite: designComponentRegistry
          .where(
            (component) =>
                component.category == DesignComponentCategory.composite,
          )
          .toList(growable: false),
      DesignComponentCategory.pattern: designComponentRegistry
          .where(
            (component) =>
                component.category == DesignComponentCategory.pattern,
          )
          .toList(growable: false),
    };
