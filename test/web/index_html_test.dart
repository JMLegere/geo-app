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

    test('does not contain synchronous maplibre-gl.js script in <head>', () {
      expect(
        head,
        isNot(contains('<script src="maplibre-gl.js">')),
        reason: 'maplibre-gl.js must not be loaded synchronously in <head> — '
            'it causes a WebGL context race with CanvasKit on iOS Safari',
      );
    });

    test('retains maplibre-gl.css link in <head>', () {
      expect(
        head,
        contains('maplibre-gl.css'),
        reason: 'CSS link is safe and required for MapLibre rendering',
      );
    });

    group('lazy-loading logic', () {
      test('defines _injectMapLibre function', () {
        expect(
          html,
          contains('function _injectMapLibre()'),
          reason: '_injectMapLibre must be defined to dynamically inject '
              'maplibre-gl.js after Flutter bootstrap',
        );
      });

      test('uses _mapLibreInjected guard to prevent double injection', () {
        expect(
          html,
          contains('_mapLibreInjected'),
          reason: 'Guard variable prevents maplibre-gl.js from being injected '
              'more than once (e.g. if both loader callback and fallback fire)',
        );
      });

      test('injects maplibre-gl.js as async script via document.createElement',
          () {
        expect(
          html,
          contains("script.src = 'maplibre-gl.js'"),
          reason: 'MapLibre must be injected dynamically as an async script, '
              'not loaded synchronously',
        );
        expect(
          html,
          contains('script.async = true'),
          reason:
              'Injected script must be async to avoid blocking the main thread',
        );
        expect(
          html,
          contains('document.head.appendChild(script)'),
          reason: 'Script must be appended to document.head',
        );
      });

      test('logs maplibre_lazy_loaded event on successful script load', () {
        expect(
          html,
          contains("push('js', 'maplibre_lazy_loaded'"),
          reason: 'Successful MapLibre load must be logged for observability',
        );
      });

      test('logs maplibre_load_failed event on script error', () {
        expect(
          html,
          contains("push('js', 'maplibre_load_failed'"),
          reason: 'MapLibre load failure must be logged for observability',
        );
      });

      test(
          'uses Object.defineProperty on _flutter.loader to intercept bootstrap',
          () {
        // The correct approach: pre-define a setter on window._flutter.loader so
        // that when flutter_bootstrap.js assigns the real loader instance our
        // setter wraps load() before it is ever called.  A direct monkey-patch of
        // window._flutter.loader.load fails because window._flutter does not exist
        // when the inline script runs (flutter_bootstrap.js loads async).
        expect(
          html,
          contains("Object.defineProperty(window._flutter, 'loader'"),
          reason: 'Must use Object.defineProperty with a setter to intercept '
              'the Flutter loader after flutter_bootstrap.js assigns it',
        );
      });

      test('uses onEntrypointLoaded callback to sequence initialization', () {
        expect(
          html,
          contains('onEntrypointLoaded'),
          reason: 'onEntrypointLoaded callback is required to intercept the '
              'Flutter engine initialization sequence',
        );
      });

      test('calls appRunner.runApp() before injecting MapLibre', () {
        // Find the position of runApp() call
        final runAppIndex = html.indexOf('appRunner.runApp()');
        expect(runAppIndex, isNot(-1),
            reason: 'appRunner.runApp() must be called');

        // Find the _injectMapLibre() call that comes AFTER runApp() (not the
        // function definition which appears earlier in the file)
        final injectAfterRunApp =
            html.indexOf('_injectMapLibre()', runAppIndex);
        expect(
          injectAfterRunApp,
          isNot(-1),
          reason: '_injectMapLibre() must be called after appRunner.runApp() — '
              'this ensures CanvasKit has acquired its WebGL contexts first',
        );
      });

      test(
          'has fallback timeout to inject MapLibre if loader callback never fires',
          () {
        expect(
          html,
          contains('setTimeout'),
          reason: 'Fallback timeout required in case Flutter loader callback '
              'never fires (e.g. edge cases, older Flutter versions)',
        );
        expect(
          html,
          contains("push('js', 'maplibre_fallback_inject'"),
          reason: 'Fallback injection must be logged so we can detect when '
              'the loader callback path is not working',
        );
      });
    });
  });
}
