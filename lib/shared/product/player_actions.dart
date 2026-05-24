typedef PlayerActionId = String;

abstract final class PlayerActions {
  static const PlayerActionId openMap = 'open-map';
  static const PlayerActionId readMapStatus = 'read-map-status';
  static const PlayerActionId moveInRealWorld = 'move-in-real-world';
  static const PlayerActionId crossMapCellBorder = 'cross-map-cell-border';
  static const PlayerActionId inspectMapCell = 'inspect-map-cell';
  static const PlayerActionId inspectNearbyOpportunity =
      'inspect-nearby-opportunity';
  static const PlayerActionId inspectWorldEventCue = 'inspect-world-event-cue';
  static const PlayerActionId changeTerritoryScale = 'change-territory-scale';
  static const PlayerActionId browseTerritoryProgress =
      'browse-territory-progress';

  static const PlayerActionId viewZoologyGuide = 'view-zoology-guide';
  static const PlayerActionId inspectAnimalRecord = 'inspect-animal-record';
  static const PlayerActionId viewBotanyGuide = 'view-botany-guide';
  static const PlayerActionId inspectPlantRecord = 'inspect-plant-record';
  static const PlayerActionId viewMycologyGuide = 'view-mycology-guide';
  static const PlayerActionId inspectFungusRecord = 'inspect-fungus-record';
  static const PlayerActionId viewGeologyGuide = 'view-geology-guide';
  static const PlayerActionId inspectRockMineralRecord =
      'inspect-rock-mineral-record';
  static const PlayerActionId viewPaleontologyGuide = 'view-paleontology-guide';
  static const PlayerActionId inspectFossilRecord = 'inspect-fossil-record';
  static const PlayerActionId viewGeneticsGuide = 'view-genetics-guide';
  static const PlayerActionId inspectTraitInheritance =
      'inspect-trait-inheritance';
  static const PlayerActionId viewArchaeologyGuide = 'view-archaeology-guide';
  static const PlayerActionId inspectArtifactRecord = 'inspect-artifact-record';

  static const PlayerActionId continueDiscoveryReward =
      'continue-discovery-reward';
  static const PlayerActionId openPack = 'open-pack';
  static const PlayerActionId inspectPackFind = 'inspect-pack-find';
  static const PlayerActionId identifyUnidentifiedFind =
      'identify-unidentified-find';
  static const PlayerActionId revealIdentification = 'reveal-identification';
  static const PlayerActionId discoverNpcVenue = 'discover-npc-venue';
  static const PlayerActionId openTown = 'open-town';
  static const PlayerActionId openNpcLedFeature = 'open-npc-led-feature';

  static const PlayerActionId openFieldGuide = 'open-field-guide';
  static const PlayerActionId inspectFieldGuideEntry =
      'inspect-field-guide-entry';
  static const PlayerActionId viewConservationGoal = 'view-conservation-goal';
  static const PlayerActionId contributeToConservation =
      'contribute-to-conservation';
  static const PlayerActionId openCollections = 'open-collections';
  static const PlayerActionId addFindToCollection = 'add-find-to-collection';
  static const PlayerActionId openSanctuary = 'open-sanctuary';
  static const PlayerActionId placeFindInSanctuary = 'place-find-in-sanctuary';
  static const PlayerActionId selectBuddy = 'select-buddy';
  static const PlayerActionId careForBuddy = 'care-for-buddy';
  static const PlayerActionId pairLineage = 'pair-lineage';
  static const PlayerActionId inspectLineageOffspring =
      'inspect-lineage-offspring';

  static const PlayerActionId openQuestBoard = 'open-quest-board';
  static const PlayerActionId inspectQuest = 'inspect-quest';
  static const PlayerActionId claimQuestReward = 'claim-quest-reward';
  static const PlayerActionId viewAchievements = 'view-achievements';
  static const PlayerActionId inspectAchievement = 'inspect-achievement';
  static const PlayerActionId viewRecap = 'view-recap';
  static const PlayerActionId dismissRecap = 'dismiss-recap';

  static const PlayerActionId openCommunity = 'open-community';
  static const PlayerActionId inspectCommunityEvent = 'inspect-community-event';
  static const PlayerActionId contributeToCommunityProgress =
      'contribute-to-community-progress';
  static const PlayerActionId openEconomy = 'open-economy';
  static const PlayerActionId offerTrade = 'offer-trade';
  static const PlayerActionId acceptTrade = 'accept-trade';

  static const all = <PlayerActionId>{
    openMap,
    readMapStatus,
    moveInRealWorld,
    crossMapCellBorder,
    inspectMapCell,
    inspectNearbyOpportunity,
    inspectWorldEventCue,
    changeTerritoryScale,
    browseTerritoryProgress,
    viewZoologyGuide,
    inspectAnimalRecord,
    viewBotanyGuide,
    inspectPlantRecord,
    viewMycologyGuide,
    inspectFungusRecord,
    viewGeologyGuide,
    inspectRockMineralRecord,
    viewPaleontologyGuide,
    inspectFossilRecord,
    viewGeneticsGuide,
    inspectTraitInheritance,
    viewArchaeologyGuide,
    inspectArtifactRecord,
    continueDiscoveryReward,
    openPack,
    inspectPackFind,
    identifyUnidentifiedFind,
    revealIdentification,
    discoverNpcVenue,
    openTown,
    openNpcLedFeature,
    openFieldGuide,
    inspectFieldGuideEntry,
    viewConservationGoal,
    contributeToConservation,
    openCollections,
    addFindToCollection,
    openSanctuary,
    placeFindInSanctuary,
    selectBuddy,
    careForBuddy,
    pairLineage,
    inspectLineageOffspring,
    openQuestBoard,
    inspectQuest,
    claimQuestReward,
    viewAchievements,
    inspectAchievement,
    viewRecap,
    dismissRecap,
    openCommunity,
    inspectCommunityEvent,
    contributeToCommunityProgress,
    openEconomy,
    offerTrade,
    acceptTrade,
  };

  static bool isKnown(PlayerActionId actionId) => all.contains(actionId);

  static PlayerActionId requireKnown(PlayerActionId actionId) {
    if (!isKnown(actionId)) {
      throw ArgumentError.value(
          actionId, 'actionId', 'Unknown player action id');
    }
    return actionId;
  }
}
