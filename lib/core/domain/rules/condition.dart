/// A typed, read-only predicate used to determine content eligibility.
///
/// Feature-owned leaf conditions extend this class and evaluate their own
/// context. The shared domain kernel only composes those leaves.
abstract class Condition<Context> {
  const Condition();

  bool evaluate(Context context);
}

/// Evaluates an optional [condition], treating its absence as eligible.
bool isEligible<Context>(Condition<Context>? condition, Context context) =>
    condition?.evaluate(context) ?? true;

/// Requires every child condition to be eligible.
final class AllCondition<Context> extends Condition<Context> {
  AllCondition(Iterable<Condition<Context>> conditions)
      : conditions = List<Condition<Context>>.unmodifiable(conditions) {
    if (this.conditions.isEmpty) {
      throw ArgumentError.value(
        conditions,
        'conditions',
        'An AllCondition must contain at least one condition.',
      );
    }
  }

  final List<Condition<Context>> conditions;

  @override
  bool evaluate(Context context) {
    for (final condition in conditions) {
      if (!condition.evaluate(context)) return false;
    }
    return true;
  }
}

/// Requires at least one child condition to be eligible.
final class AnyCondition<Context> extends Condition<Context> {
  AnyCondition(Iterable<Condition<Context>> conditions)
      : conditions = List<Condition<Context>>.unmodifiable(conditions) {
    if (this.conditions.isEmpty) {
      throw ArgumentError.value(
        conditions,
        'conditions',
        'An AnyCondition must contain at least one condition.',
      );
    }
  }

  final List<Condition<Context>> conditions;

  @override
  bool evaluate(Context context) {
    for (final condition in conditions) {
      if (condition.evaluate(context)) return true;
    }
    return false;
  }
}

/// Inverts the eligibility of its child condition.
final class NotCondition<Context> extends Condition<Context> {
  const NotCondition(this.condition);

  final Condition<Context> condition;

  @override
  bool evaluate(Context context) => !condition.evaluate(context);
}
