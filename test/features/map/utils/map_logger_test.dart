import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/utils/map_logger.dart';

void main() {
  setUp(() {
    MapLogger.stats.reset();
  });

  group('MapLoggerStats', () {
    test('reset zeros all counters', () {
      final s = MapLogger.stats;
      s.tickCount = 10;
      s.cameraCount = 5;
      s.fogUpdateCount = 3;
      s.locationCount = 7;
      s.errorCount = 2;
      s.displayUpdateCount = 4;
      s.iconRegCount = 6;
      s.tickLogInterval = 120;
      s.cameraLogInterval = 90;

      s.reset();

      expect(s.tickCount, 0);
      expect(s.cameraCount, 0);
      expect(s.fogUpdateCount, 0);
      expect(s.locationCount, 0);
      expect(s.errorCount, 0);
      expect(s.displayUpdateCount, 0);
      expect(s.iconRegCount, 0);
      expect(s.tickLogInterval, 60);
      expect(s.cameraLogInterval, 60);
    });

    test('reset resets stopwatch elapsed to zero', () {
      final s = MapLogger.stats;
      // Start and immediately stop so elapsed is measurable but stopwatch is stopped.
      s.initStopwatch.start();
      s.initStopwatch.stop();

      s.reset();

      // Stopwatch.reset() zeroes elapsed time.
      expect(s.initStopwatch.elapsedMicroseconds, 0);
    });
  });

  group('MapLogger rate limiting', () {
    test('tickFired increments tickCount', () {
      for (var i = 0; i < 5; i++) {
        MapLogger.tickFired(
          displayLat: 0.0,
          displayLon: 0.0,
          targetLat: 0.0,
          targetLon: 0.0,
          distanceM: 0.0,
          skipped: false,
        );
      }
      expect(MapLogger.stats.tickCount, 5);
    });

    test('cameraMove increments cameraCount', () {
      MapLogger.cameraMove(0.0, 0.0);
      MapLogger.cameraMove(0.0, 0.0);
      MapLogger.cameraMove(0.0, 0.0);
      expect(MapLogger.stats.cameraCount, 3);
    });

    test('fogUpdateStarted increments fogUpdateCount', () {
      MapLogger.fogUpdateStarted();
      expect(MapLogger.stats.fogUpdateCount, 1);
    });

    test('locationUpdate increments locationCount', () {
      MapLogger.locationUpdate(0.0, 0.0, source: 'test');
      MapLogger.locationUpdate(0.0, 0.0, source: 'test');
      MapLogger.locationUpdate(0.0, 0.0, source: 'test');
      expect(MapLogger.stats.locationCount, 3);
    });

    test('cameraMoveError increments errorCount', () {
      MapLogger.cameraMoveError(
          0.0, 0.0, Exception('test'), StackTrace.current);
      expect(MapLogger.stats.errorCount, 1);
    });

    test('fogUpdateError increments errorCount', () {
      MapLogger.fogUpdateError(Exception('test'), StackTrace.current);
      expect(MapLogger.stats.errorCount, 1);
    });

    test('fogInitTimeout increments errorCount', () {
      MapLogger.fogInitTimeout(5000);
      expect(MapLogger.stats.errorCount, 1);
    });

    test('iconRegistered increments iconRegCount', () {
      MapLogger.iconRegistered('test');
      expect(MapLogger.stats.iconRegCount, 1);
    });

    test('displayPositionUpdate increments displayUpdateCount', () {
      MapLogger.displayPositionUpdate(0.0, 0.0);
      MapLogger.displayPositionUpdate(0.0, 0.0);
      MapLogger.displayPositionUpdate(0.0, 0.0);
      expect(MapLogger.stats.displayUpdateCount, 3);
    });
  });

  group('MapLogger fog init stopwatch', () {
    test('fogInitStart resets and starts stopwatch', () {
      MapLogger.fogInitStart();
      expect(MapLogger.stats.initStopwatch.isRunning, isTrue);
    });

    test('fogInitComplete stops stopwatch', () {
      MapLogger.fogInitStart();
      MapLogger.fogInitComplete();
      expect(MapLogger.stats.initStopwatch.isRunning, isFalse);
    });
  });

  group('MapLogger intervals', () {
    test('tickLogInterval defaults to 60', () {
      expect(MapLogger.stats.tickLogInterval, 60);
    });

    test('cameraLogInterval defaults to 60', () {
      expect(MapLogger.stats.cameraLogInterval, 60);
    });
  });
}
