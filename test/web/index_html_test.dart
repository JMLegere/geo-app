import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('web/index.html', () {
    late String html;
    late String head;

    setUpAll(() {
      final file = File('web/index.html');
      html = file.readAsStringSync();
      // Extract <head>...</head> content
      final headMatch = RegExp(
        r'<head>(.*?)</head>',
        dotAll: true,
      ).firstMatch(html);
      head = headMatch?.group(1) ?? '';
    });

    // -------------------------------------------------------------------------
    // Constraint 1: CanvasKit must acquire WebGL contexts BEFORE MapLibre
    // -------------------------------------------------------------------------

    test('does not contain synchronous maplibre-gl.js script in <head>', () {
      expect(
        head,
        isNot(contains('<script src="maplibre-gl.js">')),
        reason: 'maplibre-gl.js must not be loaded synchronously in <head> — '
            'it causes a WebGL context race with CanvasKit on iOS Safari '
            '(see docs/ios-safari-maplibre.md, Constraint 1)',
      );
    });

    test('retains maplibre-gl.css link in <head>', () {
      expect(
        head,
        contains('maplibre-gl.css'),
        reason: 'CSS link is safe and required for MapLibre rendering',
      );
    });

    // -------------------------------------------------------------------------
    // Constraint 2: maplibregl must exist BEFORE first Flutter frame
    // -------------------------------------------------------------------------

    group('injection sequence (Constraint 2)', () {
      test('injects MapLibre BETWEEN initializeEngine and runApp', () {
        // THE KEY INVARIANT: initializeEngine → inject+await maplibre → runApp.
        // MapLibre must be defined before runApp so the MapLibreMap widget
        // finds window.maplibregl when it builds on the first frame.
        // See docs/ios-safari-maplibre.md — Constraint 2.
        final initEngineIndex = html.indexOf('initializeEngine(engineConfig)');
        // Inline injection inside the loader callback uses variable 's'
        final injectIndex = html.indexOf("s.src = 'maplibre-gl.js'");
        final runAppIndex = html.indexOf('appRunner.runApp()');

        expect(initEngineIndex, isNot(-1),
            reason: 'initializeEngine(engineConfig) must be called');
        expect(injectIndex, isNot(-1),
            reason: "MapLibre script injection (s.src = 'maplibre-gl.js') "
                'must be present inside the loader callback');
        expect(runAppIndex, isNot(-1),
            reason: 'appRunner.runApp() must be called');

        expect(initEngineIndex, lessThan(injectIndex),
            reason: 'initializeEngine must precede MapLibre injection '
                '(CanvasKit acquires WebGL context first)');
        expect(injectIndex, lessThan(runAppIndex),
            reason: 'MapLibre must be injected BEFORE runApp — '
                'MapLibreMap widget builds on first frame and needs maplibregl');
      });

      test('awaits MapLibre load inside the loader callback before runApp', () {
        // The loader callback must await the script onload promise so
        // maplibregl is defined (not just loading) before runApp().
        expect(
          html,
          contains('await new Promise'),
          reason: 'Must await MapLibre load promise before calling runApp()',
        );
        expect(
          html,
          contains('s.onload'),
          reason: 'Script onload handler must resolve the await promise',
        );
      });
      test('preserves Flutter engine config when initializing engine', () {
        expect(
          html,
          contains('var engineConfig = (config && config.config) || {};'),
          reason: 'The custom bootstrap wrapper must preserve Flutter engine '
              'config instead of calling initializeEngine() with no args, or '
              'the web engine can fail before the first frame.',
        );
        expect(
          html,
          contains('initializeEngine(engineConfig)'),
          reason: 'The wrapper should pass the preserved engine config into '
              'initializeEngine(engineConfig).',
        );
      });

      test('logs flutter_bootstrap_complete when MapLibre is ready', () {
        expect(
          html,
          contains("push('js', 'flutter_bootstrap_complete'"),
          reason: 'Must log flutter_bootstrap_complete when MapLibre is ready '
              'before runApp — key diagnostic signal in telemetry_logs',
        );
      });
    });

    // -------------------------------------------------------------------------
    // Constraint 3: Intercept loader before load() is called
    // -------------------------------------------------------------------------

    group('Flutter loader intercept (Constraint 3)', () {
      test('uses Object.defineProperty setter to intercept Flutter loader', () {
        // Direct monkey-patch of window._flutter.loader.load ALWAYS fails:
        // window._flutter does not exist when the inline script runs
        // (flutter_bootstrap.js is async). The defineProperty setter fires
        // when flutter_bootstrap.js assigns the real loader instance.
        // See docs/ios-safari-maplibre.md — Constraint 3.
        expect(
          html,
          contains("Object.defineProperty(window._flutter, 'loader'"),
          reason: 'Must use Object.defineProperty with a setter — '
              'direct monkey-patch silently fails because window._flutter '
              'does not exist when the inline script runs',
        );
      });

      test('uses onEntrypointLoaded callback to control init sequence', () {
        expect(
          html,
          contains('onEntrypointLoaded'),
          reason: 'onEntrypointLoaded callback gives control over the '
              'initializeEngine → inject → runApp sequence',
        );
      });

      test('pre-creates window._flutter before flutter_bootstrap.js runs', () {
        expect(
          html,
          contains('window._flutter = window._flutter || {}'),
          reason: 'window._flutter must be pre-created so that '
              'flutter_bootstrap.js sees it and does not overwrite the '
              'property descriptor',
        );
      });
    });

    // -------------------------------------------------------------------------
    // Observability
    // -------------------------------------------------------------------------

    group('observability events', () {
      test('attaches lifecycle grammar attributes to JS bootstrap telemetry',
          () {
        expect(
          html,
          contains('Object.assign({ msg: msg }, attrs || {})'),
          reason: 'JS bootstrap logs should accept bounded structured attrs.',
        );
        expect(html, contains("push('js', 'bootstrap_started'"));
        expect(html, contains("flow: 'web.bootstrap'"));
        expect(html, contains("phase: 'dependency_ready'"));
        expect(html, contains("phase: 'dependency_failed'"));
      });

      test('logs maplibre_lazy_loaded on successful load', () {
        expect(
          html,
          contains("push('js', 'maplibre_lazy_loaded'"),
          reason: 'Successful MapLibre load must be logged',
        );
      });

      test('logs maplibre_load_failed on script error', () {
        expect(
          html,
          contains("push('js', 'maplibre_load_failed'"),
          reason: 'MapLibre load failure must be logged',
        );
      });

      test('has fallback timeout with diagnostic event', () {
        expect(
          html,
          contains('setTimeout'),
          reason: 'Fallback timeout required if loader callback never fires',
        );
        expect(
          html,
          contains("push('js', 'maplibre_fallback_inject'"),
          reason: 'Fallback must log so we can detect when the '
              'defineProperty path is not working',
        );
      });

      test('uses _mapLibreInjected guard to prevent double injection', () {
        expect(
          html,
          contains('_mapLibreInjected'),
          reason: 'Guard prevents double injection if both loader callback '
              'and fallback fire',
        );
      });

      test('bridges real MapLibre JS idle into Dart readiness', () {
        expect(
          html,
          contains(
              "window.dispatchEvent(new CustomEvent('earthnova.maplibre.idle'"),
          reason: 'The Flutter web plugin does not currently forward MapLibre '
              'GL JS idle to onMapIdle, so the app must bridge the real JS '
              'idle event into Dart before relying on a timer fallback.',
        );
        expect(
          html,
          contains('map.loaded()'),
          reason: 'The bridge should prove the map reports loaded before '
              'clearing the startup gate.',
        );
        expect(
          html,
          contains('map.areTilesLoaded()'),
          reason: 'The bridge should prove viewport tiles are loaded before '
              'clearing the startup gate.',
        );
      });

      test('bridges real MapLibre JS load into Dart style readiness', () {
        expect(
          html,
          contains(
              "window.dispatchEvent(new CustomEvent('earthnova.maplibre.load'"),
          reason:
              'The Flutter web plugin style callback is not reliable enough '
              'to be the only source of truth for style readiness on web, so the '
              'app should bridge the real MapLibre JS load event into Dart.',
        );
        expect(
          html,
          contains("map.on('load'"),
          reason:
              'The bridge should listen to the real MapLibre JS load event.',
        );
      });

      test('logs MapLibre layout samples with bounded size attributes', () {
        expect(
          html,
          contains("push('map', 'web_layout_sample'"),
          reason: 'Web MapLibre layout should be queryable from telemetry '
              'without browser DOM inspection.',
        );
        expect(
          html,
          isNot(contains("push('map', 'map.web_layout_sample'")),
          reason: 'push() prefixes category into event_name; passing an '
              'already-prefixed event would create map.map.web_layout_sample.',
        );
        expect(html, contains('canvas_container_height_px'));
        expect(html, contains('canvas_container_height_after_px'));
        expect(html, contains('platform_view_height_px'));
        expect(html, contains('platform_view_height_after_px'));
        expect(html, contains('layout_normalized'));
        expect(html, contains('layout_normalization_requested_resize'));
        expect(html, contains("map.on('resize'"));
        expect(html, contains("'maplibre_js_resize'"));
        expect(html, contains("flow: 'map.web_layout'"));
        expect(html, contains("phase: 'state_changed'"));
        expect(html, contains("dependency: 'maplibre_layout'"));
        expect(html, contains('map_height_px'));
        expect(html, contains('map_width_px'));

      });
      test('normalizes zero-height platform hosts before logging layout', () {
        expect(
          html,
          contains("mapEl.closest('flt-platform-view')"),
          reason: 'Layout fixes should target the actual platform-view host '
              'for the active MapLibre instance, not a global guess.',
        );
        expect(html, contains("canvasContainer.style.height = mapHeightPx + 'px'"));
        expect(html, contains("platformView.style.display = 'block'"));
        expect(html, contains("platformView.style.position = 'absolute'"));
        expect(html, contains("platformView.style.height = mapHeightPx + 'px'"));
        expect(html, contains('map.resize()'));
      });
    });

    group('MapLibre attribution presentation', () {
      test('forces compact attribution so it cannot crowd the status bar', () {
        expect(
          html,
          contains('earthnova-maplibre-attribution-compact'),
          reason: 'MapLibre attribution must stay available but collapsed; '
              'the expanded attribution pill covers the map status bar on mobile.',
        );
        expect(
          html,
          contains('.maplibregl-ctrl-attrib.maplibregl-compact'),
          reason: 'Override must target MapLibre compact attribution.',
        );
        expect(
          html,
          contains('display: none !important'),
          reason:
              'Attribution text should be hidden until the user taps the info button.',
        );
      });
    });
  });
}
