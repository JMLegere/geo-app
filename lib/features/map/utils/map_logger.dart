import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

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

  /// How often to log periodic events (every N calls). Set to 1 for full
  /// verbosity during debugging, higher to reduce noise.
  static int tickLogInterval = 60; // Log every 60th tick (~1/sec at 60fps)
  static int cameraLogInterval = 60; // Log every 60th camera move

  static int _tickCount = 0;
  static int _cameraCount = 0;
  static int _fogUpdateCount = 0;
  static int _locationCount = 0;
  static int _errorCount = 0;

  // -- Rubber-band ticker --

  static void tickFired({
    required double displayLat,
    required double displayLon,
    required double targetLat,
    required double targetLon,
    required double distanceM,
    required bool skipped,
  }) {
    _tickCount++;
    if (_tickCount % tickLogInterval != 0) return;
    final tag = skipped ? 'SKIP' : 'MOVE';
    _log(
      'RUBBER',
      '[$tag] #$_tickCount  dist=${distanceM.toStringAsFixed(1)}m  '
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

  // -- Camera --

  static void cameraMove(double lat, double lon, {double? zoom}) {
    _cameraCount++;
    if (_cameraCount % cameraLogInterval != 0) return;
    final zoomStr = zoom != null ? '  z=${zoom.toStringAsFixed(2)}' : '';
    _log('CAMERA', 'moveCamera #$_cameraCount  → ($lat, $lon)$zoomStr');
  }

  static void zoomChanged(double oldZoom, double newZoom, String reason) {
    _log('CAMERA', '🔍 ZOOM $reason: ${oldZoom.toStringAsFixed(2)} → ${newZoom.toStringAsFixed(2)}');
  }

  static void cameraMoveError(double lat, double lon, Object error, StackTrace stack) {
    _errorCount++;
    _log(
      'CAMERA',
      '❌ ERROR #$_errorCount on moveCamera($lat, $lon): $error',
      isError: true,
    );
    _log('CAMERA', 'Stack: $stack', isError: true);
  }

  // -- Fog sources --

  static void fogUpdateStarted() {
    _fogUpdateCount++;
    if (_fogUpdateCount % 10 != 0 && _fogUpdateCount > 1) return;
    _log('FOG', 'updateFogSources #$_fogUpdateCount started');
  }

  static void fogUpdateCompleted() {
    if (_fogUpdateCount % 10 != 0 && _fogUpdateCount > 1) return;
    _log('FOG', 'updateFogSources #$_fogUpdateCount completed');
  }

  static void fogUpdateError(Object error, StackTrace stack) {
    _errorCount++;
    _log(
      'FOG',
      '❌ ERROR #$_errorCount on updateFogSources: $error',
      isError: true,
    );
    _log('FOG', 'Stack: $stack', isError: true);
  }

  static void fogLayersInitialized() {
    _log('FOG', 'Fog layers initialized (3 sources + 3 layers added)');
  }

  static void fogLayersInitError(Object error, StackTrace stack) {
    _errorCount++;
    _log(
      'FOG',
      '❌ ERROR #$_errorCount initializing fog layers: $error',
      isError: true,
    );
    _log('FOG', 'Stack: $stack', isError: true);
  }

  // -- Location --

  static void locationUpdate(double lat, double lon, {required String source}) {
    _locationCount++;
    if (_locationCount % 5 != 0 && _locationCount > 1) return;
    _log('LOC', '#$_locationCount from $source → ($lat, $lon)');
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

  static int _displayUpdateCount = 0;

  static void displayPositionUpdate(double lat, double lon) {
    _displayUpdateCount++;
    if (_displayUpdateCount % 60 != 0) return;
    _log(
      'DISPLAY',
      '#$_displayUpdateCount setState + camera → ($lat, $lon)',
    );
  }

  // -- Map lifecycle --

  static void mapCreated() {
    _log('MAP', 'onMapCreated — controller received');
  }

  static void styleLoaded() {
    _log('MAP', 'onStyleLoaded — initializing fog layers');
  }

  // -- Summary --

  static void printSummary() {
    _log('SUMMARY', 'ticks=$_tickCount  camera=$_cameraCount  '
        'fog=$_fogUpdateCount  loc=$_locationCount  errors=$_errorCount');
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
