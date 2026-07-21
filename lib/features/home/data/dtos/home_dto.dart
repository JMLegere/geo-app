import 'package:earth_nova/features/home/domain/entities/home.dart';
import 'package:earth_nova/features/home/domain/repositories/home_repository.dart';

/// Strict parser for the frozen `get_v3_home()` RPC response.
///
/// The server derives the authenticated owner. The locally authenticated player
/// id is accepted only to verify that returned durable ownership evidence.
final class HomeDto {
  const HomeDto._(this._home);

  final Home _home;

  factory HomeDto.fromJson(Object? json, {required String playerId}) {
    try {
      final expectedPlayerId = _uuid(playerId);
      final response = _object(json);
      _exactKeys(response, const ['id', 'user_id', 'created_at']);
      final returnedPlayerId = _uuid(response['user_id']);
      if (returnedPlayerId != expectedPlayerId) {
        throw const HomeFailure.ownerMismatch();
      }
      return HomeDto._(
        Home(
          id: _uuid(response['id']),
          playerId: returnedPlayerId,
          createdAt: _timestamp(response['created_at']),
        ),
      );
    } on HomeFailure {
      rethrow;
    } on ArgumentError {
      throw const HomeFailure.malformedPayload();
    } on FormatException {
      throw const HomeFailure.malformedPayload();
    } on StateError {
      throw const HomeFailure.malformedPayload();
    } on TypeError {
      throw const HomeFailure.malformedPayload();
    }
  }

  Home toDomain() => _home;

  /// Validates the local owner used to verify server-derived Home evidence.
  static void validatePlayerId(String playerId) => _uuid(playerId);
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map) _malformed();
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String || result.containsKey(key)) _malformed();
    result[key] = entry.value;
  }
  return result;
}

void _exactKeys(Map<String, Object?> value, List<String> expected) {
  if (value.length != expected.length ||
      value.keys.any((key) => !expected.contains(key))) {
    _malformed();
  }
}

String _text(Object? value) {
  if (value is! String || value.isEmpty || value != value.trim()) _malformed();
  return value;
}

String _uuid(Object? value) {
  final result = _text(value);
  if (!_uuidPattern.hasMatch(result)) _malformed();
  return result;
}

DateTime _timestamp(Object? value) {
  final text = _text(value);
  if (!_timestampPattern.hasMatch(text)) _malformed();
  final parsed = DateTime.tryParse(text);
  if (parsed == null) _malformed();
  return parsed.toUtc();
}

Never _malformed() => throw const HomeFailure.malformedPayload();

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final _timestampPattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$',
);
