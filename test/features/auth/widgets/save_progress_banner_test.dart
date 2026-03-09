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
///
/// NOTE: [UpgradePromptState.showBanner] is hardcoded to false in the new
/// auth design — the upgrade prompt is permanently disabled. These tests
/// verify that the banner never renders regardless of the underlying state.
class _StubUpgradePromptNotifier extends UpgradePromptNotifier {
  _StubUpgradePromptNotifier({required bool supabaseInitialized})
      : _supabaseInitialized = supabaseInitialized;

  final bool _supabaseInitialized;

  @override
  UpgradePromptState build() => UpgradePromptState(
        totalCollected: 10,
        supabaseInitialized: _supabaseInitialized,
      );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrapWithBanner({
  required bool supabaseInitialized,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      upgradePromptProvider.overrideWith(
        () => _StubUpgradePromptNotifier(
          supabaseInitialized: supabaseInitialized,
        ),
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
    // showBanner is hardcoded to false in the new auth design — the upgrade
    // prompt is permanently disabled. The banner should never render.

    testWidgets('banner is never shown — showBanner is always false',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithBanner(
          supabaseInitialized: true,
          child: SaveProgressBanner(onUpgradeTap: () {}),
        ),
      );

      // Banner content is never rendered.
      expect(find.text('Save your progress'), findsNothing);
      expect(find.text('Sign in to keep your discoveries'), findsNothing);
      expect(find.text('Sign In'), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('banner is hidden when supabase is not initialized',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithBanner(
          supabaseInitialized: false,
          child: SaveProgressBanner(onUpgradeTap: () {}),
        ),
      );

      expect(find.text('Save your progress'), findsNothing);
      expect(find.text('Sign In'), findsNothing);
    });

    testWidgets('widget tree still contains SaveProgressBanner widget',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithBanner(
          supabaseInitialized: true,
          child: SaveProgressBanner(onUpgradeTap: () {}),
        ),
      );

      // The widget itself is present in the tree, just renders as SizedBox.shrink.
      expect(find.byType(SaveProgressBanner), findsOneWidget);
    });

    testWidgets('no OutlinedButton rendered regardless of state',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithBanner(
          supabaseInitialized: true,
          child: SaveProgressBanner(onUpgradeTap: () {}),
        ),
      );

      expect(find.byType(OutlinedButton), findsNothing);
    });
  });
}
