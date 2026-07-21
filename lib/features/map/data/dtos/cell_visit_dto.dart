import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';

class CellVisitDto {
  const CellVisitDto({
    required this.id,
    required this.userId,
    required this.cellId,
    required this.clientEventId,
    required this.visitedAt,
  });

  final String id;
  final String userId;
  final String cellId;
  final DateTime visitedAt;
  final String? clientEventId;

  factory CellVisitDto.fromJson(Map<String, Object?> json) => CellVisitDto(
        id: _requiredString(json, 'id'),
        userId: _requiredString(json, 'user_id'),
        cellId: _requiredString(json, 'cell_id'),
        clientEventId: _nullableNonblankString(json, 'client_event_id'),
        visitedAt: _requiredDateTime(json, 'visited_at'),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'user_id': userId,
        'cell_id': cellId,
        'client_event_id': clientEventId,
        'visited_at': visitedAt.toIso8601String(),
      };

  CellVisit toDomain() => CellVisit(
        id: id,
        cellId: cellId,
        userId: userId,
        clientEventId: clientEventId,
        visitedAt: visitedAt,
      );

  factory CellVisitDto.fromDomain(CellVisit visit) => CellVisitDto(
        id: visit.id,
        userId: visit.userId,
        cellId: visit.cellId,
        clientEventId: visit.clientEventId,
        visitedAt: visit.visitedAt,
      );
  static String _requiredString(Map<String, Object?> json, String field) {
    final value = json[field];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Cell visit row requires a non-empty "$field".');
    }
    return value;
  }

  static String? _nullableNonblankString(
    Map<String, Object?> json,
    String field,
  ) {
    final value = json[field];
    if (value == null) {
      return null;
    }
    if (value is! String || value.trim().isEmpty) {
      throw FormatException(
        'Cell visit row requires "$field" to be a non-empty string when present.',
      );
    }
    return value;
  }

  static DateTime _requiredDateTime(
    Map<String, Object?> json,
    String field,
  ) {
    final value = _requiredString(json, field);
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException(
        'Cell visit row has an invalid "$field" timestamp: "$value".',
      );
    }
    return parsed;
  }
}
