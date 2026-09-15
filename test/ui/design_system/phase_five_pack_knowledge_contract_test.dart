import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _phaseFiveSurfaces = <String, List<String>>{
  'lib/ui/product_surfaces/pack/screens/pack_screen.dart': [
    'itemsProvider',
    'examinePackItem',
    'PlayerActions.inspectPackFind',
    'PlayerActions.openIdentificationService',
  ],
  'lib/ui/product_surfaces/pack/widgets/species_card.dart': [
    'item.isExamined',
    'item.isUnidentified',
    'IucnStatus.fromString',
    'Icons.image_not_supported_outlined',
    'PlayerActions.openIdentificationService',
  ],
  'lib/ui/product_surfaces/identification/screens/identification_service_screen.dart':
      [
        'identificationRepositoryProvider',
        'planItemIdentificationProvider',
        'PlayerActions.identifyUnidentifiedFind',
        'PlayerActions.revealIdentification',
      ],
  'lib/ui/product_surfaces/living_world/screens/town_screen.dart': [
    'townProvider',
    'VenueDetailScreen',
    'PlayerActions.openNpcVenueDetail',
  ],
  'lib/ui/product_surfaces/living_world/screens/venue_detail_screen.dart': [
    'TownVenue',
    'PlayerActions.openTown',
  ],
  'lib/ui/product_surfaces/living_world/widgets/venue_marker.dart': [
    'TownVenue',
    'VenueMarkerDisplayMode',
  ],
  'lib/ui/product_surfaces/home/screens/home_screen.dart': [
    'authProvider',
    'homeProvider',
    'ObservableScreen',
  ],
};
const _nativeDesignBarrelExceptions = {
  'lib/ui/product_surfaces/living_world/widgets/venue_marker.dart',
};

final _legacyImport = RegExp(
  r'''import\s+['"][^'"]*/(?:app_theme|design_tokens|earth[^/]*|tcg[^/]*|[^/]*(?:glow|gradient)[^/]*)\.dart['"]''',
  caseSensitive: false,
);

final _legacySymbol = RegExp(
  r'\b(?:AppTheme|DesignTokens|Earth\w*|TCG\w*|\w*(?:glow|gradient)\w*)\b',
  caseSensitive: false,
);

String _withoutStringsAndComments(String source) => source.replaceAll(
  RegExp(r'''//[^\n]*|/\*[\s\S]*?\*/|'(?:\\.|[^'])*'|"(?:\\.|[^"])*"'''),
  '',
);

void main() {
  group('Phase 5 Pack knowledge source contract', () {
    test('keeps every target on the public neutral design vocabulary', () {
      for (final entry in _phaseFiveSurfaces.entries) {
        final source = File(entry.key).readAsStringSync();
        final missing = entry.value
            .where((identifier) => !source.contains(identifier))
            .toList();

        if (!_nativeDesignBarrelExceptions.contains(entry.key)) {
          expect(
            source,
            contains("import 'package:earth_nova/ui/design_system.dart';"),
            reason: '${entry.key} must use the public design barrel.',
          );
        }
        expect(
          _legacyImport.hasMatch(source),
          isFalse,
          reason: '${entry.key} must not import retired presentation styling.',
        );
        expect(
          _legacySymbol.hasMatch(_withoutStringsAndComments(source)),
          isFalse,
          reason:
              '${entry.key} must not use retired presentation styling symbols.',
        );
        expect(
          source,
          isNot(contains('RouteSettings(')),
          reason: '${entry.key} must not add a named route.',
        );
        expect(
          missing,
          isEmpty,
          reason:
              '${entry.key} must preserve its provider, action, identity, or knowledge boundary.',
        );
      }
    });

    test('keeps Map and Pack as the two-tab shell boundary', () {
      final shell = File(
        'lib/ui/product_surfaces/app/tab_shell.dart',
      ).readAsStringSync();
      final destinations =
          RegExp(
                r"_BottomNavDestination\(\s*label: '([^']+)',\s*actionId: PlayerActions\.([A-Za-z]+)\s*\)",
              )
              .allMatches(shell)
              .map((match) => '${match.group(1)}:${match.group(2)}')
              .toList();

      expect(destinations, ['Map:openMap', 'Pack:openPack']);
      expect(
        RegExp(
          r"const _tabScreenNames\s*=\s*\['map', 'pack'\];",
        ).hasMatch(shell),
        isTrue,
      );
    });

    test('keeps Home identity-only', () {
      final home = File(
        'lib/ui/product_surfaces/home/screens/home_screen.dart',
      ).readAsStringSync();

      expect(home, isNot(contains('Modules')));
      expect(home, isNot(contains('Module')));
    });
  });
}
