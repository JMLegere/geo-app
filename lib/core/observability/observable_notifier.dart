import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/observability_service.dart';

/// Abstract base class for all app notifiers. Enforces observability
/// structurally — compile error if [obs] getter is not implemented,
/// and [transition] makes the event name required at every state change.
///
/// Usage:
/// ```dart
/// class AuthNotifier extends ObservableNotifier<AuthState> {
///   @override
///   ObservabilityService get obs => ref.watch(observabilityProvider);
///   @override
///   String get category => 'auth';
/// }
/// ```
///
/// **DO NOT use raw `state = newState`** — always use [transition].
/// See `docs/design.md` §6 for the full observability contract.
abstract class ObservableNotifier<T> extends Notifier<T> {
  /// Must be implemented by every subclass. Compile error if missing.
  ObservabilityService get obs;

  /// Log category for this notifier (e.g. 'auth', 'data').
  /// Override to set a meaningful category.
  String get category => 'state';

  /// Use instead of raw `state = newState`.
  /// Logs the event and sets state atomically.
  @protected
  void transition(T newState, String event, {Map<String, dynamic>? data}) {
    obs.log(event, category, data: data);
    state = newState;
  }

  /// Opt-in silent state update — NO observability log emitted.
  ///
  /// Only use for high-frequency paths where logging every update would
  /// produce excessive noise (e.g. 60 fps animation ticks). The call site
  /// MUST have a comment explaining why silent is appropriate.
  ///
  /// Prefer [transition] for all normal state changes.
  @protected
  void silentTransition(T newState) {
    state = newState;
  }
}
