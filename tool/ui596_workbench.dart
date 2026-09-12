import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:earth_nova/shared/design.dart';

// Isolated review entry point: uses production widgets, no backend or auth.
void main() => runApp(ui596Workbench());

Widget ui596Workbench() => ShadApp(
  theme: AppDesignTheme.dark(),
  home: Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppRibbon(title: 'Pack'),
            const SizedBox(height: Spacing.xxl),
            const AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText('EarthNova', role: AppTextRole.itemName),
                  SizedBox(height: Spacing.sm),
                  AppText('Shared foundation review', role: AppTextRole.label),
                  SizedBox(height: Spacing.sm),
                  AppText(
                    'Forest surfaces, cream lettering and friendly conservation technology.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.xxl),
            const AppStatGrid(
              inspection: true,
              items: [
                AppStatItem(
                  label: 'Length',
                  value: '12 cm',
                  icon: Icon(Icons.straighten),
                ),
                AppStatItem(
                  label: 'Mass',
                  value: '80 g',
                  icon: Icon(Icons.balance),
                ),
                AppStatItem(
                  label: 'Condition',
                  value: '?',
                  icon: Icon(Icons.favorite_border),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xxl),
            const AppCard(
              tone: AppSurfaceTone.inset,
              child: AppText(
                'Workbench values are fixtures, not new gameplay properties.',
              ),
            ),
            const SizedBox(height: Spacing.lg),
            const AppProgress(
              current: 1,
              requirement: 4,
              label: 'Example requirement',
            ),
            const SizedBox(height: Spacing.lg),
            const AppProgress(
              current: 4,
              requirement: 4,
              label: 'Completed example',
            ),
            const SizedBox(height: Spacing.xxl),
            AppActionRow(
              actions: [
                AppButton(label: 'Continue', onPressed: () {}),
                const AppButton(
                  label: 'Unavailable',
                  onPressed: null,
                  unavailableReason:
                      'This example shows an unavailable action.',
                  variant: AppButtonVariant.secondary,
                ),
              ],
            ),
            const SizedBox(height: Spacing.xxl),
            Row(
              children: [
                Expanded(
                  child: AppNavButton(
                    label: 'Map',
                    icon: const Icon(Icons.map_outlined),
                    selected: true,
                    onPressed: () {},
                  ),
                ),
                Expanded(
                  child: AppNavButton(
                    label: 'Pack',
                    icon: const Icon(Icons.backpack_outlined),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            AppNavButton(
              label: 'Pack selected',
              icon: const Icon(Icons.backpack_outlined),
              selected: true,
              showLabel: true,
              onPressed: () {},
            ),
          ],
        ),
      ),
    ),
  ),
);
