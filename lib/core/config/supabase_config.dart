class SupabaseConfig {
  static const String projectUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static void validate() {
    if (projectUrl.isEmpty || anonKey.isEmpty) {
      throw Exception(
        'Supabase configuration missing. '
        'Pass --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
  }

  static String get restUrl => '$projectUrl/rest/v1';
  static String get functionsUrl => '$projectUrl/functions/v1';
}
