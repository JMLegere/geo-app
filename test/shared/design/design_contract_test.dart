import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('design library contract', () {
    test('has the canonical structure artifacts', () {
      const requiredArtifacts = [
        'lib/shared/design.dart',
        'lib/shared/design/README.md',
        'lib/shared/design/index.dart',
        'lib/shared/design/registry.dart',
        'lib/shared/design/components.dart',
        'lib/shared/design/examples.dart',
        'lib/shared/design/foundations/index.dart',
        'lib/shared/design/primitives/index.dart',
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
