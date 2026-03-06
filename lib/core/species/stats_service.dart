import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:fog_of_world/core/models/affix.dart';
import 'package:fog_of_world/shared/constants.dart';

/// Deterministic species stat derivation and per-instance rolling.
///
/// Pure functions — no state, no dependencies. **Fully portable**: uses only
/// SHA-256 (no `dart:math Random`), so identical inputs produce identical
/// outputs on every Dart runtime (VM, dart2js, dart2wasm) and any server
/// language.
///
/// ## Base Stats
/// SHA-256 of [scientificName] → 2-byte pairs → `% 100 + 1` → deterministic
/// 1–100 per stat (speed, brawn, wit). Using 16-bit values reduces modulo
/// bias to <0.2% (vs 50% with single bytes).
///
/// ## Rolled Stats (per-instance)
/// SHA-256 of `"$scientificName:$instanceSeed"` → bytes mapped to multipliers
/// in \[0.70, 1.30\] → `clamp(base × multiplier, 1, 100)`.
///
/// ## Variance at extremes
/// Species with base stats near 1 or 100 have compressed instance variance
/// due to clamping. This is intentional — base stats reflect the species'
/// nature (e.g. a tortoise's speed stays low regardless of the individual).
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
  /// Uses 2-byte pairs from SHA-256 for near-uniform distribution.
  ({int speed, int brawn, int wit}) deriveBaseStats(String scientificName) {
    final hash = sha256.convert(utf8.encode(scientificName)).bytes;
    return (
      speed: _stat16(hash[0], hash[1]),
      brawn: _stat16(hash[2], hash[3]),
      wit: _stat16(hash[4], hash[5]),
    );
  }

  /// Roll per-instance stats with ±30% variance from base, clamped to 1–100.
  ///
  /// [scientificName] determines the base stats.
  /// [instanceSeed] provides per-instance randomness (e.g. UUID or cell+timestamp).
  /// Both values are required for server-side re-derivation.
  ///
  /// Uses only SHA-256 bytes (no `dart:math Random`) for cross-platform
  /// determinism.
  Affix rollIntrinsicAffix({
    required String scientificName,
    required String instanceSeed,
  }) {
    final base = deriveBaseStats(scientificName);

    // Portable variance: SHA-256 bytes → multiplier in [0.70, 1.30].
    // byte / 255.0 → [0.0, 1.0] → * 0.60 + 0.70 → [0.70, 1.30]
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

  /// Convert 2 hash bytes to a stat value in [kStatMin, kStatMax].
  ///
  /// 16-bit value mod 100 has <0.2% bias (65536 % 100 = 36).
  static int _stat16(int byte0, int byte1) =>
      ((byte0 << 8) | byte1) % kStatRange + kStatMin;

  /// Apply ±[kStatVariance] variance to [baseStat] using a single hash byte.
  ///
  /// Maps byte ∈ [0, 255] to multiplier ∈ [0.70, 1.30], then clamps result
  /// to [kStatMin, kStatMax].
  static int _rollStat(int baseStat, int varianceByte) {
    final multiplier =
        (1.0 - kStatVariance) + (varianceByte / 255.0) * 2.0 * kStatVariance;
    return (baseStat * multiplier).round().clamp(kStatMin, kStatMax);
  }
}
