import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/models/affix.dart';
import 'package:fog_of_world/core/species/stats_service.dart';
import 'package:fog_of_world/shared/constants.dart';

void main() {
  const service = StatsService();

  // ---------------------------------------------------------------------------
  // deriveBaseStats — determinism
  // ---------------------------------------------------------------------------

  group('StatsService.deriveBaseStats', () {
    test('same scientific name always produces the same stats', () {
      const name = 'Panthera leo';
      final first = service.deriveBaseStats(name);
      for (var i = 0; i < 100; i++) {
        expect(service.deriveBaseStats(name), equals(first),
            reason: 'Iteration $i: base stats differ');
      }
    });

    test('different species produce different base stats (statistically)', () {
      final species = [
        'Panthera leo',
        'Canis lupus',
        'Ailuropoda melanoleuca',
        'Gorilla gorilla',
        'Balaenoptera musculus',
        'Aquila chrysaetos',
        'Crocodylus niloticus',
        'Dermochelys coriacea',
        'Rhincodon typus',
        'Falco peregrinus',
      ];

      final uniqueStats = <String>{};
      for (final name in species) {
        final stats = service.deriveBaseStats(name);
        uniqueStats.add('${stats.speed},${stats.brawn},${stats.wit}');
      }

      // With 10 different species, SHA-256 should produce varied results.
      expect(uniqueStats.length, greaterThan(5),
          reason: 'Expected different species to produce varied base stats');
    });

    test('all base stats are in range 1–100', () {
      // Test with a variety of scientific names.
      final names = [
        'Panthera leo',
        'Canis lupus',
        'Mus musculus',
        'Drosophila melanogaster',
        'Homo sapiens',
        'Escherichia coli',
        'Arabidopsis thaliana',
        'Saccharomyces cerevisiae',
      ];

      for (final name in names) {
        final stats = service.deriveBaseStats(name);
        expect(stats.speed, inInclusiveRange(kStatMin, kStatMax),
            reason: '$name speed out of range');
        expect(stats.brawn, inInclusiveRange(kStatMin, kStatMax),
            reason: '$name brawn out of range');
        expect(stats.wit, inInclusiveRange(kStatMin, kStatMax),
            reason: '$name wit out of range');
      }
    });

    test('empty string produces valid stats', () {
      final stats = service.deriveBaseStats('');
      expect(stats.speed, inInclusiveRange(kStatMin, kStatMax));
      expect(stats.brawn, inInclusiveRange(kStatMin, kStatMax));
      expect(stats.wit, inInclusiveRange(kStatMin, kStatMax));
    });
  });

  // ---------------------------------------------------------------------------
  // rollIntrinsicAffix — determinism
  // ---------------------------------------------------------------------------

  group('StatsService.rollIntrinsicAffix determinism', () {
    test('same inputs always produce the same affix', () {
      const name = 'Panthera leo';
      const seed = 'instance_abc123';

      final first = service.rollIntrinsicAffix(
        scientificName: name,
        instanceSeed: seed,
      );

      for (var i = 0; i < 100; i++) {
        final affix = service.rollIntrinsicAffix(
          scientificName: name,
          instanceSeed: seed,
        );
        expect(affix.values['speed'], equals(first.values['speed']),
            reason: 'Iteration $i: speed differs');
        expect(affix.values['brawn'], equals(first.values['brawn']),
            reason: 'Iteration $i: brawn differs');
        expect(affix.values['wit'], equals(first.values['wit']),
            reason: 'Iteration $i: wit differs');
      }
    });

    test('different instance seeds produce different rolled stats', () {
      const name = 'Panthera leo';
      final uniqueStats = <String>{};

      for (var i = 0; i < 50; i++) {
        final affix = service.rollIntrinsicAffix(
          scientificName: name,
          instanceSeed: 'seed_$i',
        );
        uniqueStats.add(
          '${affix.values['speed']},${affix.values['brawn']},${affix.values['wit']}',
        );
      }

      // 50 different seeds should produce varied results.
      expect(uniqueStats.length, greaterThan(10),
          reason: 'Expected different seeds to produce varied rolled stats');
    });
  });

  // ---------------------------------------------------------------------------
  // rollIntrinsicAffix — shape and type
  // ---------------------------------------------------------------------------

  group('StatsService.rollIntrinsicAffix shape', () {
    test('returns Affix with correct id and type', () {
      final affix = service.rollIntrinsicAffix(
        scientificName: 'Canis lupus',
        instanceSeed: 'test_seed',
      );

      expect(affix.id, equals(kIntrinsicAffixId));
      expect(affix.type, equals(AffixType.intrinsic));
    });

    test('values contain exactly speed, brawn, wit keys', () {
      final affix = service.rollIntrinsicAffix(
        scientificName: 'Canis lupus',
        instanceSeed: 'test_seed',
      );

      expect(affix.values.keys, unorderedEquals(['speed', 'brawn', 'wit']));
    });

    test('all rolled values are integers', () {
      final affix = service.rollIntrinsicAffix(
        scientificName: 'Canis lupus',
        instanceSeed: 'test_seed',
      );

      expect(affix.values['speed'], isA<int>());
      expect(affix.values['brawn'], isA<int>());
      expect(affix.values['wit'], isA<int>());
    });
  });

  // ---------------------------------------------------------------------------
  // rollIntrinsicAffix — variance and clamping
  // ---------------------------------------------------------------------------

  group('StatsService.rollIntrinsicAffix variance', () {
    test('rolled stats are within ±kStatVariance (absolute) of base stats', () {
      const name = 'Panthera leo';
      final base = service.deriveBaseStats(name);

      // Roll many instances and check all are within bounds.
      for (var i = 0; i < 200; i++) {
        final affix = service.rollIntrinsicAffix(
          scientificName: name,
          instanceSeed: 'variance_test_$i',
        );

        final speed = affix.values['speed'] as int;
        final brawn = affix.values['brawn'] as int;
        final wit = affix.values['wit'] as int;

        // After clamping to 1–100, the rolled value should be within the
        // ±kStatVariance (30) absolute window OR at a clamp boundary.
        final speedLow = (base.speed - kStatVariance).clamp(kStatMin, kStatMax);
        final speedHigh =
            (base.speed + kStatVariance).clamp(kStatMin, kStatMax);
        final brawnLow = (base.brawn - kStatVariance).clamp(kStatMin, kStatMax);
        final brawnHigh =
            (base.brawn + kStatVariance).clamp(kStatMin, kStatMax);
        final witLow = (base.wit - kStatVariance).clamp(kStatMin, kStatMax);
        final witHigh = (base.wit + kStatVariance).clamp(kStatMin, kStatMax);

        expect(speed, inInclusiveRange(speedLow, speedHigh),
            reason: 'Seed $i: speed $speed outside [$speedLow, $speedHigh]');
        expect(brawn, inInclusiveRange(brawnLow, brawnHigh),
            reason: 'Seed $i: brawn $brawn outside [$brawnLow, $brawnHigh]');
        expect(wit, inInclusiveRange(witLow, witHigh),
            reason: 'Seed $i: wit $wit outside [$witLow, $witHigh]');
      }
    });

    test('all rolled stats are clamped to 1–100', () {
      // Test with many species to cover edge cases (low and high base stats).
      final species = [
        'Panthera leo',
        'Canis lupus',
        'Mus musculus',
        'Gorilla gorilla',
        'Balaenoptera musculus',
        'Aquila chrysaetos',
        'Falco peregrinus',
        'Rhincodon typus',
      ];

      for (final name in species) {
        for (var i = 0; i < 50; i++) {
          final affix = service.rollIntrinsicAffix(
            scientificName: name,
            instanceSeed: 'clamp_$i',
          );

          expect(affix.values['speed'], inInclusiveRange(kStatMin, kStatMax),
              reason: '$name seed $i: speed out of range');
          expect(affix.values['brawn'], inInclusiveRange(kStatMin, kStatMax),
              reason: '$name seed $i: brawn out of range');
          expect(affix.values['wit'], inInclusiveRange(kStatMin, kStatMax),
              reason: '$name seed $i: wit out of range');
        }
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Affix serialization round-trip
  // ---------------------------------------------------------------------------

  group('StatsService intrinsic affix serialization', () {
    test('intrinsic affix survives JSON round-trip', () {
      final affix = service.rollIntrinsicAffix(
        scientificName: 'Panthera leo',
        instanceSeed: 'serialize_test',
      );

      final json = affix.toJson();
      final restored = Affix.fromJson(json);

      expect(restored.id, equals(affix.id));
      expect(restored.type, equals(AffixType.intrinsic));
      expect(restored.values['speed'], equals(affix.values['speed']));
      expect(restored.values['brawn'], equals(affix.values['brawn']));
      expect(restored.values['wit'], equals(affix.values['wit']));
    });

    test('AffixType.intrinsic round-trips through fromString', () {
      expect(
        AffixType.fromString('intrinsic'),
        equals(AffixType.intrinsic),
      );
      expect(AffixType.intrinsic.name, equals('intrinsic'));
    });
  });

  // ---------------------------------------------------------------------------
  // Regression pin — catches accidental algorithm changes
  // ---------------------------------------------------------------------------

  group('StatsService regression pins', () {
    test('known input produces known output (algorithm anchor)', () {
      // If this test breaks, the hash algorithm or byte offsets changed.
      // That is a breaking change — all existing item stats in the wild
      // would become inconsistent with server re-derivation.
      //
      // Base stats sum to exactly kStatBaseSum (90) via largest-remainder
      // rounding. Rolled stats use ±kStatVariance (30) absolute variance.
      final base = service.deriveBaseStats('Panthera leo');
      expect(base.speed, equals(43));
      expect(base.brawn, equals(16));
      expect(base.wit, equals(31));

      final affix = service.rollIntrinsicAffix(
        scientificName: 'Panthera leo',
        instanceSeed: 'test-uuid-001',
      );
      expect(affix.values['speed'], equals(37));
      expect(affix.values['brawn'], equals(10));
      expect(affix.values['wit'], equals(3));
    });

    test('empty instanceSeed produces valid stats', () {
      final affix = service.rollIntrinsicAffix(
        scientificName: 'Panthera leo',
        instanceSeed: '',
      );

      expect(affix.values['speed'], inInclusiveRange(kStatMin, kStatMax));
      expect(affix.values['brawn'], inInclusiveRange(kStatMin, kStatMax));
      expect(affix.values['wit'], inInclusiveRange(kStatMin, kStatMax));
      expect(affix.id, equals(kIntrinsicAffixId));
      expect(affix.type, equals(AffixType.intrinsic));
    });
  });
}
