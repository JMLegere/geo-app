import 'package:flutter/material.dart';

import '../composites/app_card.dart';
import '../foundations/app_design_theme.dart';
import '../foundations/spacing.dart';

/// Shared nearly-full-width detail surface with persistent dismissal and action
/// chrome. Feature-owned content is the only scrolling region.
class AppInspectionPanel extends StatelessWidget {
  const AppInspectionPanel({
    required this.semanticLabel,
    required this.title,
    required this.onClose,
    required this.child,
    this.footer,
    super.key,
  });

  final String semanticLabel;
  final Widget title;
  final VoidCallback onClose;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => SafeArea(
    minimum: const EdgeInsets.all(Spacing.md),
    child: LayoutBuilder(
      builder: (context, constraints) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: DesignMetrics.inspectionMaxWidth,
            maxHeight: constraints.maxHeight,
          ),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: semanticLabel,
              child: AppCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: title),
                        const SizedBox(width: Spacing.sm),
                        Semantics(
                          button: true,
                          label: 'Close item inspection',
                          child: SizedBox.square(
                            key: const Key('inspection-close'),
                            dimension: DesignMetrics.touchTarget,
                            child: IconButton(
                              autofocus: true,
                              tooltip: 'Close item inspection',
                              onPressed: onClose,
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.close,
                                color: DesignPalette.outline,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.md),
                    Flexible(
                      child: SingleChildScrollView(
                        key: const Key('inspection-scroll-view'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.only(
                          bottom: footer == null ? Spacing.sm : Spacing.lg,
                        ),
                        child: child,
                      ),
                    ),
                    if (footer != null) ...[
                      const SizedBox(height: Spacing.md),
                      footer!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
