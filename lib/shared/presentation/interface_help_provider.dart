import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';

final interfaceHelpProvider = NotifierProvider<InterfaceHelpNotifier, bool>(
  InterfaceHelpNotifier.new,
);

class InterfaceHelpNotifier extends ObservableNotifier<bool> {
  @override
  ObservabilityService get obs => ref.watch(appObservabilityProvider);
  @override
  String get category => 'interface_help';
  @override
  bool build() => false;
  void toggle() => transition(!state, 'interface_help.toggled');
  void dismiss() {
    if (state) transition(false, 'interface_help.dismissed');
  }
}
