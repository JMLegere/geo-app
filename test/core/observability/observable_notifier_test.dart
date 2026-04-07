import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ObservableNotifier enforcement', () {
    test('no Notifier subclass bypasses ObservableNotifier', () {
      final libDir = Directory('lib');
      final violations = <String>[];

      for (final file in libDir.listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        if (file.path.contains('observable_notifier.dart')) continue;

        final contents = file.readAsStringSync();
        final rawNotifierPattern =
            RegExp(r'extends\s+Notifier<(?!.*ObservableNotifier)');
        if (rawNotifierPattern.hasMatch(contents)) {
          violations.add(file.path);
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'These files use raw Notifier instead of ObservableNotifier:\n'
            '${violations.join('\n')}\n\n'
            'All notifiers MUST extend ObservableNotifier<T> to ensure '
            'every state transition is logged. See docs/design.md §6.',
      );
    });

    test('all throwing providers are registered in main.dart', () {
      final libDir = Directory('lib');
      final mainContents = File('lib/main.dart').readAsStringSync();
      final throwingProviders = <String>[];

      for (final file in libDir.listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        // main.dart itself is the registration point — skip it
        if (file.path.endsWith('main.dart')) continue;

        final lines = file.readAsStringSync().split('\n');
        for (var i = 0; i < lines.length; i++) {
          final match =
              RegExp(r'final\s+(\w+)\s*=\s*Provider<').firstMatch(lines[i]);
          if (match == null) continue;

          // Check this line and the next 3 for throw UnimplementedError
          final window = lines.skip(i).take(4).join('\n');
          if (window.contains('throw UnimplementedError')) {
            throwingProviders.add(match.group(1)!);
          }
        }
      }

      final unregistered = throwingProviders
          .where((p) => !mainContents.contains('$p.overrideWithValue('))
          .toList()
        ..sort();

      expect(
        unregistered,
        isEmpty,
        reason:
            'These throwing providers have no overrideWithValue in main.dart:\n'
            '${unregistered.join('\n')}\n\n'
            'Add each to the ProviderScope overrides list in main.dart.',
      );
    });

    test('no bare state = in ObservableNotifier subclasses', () {
      final libDir = Directory('lib');
      final violations = <String>[];

      for (final file in libDir.listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        // The base class legitimately uses state = inside transition()
        if (file.path.contains('observable_notifier.dart')) continue;

        final contents = file.readAsStringSync();
        if (!contents.contains('extends ObservableNotifier<')) continue;

        final lines = contents.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          // Bare 'state =' at the start of a statement (ignoring comments)
          if (RegExp(r'^\s*state\s*=\s*').hasMatch(line) &&
              !line.trimLeft().startsWith('//')) {
            violations.add('${file.path}:${i + 1}  ${line.trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'These files use bare state = instead of transition() or silentTransition():\n'
            '${violations.join('\n')}\n\n'
            'Use transition(newState, event) for all state changes.\n'
            'For high-frequency paths, use silentTransition(newState) with a '
            'comment explaining why silent is appropriate.',
      );
    });
  });
}
