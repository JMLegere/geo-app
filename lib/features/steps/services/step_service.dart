// Platform-aware step counting service.
//
// Uses Dart conditional imports to select the right backend:
// - Native (iOS, Android): pedometer_2 hardware step counter
// - Web: stub that always returns 0
export 'step_service_native.dart'
    if (dart.library.js_interop) 'step_service_web.dart';
