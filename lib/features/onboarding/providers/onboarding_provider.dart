import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingCompletedKey = 'onboarding_completed';

/// Tracks whether the user has completed the first-run onboarding flow.
///
/// State is `null` while loading from SharedPreferences, `false` when not
/// yet completed, and `true` once the user dismisses the onboarding.
///
/// Using `bool?` avoids a visible flash of the onboarding screen on
/// subsequent launches while the preference is being read asynchronously.
class OnboardingNotifier extends Notifier<bool?> {
  @override
  bool? build() {
    _loadState();
    return null; // loading — neutral until SharedPreferences resolves
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    // Guard: provider may have been disposed while awaiting.
    if (!ref.mounted) return;
    state = prefs.getBool(_kOnboardingCompletedKey) ?? false;
  }

  // ---------------------------------------------------------------------------
  // Public actions
  // ---------------------------------------------------------------------------

  /// Marks onboarding as complete and persists the flag so it is skipped on
  /// future launches.
  Future<void> markCompleted() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingCompletedKey, true);
  }
}

final onboardingProvider = NotifierProvider<OnboardingNotifier, bool?>(
  OnboardingNotifier.new,
);
