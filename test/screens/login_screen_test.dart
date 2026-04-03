import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/data/sync/mock_auth_service.dart';

import 'package:earth_nova/providers/auth_provider.dart';
import 'package:earth_nova/screens/login_screen.dart';

void main() {
  group('LoginScreen', () {
    testWidgets('renders brand text', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );
      expect(find.text('EarthNova'), findsOneWidget);
      expect(find.text('Explore. Discover. Reveal.'), findsOneWidget);
    });

    testWidgets('renders phone input with +1 prefix', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );
      expect(find.text('+1'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Continue button disabled with empty input', (tester) async {
      final mockService = MockAuthService();
      await tester.pumpWidget(ProviderScope(
        overrides: [authServiceProvider.overrideWith((ref) => mockService)],
        child: const MaterialApp(home: LoginScreen()),
      ));
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
      mockService.dispose();
    });

    testWidgets('Continue button enabled after entering 10 digits',
        (tester) async {
      final mockService = MockAuthService();
      await tester.pumpWidget(ProviderScope(
        overrides: [authServiceProvider.overrideWith((ref) => mockService)],
        child: const MaterialApp(home: LoginScreen()),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '5551234567');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
      mockService.dispose();
    });

    testWidgets('Continue button disabled with less than 10 digits',
        (tester) async {
      final mockService = MockAuthService();
      await tester.pumpWidget(ProviderScope(
        overrides: [authServiceProvider.overrideWith((ref) => mockService)],
        child: const MaterialApp(home: LoginScreen()),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '555123');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
      mockService.dispose();
    });

    testWidgets('Continue button text shows Continue', (tester) async {
      final mockService = MockAuthService();
      await tester.pumpWidget(ProviderScope(
        overrides: [authServiceProvider.overrideWith((ref) => mockService)],
        child: const MaterialApp(home: LoginScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Continue'), findsOneWidget);
      mockService.dispose();
    });

    // Note: auth error display is tested at the provider level in
    // auth_provider_test.dart (signInWithPhone failure → error state).
  });
}
