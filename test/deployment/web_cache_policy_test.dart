import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unhashed production assets are always revalidated', () {
    final nginx = File('nginx.conf').readAsStringSync();

    expect(nginx, isNot(contains('max-age=31536000, immutable')));
    expect(
      nginx,
      contains('Cache-Control "public, max-age=0, must-revalidate"'),
    );
  });
}
