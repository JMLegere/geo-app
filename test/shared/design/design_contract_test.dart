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
        'lib/shared/design/components.dart',
        'lib/shared/design/examples.dart',
        'lib/shared/design/foundations/index.dart',
        'lib/shared/design/primitives/index.dart',
        'lib/shared/design/primitives/icon.dart',
        'lib/shared/design/composites/index.dart',
        'lib/shared/design/patterns/index.dart',
      ];

      for (final path in requiredArtifacts) {
        expect(File(path).existsSync(), isTrue, reason: '$path is required.');
      }
    });

    test('keeps app code on the public design API', () {
      final offenders = <String>[];

      for (final file in _dartFilesUnder('lib')) {
        if (_isWithin(file, 'lib/shared/design')) continue;

        final source = file.readAsStringSync();
        final hasInternalDesignPath = source.contains('shared/design/');

        if (hasInternalDesignPath) {
          offenders.add(file.path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'App/front-end code must import package:earth_nova/shared/design.dart, not internal design taxonomy paths.',
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
        expect(File(surface.path).existsSync(), isTrue,
            reason: '${surface.path} is documented but does not exist.');
        expect(surface.purpose, isNotEmpty,
            reason: '${surface.path} needs a purpose.');
        expect(surface.designSystemNotes, isNotEmpty,
            reason: '${surface.path} needs design-system notes.');
      }

      final legacySurfacePaths = designSurfaceInventory
          .where((surface) =>
              surface.status == DesignSurfaceStatus.legacyLocalComposition)
          .map((surface) => surface.path)
          .toSet();

      expect(
        legacyDesignSurfaceExceptionPaths,
        legacySurfacePaths,
        reason:
            'Legacy local UI is allowed only through legacyDesignSurfaceExceptions. '
            'New UI must use canonical design composition, infrastructure, debug-only, or add a visible exception with a migration trigger.',
      );

      for (final exception in legacyDesignSurfaceExceptions) {
        expect(publicDesignSurfacePaths, contains(exception.path),
            reason: '${exception.path} has a legacy exception but no surface.');
        expect(exception.reason, isNotEmpty,
            reason: '${exception.path} needs a legacy exception reason.');
        expect(exception.migrationTrigger, isNotEmpty,
            reason: '${exception.path} needs a migration trigger.');
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
    test(
        'keeps app chrome on canonical design icons instead of raw icons or emoji',
        () {
      final offenders = <String>[];
      const appChromeFiles = [
        'lib/shared/widgets/loading_dots.dart',
        'lib/shared/widgets/tab_shell.dart',
        'lib/features/map/presentation/widgets/map_status_bar.dart',
        'lib/features/map/presentation/widgets/discovery_notification.dart',
      ];
      final rawEmoji = RegExp(r'[🌍🌎🌏🗺👟🔥⟳]');
      final rawIcons = RegExp(r'\bIcons\.');
      final legacyIconography = RegExp(r'AppIcons\.');

      for (final path in appChromeFiles) {
        final source = File(path).readAsStringSync();
        if (rawEmoji.hasMatch(source) ||
            rawIcons.hasMatch(source) ||
            legacyIconography.hasMatch(source)) {
          offenders.add(path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'High-level app chrome should be text-first or use canonical design icons; raw Icons, AppIcons, and emoji glyphs are not allowed there.',
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
