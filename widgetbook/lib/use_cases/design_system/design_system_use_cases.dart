import 'dart:async';

import 'package:earth_nova/ui/design_system.dart';
import 'package:earth_nova_widgetbook/fixtures/story_host.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

const _primitives = '[Design System]/Primitives';
const _composites = '[Design System]/Composites';
const _patterns = '[Design System]/Patterns';
const _feedback = '[Design System]/Feedback';

Widget _story(Widget child, {double width = 420}) => earthNovaStory(
  child: Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

@widgetbook.UseCase(name: '00 Happy Path', type: AppButton, path: _primitives)
Widget appButtonHappyPath(BuildContext context) => _story(
  AppButton(
    label: 'Continue',
    leading: const Icon(Icons.arrow_forward),
    onPressed: () {},
  ),
);

@widgetbook.UseCase(name: '00 Happy Path', type: AppBadge, path: _primitives)
Widget appBadgeHappyPath(BuildContext context) =>
    _story(const AppBadge(label: 'Verified', leading: Icon(Icons.check)));

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: AppIconButton,
  path: _primitives,
)
Widget appIconButtonHappyPath(BuildContext context) => _story(
  AppIconButton(
    label: 'Open notifications',
    icon: Icons.notifications_outlined,
    badgeCount: 3,
    onPressed: () {},
  ),
);

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: AppNavButton,
  path: _primitives,
)
Widget appNavButtonHappyPath(BuildContext context) => _story(
  AppNavButton(
    label: 'Map',
    icon: const Icon(Icons.map_outlined),
    selected: true,
    showLabel: true,
    onPressed: () {},
  ),
  width: 120,
);

@widgetbook.UseCase(name: '00 Happy Path', type: AppNotice, path: _primitives)
Widget appNoticeHappyPath(BuildContext context) => _story(
  const AppNotice(
    title: 'Observation saved',
    message: 'Your field note is ready for the next sync.',
    tone: AppNoticeTone.success,
  ),
);

@widgetbook.UseCase(name: '00 Happy Path', type: AppProgress, path: _primitives)
Widget appProgressHappyPath(BuildContext context) => _story(
  const AppProgress(
    current: 3,
    requirement: 5,
    label: 'Cells explored',
    icon: Icon(Icons.explore_outlined),
  ),
);

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: AppSearchField,
  path: _primitives,
)
Widget appSearchFieldHappyPath(BuildContext context) =>
    _story(_SearchFieldStory());

class _SearchFieldStory extends StatefulWidget {
  @override
  State<_SearchFieldStory> createState() => _SearchFieldStoryState();
}

class _SearchFieldStoryState extends State<_SearchFieldStory> {
  var _query = 'Red fox';

  @override
  Widget build(BuildContext context) => AppSearchField(
    query: _query,
    onChanged: (query) => setState(() => _query = query),
  );
}

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: AppToggleChip,
  path: _primitives,
)
Widget appToggleChipHappyPath(BuildContext context) =>
    _story(_ToggleChipStory());

class _ToggleChipStory extends StatefulWidget {
  @override
  State<_ToggleChipStory> createState() => _ToggleChipStoryState();
}

class _ToggleChipStoryState extends State<_ToggleChipStory> {
  var _selected = true;

  @override
  Widget build(BuildContext context) => AppToggleChip(
    label: 'Show discovered',
    selected: _selected,
    onChanged: (selected) => setState(() => _selected = selected),
  );
}

@widgetbook.UseCase(name: '00 Happy Path', type: AppText, path: _primitives)
Widget appTextHappyPath(BuildContext context) => _story(
  const AppText('Northern river boundary', role: AppTextRole.itemName),
);

@widgetbook.UseCase(name: '00 Happy Path', type: AppCard, path: _composites)
Widget appCardHappyPath(BuildContext context) => _story(
  const AppCard(
    title: 'Map cell detail',
    description: 'A discovered place',
    child: AppText('This field note is available offline.'),
  ),
);

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: AppActionRow,
  path: _composites,
)
Widget appActionRowHappyPath(BuildContext context) => _story(
  AppActionRow(
    actions: [
      AppButton(
        label: 'Dismiss',
        onPressed: () {},
        variant: AppButtonVariant.outline,
      ),
      AppButton(label: 'Inspect', onPressed: () {}),
    ],
  ),
);

@widgetbook.UseCase(name: '00 Happy Path', type: AppRibbon, path: _composites)
Widget appRibbonHappyPath(BuildContext context) =>
    _story(const AppRibbon(title: 'New discovery'));

@widgetbook.UseCase(name: '00 Happy Path', type: AppFieldRow, path: _composites)
Widget appFieldRowHappyPath(BuildContext context) => _story(
  const AppFieldRow(
    label: 'Region',
    value: 'Northern river boundary',
    helper: 'Recorded offline',
    trailing: AppBadge(label: 'Verified'),
  ),
);

@widgetbook.UseCase(name: '00 Happy Path', type: AppStatGrid, path: _composites)
Widget appStatGridHappyPath(BuildContext context) => _story(
  const AppStatGrid(
    items: [
      AppStatItem(label: 'Visited', value: '24', helper: 'Map cells'),
      AppStatItem(label: 'Species', value: '18', helper: 'Recorded'),
    ],
  ),
);

@widgetbook.UseCase(name: '00 Happy Path', type: AppItemCard, path: _composites)
Widget appItemCardHappyPath(BuildContext context) => _story(
  const SizedBox(
    height: 220,
    child: AppItemCard(
      artwork: Icon(Icons.pets, size: 80),
      property: AppCardProperty(label: 'Species', value: 'Red fox'),
    ),
  ),
  width: 160,
);

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: AppCollectionGrid,
  path: _composites,
)
Widget appCollectionGridHappyPath(BuildContext context) => _story(
  SizedBox(
    height: 320,
    child: AppCollectionGrid(
      itemCount: 5,
      itemBuilder: (context, index) => AppItemCard(
        artwork: Icon(Icons.pets, size: 48 + index.toDouble()),
        property: AppCardProperty(label: 'Specimen', value: 'No. ${index + 1}'),
      ),
    ),
  ),
);

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: AppChoiceMenu,
  path: _composites,
)
Widget appChoiceMenuHappyPath(BuildContext context) =>
    _story(_ChoiceMenuStory());

class _ChoiceMenuStory extends StatefulWidget {
  @override
  State<_ChoiceMenuStory> createState() => _ChoiceMenuStoryState();
}

class _ChoiceMenuStoryState extends State<_ChoiceMenuStory> {
  var _value = 'Nearby';
  static const _choices = [
    AppChoice(value: 'Nearby', label: 'Nearby'),
    AppChoice(value: 'Recent', label: 'Recently discovered'),
  ];

  @override
  Widget build(BuildContext context) => AppChoiceMenu<String>(
    label: 'Sort map cells',
    value: _value,
    choices: _choices,
    onChanged: (value) => setState(() => _value = value),
  );
}

@widgetbook.UseCase(name: '00 Happy Path', type: AppEmptyState, path: _patterns)
Widget appEmptyStateHappyPath(BuildContext context) => _story(
  AppEmptyState(
    title: 'No discoveries yet',
    message: 'Explore nearby cells to record your first specimen.',
    actionLabel: 'Open map',
    onAction: () {},
  ),
);

@widgetbook.UseCase(name: '00 Happy Path', type: AppErrorState, path: _patterns)
Widget appErrorStateHappyPath(BuildContext context) => _story(
  AppErrorState(
    title: 'Nearby cells could not refresh.',
    message: 'Check your connection and try again.',
    onRetry: () {},
  ),
);

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: AppFilterSheet,
  path: _patterns,
)
Widget appFilterSheetHappyPath(BuildContext context) =>
    earthNovaStory(child: const _FilterSheetStory());

class _FilterSheetStory extends StatefulWidget {
  const _FilterSheetStory();

  @override
  State<_FilterSheetStory> createState() => _FilterSheetStoryState();
}

class _FilterSheetStoryState extends State<_FilterSheetStory> {
  var _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_open()));
  }

  Future<void> _open() => AppFilterSheet.show(
    context,
    (_) => const AppFilterSheet(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: AppToggleChip(
          label: 'Discovered only',
          selected: true,
          onChanged: _ignoreSelection,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: AppButton(
        label: 'Open filters',
        onPressed: () => unawaited(_open()),
      ),
    ),
  );
}

void _ignoreSelection(bool selected) {}

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: AppInspectionPanel,
  path: _patterns,
)
Widget appInspectionPanelHappyPath(BuildContext context) => earthNovaStory(
  child: AppInspectionPanel(
    semanticLabel: 'Red fox inspection',
    title: const AppText('Red fox', role: AppTextRole.itemName),
    onClose: () {},
    child: const AppFieldRow(
      label: 'Habitat',
      value: 'Northern river boundary',
      helper: 'Observed at dusk',
    ),
    footer: AppButton(label: 'Keep exploring', onPressed: () {}, expand: true),
  ),
);

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: DesignLibraryExample,
  path: _patterns,
)
Widget designLibraryExampleHappyPath(BuildContext context) =>
    earthNovaStory(child: const Scaffold(body: DesignLibraryExample()));

@widgetbook.UseCase(name: '00 Happy Path', type: LoadingDots, path: _feedback)
Widget loadingDotsHappyPath(BuildContext context) =>
    _story(const LoadingDots());

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: ErrorBoundaryRetry,
  path: _feedback,
)
Widget errorBoundaryRetryHappyPath(BuildContext context) =>
    earthNovaStory(child: ErrorBoundaryRetry(onRetry: () {}));
