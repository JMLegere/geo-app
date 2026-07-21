import 'package:earth_nova/features/index/data/repositories/supabase_item_index_repository.dart';
import 'package:earth_nova/features/index/domain/repositories/item_index_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> validResponse() => {
      'entries': [
        {
          'base_item_id': 'base-a',
          'category': 'fauna',
          'first_identified_item_id': 'item-a',
          'base_item_version_id': 'version-a',
          'base_item_revision': 2,
          'display_name': 'Jaguar',
          'scientific_name': 'Panthera onca',
          'discovery_provenance': 'automatic_identification',
          'discovered_at': '2026-07-20T10:00:00Z',
        },
      ],
    };

void main() {
  group('SupabaseItemIndexRepository', () {
    test('calls only the frozen no-parameter Item Index RPC', () async {
      final names = <String>[];
      final events = <Map<String, Object?>>[];
      final repository = SupabaseItemIndexRepository(
        rpc: (name) async {
          names.add(name);
          return validResponse();
        },
        logEvent: (event, category, {data}) =>
            events.add({'event': event, 'category': category, 'data': data}),
      );

      final result = await repository.fetchIndex();

      expect(names, ['fetch_v3_item_index']);
      expect(result.single.baseItemId.value, 'base-a');
      expect(events.map((event) => event['event']), [
        'db.rpc_started',
        'db.rpc_completed',
      ]);
      expect((events.last['data'] as Map)['operation'], 'fetch_v3_item_index');
      expect((events.last['data'] as Map)['duration_ms'], isA<int>());
    });

    test('maps backend failures to a safe domain error without raw message',
        () async {
      final events = <Map<String, Object?>>[];
      final repository = SupabaseItemIndexRepository(
        rpc: (_) =>
            Future<Object?>.error(StateError('database password: nope')),
        logEvent: (event, category, {data}) =>
            events.add({'event': event, 'category': category, 'data': data}),
      );

      await expectLater(
        repository.fetchIndex(),
        throwsA(
          isA<ItemIndexFailure>().having(
            (failure) => failure.toString(),
            'safe message',
            isNot(contains('database password')),
          ),
        ),
      );
      expect(events.last['event'], 'db.rpc_failed');
      expect((events.last['data'] as Map)['error_message'], 'unavailable');
    });

    test('preserves safe malformed-payload failures', () async {
      final repository =
          SupabaseItemIndexRepository(rpc: (_) async => {'entries': 'bad'});

      await expectLater(
        repository.fetchIndex(),
        throwsA(
          isA<ItemIndexFailure>().having(
            (failure) => failure.kind,
            'kind',
            ItemIndexFailureKind.malformedPayload,
          ),
        ),
      );
    });
  });
}
