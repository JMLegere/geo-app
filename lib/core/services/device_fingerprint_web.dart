import 'dart:convert';
import 'dart:js_interop';

import 'package:crypto/crypto.dart';
import 'package:web/web.dart' as web;

/// Device fingerprint for web platforms.
///
/// Hashes the browser user agent into a short stable ID.
String getDeviceFingerprint() {
  final raw = web.window.navigator.userAgent;
  final hash = sha256.convert(utf8.encode(raw)).toString();
  return hash.substring(0, 12);
}
