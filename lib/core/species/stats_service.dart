import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'package:fog_of_world/core/models/affix.dart';
import 'package:fog_of_world/shared/constants.dart';

/// Deterministic species stat derivation and per-instance rolling.
///
/// Pure functions — no state, no dependencies. Server-derivable: given the
/// same scientific name and seed, produces identical results on client and
/// server.
///
/// ## Base Stats
/// SHA-256 of [scientificName] → bytes\[0], bytes\[1], bytes\[2\] → `% 100 + 1`
/// → deterministic 1–100 per stat (speed, brawn, wit).
///
/// ## Rolled Stats (per-instance)
/// Each stat = `clamp(base × random(0.70, 1.30), 1, 100)`.
/// The RNG is seeded deterministically from `"$scientificName:$instanceSeed"`,
/// so server can re-derive the exact same roll.
///
/// ## Intrinsic Affix
/// Stored as `Affix(id: 'base_stats', type: AffixType.intrinsic, values: {...})`.
/// Always exactly one per instance, separate from the rarity-gated prefix/suffix
/// budget.
class StatsService {
  const StatsService();

  /// Derive deterministic base stats (1–100) from a species' scientific name.
  ///
  /// Same scientific name always produces the same stats. No randomness.
  ({int speed, int brawn, int wit}) deriveBaseStats(String scientificName) {
    final hash = sha256.convert(utf8.encode(scientificName)).bytes;
    return (
      speed: hash[0] % kStatRange + kStatMin,
      brawn: hash[1] % kStatRange + kStatMin,
      wit: hash[2] % kStatRange + kStatMin,
    );
  }

  /// Roll per-instance stats with ±30% variance from base, clamped to 1–100.
  ///
  /// [scientificName] determines the base stats.
  /// [instanceSeed] provides per-instance randomness (e.g. UUID or cell+timestamp).
  /// Both values are required for server-side re-derivation.
  Affix rollIntrinsicAffix({
    required String scientificName,
    required String instanceSeed,
  }) {
    final base = deriveBaseStats(scientificName);

    // Deterministic RNG seeded from scientific name + instance seed.
    final seedHash =
        sha256.convert(utf8.encode('$scientificName:$instanceSeed')).bytes;
    final seedInt = ((seedHash[0] << 24) |
            (seedHash[1] << 16) |
            (seedHash[2] << 8) |
            seedHash[3]) &
        0x7FFFFFFF;
    final rng = Random(seedInt);

    return Affix(
      id: kIntrinsicAffixId,
      type: AffixType.intrinsic,
      values: {
        'speed': _rollStat(base.speed, rng),
        'brawn': _rollStat(base.brawn, rng),
        'wit': _rollStat(base.wit, rng),
      },
    );
  }

  /// Apply ±[kStatVariance] variance to [baseStat], clamped to
  /// [kStatMin]–[kStatMax].
  int _rollStat(int baseStat, Random rng) {
    // random(0.70, 1.30) = 1.0 - variance + rng * 2 * variance
    final multiplier =
        (1.0 - kStatVariance) + rng.nextDouble() * 2.0 * kStatVariance;
    return (baseStat * multiplier).round().clamp(kStatMin, kStatMax);
  }
}
