import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Supabase edge function dependencies', () {
    test('do not depend on esm.sh CDN imports during deploy bundling', () {
      final functionsDir = Directory('supabase/functions');

      expect(
        functionsDir.existsSync(),
        isTrue,
        reason: 'Expected Supabase functions directory to exist',
      );

      final offenders = <String>[];

      for (final entity in functionsDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.ts')) {
          continue;
        }

        final contents = entity.readAsStringSync();
        if (contents.contains('https://esm.sh/')) {
          offenders.add(entity.path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Supabase deploy bundles functions server-side; esm.sh outages '
            'have broken beta deploys. Use Deno npm: imports instead.',
      );
    });
  });
}
