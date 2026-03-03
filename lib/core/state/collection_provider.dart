import 'package:flutter_riverpod/flutter_riverpod.dart';

class CollectionState {
  final List<String> collectedSpeciesIds;

  CollectionState({
    List<String>? collectedSpeciesIds,
  }) : collectedSpeciesIds = collectedSpeciesIds ?? [];

  int get totalCollected => collectedSpeciesIds.length;

  CollectionState copyWith({
    List<String>? collectedSpeciesIds,
  }) {
    return CollectionState(
      collectedSpeciesIds: collectedSpeciesIds ?? this.collectedSpeciesIds,
    );
  }
}

class CollectionNotifier extends Notifier<CollectionState> {
  @override
  CollectionState build() {
    return CollectionState();
  }

  void addSpecies(String speciesId) {
    if (!state.collectedSpeciesIds.contains(speciesId)) {
      state = state.copyWith(
        collectedSpeciesIds: [...state.collectedSpeciesIds, speciesId],
      );
    }
  }

  void removeSpecies(String speciesId) {
    if (state.collectedSpeciesIds.contains(speciesId)) {
      state = state.copyWith(
        collectedSpeciesIds: state.collectedSpeciesIds
            .where((id) => id != speciesId)
            .toList(),
      );
    }
  }

  bool isCollected(String speciesId) {
    return state.collectedSpeciesIds.contains(speciesId);
  }
}

final collectionProvider =
    NotifierProvider<CollectionNotifier, CollectionState>(
        () => CollectionNotifier());
