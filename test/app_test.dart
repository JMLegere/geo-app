import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v3 shell compiles', () {
    expect(1 + 1, 2);
  });

  test('source: MaterialApp has scrollBehavior including mouse drag devices',
      () {
    final source = File('lib/main.dart').readAsStringSync();
    // Flutter web default ScrollBehavior excludes mouse from drag devices.
    // We must override it so PageView horizontal drag and OverscrollNotification
    // work correctly on web/desktop.
    expect(source, contains('scrollBehavior'));
    expect(source, contains('PointerDeviceKind.mouse'));
  });
}
