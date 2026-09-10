import 'package:web/web.dart' as web;

const _diagnosticLogsKey = 'earthnova_session_diagnostic_logs';

String? readBrowserDiagnosticLogsJson() {
  return web.window.sessionStorage.getItem(_diagnosticLogsKey);
}
