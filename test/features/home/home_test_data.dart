const homeId = '10000000-0000-4000-8000-000000000001';
const playerId = '20000000-0000-4000-8000-000000000002';
const otherPlayerId = '30000000-0000-4000-8000-000000000003';
const createdAt = '2026-07-21T00:00:00.000Z';

Map<String, Object?> homePayload() => {
      'id': homeId,
      'user_id': playerId,
      'created_at': createdAt,
    };
