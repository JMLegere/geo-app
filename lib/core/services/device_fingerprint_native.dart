import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Device fingerprint for native platforms.
///
/// Hashes OS + OS version + hostname into a short stable ID.
String getDeviceFingerprint() {
  final raw = '${Platform.operatingSystem}'
      '|${Platform.operatingSystemVersion}'
      '|${Platform.localHostname}';
  final hash = sha256.convert(utf8.encode(raw)).toString();
  return hash.substring(0, 12);
}
