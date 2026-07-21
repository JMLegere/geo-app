/// The only runtime strategies supported while transitioning Encounter entry.
enum EncounterEngineMode { legacy, shadowPlanning, v3Authoritative }

/// Why a requested engine mode was not allowed to become effective.
enum EncounterEngineModeGateReason {
  invalidRequestedMode,
  v3ClientVerifiedWritesNotAuthorized,
}

/// A parsed, fail-closed engine-mode decision.
///
/// `ENCOUNTER_ENGINE_MODE` may request a mode, but production writes require a
/// separate compile-time authorization. Invalid values and unauthorized v3
/// requests deliberately retain shadow planning rather than performing a write.
final class EncounterEngineModeResolution {
  const EncounterEngineModeResolution._({
    required this.requestedMode,
    required this.effectiveMode,
    required this.gateReason,
  });

  /// Reads the two build-time controls without coupling application code to UI.
  factory EncounterEngineModeResolution.fromCompileTimeDefines() =>
      EncounterEngineModeResolution.parse(
        requestedValue: const String.fromEnvironment('ENCOUNTER_ENGINE_MODE'),
        clientVerifiedWriteAuthorized: const bool.fromEnvironment(
          'ENCOUNTER_ENGINE_V3_CLIENT_VERIFIED_WRITES',
        ),
      );

  factory EncounterEngineModeResolution.parse({
    required String? requestedValue,
    required bool clientVerifiedWriteAuthorized,
  }) {
    final requestedMode = switch (requestedValue) {
      null || '' || 'legacy' => EncounterEngineMode.legacy,
      'shadowPlanning' => EncounterEngineMode.shadowPlanning,
      'v3Authoritative' => EncounterEngineMode.v3Authoritative,
      _ => null,
    };

    if (requestedMode == null) {
      return const EncounterEngineModeResolution._(
        requestedMode: null,
        effectiveMode: EncounterEngineMode.shadowPlanning,
        gateReason: EncounterEngineModeGateReason.invalidRequestedMode,
      );
    }
    if (requestedMode == EncounterEngineMode.v3Authoritative &&
        !clientVerifiedWriteAuthorized) {
      return const EncounterEngineModeResolution._(
        requestedMode: EncounterEngineMode.v3Authoritative,
        effectiveMode: EncounterEngineMode.shadowPlanning,
        gateReason:
            EncounterEngineModeGateReason.v3ClientVerifiedWritesNotAuthorized,
      );
    }
    return EncounterEngineModeResolution._(
      requestedMode: requestedMode,
      effectiveMode: requestedMode,
      gateReason: null,
    );
  }

  /// Null only when the raw define was invalid.
  final EncounterEngineMode? requestedMode;
  final EncounterEngineMode effectiveMode;
  final EncounterEngineModeGateReason? gateReason;
}
