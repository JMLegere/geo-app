import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _phaseThreeChromeFiles = <String>[
  'lib/ui/product_surfaces/map/screens/map_screen.dart',
  'lib/ui/product_surfaces/map/screens/city_screen.dart',
  'lib/ui/product_surfaces/map/screens/district_screen.dart',
  'lib/ui/product_surfaces/map/screens/province_screen.dart',
  'lib/ui/product_surfaces/map/screens/country_screen.dart',
  'lib/ui/product_surfaces/map/screens/world_screen.dart',
  'lib/ui/product_surfaces/map/widgets/cell_detail_sheet.dart',
  'lib/ui/product_surfaces/map/widgets/discovery_notification.dart',
  'lib/ui/product_surfaces/map/widgets/hierarchy_header.dart',
  'lib/ui/product_surfaces/map/widgets/map_status_bar.dart',
  'lib/ui/product_surfaces/map/widgets/pinch_hint.dart',
  'lib/ui/product_surfaces/map/widgets/shimmer_cells.dart',
  'lib/ui/product_surfaces/encounters/widgets/pending_encounter_layer.dart',
];

const _neutralCompositionFiles = <String>[
  'lib/ui/product_surfaces/map/screens/map_screen.dart',
  'lib/ui/product_surfaces/map/widgets/cell_detail_sheet.dart',
  'lib/ui/product_surfaces/map/widgets/discovery_notification.dart',
  'lib/ui/product_surfaces/map/widgets/hierarchy_header.dart',
  'lib/ui/product_surfaces/map/widgets/map_status_bar.dart',
  'lib/ui/product_surfaces/map/widgets/pinch_hint.dart',
  'lib/ui/product_surfaces/encounters/widgets/pending_encounter_layer.dart',
];

const _unmigratedRendererSources = <String>[
  'lib/ui/product_surfaces/map/rendering/cell_overlay_painter.dart',
  'lib/ui/product_surfaces/map/rendering/player_marker.dart',
  'lib/ui/product_surfaces/map/rendering/cell_tessellation_render_model.dart',
  'lib/features/living_world/domain/entities/town_projection.dart',
];

void main() {
  group('Phase 3 Map chrome source contract', () {
    test('keeps neutral chrome on the public design barrel', () {
      final legacyChrome = RegExp(
        r'\b(?:AppTheme|DesignTokens|Earth[A-Z]\w*|Carbon[A-Z]\w*)\b|\b(?:rarity|rareness)[A-Za-z0-9_]*(?:Glow|Color|Style)\b|\bglow[A-Za-z0-9_]*\b',
        caseSensitive: false,
      );
      final emoji = RegExp(r'[\u{1F000}-\u{1FAFF}]', unicode: true);

      for (final path in _phaseThreeChromeFiles) {
        final source = File(path).readAsStringSync();
        expect(
          legacyChrome.hasMatch(source) || emoji.hasMatch(source),
          isFalse,
          reason:
              '$path must not restore legacy theme, Earth, rarity-glow, or emoji chrome.',
        );
      }

      for (final path in _neutralCompositionFiles) {
        expect(
          File(path).readAsStringSync(),
          contains("import 'package:earth_nova/ui/design_system.dart';"),
          reason: '$path must use the public design barrel.',
        );
      }
    });

    test('preserves Map interaction anchors and action evidence', () {
      final map = File(_phaseThreeChromeFiles.first).readAsStringSync();
      final cell = File(_phaseThreeChromeFiles[6]).readAsStringSync();
      final header = File(_phaseThreeChromeFiles[8]).readAsStringSync();
      final encounter = File(_phaseThreeChromeFiles.last).readAsStringSync();

      for (final key in const [
        'map-readiness-cover',
        'discovery-paused-status',
        'map-cell-knowledge-legend',
        'cell-knowledge-informed-category-cue',
        'cell-knowledge-present-player-marker',
        'cell-knowledge-present-player-dot',
        'discovery-reward-modal',
      ]) {
        expect(
          map,
          contains("'$key'"),
          reason: 'Map key $key must remain stable.',
        );
      }

      for (final action in const [
        'PlayerActions.inspectMapCell',
        'PlayerActions.continueDiscoveryReward',
      ]) {
        expect(
          map,
          contains(action),
          reason: 'Map action $action must remain stable.',
        );
      }
      for (final evidence in [
        RegExp(r"surface:\s*'map\.cell_overlay'"),
        RegExp(r"transition:\s*'cell_sheet_visible'"),
        RegExp(r"transition:\s*'no_cell_selected'"),
        RegExp(r"actionType:\s*'continue_discovery_reward'"),
      ]) {
        expect(
          evidence.hasMatch(map),
          isTrue,
          reason:
              'Map telemetry evidence ${evidence.pattern} must remain stable.',
        );
      }
      expect(cell, contains('ProductActionSurface('));
      expect(cell, contains('PlayerActions.openNpcVenueDetail'));
      expect(header, contains('PlayerActions.changeTerritoryScale'));
      expect(
        RegExp(r"screenName:\s*'hierarchy_header'").hasMatch(header),
        isTrue,
      );
      expect(encounter, contains("Key('resolve-present-encounter')"));
      expect(encounter, contains('PlayerActions.resolvePresentEncounter'));
      expect(
        RegExp(
          r"surface:\s*'pending_encounter\.resolve_button'",
        ).hasMatch(encounter),
        isTrue,
      );
      expect(
        RegExp(
          r'notifier\.resolve\(\s*option\.id\s*,\s*parent:\s*interaction\.context\s*\)',
        ).hasMatch(encounter),
        isTrue,
      );
      expect(
        RegExp(
          r'notifier\.retryResolution\(\s*parent:\s*interaction\.context\s*\)',
        ).hasMatch(encounter),
        isTrue,
      );
    });

    test('keeps State copy and preserves unmigrated renderer boundaries', () {
      for (final path in _phaseThreeChromeFiles.skip(1).take(5)) {
        final source = File(path).readAsStringSync();
        expect(source, isNot(contains("'Province'")));
        expect(source, isNot(contains('"Province"')));
        expect(source, isNot(contains("'PROVINCE'")));
        expect(source, isNot(contains('"PROVINCE"')));
      }
      expect(
        File(_phaseThreeChromeFiles[3]).readAsStringSync(),
        contains("scopeLevel: 'State'"),
      );

      // Frontier colors now belong to canonical design tokens (#605).
      final fogSource = File(
        'lib/ui/product_surfaces/map/rendering/fog_renderer.dart',
      ).readAsStringSync();
      expect(fogSource, contains('DesignPalette.fogFrontierFill'));
      expect(fogSource, contains('DesignPalette.fogFrontierStroke'));
      for (final path in _unmigratedRendererSources) {
        expect(
          File(path).readAsStringSync(),
          isNot(contains('package:earth_nova/ui/design_system.dart')),
          reason:
              '$path is a Phase 4 renderer/projection boundary, not Phase 3 chrome.',
        );
      }
    });
  });
}
