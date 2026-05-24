import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum EarthGlyph {
  world,
  map,
  pack,
  sanctuary,
  settings,
  cells,
  steps,
  streak,
  sync,
  search,
  close,
  debug,
}

enum EarthIconTone {
  primary,
  secondary,
  tertiary,
  neutral,
  inverse,
  success,
  warning,
  danger,
}

class EarthIcon extends StatelessWidget {
  const EarthIcon({
    required this.glyph,
    this.tone = EarthIconTone.neutral,
    this.size = 20,
    super.key,
  });

  final EarthGlyph glyph;
  final EarthIconTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Icon(
      _iconData(glyph),
      size: size,
      color: _foregroundFor(tone, theme),
      semanticLabel: _semanticLabel(glyph),
    );
  }
}

IconData _iconData(EarthGlyph glyph) {
  return switch (glyph) {
    EarthGlyph.world => Icons.public,
    EarthGlyph.map => Icons.map_outlined,
    EarthGlyph.pack => Icons.inventory_2_outlined,
    EarthGlyph.sanctuary => Icons.park_outlined,
    EarthGlyph.settings => Icons.settings_outlined,
    EarthGlyph.cells => Icons.grid_view_rounded,
    EarthGlyph.steps => Icons.directions_walk_rounded,
    EarthGlyph.streak => Icons.local_fire_department_outlined,
    EarthGlyph.sync => Icons.sync_rounded,
    EarthGlyph.search => Icons.search_rounded,
    EarthGlyph.close => Icons.close_rounded,
    EarthGlyph.debug => Icons.bug_report_outlined,
  };
}

String _semanticLabel(EarthGlyph glyph) {
  return switch (glyph) {
    EarthGlyph.world => 'World',
    EarthGlyph.map => 'Map',
    EarthGlyph.pack => 'Pack',
    EarthGlyph.sanctuary => 'Sanctuary',
    EarthGlyph.settings => 'Settings',
    EarthGlyph.cells => 'Cells observed',
    EarthGlyph.steps => 'Steps',
    EarthGlyph.streak => 'Streak',
    EarthGlyph.sync => 'Syncing',
    EarthGlyph.search => 'Search',
    EarthGlyph.close => 'Close',
    EarthGlyph.debug => 'Debug',
  };
}

Color _foregroundFor(EarthIconTone tone, ThemeData theme) {
  return switch (tone) {
    EarthIconTone.primary => theme.colorScheme.primary,
    EarthIconTone.secondary => theme.colorScheme.secondary,
    EarthIconTone.tertiary => theme.colorScheme.tertiary,
    EarthIconTone.neutral => theme.colorScheme.onSurfaceVariant,
    EarthIconTone.inverse => AppTheme.onSurface,
    EarthIconTone.success => theme.colorScheme.tertiary,
    EarthIconTone.warning => theme.colorScheme.secondary,
    EarthIconTone.danger => theme.colorScheme.error,
  };
}
