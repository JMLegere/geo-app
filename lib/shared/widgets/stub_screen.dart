import 'package:flutter/material.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';

/// Stub screen for features not yet built.
class StubScreen extends StatelessWidget {
  const StubScreen({required this.label, super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$label — Coming soon',
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'More discoveries on the way!',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
