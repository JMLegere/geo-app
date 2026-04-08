import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:earth_nova/features/map/domain/repositories/wake_lock_repository.dart';

class WebWakeLockRepository implements WakeLockRepository {
  web.WakeLockSentinel? _sentinel;

  @override
  Future<void> acquire() async {
    _sentinel = await web.window.navigator.wakeLock.request('screen').toDart;
  }

  @override
  Future<void> release() async {
    await _sentinel?.release().toDart;
    _sentinel = null;
  }
}
