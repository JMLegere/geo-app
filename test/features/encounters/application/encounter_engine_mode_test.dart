import 'package:earth_nova/features/encounters/application/encounter_engine_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EncounterEngineModeResolution', () {
    test('defaults to legacy when the mode define is absent', () {
      final resolution = EncounterEngineModeResolution.parse(
        requestedValue: null,
        clientVerifiedWriteAuthorized: false,
      );

      expect(resolution.requestedMode, EncounterEngineMode.legacy);
      expect(resolution.effectiveMode, EncounterEngineMode.legacy);
      expect(resolution.gateReason, isNull);
    });

    test('keeps an explicitly requested shadow planning mode', () {
      final resolution = EncounterEngineModeResolution.parse(
        requestedValue: 'shadowPlanning',
        clientVerifiedWriteAuthorized: false,
      );

      expect(resolution.requestedMode, EncounterEngineMode.shadowPlanning);
      expect(resolution.effectiveMode, EncounterEngineMode.shadowPlanning);
      expect(resolution.gateReason, isNull);
    });

    test('fails closed to shadow planning for an unauthorized v3 request', () {
      final resolution = EncounterEngineModeResolution.parse(
        requestedValue: 'v3Authoritative',
        clientVerifiedWriteAuthorized: false,
      );

      expect(resolution.requestedMode, EncounterEngineMode.v3Authoritative);
      expect(resolution.effectiveMode, EncounterEngineMode.shadowPlanning);
      expect(
        resolution.gateReason,
        EncounterEngineModeGateReason.v3ClientVerifiedWritesNotAuthorized,
      );
    });

    test(
        'permits v3 only with the explicit client-verified-write authorization',
        () {
      final resolution = EncounterEngineModeResolution.parse(
        requestedValue: 'v3Authoritative',
        clientVerifiedWriteAuthorized: true,
      );

      expect(resolution.requestedMode, EncounterEngineMode.v3Authoritative);
      expect(resolution.effectiveMode, EncounterEngineMode.v3Authoritative);
      expect(resolution.gateReason, isNull);
    });

    test('fails closed to shadow planning for an invalid mode value', () {
      final resolution = EncounterEngineModeResolution.parse(
        requestedValue: 'authoritative',
        clientVerifiedWriteAuthorized: true,
      );

      expect(resolution.requestedMode, isNull);
      expect(resolution.effectiveMode, EncounterEngineMode.shadowPlanning);
      expect(
        resolution.gateReason,
        EncounterEngineModeGateReason.invalidRequestedMode,
      );
    });
  });
}
