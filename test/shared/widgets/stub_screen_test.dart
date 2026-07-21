import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/shared/widgets/stub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('StubScreen renders label and coming soon copy', (tester) async {
    final obs = ObservabilityService(sessionId: 'stub-screen-test');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appObservabilityProvider.overrideWithValue(obs)],
        child: const MaterialApp(
          home: StubScreen(label: 'Future tab'),
        ),
      ),
    );

    expect(find.text('Future tab'), findsOneWidget);
    expect(find.text('Future tab — Coming soon'), findsOneWidget);
    expect(find.text('More discoveries on the way!'), findsOneWidget);
  });
}
