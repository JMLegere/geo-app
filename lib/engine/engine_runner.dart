import 'package:earth_nova/engine/engine_input.dart';
import 'package:earth_nova/engine/game_event.dart';

/// Abstraction between the UI/provider layer and [GameEngine].
///
/// The runner interface decouples consumers from the engine's execution
/// model. Today the only implementation is [MainThreadEngineRunner], which
/// runs the engine inline on the main thread. A future isolate-backed runner
/// will move the engine off the UI thread on native platforms — the interface
/// stays the same, only the transport changes.
///
/// ## Ownership
///
/// The runner owns the engine's lifecycle. Call [dispose] when the
/// ProviderScope is torn down. Do not call any methods after [dispose].
abstract interface class EngineRunner {
  /// Single broadcast stream of all [GameEvent]s emitted by the engine.
  ///
  /// Multiple consumers (persistence, UI, analytics) can listen
  /// concurrently. The stream is broadcast — new listeners do NOT receive
  /// past events.
  Stream<GameEvent> get events;

  /// Routes an [EngineInput] command to the engine.
  ///
  /// Returns immediately. The engine processes the command synchronously
  /// on the main-thread runner; an isolate runner would marshal it over
  /// a send-port. Callers should not assume synchronous side-effects.
  void send(EngineInput input);

  /// Permanently releases all resources held by this runner and the
  /// underlying engine. The runner is unusable after this call.
  Future<void> dispose();
}
