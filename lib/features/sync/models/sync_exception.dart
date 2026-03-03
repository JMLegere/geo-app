/// Thrown by cloud sync client implementations when a sync operation fails.
class SyncException implements Exception {
  const SyncException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() {
    final codePart = code != null ? ' (code: $code)' : '';
    return 'SyncException: $message$codePart';
  }
}
