import 'package:web/web.dart' as web;

import 'package:earth_nova/ui/design_system.dart';
import 'package:earth_nova/ui/product_surfaces/app/earth_nova_app.dart';
import 'package:earth_nova/ui/product_surfaces/map/rendering/player_marker.dart';
import 'package:earth_nova/ui/product_surfaces/map/screens/map_screen.dart';
import 'package:earth_nova_widgetbook/main.directories.g.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:earth_nova_widgetbook/support/browser_visual_manifest.dart';

const _browserEnvironment = String.fromEnvironment('BROWSER_GOLDEN_ENV');
const _browserViewport = String.fromEnvironment(
  'BROWSER_GOLDEN_VIEWPORT',
  defaultValue: 'wide',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final captures = browserVisualCaptures
      .where((capture) => capture.viewport == _browserViewport)
      .toList();
  if (captures.isEmpty) {
    throw StateError('Unknown browser viewport: $_browserViewport');
  }

  testWidgets(
    'captures all Map states at $_browserViewport',
    (tester) async {
      await tester.pumpWidget(
        TickerMode(
          enabled: false,
          child: Widgetbook.material(
            directories: directories,
            initialRoute: _routeFor(captures.first.path),
          ),
        ),
      );
      await tester.pump();
      for (final capture in captures) {
        expect(
          _browserEnvironment,
          isNotEmpty,
          reason:
              'Browser metadata is unavailable: pass '
              '--dart-define=BROWSER_GOLDEN_ENV='
              '<pinned-webdriver-environment> to the browser target.',
        );
        expect(web.window.innerWidth, capture.width);
        expect(web.window.innerHeight, capture.height);

        await binding.handlePushRoute(_routeFor(capture.path));
        await tester.pump(const Duration(milliseconds: 300));
        _failOnFrameworkErrors(tester, 'startup');

        expect(
          find.byType(MapScreen),
          findsOneWidget,
          reason: 'Widgetbook did not select ${capture.path}.',
        );
        final selectedPath = WidgetbookState.of(
          tester.element(find.byType(MapScreen)),
        ).path;
        expect(selectedPath, capture.path);

        final map = await _waitForMapLibre(
          tester,
          route: capture.path,
          requiresRetainedMarker: capture.requiresRetainedMarker,
        );
        final state = capture.path.split('/').last;
        expect(
          find.byType(LoadingDots),
          state == 'loading' || state == 'refreshing'
              ? findsOneWidget
              : findsNothing,
        );
        expect(
          find.text('Nearby cells could not refresh.'),
          state == 'error' ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(DiscoveryPausedBanner),
          state == 'paused-discovery' || state == 'debug-ring'
              ? findsOneWidget
              : findsNothing,
        );
        expect(
          find.byType(PlayerMarker),
          capture.requiresRetainedMarker ? findsNothing : findsOneWidget,
        );
        expect(
          find.text('© OpenStreetMap contributors © CARTO'),
          capture.requiresRetainedMarker ? findsNothing : findsOneWidget,
        );
        final retainedMarkerLabel = web.document
            .querySelector('.earthnova-player-marker')
            ?.getAttribute('aria-label');
        if (state == 'debug-ring') {
          expect(retainedMarkerLabel, 'Player location trusted');
        } else if (state == 'paused-discovery') {
          expect(retainedMarkerLabel, 'Player location paused');
        }
        await binding.takeScreenshot(capture.name, <String, Object?>{
          'environment': _browserEnvironment,
          'route': selectedPath,
          'viewport': capture.viewport,
          'viewportWidth': web.window.innerWidth,
          'viewportHeight': web.window.innerHeight,
          'devicePixelRatio': web.window.devicePixelRatio,
          'userAgent': web.window.navigator.userAgent,
          'canvasWidth': map.canvas.width,
          'canvasHeight': map.canvas.height,
        });
        await tester.pump(const Duration(milliseconds: 300));
        _failOnFrameworkErrors(tester, 'capture');
      }
      // App-root post-frame web work is not exercised by native goldens.
      for (final state in [
        '00-happy-path',
        '10-restoring-session',
        '20-authentication-error',
        '30-preparing-world',
      ]) {
        final path = 'product-surfaces/app/earthnovaapp/$state';
        await binding.handlePushRoute(_routeFor(path));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(EarthNovaApp), findsOneWidget);
        expect(
          WidgetbookState.of(tester.element(find.byType(EarthNovaApp))).path,
          path,
        );
        await tester.pump(const Duration(milliseconds: 300));
        _failOnFrameworkErrors(tester, 'app root $state');
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

void _failOnFrameworkErrors(WidgetTester tester, String phase) {
  final errors = <Object>[];
  while (true) {
    final error = tester.takeException();
    if (error == null) break;
    errors.add(error);
  }
  if (errors.isNotEmpty) {
    fail('Map visual $phase errors: $errors');
  }
}

Future<_ReadyMap> _waitForMapLibre(
  WidgetTester tester, {
  required String route,
  required bool requiresRetainedMarker,
}) async {
  for (var attempt = 0; attempt != 100; attempt++) {
    final canvas = web.document.querySelector('canvas.maplibregl-canvas');
    final attribution = web.document.querySelector(
      '.maplibregl-ctrl-attrib:not(.maplibregl-attrib-empty)',
    );
    final retainedMarker = web.document.querySelector(
      '.earthnova-player-marker',
    );
    final revealing =
        web.document.body?.textContent?.contains(
          'Revealing map... overlay frame painted',
        ) ??
        false;

    if (canvas is web.HTMLCanvasElement &&
        canvas.width > 0 &&
        canvas.height > 0 &&
        _isNonBlank(canvas) &&
        _isVisibleAttribution(attribution) &&
        (retainedMarker != null || !requiresRetainedMarker) &&
        !revealing) {
      return _ReadyMap(canvas);
    }
    await tester.pump(const Duration(milliseconds: 100));
    if (tester.takeException() case final error?) {
      fail(
        'MapScreen error while waiting for MapLibre at attempt $attempt: $error',
      );
    }
  }

  final canvas = web.document.querySelector('canvas.maplibregl-canvas');
  final attribution = web.document.querySelector(
    '.maplibregl-ctrl-attrib:not(.maplibregl-attrib-empty)',
  );
  final retainedMarker = web.document.querySelector('.earthnova-player-marker');
  fail(
    'MapLibre did not become ready for $route: expected a nonblank canvas '
    'with positive dimensions, visible attribution, and '
    '${requiresRetainedMarker ? 'the retained renderer marker' : 'no retained marker requirement'}; '
    'found canvas=$canvas, attribution=$attribution, '
    'retainedMarker=$retainedMarker.',
  );
}

bool _isNonBlank(web.HTMLCanvasElement canvas) {
  try {
    return canvas.toDataURL().length > 256;
  } catch (_) {
    return false;
  }
}

bool _isVisibleAttribution(web.Element? attribution) {
  if (attribution == null || (attribution.textContent?.trim().isEmpty ?? true))
    return false;
  final bounds = attribution.getBoundingClientRect();
  return bounds.width > 0 && bounds.height > 0;
}

String _routeFor(String path) => Uri(
  path: '/',
  queryParameters: {'path': path, 'preview': 'true'},
).toString();

class _ReadyMap {
  const _ReadyMap(this.canvas);

  final web.HTMLCanvasElement canvas;
}
