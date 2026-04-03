import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Resettable counters for map subsystem logging.
///
/// Call [reset] at session boundaries or in tests to zero all counters.
class MapLoggerStats {
  int tickCount = 0;
  int cameraCount = 0;
  int fogUpdateCount = 0;
  int locationCount = 0;
  int errorCount = 0;
  int displayUpdateCount = 0;
  int iconRegCount = 0;
  int tickLogInterval = 60;
  int cameraLogInterval = 60;
  final initStopwatch = Stopwatch();

  void reset() {
    tickCount = 0;
    cameraCount = 0;
    fogUpdateCount = 0;
    locationCount = 0;
    errorCount = 0;
    displayUpdateCount = 0;
    iconRegCount = 0;
    tickLogInterval = 60;
    cameraLogInterval = 60;
    initStopwatch.reset();
  }
}

/// Centralized logger for the map subsystem.
///
/// Logs to both `debugPrint` (visible in Flutter console / browser DevTools)
/// and `developer.log` (visible in Dart DevTools timeline).
///
/// Each subsystem has a named channel so you can filter in the console:
///   `[RUBBER]`, `[CAMERA]`, `[FOG]`, `[KEY]`, `[LOC]`
///
/// Rate-limited: the ticker fires at 60fps but we only log every N
/// frames to avoid flooding the console. Errors always log immediately.
class MapLogger {
  MapLogger._();

  /// Mutable counters extracted into a resettable object.
  static final stats = MapLoggerStats();

  // -- Rubber-band ticker --

  static void tickFired({
    required double displayLat,
    required double displayLon,
    required double targetLat,
    required double targetLon,
    required double distanceM,
    required bool skipped,
  }) {
    stats.tickCount++;
    if (stats.tickCount % stats.tickLogInterval != 0) return;
    final tag = skipped ? 'SKIP' : 'MOVE';
    _log(
      'RUBBER',
      '[$tag] #${stats.tickCount}  dist=${distanceM.toStringAsFixed(1)}m  '
          'display=(${displayLat.toStringAsFixed(6)}, ${displayLon.toStringAsFixed(6)})  '
          'target=(${targetLat.toStringAsFixed(6)}, ${targetLon.toStringAsFixed(6)})',
    );
  }

  static void tickSnapped() {
    _log('RUBBER', 'SNAP to target (within threshold)');
  }

  static void rubberBandInitialized(double lat, double lon) {
    _log(
      'RUBBER',
      'INIT first target received: ($lat, $lon) — ticker started',
    );
  }

  static void rubberBandPaused(double lat, double lon) {
    _log('RUBBER', 'PAUSED at ($lat, $lon) — ticker stopped');
  }

  static void rubberBandResumed(double lat, double lon, double distM) {
    _log('RUBBER',
        'RESUMED target ($lat, $lon) dist=${distM.toStringAsFixed(1)}m');
  }

  // -- Camera --

  static void cameraModeChanged(String from, String to, String trigger) {
    _log('CAMERA', 'MODE $from → $to ($trigger)');
  }

  static void cameraMove(double lat, double lon, {double? zoom}) {
    stats.cameraCount++;
    if (stats.cameraCount % stats.cameraLogInterval != 0) return;
    final zoomStr = zoom != null ? '  z=${zoom.toStringAsFixed(2)}' : '';
    _log('CAMERA', 'moveCamera #${stats.cameraCount}  → ($lat, $lon)$zoomStr');
  }

  static void zoomChanged(double oldZoom, double newZoom, String reason) {
    _log('CAMERA',
        '🔍 ZOOM $reason: ${oldZoom.toStringAsFixed(2)} → ${newZoom.toStringAsFixed(2)}');
  }

  static void cameraMoveError(
      double lat, double lon, Object error, StackTrace stack) {
    stats.errorCount++;
    _log(
      'CAMERA',
      '❌ ERROR #${stats.errorCount} on moveCamera($lat, $lon): $error',
      isError: true,
    );
    _log('CAMERA', 'Stack: $stack', isError: true);
  }

  // -- Fog sources --

  static void fogUpdateStarted() {
    stats.fogUpdateCount++;
    if (stats.fogUpdateCount % 10 != 0 && stats.fogUpdateCount > 1) return;
    _log('FOG', 'updateFogSources #${stats.fogUpdateCount} started');
  }

  static void fogUpdateCompleted() {
    if (stats.fogUpdateCount % 10 != 0 && stats.fogUpdateCount > 1) return;
    _log('FOG', 'updateFogSources #${stats.fogUpdateCount} completed');
  }

  static void fogUpdateError(Object error, StackTrace stack) {
    stats.errorCount++;
    _log(
      'FOG',
      '❌ ERROR #${stats.errorCount} on updateFogSources: $error',
      isError: true,
    );
    _log('FOG', 'Stack: $stack', isError: true);
  }

  static void fogLayersInitialized() {
    _log('FOG', 'Fog layers initialized (3 sources + 3 layers added)');
  }

  static void fogLayersInitError(Object error, StackTrace stack) {
    stats.errorCount++;
    _log(
      'FOG',
      '❌ ERROR #${stats.errorCount} initializing fog layers: $error',
      isError: true,
    );
    _log('FOG', 'Stack: $stack', isError: true);
  }

  // -- Location --

  static void locationUpdate(double lat, double lon, {required String source}) {
    stats.locationCount++;
    if (stats.locationCount % 5 != 0 && stats.locationCount > 1) return;
    _log('LOC', '#${stats.locationCount} from $source → ($lat, $lon)');
  }

  // -- Key presses --

  static void keyDown(String key) {
    _log('KEY', '↓ $key');
  }

  static void keyUp(String key) {
    _log('KEY', '↑ $key');
  }

  static void dpadStep(String direction) {
    _log('KEY', 'DPad $direction');
  }

  // -- Display position callback --

  static void displayPositionUpdate(double lat, double lon) {
    stats.displayUpdateCount++;
    if (stats.displayUpdateCount % 60 != 0) return;
    _log(
      'DISPLAY',
      '#${stats.displayUpdateCount} setState + camera → ($lat, $lon)',
    );
  }

  // -- Fog initialization timeline --

  /// Call at the very start of the fog init sequence.
  static void fogInitStart() {
    stats.initStopwatch
      ..reset()
      ..start();
    _log('FOG-INIT', 'T+0ms — _initFogAndReveal() started');
  }

  /// Call after _initFogLayers() completes.
  static void fogInitLayersReady() {
    _log('FOG-INIT',
        'T+${stats.initStopwatch.elapsedMilliseconds}ms — _initFogLayers() done (sources+layers added to map)');
  }

  /// Call after fogOverlayController.updateAsync() completes.
  static void fogInitDataComputed() {
    _log('FOG-INIT',
        'T+${stats.initStopwatch.elapsedMilliseconds}ms — updateAsync() done (fog GeoJSON computed)');
  }

  /// Call after _updateFogSources() completes.
  static void fogInitSourcesApplied() {
    _log('FOG-INIT',
        'T+${stats.initStopwatch.elapsedMilliseconds}ms — _updateFogSources() done (GeoJSON pushed to MapLibre)');
  }

  /// Call when markReady + _fogReady = true.
  static void fogInitComplete() {
    stats.initStopwatch.stop();
    _log('FOG-INIT',
        'T+${stats.initStopwatch.elapsedMilliseconds}ms — COMPLETE: markReady() + _fogReady=true → cover fading out');
  }

  /// Call when the cover widget rebuilds (to track when AnimatedOpacity kicks in).
  static void fogCoverBuild({required bool fogReady}) {
    _log('FOG-INIT',
        'Cover widget build: _fogReady=$fogReady (opacity=${fogReady ? '0.0→fading' : '1.0→opaque'})');
  }

  // -- Map lifecycle --

  static void mapCreated() {
    _log('MAP', 'onMapCreated — controller received');
  }

  static void styleLoaded() {
    _log('MAP', 'onStyleLoaded — will call _initFogAndReveal()');
  }

  // -- Crash prevention --

  static void fogInitTimeout(int timeoutMs) {
    stats.errorCount++;
    _log(
      'FOG-INIT',
      '⚠️ TIMEOUT #${stats.errorCount} — _initFogAndReveal() did not complete within ${timeoutMs}ms. '
          'Forcing markReady() + revealMapContainer() to show base map without fog.',
      isError: true,
    );
  }

  static void fogInitFailed(Object error, StackTrace stack) {
    stats.errorCount++;
    _log(
      'FOG-INIT',
      '⚠️ ERROR #${stats.errorCount} — _initFogAndReveal() failed: $error. '
          'Forcing markReady() + revealMapContainer() to show base map without fog.',
      isError: true,
    );
    _log('FOG-INIT', 'Stack: $stack', isError: true);
  }

  static void getCameraError(String callsite, Object error) {
    stats.errorCount++;
    _log(
      'CAMERA',
      '⚠️ getCamera() failed at $callsite: $error — skipping update',
      isError: true,
    );
  }

  static void revealRetry(int attempt) {
    _log('MAP',
        '⚠️ revealMapContainer: querySelector returned null, retry #$attempt');
  }

  static void revealFailed(int attempts) {
    stats.errorCount++;
    _log(
      'MAP',
      '❌ revealMapContainer: failed after $attempts retries — '
          'removing hide stylesheet as fallback',
      isError: true,
    );
  }

  // -- Icon registration --

  static void iconRegistrationStarted(int totalIcons) {
    _log('ICONS', 'Starting registration of $totalIcons icon images');
  }

  static void iconRegistered(String id) {
    stats.iconRegCount++;
    _log('ICONS', '✓ Registered icon image: $id (${stats.iconRegCount} total)');
  }

  static void iconRegistrationFailed(String id, Object error) {
    stats.errorCount++;
    _log('ICONS', '❌ Failed to register icon image "$id": $error',
        isError: true);
  }

  static void iconRegistrationComplete(int succeeded, int failed) {
    _log('ICONS',
        'Icon registration complete: $succeeded succeeded, $failed failed');
  }

  // -- Location nodes --

  static void locationNodesLoaded(int count) {
    _log('MAP', 'Loaded $count location nodes for territory borders');
  }

  static void locationNodesLoadError(Object error) {
    stats.errorCount++;
    _log('MAP', '❌ Failed to load location nodes: $error', isError: true);
  }

  // -- Summary --

  static void printSummary() {
    _log(
        'SUMMARY',
        'ticks=${stats.tickCount}  camera=${stats.cameraCount}  '
            'fog=${stats.fogUpdateCount}  loc=${stats.locationCount}  '
            'icons=${stats.iconRegCount}  errors=${stats.errorCount}');
  }

  // -- Internal --

  static void _log(String channel, String message, {bool isError = false}) {
    final line = '[$channel] $message';
    if (kDebugMode || kIsWeb) {
      // debugPrint rate-limits on mobile but we want to see web console output.
      // ignore: avoid_print
      print(line);
    }
    developer.log(
      message,
      name: 'map.$channel',
      level: isError ? 1000 : 800,
    );
  }
}
