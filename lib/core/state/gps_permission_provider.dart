import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks GPS permission status during app startup.
///
/// States flow: unknown → requesting → granted | denied | skipped
///
/// The loading screen gates on this state — it won't dismiss until
/// the user makes a permission decision (granted, denied, or skipped).
enum GpsPermissionState { unknown, requesting, granted, denied, skipped }

/// Provider for tracking GPS permission status during app loading.
///
/// Used by:
/// - LoadingScreen: shows permission request UI when unknown/requesting
/// - _SteadyStateShell: gates loading dismissal on permission decision
/// - KeyboardModeBanner: offers "Use My Location" button when in keyboard mode
final gpsPermissionProvider =
    NotifierProvider<GpsPermissionNotifier, GpsPermissionState>(
  GpsPermissionNotifier.new,
);

class GpsPermissionNotifier extends Notifier<GpsPermissionState> {
  @override
  GpsPermissionState build() => GpsPermissionState.unknown;

  /// Transition to requesting state when permission request starts.
  void startRequesting() => state = GpsPermissionState.requesting;

  /// Mark permission as granted.
  void markGranted() => state = GpsPermissionState.granted;

  /// Mark permission as denied.
  void markDenied() => state = GpsPermissionState.denied;

  /// Mark permission as skipped (user chose manual mode).
  void markSkipped() => state = GpsPermissionState.skipped;
}
