import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum AppNoticeTone { info, success, warning, error }

class AppNotice extends StatelessWidget {
  const AppNotice({
    required this.title,
    required this.message,
    this.tone = AppNoticeTone.info,
    super.key,
  });

  final String title;
  final String message;
  final AppNoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final alert = tone == AppNoticeTone.error
        ? ShadAlert.destructive(
            icon: Icon(_icon),
            title: Text(title),
            description: Text(message),
          )
        : ShadAlert(
            icon: Icon(_icon),
            title: Text(title),
            description: Text(message),
          );

    return Semantics(
      container: true,
      liveRegion: true,
      label: '${tone.name}: $title. $message',
      child: ExcludeSemantics(child: alert),
    );
  }

  IconData get _icon => switch (tone) {
    AppNoticeTone.info => Icons.info_outline,
    AppNoticeTone.success => Icons.check_circle_outline,
    AppNoticeTone.warning => Icons.warning_amber_outlined,
    AppNoticeTone.error => Icons.error_outline,
  };
}
