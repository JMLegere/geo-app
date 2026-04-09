import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/repositories/wake_lock_repository.dart';
import 'package:earth_nova/features/map/presentation/providers/wake_lock_provider.dart';
import 'package:earth_nova/shared/observability/navigation/app_navigation_observer.dart';
import 'package:earth_nova/shared/widgets/tab_shell.dart';

class _FakeWakeLockRepository implements WakeLockRepository {
  @override
  Future<void> acquire() async {}

  @override
  Future<void> release() async {}
}

class _TestObservabilityService extends ObservabilityService {
  _TestObservabilityService() : super(sessionId: 'test-session');
}

void main() {
  group('TabShell navigation observability', () {
    testWidgets('logs tab screen changes exactly once per transition',
        (tester) async {
      final transitions =
          <({String event, String category, Map<String, dynamic>? data})>[];
      final navigation = NavigationScreenTransitionLogger(
        logEvent: (event, category, {data}) {
          transitions.add((event: event, category: category, data: data));
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wakeLockRepositoryProvider
                .overrideWithValue(_FakeWakeLockRepository()),
            wakeLockObservabilityProvider
                .overrideWithValue(_TestObservabilityService()),
            appObservabilityProvider
                .overrideWithValue(_TestObservabilityService()),
            navigationScreenTransitionLoggerProvider
                .overrideWithValue(navigation),
          ],
          child: const MaterialApp(
            home: TabShell(
              screens: [
                SizedBox.shrink(),
                SizedBox.shrink(),
                SizedBox.shrink(),
                SizedBox.shrink(),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pack'));
      await tester.pump();

      await tester.tap(find.text('Pack'));
      await tester.pump();

      final screenChangedEvents = transitions
          .where((event) => event.event == 'navigation.screen_changed')
          .toList();
      expect(screenChangedEvents.length, 1);
      expect(screenChangedEvents.single.category, 'navigation');
      expect(screenChangedEvents.single.data, {
        'source': 'tab_shell',
        'from_screen': 'map',
        'to_screen': 'pack',
      });
    });
  });

  test('tab shell keeps cached IndexedStack screen list', () {
    final source = File('lib/shared/widgets/tab_shell.dart').readAsStringSync();

    expect(source, contains('IndexedStack('));
    expect(source, contains('late final List<Widget> _screens;'));
    expect(source, contains('children: _screens'));
  });
}
