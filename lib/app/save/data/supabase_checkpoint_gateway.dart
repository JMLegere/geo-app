import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/checkpoint_gateway.dart';
import '../domain/player_save.dart';

final class SupabaseCheckpointGateway implements CheckpointGateway {
  SupabaseCheckpointGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<PublishedPlayerSave?> fetchLatest() async {
    final response = await _client.rpc('fetch_latest_player_checkpoint');
    if (response == null) return null;
    final json = Map<String, Object?>.from(response as Map);
    return PublishedPlayerSave(
      revision: json['revision']! as int,
      save: PlayerSave.fromJson(
        Map<String, Object?>.from(json['save']! as Map),
      ),
    );
  }

  @override
  Future<CheckpointResult> submit(PlayerSave save) async {
    final response = await _client.rpc(
      'accept_player_checkpoint',
      params: {'p_save': save.sealed().toJson()},
    );
    final json = Map<String, Object?>.from(response as Map);
    switch (json['status']) {
      case 'accepted':
        return CheckpointAccepted(
          checkpointId: json['checkpoint_id']! as String,
          revision: json['revision']! as int,
          reconciliationCursor: json['reconciliation_cursor']! as int,
        );
      case 'conflict':
        return CheckpointConflict(
          reason: json['reason']! as String,
          cloud: PublishedPlayerSave(
            revision: json['cloud_revision']! as int,
            save: PlayerSave.fromJson(
              Map<String, Object?>.from(json['cloud_save']! as Map),
            ),
          ),
        );
      default:
        return CheckpointRejected(
          (json['code'] as String?) ?? 'rejected',
          (json['message'] as String?) ?? 'Checkpoint rejected.',
        );
    }
  }

  @override
  Future<List<SharedInteractionDelivery>> fetchInteractions({
    required int afterCursor,
  }) async {
    final response = await _client.rpc(
      'fetch_player_interaction_deliveries',
      params: {'p_after_sequence': afterCursor},
    );
    if (response is! List) throw const FormatException('Invalid deliveries.');
    return response
        .map((row) {
          final json = Map<String, Object?>.from(row as Map);
          return SharedInteractionDelivery(
            interactionId: json['interaction_id']! as String,
            sequence: json['sequence']! as int,
            rulesVersion: json['rules_version']! as String,
            effect: Map<String, Object?>.from(json['effect']! as Map),
          );
        })
        .toList(growable: false);
  }
}
