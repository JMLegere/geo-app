import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('root app logs lifecycle transitions and flushes when backgrounded', () {
    final mainSource = File('lib/main.dart').readAsStringSync();

    expect(mainSource, contains('with WidgetsBindingObserver'));
    expect(mainSource, contains('WidgetsBinding.instance.addObserver(this)'));
    expect(
        mainSource, contains('WidgetsBinding.instance.removeObserver(this)'));
    expect(mainSource, contains("eventName: 'app.lifecycle_changed'"));
    expect(mainSource, contains("eventName: 'app.backgrounded'"));
    expect(mainSource, contains("eventName: 'app.foregrounded'"));
    expect(mainSource, contains("eventName: 'app.warm_start'"));
    expect(mainSource, contains('unawaited(obs.flush())'));
  });
}
