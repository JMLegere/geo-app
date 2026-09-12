import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only commit-namespaced Flutter assets are immutable', () {
    final nginx = File('nginx.conf').readAsStringSync();

    expect(nginx, contains('location ~ "^/releases/[0-9a-f]{40}/assets/"'));
    expect(
      nginx,
      contains('Cache-Control "public, max-age=31536000, immutable"'),
    );
    expect(nginx, contains('location ~ ^/releases/'));
    expect(
      nginx,
      contains('Cache-Control "public, max-age=0, must-revalidate"'),
    );
  });
}
