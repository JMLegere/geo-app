/// No-op on native — sessionStorage is a web-only API.
void writeTelemetry(String key, String value) {}
String? readTelemetry(String key) => null;
void clearTelemetry(String key) {}
List<String> drainTelemetryList(String key) => const [];
void appendTelemetryList(String key, String entry, {int maxEntries = 50}) {}
