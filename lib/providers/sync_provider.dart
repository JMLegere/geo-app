import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/data/repos/write_queue_repo.dart';
import 'package:earth_nova/providers/database_provider.dart';

// ---------------------------------------------------------------------------
// Write-queue repo provider
// ---------------------------------------------------------------------------

final writeQueueRepoProvider = Provider<WriteQueueRepo>(
  (ref) => WriteQueueRepo(ref.watch(databaseProvider)),
);

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum SyncStatus { idle, syncing, error }

class SyncState {
  final SyncStatus status;
  final int pendingCount;
  final String? lastError;

  const SyncState({
    this.status = SyncStatus.idle,
    this.pendingCount = 0,
    this.lastError,
  });

  SyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    String? lastError,
    bool clearError = false,
  }) =>
      SyncState(
        status: status ?? this.status,
        pendingCount: pendingCount ?? this.pendingCount,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );
}

// ---------------------------------------------------------------------------
// Provider + Notifier
// ---------------------------------------------------------------------------

final syncProvider =
    NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);

class SyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() => const SyncState();

  void setSyncing() => state = state.copyWith(status: SyncStatus.syncing);

  void setIdle({int? pendingCount}) => state = state.copyWith(
        status: SyncStatus.idle,
        pendingCount: pendingCount,
        clearError: true,
      );

  void setError(String message) => state = state.copyWith(
        status: SyncStatus.error,
        lastError: message,
      );

  Future<void> refreshPendingCount({String? userId}) async {
    final repo = ref.read(writeQueueRepoProvider);
    final count = await repo.countPending(userId: userId);
    state = state.copyWith(pendingCount: count);
  }
}
