/// App name and version.
abstract final class AppConstants {
  static const String appName = 'EarthNova';
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'dev',
  );
}
