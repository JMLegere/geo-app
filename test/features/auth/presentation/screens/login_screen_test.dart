import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/auth/presentation/screens/login_screen.dart';

void main() {
  group('LoginScreen', () {
    late MockAuthRepository auth;
    late ObservabilityService obs;

    setUp(() {
      auth = MockAuthRepository();
      obs = ObservabilityService(sessionId: 'test-session');
    });

    tearDown(() => auth.dispose());

    Widget buildScreen() {
      return ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          observabilityProvider.overrideWithValue(obs),
        ],
        child: const MaterialApp(home: LoginScreen()),
      );
    }

    Future<void> pumpLogin(WidgetTester tester) async {
      await tester.pumpWidget(buildScreen());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LoginScreen)),
      );
      await container.read(authProvider.notifier).restoreSession();
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

      await tester.enterText(textField, '5551234567');
      await tester.pump();
      var elevatedButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Continue'));
      expect(elevatedButton.onPressed, isNotNull);

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

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final authState = container.read(authProvider);
      expect(authState.status.name, 'authenticated');
    });

    testWidgets('phone field shows (555) 123-4567 placeholder', (tester) async {
      await pumpLogin(tester);

      expect(find.text('(555) 123-4567'), findsOneWidget);
    });

    testWidgets('phone field shows +1 prefix', (tester) async {
      await pumpLogin(tester);

      expect(find.text('+1 '), findsOneWidget);
    });

    testWidgets('phone field has max 10 character limit', (tester) async {
      await pumpLogin(tester);

      final textField = find.byType(TextField);
      await tester.enterText(textField, '55512345678901');
      await tester.pump();

      final controller = tester.widget<TextField>(textField).controller!;
      final rawDigits = controller.text.replaceAll(RegExp(r'[^\d]'), '');
      expect(rawDigits.length, lessThanOrEqualTo(10),
          reason:
              'Formatter must cap input at 10 raw digits regardless of formatting');
    });
  });
}
