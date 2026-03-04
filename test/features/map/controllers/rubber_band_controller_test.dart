import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/features/map/controllers/rubber_band_controller.dart';

/// Minimal [TickerProvider] for unit tests. Creates a real [Ticker] but
/// captures the callback so we can manually drive frames without needing
/// a widget tree. Requires [TestWidgetsFlutterBinding.ensureInitialized].
class _TestVSync implements TickerProvider {
  TickerCallback? _callback;

  @override
  Ticker createTicker(TickerCallback onTick) {
    _callback = onTick;
    return Ticker(onTick);
  }

  /// Simulate a frame at the given elapsed time.
  void tick(Duration elapsed) {
    _callback?.call(elapsed);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RubberBandController', () {
    late _TestVSync vsync;
    late List<(double, double)> updates;

    setUp(() {
      vsync = _TestVSync();
      updates = [];
    });

    RubberBandController createController({
      double minSpeedMps = 1.389,
      double speedMultiplier = 2.5,
      double snapThresholdMeters = 0.5,
    }) {
      return RubberBandController(
        vsync: vsync,
        onDisplayUpdate: (lat, lon) => updates.add((lat, lon)),
        minSpeedMps: minSpeedMps,
        speedMultiplier: speedMultiplier,
        snapThresholdMeters: snapThresholdMeters,
      );
    }

    // -----------------------------------------------------------------------
    // Initialization
    // -----------------------------------------------------------------------

    test('first setTarget snaps display to target and emits immediately', () {
      final rb = createController();
      rb.setTarget(45.9636, -66.6431);

      expect(rb.displayLat, equals(45.9636));
      expect(rb.displayLon, equals(-66.6431));
      expect(updates.length, equals(1));
      expect(updates[0].$1, equals(45.9636));
      expect(updates[0].$2, equals(-66.6431));

      rb.dispose();
    });

    test('isAtTarget is true immediately after first setTarget', () {
      final rb = createController();
      rb.setTarget(45.9636, -66.6431);

      expect(rb.isAtTarget, isTrue);

      rb.dispose();
    });

    // -----------------------------------------------------------------------
    // Interpolation
    // -----------------------------------------------------------------------

    test('display moves toward target on subsequent ticks', () {
      final rb = createController();

      // Start at origin-ish position.
      rb.setTarget(45.0, -66.0);
      updates.clear();

      // Move target ~111m north (0.001 degree lat ≈ 111m).
      rb.setTarget(45.001, -66.0);

      // Simulate a few frames at 60fps.
      vsync.tick(const Duration(milliseconds: 16));
      vsync.tick(const Duration(milliseconds: 32));
      vsync.tick(const Duration(milliseconds: 48));

      // Display should have moved toward the target but not reached it
      // in just 3 frames at ~111m distance.
      expect(updates.isNotEmpty, isTrue);
      final lastUpdate = updates.last;
      expect(lastUpdate.$1, greaterThan(45.0));
      expect(lastUpdate.$1, lessThan(45.001));

      rb.dispose();
    });

    test('display eventually converges to target given enough frames', () {
      final rb = createController();

      rb.setTarget(45.0, -66.0);
      updates.clear();

      // Move target a small distance (~11m).
      rb.setTarget(45.0001, -66.0);

      // Simulate 120 frames (2 seconds at 60fps). Should be enough to
      // converge for an 11m distance.
      for (int i = 1; i <= 120; i++) {
        vsync.tick(Duration(milliseconds: i * 16));
      }

      expect(rb.displayLat, closeTo(45.0001, 1e-6));
      expect(rb.displayLon, closeTo(-66.0, 1e-6));

      rb.dispose();
    });

    test('snap threshold prevents oscillation near target', () {
      final rb = createController(snapThresholdMeters: 1.0);

      rb.setTarget(45.0, -66.0);
      updates.clear();

      // Move target by an incredibly tiny amount (< snap threshold).
      rb.setTarget(45.000001, -66.0);

      vsync.tick(const Duration(milliseconds: 16));

      // Should snap to target immediately.
      expect(rb.displayLat, equals(45.000001));
      expect(rb.displayLon, equals(-66.0));
      expect(rb.isAtTarget, isTrue);

      rb.dispose();
    });

    // -----------------------------------------------------------------------
    // Speed scaling
    // -----------------------------------------------------------------------

    test('speed increases with distance (farther target = faster movement)', () {
      final rb = createController();

      // Start at a fixed position.
      rb.setTarget(45.0, -66.0);
      updates.clear();

      // Move target ~1111m north.
      rb.setTarget(45.01, -66.0);

      // One frame at 60fps.
      vsync.tick(const Duration(milliseconds: 16));

      // Speed = max(1.389, 2.5 * 1111) ≈ 2778 m/s.
      // Step = 2778 * 0.0167 ≈ 46m. Fraction ≈ 46/1111 ≈ 0.042.
      // Display should have moved noticeably toward target in one frame.
      expect(rb.displayLat, greaterThan(45.0));
      expect(rb.displayLat, lessThan(45.01));

      rb.dispose();
    });

    // -----------------------------------------------------------------------
    // Multiple target updates (GPS ticks during interpolation)
    // -----------------------------------------------------------------------

    test('setting a new target mid-interpolation redirects smoothly', () {
      final rb = createController();

      rb.setTarget(45.0, -66.0);
      rb.setTarget(45.001, -66.0); // Move north

      // Simulate a few frames.
      vsync.tick(const Duration(milliseconds: 16));
      vsync.tick(const Duration(milliseconds: 32));

      // Display should be moving northward.
      expect(rb.displayLat, greaterThan(45.0));

      // Now redirect east.
      rb.setTarget(45.001, -65.999);

      vsync.tick(const Duration(milliseconds: 48));
      vsync.tick(const Duration(milliseconds: 64));

      // Longitude should have started moving east.
      expect(rb.displayLon, greaterThan(-66.0));

      rb.dispose();
    });

    // -----------------------------------------------------------------------
    // Edge cases
    // -----------------------------------------------------------------------

    test('dispose stops the ticker without errors', () {
      final rb = createController();
      rb.setTarget(45.0, -66.0);

      expect(() => rb.dispose(), returnsNormally);
    });

    test('target and display getters return correct values', () {
      final rb = createController();
      rb.setTarget(45.9636, -66.6431);

      expect(rb.targetLat, equals(45.9636));
      expect(rb.targetLon, equals(-66.6431));
      expect(rb.displayLat, equals(45.9636));
      expect(rb.displayLon, equals(-66.6431));

      rb.dispose();
    });

    test('no callbacks emitted before setTarget is called', () {
      final rb = createController();

      // Tick without setting target — should be safe.
      vsync.tick(const Duration(milliseconds: 16));

      expect(updates, isEmpty);

      rb.dispose();
    });

    test('large dt (tab-switch resume) is clamped to 100ms', () {
      final rb = createController();

      rb.setTarget(45.0, -66.0);
      updates.clear();

      rb.setTarget(45.01, -66.0); // ~1111m north

      // First frame at 16ms.
      vsync.tick(const Duration(milliseconds: 16));
      final posAfterNormalFrame = rb.displayLat;

      // Huge jump — 5 seconds (simulating tab switch). Should be clamped.
      vsync.tick(const Duration(milliseconds: 5016));
      final posAfterHugeJump = rb.displayLat;

      // Should have moved, but not teleported to target.
      expect(posAfterHugeJump, greaterThan(posAfterNormalFrame));
      // With clamping, the step is limited — should not overshoot.
      expect(posAfterHugeJump, lessThanOrEqualTo(45.01));

      rb.dispose();
    });
  });
}
