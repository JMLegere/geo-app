import 'condition.dart';

/// Supplies one deterministic normalized roll for a selector resolution.
typedef NormalizedRollSource = double Function();

/// The resolved outcome of a [Selector].
sealed class SelectionResult<Value> {
  const SelectionResult();
}

/// A selector outcome containing a concrete value.
final class SelectedValue<Value> extends SelectionResult<Value> {
  const SelectedValue(this.value);

  final Value value;

  @override
  bool operator ==(Object other) =>
      other is SelectedValue<Value> && other.value == value;

  @override
  int get hashCode => Object.hash(SelectedValue<Value>, value);
}

/// A selector outcome that explicitly represents no value.
final class SelectedNone<Value> extends SelectionResult<Value> {
  const SelectedNone();

  @override
  bool operator ==(Object other) => other is SelectedNone<Value>;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// One immutable, conditionally eligible weighted outcome in a [Selector].
final class SelectorCandidate<Value, Context> {
  SelectorCandidate.value({
    required this.id,
    required Value value,
    required this.weight,
    this.condition,
  }) : result = SelectedValue<Value>(value) {
    _validate();
  }

  SelectorCandidate.none({
    required this.id,
    required this.weight,
    this.condition,
  }) : result = SelectedNone<Value>() {
    _validate();
  }

  /// A stable authored identity. It must not carry mutable lookup semantics.
  final String id;

  /// Relative selection likelihood among eligible candidates.
  final double weight;

  /// An absent condition means this candidate is eligible.
  final Condition<Context>? condition;

  /// The candidate's value or explicit no-value outcome.
  final SelectionResult<Value> result;

  void _validate() {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'A candidate ID must not be blank.');
    }
    if (!weight.isFinite || weight <= 0) {
      throw ArgumentError.value(
        weight,
        'weight',
        'A candidate weight must be positive and finite.',
      );
    }
  }
}

/// A reusable weighted choice over conditionally eligible candidates.
final class Selector<Value, Context> {
  Selector({required Iterable<SelectorCandidate<Value, Context>> candidates})
      : candidates = List<SelectorCandidate<Value, Context>>.unmodifiable(
          candidates,
        ) {
    if (this.candidates.isEmpty) {
      throw ArgumentError.value(
        candidates,
        'candidates',
        'A selector must contain at least one candidate.',
      );
    }

    final candidateIds = <String>{};
    for (final candidate in this.candidates) {
      if (!candidateIds.add(candidate.id)) {
        throw ArgumentError.value(
          candidate.id,
          'candidates',
          'Candidate IDs must be unique within a selector.',
        );
      }
    }
  }

  final List<SelectorCandidate<Value, Context>> candidates;

  /// Resolves exactly one eligible candidate using [rollSource].
  ///
  /// All conditions are evaluated before any relative weights are calculated.
  /// A selector with no eligible candidates is invalid and fails explicitly.
  SelectionResult<Value> resolve(
    Context context,
    NormalizedRollSource rollSource,
  ) =>
      resolveCandidate(context, rollSource).result;

  /// Resolves exactly one eligible candidate while retaining its stable
  /// candidate identity for durable resolution evidence.
  ///
  /// All conditions are evaluated before any relative weights are calculated.
  /// A selector with no eligible candidates is invalid and fails explicitly.
  SelectorCandidate<Value, Context> resolveCandidate(
    Context context,
    NormalizedRollSource rollSource,
  ) {
    final eligibleCandidates = <SelectorCandidate<Value, Context>>[];
    var largestWeight = 0.0;

    for (final candidate in candidates) {
      if (isEligible(candidate.condition, context)) {
        eligibleCandidates.add(candidate);
        if (candidate.weight > largestWeight) {
          largestWeight = candidate.weight;
        }
      }
    }

    if (eligibleCandidates.isEmpty) {
      throw StateError('A selector must have at least one eligible candidate.');
    }

    var scaledTotalWeight = 0.0;
    for (final candidate in eligibleCandidates) {
      scaledTotalWeight += candidate.weight / largestWeight;
    }

    final roll = rollSource();
    if (!roll.isFinite || roll < 0 || roll >= 1) {
      throw ArgumentError.value(
        roll,
        'roll',
        'A selector roll must be finite and in [0, 1).',
      );
    }

    var threshold = roll * scaledTotalWeight;
    for (final candidate in eligibleCandidates) {
      threshold -= candidate.weight / largestWeight;
      if (threshold < 0) return candidate;
    }

    // Floating-point rounding can leave a zero residual for a valid roll.
    return eligibleCandidates.last;
  }
}
