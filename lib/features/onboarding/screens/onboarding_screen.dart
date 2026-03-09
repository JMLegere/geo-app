import 'package:flutter/material.dart' hide Durations;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/state/player_provider.dart';
import 'package:earth_nova/features/onboarding/widgets/onboarding_page.dart';
import 'package:earth_nova/shared/design_tokens.dart';

// ---------------------------------------------------------------------------
// Page definitions
// ---------------------------------------------------------------------------

const _kPages = [
  OnboardingPageData(
    icon: Icons.explore_rounded,
    title: 'Explore the World',
    subtitle:
        'Walk around to reveal the map. The world is hidden in fog until you discover it.',
    accentColor: Color(0xFF1A73E8),
  ),
  OnboardingPageData(
    icon: Icons.biotech_rounded,
    title: 'Discover Species',
    subtitle:
        'Find real species from the IUCN database. 32,752 species across 7 habitats — each one waiting to be found.',
    accentColor: Color(0xFF34A853),
  ),
  OnboardingPageData(
    icon: Icons.forest_rounded,
    title: 'Build Your Sanctuary',
    subtitle:
        'Collect species and restore habitats. Track your exploration streaks and watch your sanctuary grow.',
    accentColor: Color(0xFFF29900),
  ),
  OnboardingPageData(
    icon: Icons.travel_explore_rounded,
    title: 'Begin Your Journey',
    subtitle:
        'The fog awaits. Step outside, explore your neighbourhood, and uncover the world around you.',
    accentColor: Color(0xFF1A73E8),
  ),
];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Full-screen onboarding flow shown on first app launch.
///
/// Presents 4 pages via a [PageView] with animated dot indicators, a Skip
/// button on all non-final pages, and a Next / Get Started CTA.
///
/// On completion (last page CTA or skip), calls
/// [OnboardingNotifier.markCompleted] to persist the flag and let the app
/// root route to the auth flow.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool get _isLastPage => _currentPage == _kPages.length - 1;

  void _goToNextPage() {
    _pageController.nextPage(
      duration: Durations.slow,
      curve: AppCurves.standard,
    );
  }

  Future<void> _complete() async {
    ref.read(playerProvider.notifier).markOnboardingComplete();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip button ────────────────────────────────────────────────
            _SkipButton(visible: !_isLastPage, onSkip: _complete),

            // ── Pages ──────────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _kPages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) =>
                    OnboardingPage(data: _kPages[index]),
              ),
            ),

            // ── Dot indicators ─────────────────────────────────────────────
            _DotIndicator(
              count: _kPages.length,
              currentIndex: _currentPage,
            ),
            Spacing.gapXxl,

            // ── CTA button ─────────────────────────────────────────────────
            _CtaButton(
              isLastPage: _isLastPage,
              onNext: _goToNextPage,
              onGetStarted: _complete,
            ),
            Spacing.gapHuge,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.visible, required this.onSkip});

  final bool visible;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: TextButton(
          onPressed: visible ? onSkip : null,
          child: Text(
            'Skip',
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({
    required this.count,
    required this.currentIndex,
  });

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: Durations.normal,
          curve: AppCurves.standard,
          margin: EdgeInsets.symmetric(horizontal: Spacing.xs),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            borderRadius: Radii.borderXs,
          ),
        );
      }),
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.isLastPage,
    required this.onNext,
    required this.onGetStarted,
  });

  final bool isLastPage;
  final VoidCallback onNext;
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Spacing.xxxl),
      child: SizedBox(
        width: double.infinity,
        height: ComponentSizes.buttonHeight,
        child: FilledButton(
          onPressed: isLastPage ? onGetStarted : onNext,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: Radii.borderXxl,
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              isLastPage ? 'Get Started' : 'Next',
              key: ValueKey<bool>(isLastPage),
            ),
          ),
        ),
      ),
    );
  }
}
