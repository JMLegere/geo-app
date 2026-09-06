import 'package:flutter/material.dart';
import '../foundations/app_design_theme.dart';

enum AppTextRole { body, label, value, compact, itemName, action, ribbon }

class AppText extends StatelessWidget {
  const AppText(this.text, {this.role = AppTextRole.body, super.key});
  final String text;
  final AppTextRole role;
  @override
  Widget build(BuildContext context) {
    final style = switch (role) {
      AppTextRole.body => DesignTypography.body,
      AppTextRole.label => DesignTypography.label,
      AppTextRole.value => DesignTypography.value,
      AppTextRole.compact => DesignTypography.compact,
      AppTextRole.itemName => DesignTypography.itemName,
      AppTextRole.action => DesignTypography.action,
      AppTextRole.ribbon => DesignTypography.ribbon,
    };
    final outlined = role == AppTextRole.itemName || role == AppTextRole.action;
    Widget content = Text(
      text,
      style: style,
      softWrap: role != AppTextRole.itemName,
    );
    if (outlined) {
      content = Stack(
        children: [
          Text(
            text,
            softWrap: role != AppTextRole.itemName,
            style: style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.5
                ..color = DesignPalette.outline,
            ),
          ),
          content,
        ],
      );
    }
    if (role == AppTextRole.itemName) {
      content = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: content,
      );
    }
    return Semantics(
      label: text,
      child: ExcludeSemantics(child: content),
    );
  }
}
