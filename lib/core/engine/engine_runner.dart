import 'package:earth_nova/core/engine/engine_input.dart';
import 'package:earth_nova/core/engine/game_event.dart';

/// Abstraction between the UI/provider layer and [GameEngine].
///
/// Today: [MainThreadEngineRunner] wraps GameEngine directly (same thread).
/// Future: An isolate-backed runner will move the engine off the main thread
/// on native platforms.
abstract class EngineRunner {
  /// Single broadcast stream of all game events.
  Stream<GameEvent> get events;

  /// Routes an [EngineInput] command to the engine.
  void send(EngineInput input);

  /// Releases all resources. The runner is unusable after this call.
  Future<void> dispose();
}
