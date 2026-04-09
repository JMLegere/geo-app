import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shared observability architecture guards', () {
    test('feature observability files do not import lib/shared', () {
      final featuresDir = Directory('lib/features');
      final violations = <String>[];

      for (final entity in featuresDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final contents = entity.readAsStringSync();
        if (!contents.contains('ObservabilityService')) continue;
        if (contents.contains("import 'package:earth_nova/shared/")) {
          violations.add(entity.path);
        }
      }

      violations.sort();

      expect(
        violations,
        isEmpty,
        reason: 'Feature observability files must not import lib/shared:\n'
            '${violations.join('\n')}',
      );
    });

    test('observability layer has no static mutable globals', () {
      final dirs = [
        Directory('lib/core/observability'),
        Directory('lib/shared/observability'),
      ];

      final violations = <String>[];
      final staticMutablePattern = RegExp(
          r'^\s*static\s+(?!const\b|final\b)[\w<>?,\s]+\s+\w+\s*(=|;)',
          multiLine: true);

      for (final dir in dirs) {
        if (!dir.existsSync()) continue;
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final contents = entity.readAsStringSync();
          if (staticMutablePattern.hasMatch(contents)) {
            violations.add(entity.path);
          }
        }
      }

      violations.sort();

      expect(
        violations,
        isEmpty,
        reason: 'Observability files must not define static mutable globals:\n'
            '${violations.join('\n')}',
      );
    });

    test('core observability contract files have no Flutter UI imports', () {
      final contractFiles = [
        File('lib/core/observability/app_observability_provider.dart'),
        File('lib/core/observability/observable_use_case_provider.dart'),
      ];

      final violations = <String>[];

      for (final file in contractFiles) {
        expect(
          file.existsSync(),
          isTrue,
          reason:
              'Expected core observability contract file to exist: ${file.path}',
        );

        final contents = file.readAsStringSync();
        final hasFlutterUiImport =
            contents.contains("import 'package:flutter/material.dart'") ||
                contents.contains("import 'package:flutter/widgets.dart'") ||
                contents.contains("import 'package:flutter/cupertino.dart'");

        if (hasFlutterUiImport) {
          violations.add(file.path);
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Core observability contract files must stay UI-free:\n'
            '${violations.join('\n')}',
      );
    });
  });
}
