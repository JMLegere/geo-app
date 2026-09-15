import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova_widgetbook/support/browser_visual_manifest.dart';

const _artifactDirectory = 'artifacts/widgetbook/actual';
const _updateBrowserGolden = bool.fromEnvironment('UPDATE_BROWSER_GOLDEN');
const _browserEnvironment = String.fromEnvironment('BROWSER_GOLDEN_ENV');
const _expectedUserAgent = String.fromEnvironment('BROWSER_GOLDEN_USER_AGENT');

void main() {
  for (final capture in browserVisualCaptures) {
    test('WebDriver capture matches ${capture.name}', () async {
      if (autoUpdateGoldenFiles && !_updateBrowserGolden) {
        fail(
          'Unsupported browser golden update mode: --update-goldens never '
          'updates WebDriver MapLibre baselines. Use '
          '--dart-define=UPDATE_BROWSER_GOLDEN=true after deliberately '
          'capturing ${capture.name}.',
        );
      }

      expect(
        _browserEnvironment,
        isNotEmpty,
        reason:
            'Browser golden environment is unspecified. Pass '
            '--dart-define=BROWSER_GOLDEN_ENV=<pinned-webdriver-environment>.',
      );

      final png = File('$_artifactDirectory/${capture.name}.png');
      expect(
        png.existsSync(),
        isTrue,
        reason:
            'Missing browser PNG at ${png.path}. Run the WebDriver MapLibre '
            'capture before comparing browser goldens.',
      );
      final bytes = Uint8List.fromList(await png.readAsBytes());
      expect(
        bytes.isNotEmpty,
        isTrue,
        reason: 'Blank browser PNG at ${png.path}.',
      );
      expect(
        _isPng(bytes),
        isTrue,
        reason: 'Browser artifact at ${png.path} is not a WebDriver PNG.',
      );

      final metadata = await _readMetadata(capture);
      expect(
        metadata['environment'],
        _browserEnvironment,
        reason:
            'Browser environment mismatch: captured=${metadata['environment']}; '
            'expected=$_browserEnvironment.',
      );
      if (_expectedUserAgent.isNotEmpty) {
        expect(
          metadata['userAgent'],
          contains(_expectedUserAgent),
          reason:
              'Browser user-agent mismatch: captured=${metadata['userAgent']}; '
              'expected a value containing $_expectedUserAgent.',
        );
      }

      final golden = Uri.parse('goldens/browser/${capture.name}.png');
      if (_updateBrowserGolden) {
        await goldenFileComparator.update(golden, bytes);
        return;
      }

      expect(
        await goldenFileComparator.compare(bytes, golden),
        isTrue,
        reason: 'WebDriver capture differs from $golden.',
      );
    });
  }
}

Future<Map<String, dynamic>> _readMetadata(BrowserVisualCapture capture) async {
  final file = File('$_artifactDirectory/${capture.name}.json');
  expect(
    file.existsSync(),
    isTrue,
    reason:
        'Browser metadata is unavailable at ${file.path}; cannot verify the '
        'WebDriver environment before comparing the golden.',
  );

  final decoded = jsonDecode(await file.readAsString());
  expect(
    decoded,
    isA<Map<String, dynamic>>(),
    reason: 'Browser metadata at ${file.path} is malformed.',
  );
  final metadata = decoded as Map<String, dynamic>;
  expect(
    metadata['route'],
    capture.path,
    reason: 'Browser metadata did not come from ${capture.path}.',
  );
  expect(metadata['viewport'], capture.viewport);
  expect(metadata['viewportWidth'], capture.width);
  expect(metadata['viewportHeight'], capture.height);
  expect(
    metadata['devicePixelRatio'],
    isNotNull,
    reason:
        'Browser metadata is missing devicePixelRatio; environment comparison is unsafe.',
  );
  expect(
    metadata['userAgent'],
    isNotNull,
    reason:
        'Browser metadata is missing userAgent; environment comparison is unsafe.',
  );
  return metadata;
}

bool _isPng(Uint8List bytes) =>
    bytes.length >= 8 &&
    bytes[0] == 0x89 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x4e &&
    bytes[3] == 0x47 &&
    bytes[4] == 0x0d &&
    bytes[5] == 0x0a &&
    bytes[6] == 0x1a &&
    bytes[7] == 0x0a;
