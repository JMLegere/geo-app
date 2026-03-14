/// Native crash log persistence — no-op.
///
/// Native platforms don't lose in-memory state on navigation the way
/// mobile browsers do. The async Supabase flush is sufficient.
class CrashLogPersistence {
  CrashLogPersistence._();

  /// No-op on native.
  static void persist(List<String> lines) {}

  /// No-op on native — always returns null.
  static List<String>? recover() => null;

  /// No-op on native.
  static void clear() {}
}
