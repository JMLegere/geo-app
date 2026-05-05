import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';

// Minimal concrete subclass that does NOT override category — exercises the
// default 'state' value on line 27 of observable_notifier.dart.
class _DefaultCategoryNotifier extends ObservableNotifier<int> {
  @override
  ObservabilityService get obs => ObservabilityService(sessionId: 'test');

  @override
  int build() => 0;
}

late ObservabilityService _transitionObs;

class _TransitionProbeNotifier extends ObservableNotifier<int> {
  @override
  ObservabilityService get obs => _transitionObs;

  @override
  String get category => 'probe';

  @override
  int build() => 0;

  void advance() => transition(1, 'probe.advanced');
}

void main() {
  group('ObservableNotifier default category', () {
    test('returns "state" when category is not overridden', () {
      final container = ProviderContainer(
        overrides: [],
      );
      addTearDown(container.dispose);

      final provider = NotifierProvider<_DefaultCategoryNotifier, int>(
        _DefaultCategoryNotifier.new,
      );

      final notifier = container.read(provider.notifier);
      expect(notifier.category, 'state');
    });
  });

  group('ObservableNotifier transition telemetry', () {
    test('adds lifecycle state_changed attributes to every transition', () {
      _transitionObs = ObservabilityService(sessionId: 'test');
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final provider = NotifierProvider<_TransitionProbeNotifier, int>(
        _TransitionProbeNotifier.new,
      );

      container.read(provider.notifier).advance();

      final row = _transitionObs.pendingLogRecords.single;
      final attributes = row['attributes'] as Map<String, dynamic>;
      expect(row['event_name'], 'probe.advanced');
      expect(attributes, containsPair('flow', 'probe'));
      expect(attributes, containsPair('phase', 'state_changed'));
      expect(attributes, containsPair('previous_state', 'int:0'));
      expect(attributes, containsPair('next_state', 'int:1'));
      expect(attributes, containsPair('reason', 'probe.advanced'));
      expect(attributes, containsPair('transition_event', 'probe.advanced'));
    });
  });

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

    test('silentTransition calls document why telemetry is intentionally skipped', () {
      final libDir = Directory('lib');
      final violations = <String>[];

      for (final file in libDir.listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        if (file.path.contains('observable_notifier.dart')) continue;

        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (!lines[i].contains('silentTransition(')) continue;
          final context = lines
              .sublist(i >= 3 ? i - 3 : 0, i)
              .map((line) => line.trim())
              .join(' ');
          if (!context.contains('silentTransition:')) {
            violations.add('${file.path}:${i + 1}  ${lines[i].trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'silentTransition intentionally skips telemetry. Every call '
            'must have a nearby `silentTransition:` comment explaining why the '
            'state change is too noisy or non-diagnostic to log.\n'
            '${violations.join('\n')}',
      );
    });
  });
}
