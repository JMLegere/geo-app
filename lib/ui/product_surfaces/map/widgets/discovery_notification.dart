import 'package:flutter/material.dart';

import 'package:earth_nova/ui/design_system.dart';

/// Brief first-entry feedback shown below the Map status bar.
class DiscoveryNotification extends StatelessWidget {
  const DiscoveryNotification({super.key, required this.cellName});

  final String cellName;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: AppNotice(
        title: 'New cell',
        message: cellName.isEmpty ? 'Unknown Cell' : cellName,
        tone: AppNoticeTone.success,
      ),
    );
  }
}
