import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';

/// Stub screen for features not yet built.
class StubScreen extends ConsumerWidget {
  const StubScreen({required this.label, super.key});
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obs = ref.watch(appObservabilityProvider);

    return ObservableScreen(
      screenName: 'stub_screen',
      observability: obs,
      builder: (_) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(Spacing.xxl),
              child: AppCard(
                title: label,
                child: AppNotice(
                  title: '$label — Coming soon',
                  message: 'More discoveries on the way!',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
