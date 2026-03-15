import 'package:earth_nova/core/engine/engine_input.dart';
import 'package:earth_nova/core/engine/engine_runner.dart';
import 'package:earth_nova/core/engine/game_engine.dart';
import 'package:earth_nova/core/engine/game_event.dart';

/// [EngineRunner] that wraps [GameEngine] directly on the main thread.
///
/// This is the only runner for now. When native ships, an isolate-backed
/// runner will move the engine off the UI thread — same [EngineRunner]
/// interface, different transport.
class MainThreadEngineRunner implements EngineRunner {
  MainThreadEngineRunner(this._engine);

  final GameEngine _engine;

  /// The wrapped engine. Exposed for transitional use by the provider layer
  /// while migration is in progress. Prefer [send] and [events].
  GameEngine get engine => _engine;

  @override
  Stream<GameEvent> get events => _engine.events;

  @override
  void send(EngineInput input) => _engine.send(input);

  @override
  Future<void> dispose() async => _engine.dispose();
}
