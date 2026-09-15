import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/ui/design_system.dart';
import 'package:earth_nova/ui/product_surfaces/system/stub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets(
    'StubScreen renders canonical coming soon copy and observability',
    (tester) async {
      final obs = _TestObservabilityService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appObservabilityProvider.overrideWithValue(obs)],
          child: ShadApp(
            theme: ShadThemeData(
              brightness: Brightness.dark,
              colorScheme: const ShadZincColorScheme.dark(),
            ),
            themeMode: ThemeMode.dark,
            home: const StubScreen(label: 'Future tab'),
          ),
        ),
      );

      expect(find.byType(AppCard), findsOneWidget);
      expect(find.byType(AppNotice), findsOneWidget);
      expect(find.text('Future tab'), findsOneWidget);
      expect(find.text('Future tab — Coming soon'), findsOneWidget);
      expect(find.text('More discoveries on the way!'), findsOneWidget);
      expect(
        obs.findEvent('ui.screen.mounted')?['data']?['screen_name'],
        'stub_screen',
      );
      expect(
        obs.findEvent('ui.screen.ready')?['data']?['screen_name'],
        'stub_screen',
      );
    },
  );
}

class _TestObservabilityService extends ObservabilityService {
  _TestObservabilityService() : super(sessionId: 'stub-screen-test');

  final List<Map<String, dynamic>> events = [];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add({'event': event, 'category': category, 'data': data});
  }

  Map<String, dynamic>? findEvent(String event) {
    for (final entry in events) {
      if (entry['event'] == event) return entry;
    }
    return null;
  }
}
