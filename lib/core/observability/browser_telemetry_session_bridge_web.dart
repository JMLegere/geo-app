import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('earthnovaSetAppSessionId')
external void _earthnovaSetAppSessionId(String sessionId);

const _appSessionKey = 'earthnova_app_session_id';
const _bootstrapSessionKey = 'earthnova_session_id';

String? readBrowserTelemetrySessionId() {
  final appSession = web.window.sessionStorage.getItem(_appSessionKey);
  if (appSession != null && appSession.isNotEmpty) return appSession;

  final bootstrapSession =
      web.window.sessionStorage.getItem(_bootstrapSessionKey);
  if (bootstrapSession != null && bootstrapSession.isNotEmpty) {
    return bootstrapSession;
  }

  return null;
}

void publishTelemetrySessionToBrowser(String sessionId) {
  if (sessionId.isEmpty) return;
  web.window.sessionStorage.setItem(_appSessionKey, sessionId);
  web.window.sessionStorage.setItem(_bootstrapSessionKey, sessionId);
  _earthnovaSetAppSessionId(sessionId);
}
