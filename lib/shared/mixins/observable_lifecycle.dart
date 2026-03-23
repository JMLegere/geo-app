import 'package:flutter/widgets.dart';

import 'package:earth_nova/core/services/observability_buffer.dart';

mixin ObservableLifecycle<T extends StatefulWidget> on State<T> {
  /// Override to provide an unminified name for production builds.
  String get observabilityName;

  @override
  void initState() {
    super.initState();
    ObservabilityBuffer.instance?.event('ui_mount', {
      'widget': observabilityName,
    });
  }

  @override
  void dispose() {
    ObservabilityBuffer.instance?.event('ui_dispose', {
      'widget': observabilityName,
    });
    super.dispose();
  }
}
