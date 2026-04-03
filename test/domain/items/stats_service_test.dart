import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/domain/items/stats_service.dart';
import 'package:earth_nova/models/affix.dart';
import 'package:earth_nova/models/animal_size.dart';
import 'package:earth_nova/shared/constants.dart';

void main() {
  const service = StatsService();

  group('StatsService.deriveBaseStats', () {
    test('brawn + wit + speed sums to kStatBaseSum (90)', () {
      final stats = service.deriveBaseStats('Panthera leo');
      expect(stats.brawn + stats.wit + stats.speed, kStatBaseSum);
    });

    test('is deterministic for same scientific name', () {
      final first = service.deriveBaseStats('Vulpes vulpes');
      final second = service.deriveBaseStats('Vulpes vulpes');
      expect(first.brawn, second.brawn);
      expect(first.wit, second.wit);
      expect(first.speed, second.speed);
    });

    test('produces different values for different species', () {
      final fox = service.deriveBaseStats('Vulpes vulpes');
      final lion = service.deriveBaseStats('Panthera leo');
      // Not all three must differ, but at least one should.
      final anyDifference = fox.brawn != lion.brawn ||
          fox.wit != lion.wit ||
          fox.speed != lion.speed;
      expect(anyDifference, isTrue);
    });

    test('each stat is at least kStatMin (1)', () {
      const names = ['Aa', 'Bb', 'Cc', 'Panthera tigris', 'Homo sapiens'];
      for (final name in names) {
        final s = service.deriveBaseStats(name);
        expect(s.brawn, greaterThanOrEqualTo(kStatMin));
        expect(s.wit, greaterThanOrEqualTo(kStatMin));
        expect(s.speed, greaterThanOrEqualTo(kStatMin));
      }
    });

    test('stats sum to exactly 90 for various species names', () {
      const names = [
        'Ailuropoda melanoleuca',
        'Tursiops truncatus',
        'Gorilla gorilla',
        'Loxodonta africana',
        'Acinonyx jubatus',
      ];
      for (final name in names) {
        final s = service.deriveBaseStats(name);
        expect(s.brawn + s.wit + s.speed, kStatBaseSum,
            reason: '$name should sum to $kStatBaseSum');
      }
    });
  });

  group('StatsService.rollIntrinsicAffix', () {
    test('returns an Affix with id kIntrinsicAffixId and intrinsic type', () {
      final affix = service.rollIntrinsicAffix(
        scientificName: 'Vulpes vulpes',
        instanceSeed: 'instance-uuid-1',
      );

      expect(affix.id, kIntrinsicAffixId);
      expect(affix.type, AffixType.intrinsic);
    });

    test('affix values contain speed, brawn, and wit keys', () {
      final affix = service.rollIntrinsicAffix(
        scientificName: 'Vulpes vulpes',
        instanceSeed: 'instance-uuid-1',
      );

      expect(affix.values.containsKey('speed'), isTrue);
      expect(affix.values.containsKey('brawn'), isTrue);
      expect(affix.values.containsKey('wit'), isTrue);
    });

    test('is deterministic for same scientificName + instanceSeed', () {
      final first = service.rollIntrinsicAffix(
        scientificName: 'Panthera leo',
        instanceSeed: 'seed-abc',
      );
      final second = service.rollIntrinsicAffix(
        scientificName: 'Panthera leo',
        instanceSeed: 'seed-abc',
      );

      expect(first.values['speed'], second.values['speed']);
      expect(first.values['brawn'], second.values['brawn']);
      expect(first.values['wit'], second.values['wit']);
    });

    test(
        'rolled stats are within ±kStatVariance of base stats (after clamping)',
        () {
      const name = 'Panthera leo';
      final base = service.deriveBaseStats(name);
      final affix = service.rollIntrinsicAffix(
        scientificName: name,
        instanceSeed: 'test-seed',
      );

      // After clamping to [kStatMin, kStatMax], value must be in
      // [max(kStatMin, base-kStatVariance), min(kStatMax, base+kStatVariance)].
      for (final entry in {
        'speed': base.speed,
        'brawn': base.brawn,
        'wit': base.wit,
      }.entries) {
        final rolledValue = affix.values[entry.key] as int;
        final expectedMin =
            (entry.value - kStatVariance).clamp(kStatMin, kStatMax);
        final expectedMax =
            (entry.value + kStatVariance).clamp(kStatMin, kStatMax);
        expect(rolledValue, greaterThanOrEqualTo(expectedMin),
            reason: '${entry.key} $rolledValue < expectedMin $expectedMin');
        expect(rolledValue, lessThanOrEqualTo(expectedMax),
            reason: '${entry.key} $rolledValue > expectedMax $expectedMax');
      }
    });

    test('uses enrichedBaseStats when provided instead of hash-derived stats',
        () {
      const enriched = (speed: 50, brawn: 20, wit: 20);
      final affix = service.rollIntrinsicAffix(
        scientificName: 'Any species',
        instanceSeed: 'seed',
        enrichedBaseStats: enriched,
      );

      // Rolled value should be near 50/20/20 (within variance), not the
      // hash-derived value.
      final speed = affix.values['speed'] as int;
      expect(speed,
          greaterThanOrEqualTo((50 - kStatVariance).clamp(kStatMin, kStatMax)));
      expect(speed,
          lessThanOrEqualTo((50 + kStatVariance).clamp(kStatMin, kStatMax)));
    });
  });

  group('StatsService.rollWeightGrams', () {
    test('returns value within the size band range', () {
      for (final size in AnimalSize.values) {
        final weight = service.rollWeightGrams(
          size: size,
          instanceSeed: 'test-uuid',
        );
        expect(weight, greaterThanOrEqualTo(size.minGrams),
            reason: '${size.name}: $weight < minGrams');
        expect(weight, lessThanOrEqualTo(size.maxGrams),
            reason: '${size.name}: $weight > maxGrams');
      }
    });

    test('is deterministic for same instanceSeed and size', () {
      final first = service.rollWeightGrams(
        size: AnimalSize.medium,
        instanceSeed: 'uuid-123',
      );
      final second = service.rollWeightGrams(
        size: AnimalSize.medium,
        instanceSeed: 'uuid-123',
      );

      expect(first, equals(second));
    });

    test('produces different weights for different instance seeds', () {
      final weights = <int>{};
      for (var i = 0; i < 10; i++) {
        weights.add(service.rollWeightGrams(
          size: AnimalSize.large,
          instanceSeed: 'uuid-$i',
        ));
      }
      // Very unlikely to get all the same weight across 10 seeds.
      expect(weights.length, greaterThan(1));
    });
  });
}
