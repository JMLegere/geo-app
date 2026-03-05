import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/features/sync/models/sync_status.dart';
import 'package:fog_of_world/features/sync/providers/sync_provider.dart';

void main() {
  group('SyncNotifier', () {
    test('initial state reflects Supabase not configured in test environment',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(syncProvider);

      expect(state.type, SyncStatusType.error);
      expect(state.errorMessage, isNotNull);
      expect(state.pendingChanges, 0);
      expect(state.lastSyncedAt, isNull);
    });

    test('syncNow is a no-op and does not throw', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await expectLater(
        container.read(syncProvider.notifier).syncNow(),
        completes,
      );
    });
  });
}
