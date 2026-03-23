import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/models/fog_state.dart';

class FogNotifier extends Notifier<Map<String, FogState>> {
  @override
  Map<String, FogState> build() {
    return {};
  }

  void updateCellFogState(String cellId, FogState newState) {
    state = {
      ...state,
      cellId: newState,
    };
  }

  FogState getCellFogState(String cellId) {
    return state[cellId] ?? FogState.unknown;
  }
}

final fogProvider =
    NotifierProvider<FogNotifier, Map<String, FogState>>(() => FogNotifier());
