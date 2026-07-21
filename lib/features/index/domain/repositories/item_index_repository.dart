import 'package:earth_nova/features/index/domain/entities/index_entry.dart';

/// Read-only boundary for the stable Base Item Index projection.
abstract interface class ItemIndexRepository {
  Future<List<IndexEntry>> fetchIndex({String? traceId});
}

/// A deliberately non-diagnostic failure safe to expose to telemetry and UI.
///
/// Adapters must map backend exceptions to this type rather than retaining raw
/// service messages, query text, or response bodies.
final class ItemIndexFailure implements Exception {
  const ItemIndexFailure._(this.kind);

  const ItemIndexFailure.unavailable()
      : this._(ItemIndexFailureKind.unavailable);
  const ItemIndexFailure.malformedPayload()
      : this._(ItemIndexFailureKind.malformedPayload);

  final ItemIndexFailureKind kind;

  @override
  String toString() => 'Item Index request failed (${kind.name}).';
}

enum ItemIndexFailureKind { unavailable, malformedPayload }
