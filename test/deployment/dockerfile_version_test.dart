import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('deployment Dockerfile', () {
    test('pins Flutter image to the same version as CI', () {
      final ciFile = File('.github/workflows/ci.yml');
      final dockerfile = File('Dockerfile');

      expect(ciFile.existsSync(), isTrue, reason: 'Expected CI workflow to exist');
      expect(dockerfile.existsSync(), isTrue, reason: 'Expected Dockerfile to exist');

      final ci = ciFile.readAsStringSync();
      final docker = dockerfile.readAsStringSync();

      final versionMatch = RegExp(
        r"flutter-version:\s*'([^']+)'",
      ).firstMatch(ci);

      expect(versionMatch, isNotNull,
          reason: 'CI workflow must declare a Flutter version pin');

      final flutterVersion = versionMatch!.group(1)!;
      final expectedImage = 'FROM instrumentisto/flutter:$flutterVersion AS build';

      expect(
        docker,
        contains(expectedImage),
        reason: 'Railway beta must build with the same Flutter version as CI '
            'and local mise tooling. A floating Docker tag can drift to a '
            'different web engine and ship runtime-only regressions.',
      );
    });
  });
}
