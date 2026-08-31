import 'package:flutter/material.dart';

import '../../widgets/loading_dots.dart';
import '../composites/index.dart';
import '../primitives/index.dart';
import 'app_empty_state.dart';
import 'app_error_state.dart';

class DesignLibraryExample extends StatelessWidget {
  const DesignLibraryExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppCard(
            title: 'Design system',
            description: 'Canonical shared foundation',
            child: AppBadge(label: 'Canonical'),
          ),
          const SizedBox(height: 16),
          const AppNotice(
            title: 'Usability contract',
            message:
                'Screens assemble shared components and keep actions usable.',
          ),
          const SizedBox(height: 16),
          const AppFieldRow(
            label: 'Map cell detail',
            value: 'Shared label and value alignment',
            helper: 'Use this grammar for compact detail surfaces.',
            trailing: AppBadge(label: 'Surface'),
          ),
          const SizedBox(height: 16),
          const AppStatGrid(
            items: [
              AppStatItem(
                label: 'Touch target',
                value: '44px+',
                helper: 'minimum action height',
              ),
              AppStatItem(
                label: 'Source',
                value: 'Shad',
                helper: 'neutral shared components',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const AppEmptyState(
            title: 'No sample results',
            message: 'An optional action can help users continue.',
          ),
          const SizedBox(height: 16),
          const AppErrorState(
            title: 'Sample error',
            message: 'A retry action is available when recovery is possible.',
          ),
          const SizedBox(height: 16),
          const Center(child: LoadingDots()),
          const SizedBox(height: 16),
          AppButton(label: 'Continue', onPressed: () {}, expand: true),
        ],
      ),
    );
  }
}
