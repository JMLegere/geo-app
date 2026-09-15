import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// These stories own named non-widget boundaries.
const _boundaryOwnerCoverage = <String, String>{
  'MapScreen': 'retained platform/render-model/diagnostic boundaries',
  'CellOverlayPainter': 'fog, player, and cell painter rendering',
  'MapRootScreen': 'DesktopTraversalInput input-only boundary',
  'ErrorBoundaryRetry': 'private story state helper is test harness, not UI',
};

final _retiredDesignTypes = RegExp(
  r'\bEarth(?:Action|Icon|Meta|Notice|Tag|Field|Stat|Panel)\w*\b',
);

// Public visual types that are materially rendered by another catalog owner.
const _delegatedVisualOwners = <String, String>{
  'DiscoveryPausedBanner': 'MapScreen',
  'DistrictFootprintMapPainter': 'DistrictFootprintMap',
};

// These wrappers intentionally have no independent pixel catalog entry.
const _excludedNonvisual = <String, String>{
  'DesktopTraversalInput': 'input-only; covered by MapRootScreen',
  'ProductActionSurface': 'invisible action evidence wrapper',
  'ObservableScreen': 'invisible observability lifecycle wrapper',
};

const _allowedRoots = <String>['[Design System]', '[Product Surfaces]'];

void main() {
  final useCases = Directory('lib/use_cases');
  final generated = File('lib/main.directories.g.dart');

  test('catalog navigation, owners, and generated registrations stay closed', () {
    expect(
      generated.existsSync(),
      isTrue,
      reason: 'Missing generated catalog: ${generated.path}',
    );

    final directorySource = generated.readAsStringSync();
    final labels = RegExp(
      r"WidgetbookCategory\(\s*name:\s*'([^']+)'",
    ).allMatches(directorySource).map((match) => match.group(1)!).toList();
    expect(
      labels,
      equals(
        _allowedRoots
            .map((root) => root.substring(1, root.length - 1))
            .toList(),
      ),
      reason: '${generated.path} must expose only the approved roots in order',
    );

    final stories = _stories(useCases);
    expect(
      stories,
      isNotEmpty,
      reason: 'No @widgetbook.UseCase blocks under ${useCases.path}',
    );

    for (final story in stories) {
      expect(
        _allowedRoots.any((root) => story.path.startsWith(root)),
        isTrue,
        reason:
            '${story.source}: ${story.type} uses disallowed path ${story.path}',
      );
    }
    for (final story in stories) {
      expect(
        _retiredDesignTypes.hasMatch(
          File('lib/${story.source}').readAsStringSync(),
        ),
        isFalse,
        reason: '${story.source} still references a retired Earth design type',
      );
    }

    final byType = <String, List<_Story>>{};
    for (final story in stories) {
      (byType[story.type] ??= []).add(story);
    }
    for (final entry in byType.entries) {
      expect(
        entry.value.first.name,
        '00 Happy Path',
        reason:
            '${entry.value.first.source}: ${entry.key} must lead with 00 Happy Path',
      );
      expect(
        entry.value.any((story) => story.name == '00 Happy Path'),
        isTrue,
        reason:
            '${entry.value.first.source}: ${entry.key} is missing 00 Happy Path',
      );
    }

    final productionVisualTypes = _productionVisualTypes();
    final requiredVisualTypes = productionVisualTypes
        .difference(_excludedNonvisual.keys.toSet())
        .difference(_delegatedVisualOwners.keys.toSet());
    expect(
      byType.keys.toSet(),
      equals(requiredVisualTypes),
      reason:
          'Widgetbook stories must exactly cover public production visual '
          'types, except explicit headless or delegated owners.',
    );
    expect(
      byType.keys,
      containsAll(_publicDesignComponentNames()),
      reason:
          'Every public design registry component needs an independently '
          'annotated catalog story.',
    );

    for (final entry in _boundaryOwnerCoverage.entries) {
      expect(
        byType.keys,
        contains(entry.key),
        reason: '${entry.key} must cover ${entry.value}',
      );
    }
    for (final entry in _excludedNonvisual.entries) {
      expect(
        byType.keys,
        isNot(contains(entry.key)),
        reason: '${entry.key} is nonvisual: ${entry.value}',
      );
    }
    for (final entry in _delegatedVisualOwners.entries) {
      expect(
        productionVisualTypes,
        contains(entry.key),
        reason: 'Stale delegated visual owner ${entry.key}',
      );
      expect(
        byType.keys,
        contains(entry.value),
        reason: '${entry.key} must be covered by ${entry.value}',
      );
    }

    for (final source in stories.map((story) => story.source).toSet()) {
      expect(
        directorySource,
        contains(source),
        reason: '${generated.path} does not import story source $source',
      );
    }
    for (final story in stories) {
      expect(
        directorySource,
        contains('.${story.builder}'),
        reason:
            '${generated.path} does not register ${story.source}:${story.builder}',
      );
    }
  });
}

Set<String> _productionVisualTypes() {
  final inventory = File('../lib/ui/product_surfaces/surface_inventory.dart');
  if (!inventory.existsSync()) {
    throw StateError('Missing production surface inventory: ${inventory.path}');
  }
  final paths = RegExp(
    r"path:\s*'([^']+)'",
  ).allMatches(inventory.readAsStringSync()).map((match) => match.group(1)!);
  final files = <File>[
    ...Directory('../lib/ui/design_system')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart')),
    ...paths.map((path) => File('../$path')),
  ];
  final visualType = RegExp(
    r'class\s+([A-Z]\w*)(?:<[^>]+>)?\s+extends\s+(?:StatelessWidget|StatefulWidget|ConsumerWidget|ConsumerStatefulWidget|CustomPainter)',
  );
  return {
    for (final file in files)
      for (final match in visualType.allMatches(file.readAsStringSync()))
        match.group(1)!,
  };
}

Set<String> _publicDesignComponentNames() {
  final registry = File('../lib/ui/design_system/index.dart');
  if (!registry.existsSync()) {
    throw StateError('Missing public design registry: ${registry.path}');
  }
  return {
    for (final match in RegExp(
      r"^\s*'(\w+)',$",
      multiLine: true,
    ).allMatches(registry.readAsStringSync()))
      match.group(1)!,
  };
}

List<_Story> _stories(Directory root) {
  final stories = <_Story>[];
  final files =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final source = file.readAsStringSync();
    final constants = <String, String>{
      for (final match in RegExp(
        r"const\s+(\w+)\s*=\s*'([^']+)'",
      ).allMatches(source))
        match.group(1)!: match.group(2)!,
    };
    for (final match in RegExp(
      r'@widgetbook\.UseCase\(([\s\S]*?)\)\s*Widget\s+(\w+)',
    ).allMatches(source)) {
      final annotation = match.group(1)!;
      final name = RegExp(
        r"name:\s*'([^']+)'",
      ).firstMatch(annotation)?.group(1);
      final type = RegExp(r'type:\s*(\w+)').firstMatch(annotation)?.group(1);
      final pathValue = RegExp(
        r'path:\s*([^,\n)]+)',
      ).firstMatch(annotation)?.group(1)?.trim();
      final path = pathValue == null
          ? null
          : RegExp(r"^'([^']+)'$").firstMatch(pathValue)?.group(1) ??
                constants[pathValue];
      expect(name, isNotNull, reason: '${file.path}: malformed UseCase name');
      expect(type, isNotNull, reason: '${file.path}: malformed UseCase type');
      expect(
        path,
        isNotNull,
        reason: '${file.path}: UseCase path must be a string or local const',
      );
      stories.add(
        _Story(
          source: file.path.replaceFirst('lib/', ''),
          name: name!,
          type: type!,
          path: path!,
          builder: match.group(2)!,
        ),
      );
    }
  }
  return stories;
}

class _Story {
  const _Story({
    required this.source,
    required this.name,
    required this.type,
    required this.path,
    required this.builder,
  });

  final String source;
  final String name;
  final String type;
  final String path;
  final String builder;
}
