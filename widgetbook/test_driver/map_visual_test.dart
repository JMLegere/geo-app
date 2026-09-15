import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';
import 'package:earth_nova_widgetbook/support/browser_visual_manifest.dart';

const _artifactDirectory = 'artifacts/widgetbook/actual';

Future<void> main() async {
  final directory = Directory(_artifactDirectory);
  await directory.create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [metadata]) async {
      if (!browserVisualCaptures.any((capture) => capture.name == name)) {
        stderr.writeln('Unexpected WebDriver screenshot "$name".');
        return false;
      }
      if (bytes.isEmpty) {
        stderr.writeln('WebDriver returned a blank PNG for "$name".');
        return false;
      }
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(bytes, flush: true);
      await File('${directory.path}/$name.json').writeAsString(
        jsonEncode(metadata ?? const <String, Object?>{}),
        flush: true,
      );
      return true;
    },
  );
}
