// Platform-aware crash log persistence.
//
// On web: synchronously writes crash context to localStorage so it survives
// page refresh even if the async Supabase flush gets cancelled.
// On native: no-op (native apps don't lose memory on crash the same way).
export 'crash_log_persistence_native.dart'
    if (dart.library.js_interop) 'crash_log_persistence_web.dart';
