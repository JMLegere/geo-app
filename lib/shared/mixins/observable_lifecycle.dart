import 'package:flutter/widgets.dart';

import 'package:earth_nova/core/services/observability_buffer.dart';

mixin ObservableLifecycle<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    ObservabilityBuffer.instance?.ui('mount:${widget.runtimeType}');
  }

  @override
  void dispose() {
    ObservabilityBuffer.instance?.ui('dispose:${widget.runtimeType}');
    super.dispose();
  }
}
