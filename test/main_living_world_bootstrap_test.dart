import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bootstrap wires Living World repository observability and fallback',
      () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(
      source,
      contains(
          "import 'package:earth_nova/features/living_world/data/repositories/supabase_living_world_repository.dart';"),
    );
    expect(
      RegExp(
        r'SupabaseLivingWorldRepository\.fromSupabase\s*\(\s*supabaseClient\s*,\s*logEvent:\s*obs\.log\s*,?\s*\)',
      ).hasMatch(source),
      isTrue,
      reason:
          'Bootstrap must construct the Supabase Living World repository with observability.',
    );
    expect(
      RegExp(
        r'livingWorldRepositoryProvider\s*\.\s*overrideWithValue\s*\(\s*livingWorldRepository\s*\)',
      ).hasMatch(source),
      isTrue,
      reason:
          'Bootstrap must override livingWorldRepositoryProvider with the exact repository instance.',
    );
    expect(
      source,
      contains('livingWorldObservabilityProvider.overrideWithValue(obs)'),
    );
    expect(source, contains('const _EmptyLivingWorldRepository()'));
    expect(source, contains('return TownProjection(playerId: playerId);'));
  });
}
