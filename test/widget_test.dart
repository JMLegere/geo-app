import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/features/map/map_screen.dart';
import 'package:fog_of_world/features/onboarding/providers/onboarding_provider.dart';
import 'package:fog_of_world/main.dart';

/// Stub notifier that reports onboarding as complete without touching
/// SharedPreferences — safe to use in the headless test environment.
class _CompletedOnboardingNotifier extends OnboardingNotifier {
  @override
  bool? build() => true;
}

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    // FogOfWorldApp uses ConsumerWidgets (Riverpod) so it needs a ProviderScope.
    // Override onboardingProvider so the test skips onboarding and exercises
    // the existing auth → loading splash → MapScreen routing path.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingProvider
              .overrideWith(_CompletedOnboardingNotifier.new),
        ],
        child: const FogOfWorldApp(),
      ),
    );

    // Auth starts in loading state, which now shows _LoadingSplash
    // (not MapScreen) to avoid expensive map/fog initialization before
    // auth resolves. Verify the splash is visible initially.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let _initializeAuth() complete: supabaseReady resolves immediately
    // in tests, then MockAuthService.signInAnonymously() has a 100ms delay.
    await tester.pump(const Duration(milliseconds: 200));

    // MapLibreMap is a platform view (native map renderer). It throws
    // UnimplementedError in the headless Flutter test environment because
    // there is no real iOS/Android platform to host it. This is expected
    // behaviour — the error is caught by the Widgets library, not a sign of
    // a bug in our code.
    //
    // We clear the exception so the test can still verify the screen
    // scaffolding is correct.
    tester.takeException();

    // After auth resolves, the MapScreen widget is present in the widget tree.
    expect(find.byType(MapScreen), findsOneWidget);
  });
}
