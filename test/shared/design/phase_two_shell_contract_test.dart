import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migratedSurfaces = <String, List<String>>{
    'lib/features/auth/presentation/screens/login_screen.dart': [
      'AppCard',
      'AppButton',
      'ShadInput',
    ],
    'lib/features/auth/presentation/screens/loading_screen.dart': [
      'AppCard',
      'LoadingDots',
    ],
    'lib/app/readiness/app_readiness_gate.dart': [
      'AppCard',
      'AppButton',
      'AppNotice',
      'ShadProgress',
    ],
    'lib/shared/widgets/tab_shell.dart': [
      'ShadButton.ghost',
      'Semantics(',
      'IndexedStack',
    ],
    'lib/features/profile/presentation/screens/settings_screen.dart': [
      'AppCard',
      'AppFieldRow',
      'AppButton',
      'ShadSwitch',
      'ShadDialog',
    ],
  };

  group('Phase 2 shell source contract', () {
    test('uses only the intended neutral App and Shad compositions', () {
      final legacyStyling = RegExp(
        r'\b(?:AppTheme|DesignTokens|Earth[A-Z]\w*|Carbon[A-Z]\w*)\b|design_tokens|0x[0-9A-Fa-f]{6,8}\b',
      );

      for (final entry in migratedSurfaces.entries) {
        final source = File(entry.key).readAsStringSync();
        final missingControls = [
          for (final control in entry.value)
            if (!source.contains(control)) control,
        ];

        expect(
          missingControls,
          isEmpty,
          reason: '${entry.key} must use its Phase 2 App/Shad composition.',
        );
        expect(
          legacyStyling.hasMatch(source),
          isFalse,
          reason:
              '${entry.key} must not reintroduce AppTheme, design tokens, Earth/Carbon components, or hex styling.',
        );
      }
    });

    test('keeps Map and Pack as the only destinations and Settings separate', () {
      final shell = File(
        'lib/shared/widgets/tab_shell.dart',
      ).readAsStringSync();
      final destinations =
          RegExp(
                r"_BottomNavDestination\(\s*label: '([^']+)',\s*actionId: PlayerActions\.([A-Za-z]+)\s*\)",
              )
              .allMatches(shell)
              .map((match) => '${match.group(1)}:${match.group(2)}')
              .toList(growable: false);

      expect(destinations, ['Map:openMap', 'Pack:openPack']);
      expect(
        RegExp(
          r"const _tabScreenNames\s*=\s*\['map', 'pack'\];",
        ).hasMatch(shell),
        isTrue,
      );
      expect(shell, contains('ShadButton.ghost'));
      expect(shell, contains('selected: selected'));
      expect(
        RegExp(
          r"MaterialPageRoute(?:<void>)?\([\s\S]*?RouteSettings\(name: 'settings'\)[\s\S]*?SettingsScreen\(\)",
        ).hasMatch(shell),
        isTrue,
        reason: 'Settings must remain a separate named Material route.',
      );
    });
  });
}
