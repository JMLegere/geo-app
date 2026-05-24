import 'package:flutter/material.dart';

import 'package:earth_nova/shared/theme/app_theme.dart';

/// Animated loading indicator for map/bootstrap surfaces.
class LoadingDots extends StatelessWidget {
  const LoadingDots({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.tertiary),
          ),
        ),
      ),
    );
  }
}
