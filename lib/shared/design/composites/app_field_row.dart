import 'package:flutter/material.dart';

class AppFieldRow extends StatelessWidget {
  const AppFieldRow({
    required this.label,
    required this.value,
    this.helper,
    this.trailing,
    super.key,
  });

  final String label;
  final String value;
  final String? helper;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                const SizedBox(height: 4),
                Text(value),
                if (helper != null) ...[
                  const SizedBox(height: 4),
                  Text(helper!),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
