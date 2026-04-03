import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:earth_nova/models/affix.dart';
import 'package:earth_nova/models/animal_size.dart';
import 'package:earth_nova/shared/constants.dart';

/// Deterministic species stat derivation and per-instance rolling.
///
/// Pure functions — no state, no dependencies. **Fully portable**: uses only
/// SHA-256 (no `dart:math Random`), so identical inputs produce identical
/// outputs on every Dart runtime (VM, dart2js, dart2wasm) and any server
/// language.
///
/// ## Base Stats
/// SHA-256 of [scientificName] → 2-byte pairs → proportional scaling to
/// sum exactly [kStatBaseSum] (90). Each stat ≥ [kStatMin] (1).
///
/// ## Rolled Stats (per-instance)
/// SHA-256 of `"$scientificName:$instanceSeed"` → bytes mapped to delta
/// in \[-kStatVariance, +kStatVariance\] (±30) → `clamp(base + delta, 1, 100)`.
/// The ±30 absolute variance is what allows instance stats to reach 100.
///
/// ## Variance at extremes
/// Species with base stats near 1 or near [kStatBaseSum] have compressed
/// instance variance due to clamping. This is intentional — base stats
/// reflect the species' nature (e.g. a tortoise's speed stays low).
///
/// ## Intrinsic Affix
/// Stored as `Affix(id: 'base_stats', type: AffixType.intrinsic, values: {...})`.
/// Always exactly one per instance, separate from the rarity-gated prefix/suffix
/// budget.
class StatsService {
  const StatsService();

  /// Derive deterministic base stats from a species' scientific name.
  ///
  /// The three stats (speed, brawn, wit) always sum to exactly [kStatBaseSum]
  /// (90), with each stat ≥ [kStatMin] (1). Same scientific name always
  /// produces the same stats. No randomness.
  ///
  /// Algorithm: 3 raw 16-bit hash values → reserve 1 per stat → distribute
  /// remaining budget proportionally → round via largest-remainder method
  /// to guarantee exact sum.
  ({int speed, int brawn, int wit}) deriveBaseStats(String scientificName) {
    final hash = sha256.convert(utf8.encode(scientificName)).bytes;

    // Raw 16-bit values (1–65536 range, never zero).
    final rawSpeed = _raw16(hash[0], hash[1]);
    final rawBrawn = _raw16(hash[2], hash[3]);
    final rawWit = _raw16(hash[4], hash[5]);
    final rawSum = rawSpeed + rawBrawn + rawWit;

    // Reserve kStatMin (1) per stat, distribute the rest proportionally.
    const reserve = kStatMin * 3; // 3
    const budget = kStatBaseSum - reserve; // 87

    // Exact fractional shares.
    final shareSpeed = rawSpeed / rawSum * budget;
    final shareBrawn = rawBrawn / rawSum * budget;
    final shareWit = rawWit / rawSum * budget;

    // Floor each, then distribute remainder to largest fractional parts.
    var floorSpeed = shareSpeed.floor();
    var floorBrawn = shareBrawn.floor();
    var floorWit = shareWit.floor();
    var remainder = budget - (floorSpeed + floorBrawn + floorWit);

    // Sort by descending fractional part to allocate remainder fairly.
    final fractions = [
      (0, shareSpeed - floorSpeed),
      (1, shareBrawn - floorBrawn),
      (2, shareWit - floorWit),
    ]..sort((a, b) => b.$2.compareTo(a.$2));

    final floors = [floorSpeed, floorBrawn, floorWit];
    for (final (index, _) in fractions) {
      if (remainder <= 0) break;
      floors[index]++;
      remainder--;
    }

    return (
      speed: floors[0] + kStatMin,
      brawn: floors[1] + kStatMin,
      wit: floors[2] + kStatMin,
    );
  }

  /// Roll per-instance stats with ±[kStatVariance] (30) absolute variance
  /// from base, clamped to [kStatMin]–[kStatMax] (1–100).
  ///
  /// [scientificName] determines the fallback base stats (hash-derived).
  /// [instanceSeed] provides per-instance randomness (e.g. UUID or cell+timestamp).
  /// Both values are required for server-side re-derivation.
  ///
  /// When [enrichedBaseStats] is provided (from AI enrichment), those values
  /// are used as the base instead of the hash-derived stats. This produces
  /// biologically accurate results (e.g. cheetah = fast, elephant = strong).
  ///
  /// Uses only SHA-256 bytes (no `dart:math Random`) for cross-platform
  /// determinism.
  Affix rollIntrinsicAffix({
    required String scientificName,
    required String instanceSeed,
    ({int speed, int brawn, int wit})? enrichedBaseStats,
  }) {
    final base = enrichedBaseStats ?? deriveBaseStats(scientificName);

    final seedHash =
        sha256.convert(utf8.encode('$scientificName:$instanceSeed')).bytes;

    return Affix(
      id: kIntrinsicAffixId,
      type: AffixType.intrinsic,
      values: {
        'speed': _rollStat(base.speed, seedHash[0]),
        'brawn': _rollStat(base.brawn, seedHash[1]),
        'wit': _rollStat(base.wit, seedHash[2]),
      },
    );
  }

  /// Roll a deterministic weight in grams for an item instance.
  ///
  /// Uses SHA-256 of [instanceSeed] (typically the instance UUID) to produce
  /// a uniform random integer in \[[size.minGrams], [size.maxGrams]\].
  ///
  /// Each instance gets a unique weight because each has a unique UUID.
  /// The roll is fully deterministic and server-re-derivable.
  int rollWeightGrams({
    required AnimalSize size,
    required String instanceSeed,
  }) {
    final hash =
        sha256.convert(utf8.encode('$kWeightSeedPrefix$instanceSeed')).bytes;

    // Use first 4 bytes as a big-endian unsigned 32-bit integer.
    final raw = BigInt.from(hash[0]) << 24 |
        BigInt.from(hash[1]) << 16 |
        BigInt.from(hash[2]) << 8 |
        BigInt.from(hash[3]);

    return (raw % BigInt.from(size.rangeSpan) + BigInt.from(size.minGrams))
        .toInt();
  }

  /// Convert 2 hash bytes to a raw positive value (1–65536, never zero).
  static int _raw16(int byte0, int byte1) => ((byte0 << 8) | byte1) + 1;

  /// Apply ±[kStatVariance] absolute variance to [baseStat] using a hash byte.
  ///
  /// Maps byte ∈ [0, 255] to delta ∈ [-kStatVariance, +kStatVariance],
  /// then clamps result to [kStatMin, kStatMax].
  static int _rollStat(int baseStat, int varianceByte) {
    final delta =
        (varianceByte / 255.0 * 2.0 * kStatVariance - kStatVariance).round();
    return (baseStat + delta).clamp(kStatMin, kStatMax);
  }
}
