import 'package:flutter/material.dart';
import '../foundations/app_design_theme.dart';
import '../foundations/spacing.dart';

class AppRibbon extends StatelessWidget {
  const AppRibbon({required this.title, super.key});
  final String title;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Align(
      child: SizedBox(
        width: constraints.maxWidth / 2,
        child: CustomPaint(
          key: const Key('app-ribbon-material'),
          painter: const _RibbonPainter(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg,
              vertical: Spacing.sm,
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: DesignTypography.ribbon,
            ),
          ),
        ),
      ),
    ),
  );
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final fold = Spacing.sm;
    final ends = Path()
      ..moveTo(-fold, fold)
      ..lineTo(size.width + fold, fold)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width + fold, size.height)
      ..lineTo(-fold, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
    canvas.drawPath(ends, Paint()..color = DesignPalette.emphasis);
    final front = RRect.fromRectAndRadius(
      Offset.zero & Size(size.width, size.height - Spacing.xs),
      const Radius.circular(2),
    );
    canvas.drawShadow(Path()..addRRect(front), DesignPalette.shadow, 3, false);
    canvas.drawRRect(front, Paint()..color = DesignPalette.text);
  }

  @override
  bool shouldRepaint(_RibbonPainter oldDelegate) => false;
}
