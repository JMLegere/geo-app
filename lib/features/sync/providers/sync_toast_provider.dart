import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The type of sync toast to display.
enum SyncToastType { success, error }

/// State for the sync toast overlay.
class SyncToastState {
  final SyncToastType? activeToast;
  final String? message;

  const SyncToastState({this.activeToast, this.message});

  bool get hasActiveToast => activeToast != null;

  SyncToastState copyWith({SyncToastType? activeToast, String? message}) {
    return SyncToastState(
      activeToast: activeToast ?? this.activeToast,
      message: message ?? this.message,
    );
  }
}

/// Notifier that manages the sync toast visibility.
///
/// Shows a brief "Game saved" or "Sync failed" pill toast at the bottom of
/// the screen after a write queue auto-flush completes.
class SyncToastNotifier extends Notifier<SyncToastState> {
  @override
  SyncToastState build() => const SyncToastState();

  /// Shows a success toast. Defaults to "Game saved".
  void showSuccess({String message = 'Game saved'}) {
    state = SyncToastState(
      activeToast: SyncToastType.success,
      message: message,
    );
  }

  /// Shows an error toast. Defaults to "Sync failed".
  void showError({String message = 'Sync failed'}) {
    state = SyncToastState(
      activeToast: SyncToastType.error,
      message: message,
    );
  }

  /// Clears the active toast.
  void dismiss() {
    state = const SyncToastState();
  }
}

/// Provider for sync toast state.
final syncToastProvider =
    NotifierProvider<SyncToastNotifier, SyncToastState>(SyncToastNotifier.new);
