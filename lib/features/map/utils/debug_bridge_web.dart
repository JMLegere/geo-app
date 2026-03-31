import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Exposes `window.__earthNovaDebug` for Playwright E2E tests.
///
/// Methods:
/// - `toggleInfographic()` → toggles district infographic overlay
/// - `isInfographicOpen()` → returns current state (true/false)
class DebugBridge {
  DebugBridge({
    required bool Function() getInfographicState,
    required void Function(bool) setInfographicState,
  })  : _getState = getInfographicState,
        _setState = setInfographicState;

  final bool Function() _getState;
  final void Function(bool) _setState;

  void install() {
    final obj = JSObject();
    obj.setProperty(
      'toggleInfographic'.toJS,
      (() => _setState(!_getState())).toJS,
    );
    obj.setProperty(
      'isInfographicOpen'.toJS,
      (() => _getState().toJS).toJS,
    );
    (web.window as JSObject).setProperty('__earthNovaDebug'.toJS, obj);
  }

  void dispose() {
    (web.window as JSObject).setProperty('__earthNovaDebug'.toJS, null);
  }
}
