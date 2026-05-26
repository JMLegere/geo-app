import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../composites/index.dart';
import '../primitives/index.dart';

class DesignLibraryExample extends StatelessWidget {
  const DesignLibraryExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.lg),
      child: EarthPanel(
        title: 'Design system',
        eyebrow: 'canonical',
        tone: EarthPanelTone.accent,
        actions: const [
          EarthTag(label: 'canonical', tone: EarthTagTone.success),
          EarthTag(label: 'mobile-first', tone: EarthTagTone.accent),
          EarthIcon(glyph: EarthGlyph.world, tone: EarthIconTone.tertiary),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            EarthNotice(
              title: 'Usability contract',
              message:
                  'Screens should assemble named design components, keep touch targets usable, and make map/discovery state legible before adding ornament.',
            ),
            SizedBox(height: Spacing.lg),
            EarthFieldRow(
              label: 'Map cell detail',
              value: 'Field-note panel before downstream reward reveal',
              helper:
                  'Use this grammar for status, terrain, visit facts, and provenance.',
              trailing: EarthTag(label: 'surface'),
            ),
            SizedBox(height: Spacing.lg),
            EarthStatGrid(
              items: [
                EarthStatItem(
                    label: 'touch', value: '44px+', helper: 'minimum target'),
                EarthStatItem(
                    label: 'source',
                    value: 'tokens',
                    helper: 'no ad hoc styles'),
              ],
            ),
            SizedBox(height: Spacing.lg),
            EarthActionButton(
              label: 'Continue',
              onPressed: null,
              actionId: null,
              tone: EarthActionTone.primary,
              expand: true,
            ),
          ],
        ),
      ),
    );
  }
}
