/// Sealed command type sent to [GameEngine] via [GameEngine.send].
///
/// All game inputs are value objects — immutable, comparable, and
/// safe to queue or log. The engine pattern-matches exhaustively on
/// [EngineInput] subtypes so any new input type requires a compiler
/// error to be handled.
///
/// ## Call-site examples
///
/// ```dart
/// // Rubber-band controller (60 fps) — throttled internally to ~10 Hz
/// engine.send(PositionUpdate(lat, lon, accuracy));
///
/// // Auth provider — user signed in / out
/// engine.send(AuthChanged(userId));
///
/// // App lifecycle observer
/// engine.send(AppLifecycleChanged(isActive: false));
/// ```
sealed class EngineInput {
  const EngineInput();
}

/// Interpolated player position pushed by the rubber-band controller.
///
/// Called at the display frame rate (~60 fps). The engine throttles
/// game logic to ~10 Hz via an internal frame counter — callers do
/// NOT need to throttle externally.
///
/// [accuracy] is the GPS accuracy in metres from the most recent raw
/// GPS fix. Passed through so the engine can broadcast it alongside
/// position events.
final class PositionUpdate extends EngineInput {
  final double lat;
  final double lon;
  final double accuracy;

  const PositionUpdate(this.lat, this.lon, [this.accuracy = 0]);

  @override
  String toString() =>
      'PositionUpdate(lat: $lat, lon: $lon, accuracy: $accuracy)';
}

/// Auth state changed — user signed in, signed out, or identity switched.
///
/// [userId] is null when signed out. The engine tracks this to stamp
/// emitted events with the current user ID.
final class AuthChanged extends EngineInput {
  final String? userId;

  const AuthChanged(this.userId);

  @override
  String toString() => 'AuthChanged(userId: $userId)';
}

/// A cell on the map was tapped by the player.
///
/// Reserved for future interaction (cell inspection, manual exploration).
/// Currently a no-op in the engine.
final class CellTapped extends EngineInput {
  final String cellId;

  const CellTapped(this.cellId);

  @override
  String toString() => 'CellTapped(cellId: $cellId)';
}

/// App moved to the background (paused / minimized).
///
/// The engine can use this to flush write queues or pause GPS-driven
/// work. Currently forwarded but not acted upon — handled by
/// [LogFlushService] at the provider layer.
final class AppLifecycleChanged extends EngineInput {
  final bool isActive;

  const AppLifecycleChanged({required this.isActive});

  @override
  String toString() => 'AppLifecycleChanged(isActive: $isActive)';
}
