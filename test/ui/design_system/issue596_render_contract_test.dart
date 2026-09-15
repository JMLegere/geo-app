import 'dart:ui' as ui;
import 'package:earth_nova/ui/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('a partial requirement leaves the unfilled track dark', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      ShadApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: const SizedBox(
                width: 200,
                height: 24,
                child: AppProgress(
                  current: 1,
                  requirement: 4,
                  label: 'Requirement',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final color = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final offset = (12 * image.width + 190) * 4;
      final result = Color.fromARGB(
        pixels!.getUint8(offset + 3),
        pixels.getUint8(offset),
        pixels.getUint8(offset + 1),
        pixels.getUint8(offset + 2),
      );
      image.dispose();
      return result;
    });
    expect(color, DesignPalette.inset);
  });
}
