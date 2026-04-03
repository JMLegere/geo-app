/// Fat structured event envelope emitted by [GameEngine].
///
/// Every game-relevant state change, user action, system event, and
/// performance measurement flows through this type. Downstream consumers
/// (persistence, UI, analytics) subscribe to the single event stream and
/// filter by [category] + [event].
///
/// ## Category taxonomy
///
/// | Category    | Examples                                              |
/// |-------------|-------------------------------------------------------|
/// | state       | cell_visited, species_discovered, fog_changed         |
/// | user        | cell_tapped, app_backgrounded, app_resumed            |
/// | system      | gps_error_changed, exploration_disabled_changed, crash|
/// | performance | frame_budget_exceeded, tick_duration_ms               |
///
/// ## Data convention
///
/// [data] is `Map<String, dynamic>` — values may be primitives OR rich Dart
/// objects (e.g. an `ItemInstance`). Consumers that need JSON serialization
/// (Supabase write queue) must extract and encode at the boundary.
///
/// Use the named factory constructors for all engine-internal emissions.
/// They stamp [timestamp], [category], and required envelope fields so
/// call-sites remain readable.
class GameEvent {
  /// Session-scoped identifier for correlation across events in one run.
  /// Generated when [GameEngine.start] is called.
  final String sessionId;

  /// Authenticated user ID at the time of emission. May be null before
  /// auth resolves or after sign-out.
  final String? userId;

  /// Stable device identifier for multi-device analytics. Optional.
  final String? deviceId;

  /// Wall-clock time at emission (UTC).
  final DateTime timestamp;

  /// Broad grouping: `state` | `user` | `system` | `performance`.
  final String category;

  /// Specific event name within the category (snake_case).
  final String event;

  /// Structured payload. May contain primitive or rich Dart values.
  final Map<String, dynamic> data;

  const GameEvent({
    required this.sessionId,
    this.userId,
    this.deviceId,
    required this.timestamp,
    required this.category,
    required this.event,
    this.data = const {},
  });

  // ---------------------------------------------------------------------------
  // Factory constructors
  // ---------------------------------------------------------------------------

  /// Cell visited for the first time.
  factory GameEvent.cellVisited({
    required String sessionId,
    String? userId,
    String? deviceId,
    required String cellId,
  }) =>
      GameEvent(
        sessionId: sessionId,
        userId: userId,
        deviceId: deviceId,
        timestamp: DateTime.now().toUtc(),
        category: 'state',
        event: 'cell_visited',
        data: {'cell_id': cellId},
      );

  /// Species (or other item) discovered in a cell.
  ///
  /// [instance] is the fully-built `ItemInstance` object. Include it in
  /// [data] so persistence listeners can extract it without re-hydrating
  /// from definitions.
  factory GameEvent.speciesDiscovered({
    required String sessionId,
    String? userId,
    String? deviceId,
    required String cellId,
    required String definitionId,
    required String displayName,
    required String category,
    required String? rarity,
    required String? dailySeed,
    required String? cellEventType,
    required Object?
        instance, // ItemInstance — typed as Object to avoid Flutter import
    required bool hasEnrichment,
    required int affixCount,
  }) =>
      GameEvent(
        sessionId: sessionId,
        userId: userId,
        deviceId: deviceId,
        timestamp: DateTime.now().toUtc(),
        category: 'state',
        event: 'species_discovered',
        data: {
          'cell_id': cellId,
          'definition_id': definitionId,
          'display_name': displayName,
          'category': category,
          'rarity': rarity,
          'daily_seed': dailySeed,
          'cell_event_type': cellEventType,
          'instance': instance,
          'has_enrichment': hasEnrichment,
          'affix_count': affixCount,
        },
      );

  /// Fog state changed for one or more cells.
  factory GameEvent.fogChanged({
    required String sessionId,
    String? userId,
    String? deviceId,
    required String cellId,
    required String oldState,
    required String newState,
  }) =>
      GameEvent(
        sessionId: sessionId,
        userId: userId,
        deviceId: deviceId,
        timestamp: DateTime.now().toUtc(),
        category: 'state',
        event: 'fog_changed',
        data: {
          'cell_id': cellId,
          'old_state': oldState,
          'new_state': newState,
        },
      );

  /// Cell geo-properties resolved (habitat, climate, continent).
  factory GameEvent.cellPropertiesResolved({
    required String sessionId,
    String? userId,
    String? deviceId,
    required String cellId,
    required List<String> habitats,
    required String climate,
    required String continent,
    String? locationId,
  }) =>
      GameEvent(
        sessionId: sessionId,
        userId: userId,
        deviceId: deviceId,
        timestamp: DateTime.now().toUtc(),
        category: 'state',
        event: 'cell_properties_resolved',
        data: {
          'cell_id': cellId,
          'habitats': habitats,
          'climate': climate,
          'continent': continent,
          'location_id': locationId,
        },
      );

  /// GPS error state changed.
  factory GameEvent.gpsErrorChanged({
    required String sessionId,
    String? userId,
    String? deviceId,
    required String error,
    double? accuracy,
  }) =>
      GameEvent(
        sessionId: sessionId,
        userId: userId,
        deviceId: deviceId,
        timestamp: DateTime.now().toUtc(),
        category: 'system',
        event: 'gps_error_changed',
        data: {
          'error': error,
          if (accuracy != null) 'accuracy': accuracy,
        },
      );

  /// Exploration guard toggled (player marker diverged too far from GPS cell).
  factory GameEvent.explorationDisabledChanged({
    required String sessionId,
    String? userId,
    String? deviceId,
    required bool disabled,
  }) =>
      GameEvent(
        sessionId: sessionId,
        userId: userId,
        deviceId: deviceId,
        timestamp: DateTime.now().toUtc(),
        category: 'system',
        event: 'exploration_disabled_changed',
        data: {'disabled': disabled},
      );

  /// An internal error or unhandled exception in the engine.
  factory GameEvent.error({
    required String sessionId,
    String? userId,
    String? deviceId,
    required String message,
    String? context,
    String? stackTrace,
  }) =>
      GameEvent(
        sessionId: sessionId,
        userId: userId,
        deviceId: deviceId,
        timestamp: DateTime.now().toUtc(),
        category: 'system',
        event: 'error',
        data: {
          'message': message,
          if (context != null) 'context': context,
          if (stackTrace != null) 'stack_trace': stackTrace,
        },
      );

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  /// Serialize to an `app_events` row.
  ///
  /// [data] values that are not JSON-primitives are excluded — the caller
  /// is responsible for extracting and serializing rich objects (e.g.
  /// `ItemInstance`) before calling this method.
  Map<String, dynamic> toRow() {
    return {
      'session_id': sessionId,
      'user_id': userId,
      'device_id': deviceId,
      'category': category,
      'event': event,
      'data': Map<String, dynamic>.fromEntries(
        data.entries.whereType<MapEntry<String, Object?>>().where(
              (e) =>
                  e.value == null ||
                  e.value is String ||
                  e.value is num ||
                  e.value is bool ||
                  e.value is List ||
                  e.value is Map,
            ),
      ),
      'created_at': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() => 'GameEvent($category/$event, session: $sessionId, '
      '${data.length} data fields)';
}
