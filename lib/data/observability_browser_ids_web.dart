import 'package:web/web.dart' as web;

Future<void> persistBrowserObservabilityIds({
  required String sessionId,
  required String deviceId,
}) async {
  web.window.localStorage.setItem('earthnova_session_id', sessionId);
  web.window.localStorage.setItem('earthnova_device_id', deviceId);
}
