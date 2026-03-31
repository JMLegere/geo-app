/// No-op debug bridge for non-web platforms.
class DebugBridge {
  DebugBridge({
    required bool Function() getInfographicState,
    required void Function(bool) setInfographicState,
  });

  void install() {}
  void dispose() {}
}
