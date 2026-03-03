import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fog_of_world/features/auth/widgets/auth_button.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('AuthButton', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        _wrap(const AuthButton(label: 'Sign In', onPressed: null)),
      );

      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator when isLoading', (tester) async {
      await tester.pumpWidget(
        _wrap(const AuthButton(label: 'Sign In', isLoading: true)),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Label is hidden while loading.
      expect(find.text('Sign In'), findsNothing);
    });

    testWidgets('onPressed callback fires on tap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _wrap(AuthButton(label: 'Sign In', onPressed: () => tapped = true)),
      );

      await tester.tap(find.byType(AuthButton));
      expect(tapped, isTrue);
    });

    testWidgets('button is disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(
        _wrap(const AuthButton(label: 'Sign In', onPressed: null)),
      );

      final button =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('button is not tappable when isLoading', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _wrap(AuthButton(
          label: 'Sign In',
          isLoading: true,
          onPressed: () => tapped = true,
        )),
      );

      await tester.tap(find.byType(AuthButton));
      expect(tapped, isFalse);
    });
  });
}
