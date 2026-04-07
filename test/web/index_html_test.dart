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
  });
}
