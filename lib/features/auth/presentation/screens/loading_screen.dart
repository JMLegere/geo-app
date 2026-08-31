import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoadingScreen extends ConsumerWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obs = ref.watch(appObservabilityProvider);
    return ObservableScreen(
      screenName: 'loading_screen',
      observability: obs,
      builder: (_) => Scaffold(
        body: SafeArea(
          child: Center(
            child: AppCard(
              title: 'Getting ready',
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Preparing your map…'),
                  SizedBox(height: 16),
                  LoadingDots(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
