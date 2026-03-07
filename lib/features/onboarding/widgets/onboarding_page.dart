import 'package:flutter/material.dart';

/// Data model for a single onboarding page.
class OnboardingPageData {
  const OnboardingPageData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
}

/// Renders a single page in the onboarding [PageView].
///
/// Displays a large icon in a tinted circle, a bold title, and a muted
/// subtitle. The layout is vertically centred in the available space with
/// generous padding so it reads well on both small and large screens.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.data});

  final OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Icon badge ────────────────────────────────────────────────────
          _IconBadge(icon: data.icon, color: data.accentColor),
          const SizedBox(height: 40),

          // ── Title ─────────────────────────────────────────────────────────
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          // ── Subtitle ──────────────────────────────────────────────────────
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private components
// ---------------------------------------------------------------------------

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        color: color.withAlpha(26), // ~10% opacity
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withAlpha(51), // ~20% opacity
          width: 1.5,
        ),
      ),
      child: Icon(
        icon,
        size: 52,
        color: color,
      ),
    );
  }
}
