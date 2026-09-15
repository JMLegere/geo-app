import 'package:flutter/material.dart';
import 'package:earth_nova/ui/design_system.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import 'main.directories.g.dart';

final _earthNovaDarkTheme = WidgetbookTheme(
  name: 'EarthNova Dark',
  data: ThemeData.dark(
    useMaterial3: true,
  ).copyWith(scaffoldBackgroundColor: DesignPalette.base),
);

void main() {
  runApp(const WidgetbookApp());
}

@widgetbook.App()
class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      directories: directories,
      addons: [
        MaterialThemeAddon(
          themes: [_earthNovaDarkTheme],
          initialTheme: _earthNovaDarkTheme,
        ),
        ViewportAddon([
          ViewportData(
            name: 'Mobile',
            width: 390,
            height: 844,
            pixelRatio: 1,
            platform: TargetPlatform.iOS,
          ),
          ViewportData(
            name: 'Desktop',
            width: 1440,
            height: 900,
            pixelRatio: 1,
            platform: TargetPlatform.linux,
          ),
        ]),
      ],
    );
  }
}
