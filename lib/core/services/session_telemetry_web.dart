import 'dart:convert';
import 'package:web/web.dart' as web;

void writeTelemetry(String key, String value) {
  try {
    web.window.sessionStorage.setItem(key, value);
  } catch (_) {}
}

String? readTelemetry(String key) {
  try {
    return web.window.sessionStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

void clearTelemetry(String key) {
  try {
    web.window.sessionStorage.removeItem(key);
  } catch (_) {}
}

List<String> drainTelemetryList(String key) {
  try {
    final raw = web.window.sessionStorage.getItem(key);
    if (raw == null || raw.isEmpty) return const [];
    web.window.sessionStorage.removeItem(key);
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.cast<String>();
  } catch (_) {
    return const [];
  }
}

void appendTelemetryList(String key, String entry, {int maxEntries = 50}) {
  try {
    final raw = web.window.sessionStorage.getItem(key);
    final list = raw != null
        ? (jsonDecode(raw) as List<dynamic>).cast<String>()
        : <String>[];
    list.add(entry);
    if (list.length > maxEntries) list.removeRange(0, list.length - maxEntries);
    web.window.sessionStorage.setItem(key, jsonEncode(list));
  } catch (_) {}
}
