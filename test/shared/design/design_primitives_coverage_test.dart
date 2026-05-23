import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('design primitive coverage', () {
    test('designSlug normalizes human labels into stable ids', () {
      expect(designSlug(' Map Cell Detail '), 'map-cell-detail');
      expect(designSlug('Urban / Plains + Forest'), 'urban-plains-forest');
    });

    testWidgets(
        'EarthActionButton covers all tones plus icon and expand variants', (
      tester,
    ) async {
      final widgets = [
        const EarthActionButton(label: 'Primary', onPressed: null),
        const EarthActionButton(
          label: 'Secondary',
          onPressed: null,
          tone: EarthActionTone.secondary,
        ),
        const EarthActionButton(
          label: 'Neutral',
          onPressed: null,
          tone: EarthActionTone.neutral,
          icon: Icons.map,
        ),
        const EarthActionButton(
          label: 'Danger',
          onPressed: null,
          tone: EarthActionTone.danger,
          expand: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Column(children: widgets),
          ),
        ),
      );

      expect(find.byIcon(Icons.map), findsOneWidget);
      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('Secondary'), findsOneWidget);
      expect(find.text('Neutral'), findsOneWidget);
      expect(find.text('Danger'), findsOneWidget);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('EarthTag covers all semantic tones and optional icon',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: Column(
              children: [
                EarthTag(label: 'Neutral'),
                EarthTag(label: 'Accent', tone: EarthTagTone.accent),
                EarthTag(label: 'Success', tone: EarthTagTone.success),
                EarthTag(label: 'Warning', tone: EarthTagTone.warning),
                EarthTag(
                    label: 'Danger',
                    tone: EarthTagTone.danger,
                    icon: Icons.warning_amber_rounded),
              ],
            ),
          ),
        ),
      );

      expect(find.text('NEUTRAL'), findsOneWidget);
      expect(find.text('ACCENT'), findsOneWidget);
      expect(find.text('SUCCESS'), findsOneWidget);
      expect(find.text('WARNING'), findsOneWidget);
      expect(find.text('DANGER'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('EarthNotice covers all semantic tones', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: Column(
              children: [
                EarthNotice(title: 'Info', message: 'Info body'),
                EarthNotice(
                    title: 'Success',
                    message: 'Success body',
                    tone: EarthNoticeTone.success),
                EarthNotice(
                    title: 'Warning',
                    message: 'Warning body',
                    tone: EarthNoticeTone.warning),
                EarthNotice(
                    title: 'Danger',
                    message: 'Danger body',
                    tone: EarthNoticeTone.danger),
              ],
            ),
          ),
        ),
      );

      expect(find.text('INFO'), findsOneWidget);
      expect(find.text('SUCCESS'), findsOneWidget);
      expect(find.text('WARNING'), findsOneWidget);
      expect(find.text('DANGER'), findsOneWidget);
      expect(find.text('Danger body'), findsOneWidget);
    });
  });
}
