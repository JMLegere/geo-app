import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/providers/auth_provider.dart';
import 'package:earth_nova/screens/login_screen.dart';
import 'package:earth_nova/services/mock_auth_service.dart';
import 'package:earth_nova/services/observability_service.dart';

void main() {
  group('LoginScreen', () {
    late MockAuthService auth;
    late ObservabilityService obs;

    setUp(() {
      auth = MockAuthService();
      obs = ObservabilityService(sessionId: 'test-session');
    });

    tearDown(() => auth.dispose());

    Widget buildScreen() {
      return ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          observabilityProvider.overrideWithValue(obs),
        ],
        child: const MaterialApp(home: LoginScreen()),
      );
    }

    /// Pump the widget and move AuthNotifier past loading → unauthenticated.
    Future<void> pumpLogin(WidgetTester tester) async {
      await tester.pumpWidget(buildScreen());
      // AuthNotifier starts in loading state (shows CircularProgressIndicator).
      // Trigger restoreSession to move to unauthenticated.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LoginScreen)),
      );
      await container.read(authProvider.notifier).restoreSession();
      // pump() instead of pumpAndSettle() — avoids timer issues.
      await tester.pump();
    }

    testWidgets('Continue button is disabled when phone field is empty',
        (tester) async {
      await pumpLogin(tester);

      final button = find.widgetWithText(ElevatedButton, 'Continue');
      expect(button, findsOneWidget);

      final elevatedButton = tester.widget<ElevatedButton>(button);
      expect(elevatedButton.onPressed, isNull,
          reason: 'Button should be disabled with no input');
    });

    testWidgets('Continue button enables after 10 digits typed',
        (tester) async {
      await pumpLogin(tester);

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, '5551234567');
      await tester.pump();

      final button = find.widgetWithText(ElevatedButton, 'Continue');
      final elevatedButton = tester.widget<ElevatedButton>(button);
      expect(elevatedButton.onPressed, isNotNull,
          reason: 'Button should enable after 10 digits');
    });

    testWidgets('Continue button stays disabled with < 10 digits',
        (tester) async {
      await pumpLogin(tester);

      final textField = find.byType(TextField);
      await tester.enterText(textField, '55512');
      await tester.pump();

      final button = find.widgetWithText(ElevatedButton, 'Continue');
      final elevatedButton = tester.widget<ElevatedButton>(button);
      expect(elevatedButton.onPressed, isNull,
          reason: 'Button should stay disabled with < 10 digits');
    });

    testWidgets('Continue button disables when digits are deleted',
        (tester) async {
      await pumpLogin(tester);

      final textField = find.byType(TextField);

      // Type 10 digits — button enables.
      await tester.enterText(textField, '5551234567');
      await tester.pump();
      var elevatedButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Continue'));
      expect(elevatedButton.onPressed, isNotNull);

      // Delete down to 5 digits — button disables.
      await tester.enterText(textField, '55512');
      await tester.pump();
      elevatedButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Continue'));
      expect(elevatedButton.onPressed, isNull);
    });

    testWidgets('tapping Continue with valid phone navigates to pack',
        (tester) async {
      await pumpLogin(tester);

      final textField = find.byType(TextField);
      await tester.enterText(textField, '5551234567');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // After successful sign-in, auth state → authenticated.
      // LoginScreen should still be in the tree (no navigator in test),
      // but the auth state should be authenticated.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final authState = container.read(authProvider);
      expect(authState.status.name, 'authenticated');
    });

    testWidgets('phone field shows +1 prefix', (tester) async {
      await pumpLogin(tester);

      // The prefix is rendered as part of InputDecoration.prefixText.
      // Find it in the widget tree.
      expect(find.text('+1 '), findsOneWidget);
    });

    testWidgets('phone field has max 10 character limit', (tester) async {
      await pumpLogin(tester);

      final textField = find.byType(TextField);
      // Type more than 10 chars — should be capped at 10.
      await tester.enterText(textField, '55512345678901');
      await tester.pump();

      final controller = tester.widget<TextField>(textField).controller!;
      expect(controller.text.length, lessThanOrEqualTo(10));
    });
  });
}
