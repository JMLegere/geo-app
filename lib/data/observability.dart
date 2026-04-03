import 'dart:async';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:earth_nova/data/observability_browser_ids.dart';
import 'package:earth_nova/data/observability_buffer.dart';
import 'package:earth_nova/engine/game_event.dart';

typedef DebugPrintFn = void Function(String? message, {int? wrapWidth});

class AppObservability {
  AppObservability._({
    required this.controller,
    required this.sessionId,
    required this.deviceId,
    required this.rawDebugPrint,
    required SupabaseClient? client,
  }) : _client = client;

  static const _deviceIdKey = 'earthnova_device_id';
  static final Uuid _uuid = const Uuid();
  static AppObservability? _instance;

  static AppObservability get instance {
    final instance = _instance;
    if (instance == null) {
      throw StateError('AppObservability has not been initialized');
    }
    return instance;
  }

  static Future<AppObservability> initialize({
    required DebugPrintFn rawDebugPrint,
    required SupabaseClient? client,
    String? userId,
  }) async {
    if (_instance != null) {
      _instance!.setUserId(userId);
      return _instance!;
    }

    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString(_deviceIdKey) ?? _uuid.v4();
    await prefs.setString(_deviceIdKey, deviceId);

    final sessionId = _uuid.v4();
    final buffer = ObservabilityBuffer(
      sessionId: sessionId,
      deviceId: deviceId,
      userId: userId,
    );

    final controller = ObservabilityController(
      buffer: buffer,
      uploader: (rows) async {
        if (client == null || rows.isEmpty) return;
        await client.from('app_logs').insert(rows);
      },
    );

    final instance = AppObservability._(
      controller: controller,
      sessionId: sessionId,
      deviceId: deviceId,
      rawDebugPrint: rawDebugPrint,
      client: client,
    );
    await persistBrowserObservabilityIds(
      sessionId: sessionId,
      deviceId: deviceId,
    );
    instance._flushTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => instance.flush(),
    );
    _instance = instance;
    instance.log('[ENGINE] boot session=$sessionId');
    return instance;
  }

  final ObservabilityController controller;
  final String sessionId;
  final String deviceId;
  final DebugPrintFn rawDebugPrint;
  final SupabaseClient? _client;
  Timer? _flushTimer;

  void setUserId(String? userId) {
    controller.buffer.userId = userId;
  }

  void log(String line) {
    controller.recordLine(line);
  }

  void recordEvent(GameEvent event, {String? line}) {
    controller.recordEvent(event, line: line ?? '[ENGINE] ${event.event}');
  }

  Future<void> flush() async {
    if (_client == null) return;
    try {
      await controller.flush();
    } catch (error, stack) {
      developer.log(
        'observability flush failed: $error',
        name: 'earthnova.observability',
        level: 1000,
        stackTrace: stack,
      );
    }
  }

  Future<void> dispose() async {
    _flushTimer?.cancel();
    await flush();
  }
}
