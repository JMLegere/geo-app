import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/state/fun_facts_provider.dart';
import 'package:earth_nova/core/state/player_provider.dart';
import 'package:earth_nova/core/state/player_located_provider.dart';
import 'package:earth_nova/core/state/zone_ready_provider.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/widgets/spinning_globe.dart';

/// Hardcoded fallback fun facts — used when no cached facts are available.
const _fallbackFacts = [
  'The Arctic Tern migrates 44,000 miles every year — the longest migration of any animal.',
  'A group of flamingos is called a "flamboyance."',
  'Octopuses have three hearts and blue blood.',
  'The Mantis Shrimp can punch with the force of a .22 caliber bullet.',
  'Honey badgers can withstand venomous snake bites and bee stings.',
  'A chameleon\'s tongue can be twice the length of its body.',
  'The Pistol Shrimp snaps its claw so fast it creates a shockwave hotter than the sun\'s surface.',
  'Elephants are the only animals that can\'t jump.',
  'A woodpecker\'s tongue wraps around its skull to cushion its brain.',
  'Sea otters hold hands while sleeping to avoid drifting apart.',
  'The Axolotl can regenerate its brain, heart, and limbs.',
  'A blue whale\'s heart is the size of a small car.',
  'Crows can recognize and remember human faces for years.',
  'The Immortal Jellyfish can revert to its juvenile form indefinitely.',
  'A tardigrade can survive in the vacuum of space.',
];

class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _subtitleOpacity;
  late final String _funFact;

  @override
  void initState() {
    super.initState();

    final cached = ref.read(cachedFunFactsProvider);
    final allFacts = {..._fallbackFacts, ...cached}.toList();
    _funFact = (allFacts..shuffle()).first;

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _titleOpacity = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.3, 0.7, curve: AppCurves.fadeIn),
    );

    _subtitleOpacity = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.55, 1.0, curve: AppCurves.fadeIn),
    );

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  String _loadingMessage() {
    final isHydrated = ref.watch(playerProvider).isHydrated;
    final isZoneReady = ref.watch(zoneReadyProvider);
    final isPlayerLocated = ref.watch(playerLocatedProvider);

    if (!isHydrated) return 'Unpacking your backpack...';
    if (!isZoneReady) return 'Scouting the area...';
    if (!isPlayerLocated) return 'Finding the player...';
    return 'Ready to explore!';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final message = _loadingMessage();

    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SpinningGlobe(size: 64, animate: true),
              const SizedBox(height: Spacing.xxl),
              FadeTransition(
                opacity: _titleOpacity,
                child: Text(
                  'EarthNova',
                  style: tt.displaySmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              FadeTransition(
                opacity: _subtitleOpacity,
                child: Text(
                  message,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.xxl),
              FadeTransition(
                opacity: _subtitleOpacity,
                child: Text(
                  _funFact,
                  textAlign: TextAlign.center,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
