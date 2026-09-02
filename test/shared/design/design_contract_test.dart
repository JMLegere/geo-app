import 'dart:io';

import 'package:earth_nova/shared/design.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('design library contract', () {
    test('has the canonical structure artifacts', () {
      const requiredArtifacts = [
        'lib/shared/design.dart',
        'lib/shared/design/README.md',
        'lib/shared/design/index.dart',
        'lib/shared/design/registry.dart',
        'lib/shared/design/surface_inventory.dart',
        'lib/shared/design/foundations/index.dart',
        'lib/shared/design/foundations/spacing.dart',
        'lib/shared/design/primitives/index.dart',
        'lib/shared/design/primitives/app_badge.dart',
        'lib/shared/design/primitives/app_button.dart',
        'lib/shared/design/primitives/app_notice.dart',
        'lib/shared/design/composites/index.dart',
        'lib/shared/design/composites/app_card.dart',
        'lib/shared/design/composites/app_field_row.dart',
        'lib/shared/design/composites/app_stat_grid.dart',
        'lib/shared/design/patterns/index.dart',
        'lib/shared/design/patterns/app_empty_state.dart',
        'lib/shared/design/patterns/app_error_state.dart',
        'lib/shared/product/product_action_surface.dart',
        'lib/shared/widgets/loading_dots.dart',
      ];

      for (final path in requiredArtifacts) {
        expect(File(path).existsSync(), isTrue, reason: '$path is required.');
      }
    });

    test('forbids imports of internal shared-design taxonomy paths', () {
      final offenders = <String>[];

      for (final root in const ['lib', 'test', 'tool']) {
        for (final file in _dartFilesUnder(root)) {
          if (_isWithin(file, 'lib/shared/design')) continue;

          final source = file.readAsStringSync();
          final imports = RegExp(
            r'''^import\s+['"]([^'"]+)['"]''',
            multiLine: true,
          ).allMatches(source);

          for (final import in imports) {
            final uri = import.group(1)!;
            if (_targetsInternalSharedDesign(file, uri)) {
              offenders.add('${file.path} imports $uri');
            }
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Dart code outside the taxonomy may import the public shared/design.dart barrel, but never an internal shared-design path.',
      );
    });

    test('exposes exact public design component names', () {
      expect(
        publicDesignComponentNames,
        unorderedEquals(const {
          'AppBadge',
          'AppButton',
          'AppCard',
          'AppEmptyState',
          'AppErrorState',
          'AppFieldRow',
          'AppNotice',
          'AppStatGrid',
          'DesignLibraryExample',
          'LoadingDots',
        }),
      );
    });

    test('keeps public API exports taxonomy-first', () {
      final source = File('lib/shared/design/index.dart').readAsStringSync();

      expect(source, contains("export 'foundations/index.dart';"));
      expect(source, contains("export 'primitives/index.dart';"));
      expect(source, contains("export 'composites/index.dart';"));
      expect(source, contains("export 'patterns/index.dart';"));
      expect(source, isNot(contains("export 'components.dart';")));
      expect(source, isNot(contains("export 'examples.dart';")));
    });
    test('documents every app UI surface outside the design taxonomy', () {
      final discoveredUiFiles = <String>{};

      final uiClass = RegExp(
        r'extends\s+(?:StatelessWidget|StatefulWidget|ConsumerWidget|ConsumerStatefulWidget|CustomPainter)',
      );

      for (final file in _dartFilesUnder('lib')) {
        if (_isWithin(file, 'lib/shared/design')) continue;

        final source = file.readAsStringSync();
        if (uiClass.hasMatch(source)) {
          discoveredUiFiles.add(_normalizedPath(file));
        }
      }

      expect(
        publicDesignSurfacePaths,
        discoveredUiFiles,
        reason:
            'Every app UI file outside lib/shared/design must be documented in designSurfaceInventory. '
            'Add new player-facing, debug, observability, painter, and route UI there before shipping.',
      );

      for (final surface in designSurfaceInventory) {
        expect(
          File(surface.path).existsSync(),
          isTrue,
          reason: '${surface.path} is documented but does not exist.',
        );
        expect(
          surface.purpose,
          isNotEmpty,
          reason: '${surface.path} needs a purpose.',
        );
        expect(
          surface.designSystemNotes,
          isNotEmpty,
          reason: '${surface.path} needs design-system notes.',
        );
      }
    });

    test('prevents style escape hatches in design widgets', () {
      final offenders = <String>[];
      final forbiddenField = RegExp(
        r'final\s+(?:Color|TextStyle|EdgeInsets|EdgeInsetsGeometry|Decoration|BoxDecoration)\??\s+[A-Za-z_][A-Za-z0-9_]*',
      );

      for (final file in [
        ..._dartFilesUnder('lib/shared/design/primitives'),
        ..._dartFilesUnder('lib/shared/design/composites'),
        ..._dartFilesUnder('lib/shared/design/patterns'),
      ]) {
        if (file.uri.pathSegments.last == 'index.dart') continue;
        final source = file.readAsStringSync();
        if (forbiddenField.hasMatch(source) || source.contains('Color(0x')) {
          offenders.add(file.path);
        }
      }

      expect(
        offenders.toSet().toList(),
        isEmpty,
        reason:
            'Design widgets should expose semantic variants/tone props, not raw color/style/padding escape hatches.',
      );
    });
    test('keeps canonical app components independent of legacy styling', () {
      final offenders = <String>[];
      const taxonomyDirs = ['primitives', 'composites', 'patterns'];

      for (final dir in taxonomyDirs) {
        for (final file in _dartFilesUnder('lib/shared/design/$dir')) {
          if (!file.uri.pathSegments.last.startsWith('app_')) continue;

          final source = file.readAsStringSync();
          final imports = RegExp(
            r'''^import\s+['"]([^'"]+)['"]''',
            multiLine: true,
          ).allMatches(source);
          for (final import in imports) {
            final uri = import.group(1)!;
            if (RegExp(r'(?:app_theme|design_tokens|earth_)').hasMatch(uri)) {
              offenders.add('${file.path} imports $uri');
            }
          }
          if (RegExp(
            r'\b(?:AppTheme|DesignTokens|Earth[A-Z])',
          ).hasMatch(source)) {
            offenders.add('${file.path} references a legacy design symbol');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'New app_*.dart components must use Shad primitives directly, not legacy AppTheme, design tokens, or Earth components.',
      );
    });
    test('keeps app chrome free of emoji and retired AppIcons', () {
      final offenders = <String>[];
      const appChromeFiles = [
        'lib/shared/widgets/loading_dots.dart',
        'lib/shared/widgets/tab_shell.dart',
        'lib/features/map/presentation/widgets/map_status_bar.dart',
        'lib/features/map/presentation/widgets/discovery_notification.dart',
      ];
      final rawEmoji = RegExp(r'[🌍🌎🌏🗺👟🔥⟳]');
      final legacyIconography = RegExp(r'AppIcons\.');

      for (final path in appChromeFiles) {
        final source = File(path).readAsStringSync();
        if (rawEmoji.hasMatch(source) || legacyIconography.hasMatch(source)) {
          offenders.add(path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'High-level app chrome may use approved native icons, but retired AppIcons and emoji glyphs are not allowed.',
      );
    });
  });
}

List<File> _dartFilesUnder(String relativePath) {
  final directory = Directory(relativePath);
  if (!directory.existsSync()) return const [];

  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();
}

bool _isWithin(File file, String relativeDirectory) {
  final dir = Directory(relativeDirectory).absolute.path;
  final path = file.absolute.path;
  return path == dir || path.startsWith('$dir${Platform.pathSeparator}');
}

String _normalizedPath(File file) {
  final current = Directory.current.absolute.path;
  final absolute = file.absolute.path;
  if (absolute == current) return '.';
  if (absolute.startsWith('$current${Platform.pathSeparator}')) {
    return absolute
        .substring(current.length + 1)
        .replaceAll(Platform.pathSeparator, '/');
  }
  return file.path.replaceAll(Platform.pathSeparator, '/');
}

bool _targetsInternalSharedDesign(File importingFile, String importUri) {
  if (importUri.startsWith('package:earth_nova/shared/design/')) {
    return true;
  }
  if (importUri.startsWith('package:') || importUri.startsWith('dart:')) {
    return false;
  }

  final resolved = importingFile.uri.resolveUri(Uri.parse(importUri));
  return resolved.scheme == 'file' &&
      _isWithin(File.fromUri(resolved), 'lib/shared/design');
}
