import 'package:earth_nova/features/map/domain/entities/player_marker_state.dart';
import 'package:earth_nova/ui/product_surfaces/map/rendering/player_marker.dart';
import 'package:earth_nova/features/map/presentation/providers/player_marker_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StaticPlayerMarkerNotifier extends PlayerMarkerNotifier {
  _StaticPlayerMarkerNotifier(this.initialState);

  final PlayerMarkerState initialState;

  @override
  PlayerMarkerState build() => initialState;
}

const _trustedState = PlayerMarkerState(
  lat: 45.9636,
  lng: -66.6431,
  isRing: false,
  gapDistance: 0,
);

const _ringState = PlayerMarkerState(
  lat: 45.9636,
  lng: -66.6431,
  isRing: true,
  gapDistance: 120,
);

const _surface = Color(0xFF202020);
const _onSurface = Color(0xFFE0E0E0);
const _onSurfaceVariant = Color(0xFF909090);
const _markerKey = ValueKey('player-marker-under-test');

Widget _markerHarness({
  required PlayerMarkerTrust trust,
  PlayerMarkerState state = _trustedState,
  bool disableAnimations = false,
  ValueListenable<PlayerMarkerTrust>? trustListenable,
}) {
  final marker = trustListenable == null
      ? PlayerMarker(key: _markerKey, trust: trust)
      : ValueListenableBuilder<PlayerMarkerTrust>(
          valueListenable: trustListenable,
          builder: (context, value, _) =>
              PlayerMarker(key: _markerKey, trust: value),
        );
  return ProviderScope(
    overrides: [
      playerMarkerProvider.overrideWith(
        () => _StaticPlayerMarkerNotifier(state),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          surface: _surface,
          onSurface: _onSurface,
          onSurfaceVariant: _onSurfaceVariant,
        ),
      ),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: Center(child: marker)),
      ),
    ),
  );
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  testWidgets('mounts one gameplay marker with trusted semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_markerHarness(trust: PlayerMarkerTrust.trusted));

    expect(find.byKey(_markerKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(_markerKey),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Player location trusted'), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('labels low-confidence and paused visual trust states', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _markerHarness(trust: PlayerMarkerTrust.lowConfidence),
    );
    expect(
      find.bySemanticsLabel('Player location low confidence'),
      findsOneWidget,
    );

    await tester.pumpWidget(_markerHarness(trust: PlayerMarkerTrust.paused));
    expect(find.bySemanticsLabel('Player location paused'), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('retains one center marker in every ring mode', (tester) async {
    for (final configuration
        in <({PlayerMarkerTrust trust, PlayerMarkerState state})>[
          (trust: PlayerMarkerTrust.trusted, state: _ringState),
          (trust: PlayerMarkerTrust.lowConfidence, state: _trustedState),
          (trust: PlayerMarkerTrust.paused, state: _trustedState),
        ]) {
      await tester.pumpWidget(
        _markerHarness(
          trust: configuration.trust,
          state: configuration.state,
          disableAnimations: true,
        ),
      );

      expect(
        playerMarkerShowsRing(configuration.state, configuration.trust),
        isTrue,
      );
      expect(find.byKey(_markerKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(_markerKey),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    }
  });

  test('neutral marker palette remains distinct in grayscale', () {
    for (final color in [_surface, _onSurface, _onSurfaceVariant]) {
      expect(color.r, color.g);
      expect(color.g, color.b);
    }
    expect(_contrastRatio(_onSurface, _surface), greaterThanOrEqualTo(3));
  });

  test('ring palette supports 3:1 contrast across representative basemaps', () {
    for (final substrate in const [
      Color(0xFFE8E8E8),
      Color(0xFF777777),
      Color(0xFF181818),
    ]) {
      final strongestEdgeContrast = [
        _contrastRatio(_surface, substrate),
        _contrastRatio(_onSurfaceVariant, substrate),
      ].reduce((first, second) => first > second ? first : second);
      expect(
        strongestEdgeContrast,
        greaterThanOrEqualTo(3),
        reason: 'One edge of the neutral ring must contrast with $substrate.',
      );
    }
  });

  testWidgets('reduced motion applies a trust-ring transition immediately', (
    tester,
  ) async {
    final trust = ValueNotifier(PlayerMarkerTrust.trusted);
    addTearDown(trust.dispose);
    await tester.pumpWidget(
      _markerHarness(
        trust: PlayerMarkerTrust.trusted,
        trustListenable: trust,
        disableAnimations: true,
      ),
    );

    final before = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byKey(_markerKey),
        matching: find.byType(CustomPaint),
      ),
    );

    trust.value = PlayerMarkerTrust.lowConfidence;
    await tester.pump();

    final after = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byKey(_markerKey),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(after.painter, isNot(same(before.painter)));
    expect(find.byKey(_markerKey), findsOneWidget);
  });
}
