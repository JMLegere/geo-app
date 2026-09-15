import 'package:flutter/material.dart';
import '../primitives/app_button.dart';
import '../foundations/spacing.dart';

class AppActionRow extends StatelessWidget {
  const AppActionRow({required this.actions, super.key})
    : assert(actions.length > 0 && actions.length <= 2);
  final List<AppButton> actions;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (index, action) in actions.indexed) ...[
        if (index > 0) const SizedBox(width: Spacing.md),
        Expanded(
          child: AppButton(
            key: action.key,
            label: action.label,
            onPressed: action.onPressed,
            variant: action.variant,
            leading: action.leading,
            trailing: action.trailing,
            isLoading: action.isLoading,
            expand: true,
            unavailableReason: action.unavailableReason,
            cost: action.cost,
            reward: action.reward,
          ),
        ),
      ],
    ],
  );
}
