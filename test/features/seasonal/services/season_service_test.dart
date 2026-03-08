import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/models/season.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/features/seasonal/models/seasonal_species.dart';
import 'package:earth_nova/features/seasonal/services/season_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

FaunaDefinition _species(String scientificName) => FaunaDefinition(
  id: 'fauna_${scientificName.toLowerCase().replaceAll(' ', '_')}',
  displayName: scientificName,
  scientificName: scientificName,
  taxonomicClass: 'Mammalia',
  continents: [Continent.northAmerica],
  habitats: [Habitat.forest],
  rarity: IucnStatus.leastConcern,
);

/// Returns the first species (out of up to [limit] candidates) whose
/// availability matches [target], or null if none found.
FaunaDefinition? _findSpeciesWithAvailability(
  SeasonService service,
  SeasonAvailability target, {
  String prefix = 'Species',
  int limit = 200,
}) {
  for (var i = 0; i < limit; i++) {
    final s = _species('${prefix}_$i');
    if (service.getAvailability(s) == target) return s;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const service = SeasonService();

  group('SeasonService.getCurrentSeason', () {
    test('June date → summer', () {
      expect(
        service.getCurrentSeason(now: DateTime(2024, 6, 15)),
        equals(Season.summer),
      );
    });

    test('July date → summer', () {
      expect(
        service.getCurrentSeason(now: DateTime(2025, 7, 1)),
        equals(Season.summer),
      );
    });

    test('January date → winter', () {
      expect(
        service.getCurrentSeason(now: DateTime(2024, 1, 15)),
        equals(Season.winter),
      );
    });

    test('December date → winter', () {
      expect(
        service.getCurrentSeason(now: DateTime(2024, 12, 31)),
        equals(Season.winter),
      );
    });

    test('May date → summer (boundary)', () {
      expect(
        service.getCurrentSeason(now: DateTime(2024, 5, 1)),
        equals(Season.summer),
      );
    });

    test('November date → winter (boundary)', () {
      expect(
        service.getCurrentSeason(now: DateTime(2024, 11, 1)),
        equals(Season.winter),
      );
    });
  });

  group('SeasonService.getAvailability', () {
    test('deterministic — same species always gets same availability', () {
      final s = _species('Vulpes vulpes');
      final first = service.getAvailability(s);
      for (var i = 0; i < 10; i++) {
        expect(
          service.getAvailability(s),
          equals(first),
          reason: 'Invocation $i should return the same availability',
        );
      }
    });

    test('returns one of the three SeasonAvailability values', () {
      final s = _species('Canis lupus');
      expect(
        SeasonAvailability.values,
        contains(service.getAvailability(s)),
      );
    });

    test('~80/10/10 distribution across 100 species (±5% tolerance)', () {
      final species = List.generate(100, (i) => _species('Dist_$i'));

      var yearRound = 0;
      var summerOnly = 0;
      var winterOnly = 0;

      for (final s in species) {
        switch (service.getAvailability(s)) {
          case SeasonAvailability.yearRound:
            yearRound++;
          case SeasonAvailability.summerOnly:
            summerOnly++;
          case SeasonAvailability.winterOnly:
            winterOnly++;
        }
      }

      // 80 % year-round → 75-85
      expect(
        yearRound,
        allOf(greaterThanOrEqualTo(75), lessThanOrEqualTo(85)),
        reason: 'Expected ~80 year-round, got $yearRound',
      );
      // 10 % summer-only → 5-15
      expect(
        summerOnly,
        allOf(greaterThanOrEqualTo(5), lessThanOrEqualTo(15)),
        reason: 'Expected ~10 summerOnly, got $summerOnly',
      );
      // 10 % winter-only → 5-15
      expect(
        winterOnly,
        allOf(greaterThanOrEqualTo(5), lessThanOrEqualTo(15)),
        reason: 'Expected ~10 winterOnly, got $winterOnly',
      );
    });
  });

  group('SeasonService.isAvailable', () {
    test('yearRound species is available in summer', () {
      final s = _findSpeciesWithAvailability(
        service,
        SeasonAvailability.yearRound,
        prefix: 'YR',
      );
      expect(s, isNotNull, reason: 'Could not find a yearRound species');
      expect(service.isAvailable(s!, Season.summer), isTrue);
    });

    test('yearRound species is available in winter', () {
      final s = _findSpeciesWithAvailability(
        service,
        SeasonAvailability.yearRound,
        prefix: 'YR2',
      );
      expect(s, isNotNull);
      expect(service.isAvailable(s!, Season.winter), isTrue);
    });

    test('summerOnly species is available in summer', () {
      final s = _findSpeciesWithAvailability(
        service,
        SeasonAvailability.summerOnly,
        prefix: 'SO',
      );
      expect(s, isNotNull, reason: 'Could not find a summerOnly species');
      expect(service.isAvailable(s!, Season.summer), isTrue);
    });

    test('summerOnly species is NOT available in winter', () {
      final s = _findSpeciesWithAvailability(
        service,
        SeasonAvailability.summerOnly,
        prefix: 'SO2',
      );
      expect(s, isNotNull);
      expect(service.isAvailable(s!, Season.winter), isFalse);
    });

    test('winterOnly species is available in winter', () {
      final s = _findSpeciesWithAvailability(
        service,
        SeasonAvailability.winterOnly,
        prefix: 'WO',
      );
      expect(s, isNotNull, reason: 'Could not find a winterOnly species');
      expect(service.isAvailable(s!, Season.winter), isTrue);
    });

    test('winterOnly species is NOT available in summer', () {
      final s = _findSpeciesWithAvailability(
        service,
        SeasonAvailability.winterOnly,
        prefix: 'WO2',
      );
      expect(s, isNotNull);
      expect(service.isAvailable(s!, Season.summer), isFalse);
    });
  });

  group('SeasonService.filterBySeason', () {
    test('returns only species available in summer', () {
      final all = List.generate(50, (i) => _species('FiltSum_$i'));
      final result = service.filterBySeason(all, Season.summer);

      for (final s in result) {
        expect(
          service.isAvailable(s, Season.summer),
          isTrue,
          reason: '${s.id} should be available in summer',
        );
      }
    });

    test('returns only species available in winter', () {
      final all = List.generate(50, (i) => _species('FiltWin_$i'));
      final result = service.filterBySeason(all, Season.winter);

      for (final s in result) {
        expect(
          service.isAvailable(s, Season.winter),
          isTrue,
          reason: '${s.id} should be available in winter',
        );
      }
    });

    test('summerOnly species is excluded from winter filter', () {
      final summerSpecies = _findSpeciesWithAvailability(
        service,
        SeasonAvailability.summerOnly,
        prefix: 'SumEx',
      );
      expect(summerSpecies, isNotNull);

      final result = service.filterBySeason([summerSpecies!], Season.winter);
      expect(result, isEmpty, reason: 'summerOnly must not appear in winter');
    });

    test('winterOnly species is excluded from summer filter', () {
      final winterSpecies = _findSpeciesWithAvailability(
        service,
        SeasonAvailability.winterOnly,
        prefix: 'WinEx',
      );
      expect(winterSpecies, isNotNull);

      final result = service.filterBySeason([winterSpecies!], Season.summer);
      expect(result, isEmpty, reason: 'winterOnly must not appear in summer');
    });

    test('yearRound species survives both season filters', () {
      final yrSpecies = _findSpeciesWithAvailability(
        service,
        SeasonAvailability.yearRound,
        prefix: 'YREx',
      );
      expect(yrSpecies, isNotNull);

      final inSummer = service.filterBySeason([yrSpecies!], Season.summer);
      final inWinter = service.filterBySeason([yrSpecies], Season.winter);

      expect(inSummer, isNotEmpty, reason: 'yearRound must appear in summer');
      expect(inWinter, isNotEmpty, reason: 'yearRound must appear in winter');
    });

    test('empty list returns empty list', () {
      expect(service.filterBySeason([], Season.summer), isEmpty);
      expect(service.filterBySeason([], Season.winter), isEmpty);
    });
  });
}
