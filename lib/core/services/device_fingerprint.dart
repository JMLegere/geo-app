// Platform-aware device fingerprint factory.
//
// Uses Dart conditional imports to select the right backend:
// - Native (iOS, Android, desktop): OS + version + hostname
// - Web: navigator.userAgent
//
// Returns the first 12 characters of a SHA-256 hash — stable per device,
// privacy-friendly.
export 'device_fingerprint_native.dart'
    if (dart.library.js_interop) 'device_fingerprint_web.dart';
