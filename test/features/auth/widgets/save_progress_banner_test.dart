import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/features/auth/providers/upgrade_prompt_provider.dart';
import 'package:earth_nova/features/auth/widgets/save_progress_banner.dart';

// ---------------------------------------------------------------------------
// Stub notifier — hand-written, no mockito/mocktail
// ---------------------------------------------------------------------------

/// Returns a fixed [UpgradePromptState] without touching the real provider
/// graph (collection / auth / supabase). Safe for isolated widget tests.
class _StubUpgradePromptNotifier extends UpgradePromptNotifier {
  _StubUpgradePromptNotifier({required bool showBanner})
      : _showBanner = showBanner;

  final bool _showBanner;

  @override
  UpgradePromptState build() => UpgradePromptState(
        totalCollected: _showBanner ? 10 : 0,
        isAnonymous: _showBanner,
        supabaseInitialized: _showBanner,
      );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrapWithBanner({required bool showBanner, required Widget child}) {
  return ProviderScope(
    overrides: [
      upgradePromptProvider.overrideWith(
        () => _StubUpgradePromptNotifier(showBanner: showBanner),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SaveProgressBanner', () {
    testWidgets('renders banner when showBanner is true', (tester) async {
      await tester.pumpWidget(
        _wrapWithBanner(
          showBanner: true,
          child: SaveProgressBanner(onUpgradeTap: () {}),
        ),
      );

      expect(find.byType(SaveProgressBanner), findsOneWidget);
      expect(find.text('Save your progress'), findsOneWidget);
    });

    testWidgets('renders SizedBox.shrink when showBanner is false',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithBanner(
          showBanner: false,
          child: SaveProgressBanner(onUpgradeTap: () {}),
        ),
      );

      // No visible banner texts when hidden.
      expect(find.text('Save your progress'), findsNothing);
      expect(find.text('Sign In'), findsNothing);
    });

    testWidgets('banner contains "Save your progress" text when visible',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithBanner(
          showBanner: true,
          child: SaveProgressBanner(onUpgradeTap: () {}),
        ),
      );

      expect(find.text('Save your progress'), findsOneWidget);
    });

    testWidgets('banner contains subtitle text when visible', (tester) async {
      await tester.pumpWidget(
        _wrapWithBanner(
          showBanner: true,
          child: SaveProgressBanner(onUpgradeTap: () {}),
        ),
      );

      expect(find.text('Sign in to keep your discoveries'), findsOneWidget);
    });

    testWidgets('banner contains "Sign In" button when visible', (tester) async {
      await tester.pumpWidget(
        _wrapWithBanner(
          showBanner: true,
          child: SaveProgressBanner(onUpgradeTap: () {}),
        ),
      );

      expect(find.text('Sign In'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('tapping the "Sign In" button invokes callback', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _wrapWithBanner(
          showBanner: true,
          child: SaveProgressBanner(onUpgradeTap: () => tapped = true),
        ),
      );

      await tester.tap(find.byType(OutlinedButton));
      expect(tapped, isTrue);
    });

    testWidgets('tapping the banner body invokes callback', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _wrapWithBanner(
          showBanner: true,
          child: SaveProgressBanner(onUpgradeTap: () => tapped = true),
        ),
      );

      // Tap the primary text — lands on the GestureDetector wrapping the banner.
      await tester.tap(find.text('Save your progress'));
      expect(tapped, isTrue);
    });

    testWidgets('no "Sign In" button rendered when banner is hidden',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithBanner(
          showBanner: false,
          child: SaveProgressBanner(onUpgradeTap: () {}),
        ),
      );

      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('cloud upload icon is visible when banner is shown',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithBanner(
          showBanner: true,
          child: SaveProgressBanner(onUpgradeTap: () {}),
        ),
      );

      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
    });
  });
}
