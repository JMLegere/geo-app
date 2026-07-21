/// Purely derives whether an Item must be Identified.
///
/// Identification is necessary exactly when the Player has not yet Discovered
/// the stable Base Item, or the Item's exact Base Item Version defines one or
/// more Variable Properties. This rule does not resolve values or mutate state.
final class IdentificationRequirement {
  const IdentificationRequirement._();

  static bool requires({
    required bool playerDiscovered,
    required int variablePropertyCount,
  }) {
    if (variablePropertyCount < 0) {
      throw ArgumentError.value(
        variablePropertyCount,
        'variablePropertyCount',
        'must not be negative',
      );
    }
    return !playerDiscovered || variablePropertyCount > 0;
  }
}
