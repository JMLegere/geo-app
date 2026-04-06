import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';

class CellVisitDto {
  const CellVisitDto({
    required this.id,
    required this.userId,
    required this.cellId,
    required this.visitedAt,
  });

  final String id;
  final String userId;
  final String cellId;
  final DateTime visitedAt;

  factory CellVisitDto.fromJson(Map<String, dynamic> json) => CellVisitDto(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        cellId: json['cell_id'] as String,
        visitedAt: DateTime.parse(json['visited_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'cell_id': cellId,
        'visited_at': visitedAt.toIso8601String(),
      };

  CellVisit toDomain() => CellVisit(
        id: id,
        cellId: cellId,
        userId: userId,
        visitedAt: visitedAt,
      );

  factory CellVisitDto.fromDomain(CellVisit visit) => CellVisitDto(
        id: visit.id,
        userId: visit.userId,
        cellId: visit.cellId,
        visitedAt: visit.visitedAt,
      );
}
