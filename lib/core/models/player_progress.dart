/// Represents the player's overall progress and statistics.
/// 
/// Tracks:
/// - Number of cells observed and species collected
/// - Daily visit streak (consecutive days with at least one visit)
/// - Total distance walked
/// 
/// This class is immutable — use [copyWith] to create modified instances.
class PlayerProgress {
  /// Unique identifier for the player (typically their user ID from auth)
  final String userId;

  /// Number of cells the player has observed (fog state >= unexplored)
  final int cellsObserved;

  /// Number of unique species the player has collected
  final int speciesCollected;

  /// Current daily visit streak (consecutive days with at least one visit)
  final int currentStreak;

  /// Longest daily visit streak ever achieved
  final int longestStreak;

  /// Total distance walked in kilometers
  final double totalDistanceKm;

  const PlayerProgress({
    required this.userId,
    required this.cellsObserved,
    required this.speciesCollected,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalDistanceKm,
  });

  /// Creates a copy of this progress with optionally updated fields.
  PlayerProgress copyWith({
    String? userId,
    int? cellsObserved,
    int? speciesCollected,
    int? currentStreak,
    int? longestStreak,
    double? totalDistanceKm,
  }) {
    return PlayerProgress(
      userId: userId ?? this.userId,
      cellsObserved: cellsObserved ?? this.cellsObserved,
      speciesCollected: speciesCollected ?? this.speciesCollected,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
    );
  }

  /// Converts this progress to a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'cellsObserved': cellsObserved,
      'speciesCollected': speciesCollected,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'totalDistanceKm': totalDistanceKm,
    };
  }

  /// Creates progress from a JSON map.
  static PlayerProgress fromJson(Map<String, dynamic> json) {
    return PlayerProgress(
      userId: json['userId'] as String,
      cellsObserved: json['cellsObserved'] as int,
      speciesCollected: json['speciesCollected'] as int,
      currentStreak: json['currentStreak'] as int,
      longestStreak: json['longestStreak'] as int,
      totalDistanceKm: (json['totalDistanceKm'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PlayerProgress &&
        other.userId == userId &&
        other.cellsObserved == cellsObserved &&
        other.speciesCollected == speciesCollected &&
        other.currentStreak == currentStreak &&
        other.longestStreak == longestStreak &&
        other.totalDistanceKm == totalDistanceKm;
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      cellsObserved,
      speciesCollected,
      currentStreak,
      longestStreak,
      totalDistanceKm,
    );
  }

  @override
  String toString() {
    return 'PlayerProgress(userId: $userId, cellsObserved: $cellsObserved, '
        'speciesCollected: $speciesCollected, currentStreak: $currentStreak, '
        'longestStreak: $longestStreak, totalDistanceKm: $totalDistanceKm)';
  }
}
