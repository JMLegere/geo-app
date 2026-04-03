import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/data/sync/mock_auth_service.dart';
import 'package:earth_nova/models/user_profile.dart';
import 'package:earth_nova/providers/auth_provider.dart';
import 'package:earth_nova/screens/settings_screen.dart';

void main() {
  group('SettingsScreen', () {
    testWidgets('renders Settings title', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SettingsScreen())),
      );
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('shows user display name when authenticated', (tester) async {
      final mockService = MockAuthService();
      await tester.pumpWidget(ProviderScope(
        overrides: [authServiceProvider.overrideWith((ref) => mockService)],
        child: const MaterialApp(home: SettingsScreen()),
      ));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );
      container.read(authProvider.notifier).setAuthenticated(
            UserProfile(
              id: 'u_1',
              email: 'test@earthnova.app',
              displayName: 'TestExplorer',
              phoneNumber: '+15551234567',
              createdAt: DateTime(2026, 1, 1),
            ),
          );
      await tester.pumpAndSettle();

      expect(find.text('TestExplorer'), findsOneWidget);
      mockService.dispose();
    });

    testWidgets('shows Sign Out button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SettingsScreen())),
      );
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('sign out shows confirmation dialog', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SettingsScreen())),
      );
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });
}
