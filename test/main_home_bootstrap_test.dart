import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bootstrap wires Home repository observability and preview fallback',
      () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(
      source,
      contains(
          "import 'package:earth_nova/features/home/data/repositories/supabase_home_repository.dart';"),
    );
    expect(
      RegExp(
        r'SupabaseHomeRepository\.fromSupabase\s*\(\s*supabaseClient\s*,\s*logEvent:\s*obs\.log\s*,?\s*\)',
      ).hasMatch(source),
      isTrue,
      reason:
          'Bootstrap must construct the Supabase Home repository with observability.',
    );
    expect(source, contains('const _PreviewHomeRepository()'));
    expect(
      source,
      contains('homeRepositoryProvider.overrideWithValue(homeRepository)'),
    );
    expect(
      source,
      contains('homeObservabilityProvider.overrideWithValue(obs)'),
    );
    expect(source, contains('Future<Home> readHome('));
    expect(source, isNot(contains('createHome')));
    expect(source, isNot(contains('updateHome')));
  });

  test('root app invalidates Home state when auth signs out', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('ref.listen<app_auth.AuthState>(authProvider'));
    expect(source,
        contains('previous?.status == app_auth.AuthStatus.authenticated'));
    expect(
        source, contains('next.status != app_auth.AuthStatus.authenticated'));
    expect(source, contains('homeProvider.notifier).invalidate()'));
  });
}
