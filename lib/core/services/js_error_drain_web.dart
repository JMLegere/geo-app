import 'dart:convert';

import 'package:web/web.dart' as web;

const _key = 'earthnova_js_errors';

List<String> drainJsErrors() {
  try {
    final raw = web.window.sessionStorage.getItem(_key);
    if (raw == null || raw.isEmpty) return const [];
    web.window.sessionStorage.removeItem(_key);
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.cast<String>();
  } catch (_) {
    return const [];
  }
}
