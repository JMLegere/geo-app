import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fog_of_world/core/models/fog_state.dart';

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
    return state[cellId] ?? FogState.undetected;
  }
}

final fogProvider =
    NotifierProvider<FogNotifier, Map<String, FogState>>(() => FogNotifier());
