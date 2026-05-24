import {
  playerActions,
  playerActionWorkflows,
  type PlayerActionId,
  type PlayerActionWorkflowId,
} from "./actions.ts";

type CapabilityInput = {
  id: string;
  label: string;
  description: string;
  emotionalReward: string;
  cucumberFeatures: readonly string[];
  requiredActions?: readonly PlayerActionId[];
  workflows?: readonly PlayerActionWorkflowId[];
};

const capability = ({
  id,
  requiredActions = [],
  workflows = [],
  ...spec
}: CapabilityInput) => ({
  id,
  ...spec,
  tag: `@capability.${id}`,
  requiredActions,
  workflows,
});

const spineFeature = "features/capability-spine.feature";

export const productCapabilities = {
  map: capability({
    id: "map",
    label: "Map",
    description:
      "The player experiences the real world as a playable map made of framing, trusted position, fog, reward-clean map-cell entry, territory scale, and event cues.",
    emotionalReward: "My real world is becoming a playable map that grows as I move.",
    cucumberFeatures: [
      spineFeature,
      "features/map-frame.feature",
      "features/map-debug-controls.feature",
      "features/map-player-marker-accuracy-ring.feature",
      "features/map-fog-overlay.feature",
      "features/map-cell-detail-sheet.feature",
      "features/map-nearby-opportunity-layer.feature",
      "features/map-world-event-cue-layer.feature",
      "features/map-districts.feature",
      "features/map-cities.feature",
      "features/map-states.feature",
      "features/map-countries.feature",
      "features/map-world.feature",
      "features/map-territory-navigation.feature",
      "features/map-exploration-eligibility-state.feature",
      "features/map-cell-entry-model.feature",
      "features/map-fog-state-model.feature",
      "features/map-territory-progress-model.feature",
      "features/map-global-map-state-model.feature",
      "features/map-world-event-instance-model.feature",
    ],
    requiredActions: [
      playerActions.openMap,
      playerActions.readMapStatus,
      playerActions.moveInRealWorld,
      playerActions.crossMapCellBorder,
      playerActions.inspectMapCell,
      playerActions.inspectNearbyOpportunity,
      playerActions.inspectWorldEventCue,
      playerActions.changeTerritoryScale,
      playerActions.browseTerritoryProgress,
    ],
    workflows: [playerActionWorkflows.mapExploration],
  }),
  zoology: capability({
    id: "zoology",
    label: "Zoology",
    description: "The player studies animals, behavior, tracks, and migrations.",
    emotionalReward: "Field-guide curiosity about animal life.",
    cucumberFeatures: [spineFeature, "features/field-guide-zoology.feature"],
    requiredActions: [
      playerActions.viewZoologyGuide,
      playerActions.inspectAnimalRecord,
    ],
  }),
  botany: capability({
    id: "botany",
    label: "Botany",
    description: "The player studies plants and the habitats where they grow.",
    emotionalReward: "Attention to living detail in everyday places.",
    cucumberFeatures: [spineFeature, "features/field-guide-botany.feature"],
    requiredActions: [
      playerActions.viewBotanyGuide,
      playerActions.inspectPlantRecord,
    ],
  }),
  mycology: capability({
    id: "mycology",
    label: "Mycology",
    description:
      "The player studies fungi, spores, substrates, and seasonal conditions.",
    emotionalReward: "Hidden-world curiosity.",
    cucumberFeatures: [spineFeature, "features/field-guide-mycology.feature"],
    requiredActions: [
      playerActions.viewMycologyGuide,
      playerActions.inspectFungusRecord,
    ],
  }),
  geology: capability({
    id: "geology",
    label: "Geology",
    description: "The player studies rocks, minerals, and landforms.",
    emotionalReward: "Reading the earth itself.",
    cucumberFeatures: [spineFeature, "features/field-guide-geology.feature"],
    requiredActions: [
      playerActions.viewGeologyGuide,
      playerActions.inspectRockMineralRecord,
    ],
  }),
  paleontology: capability({
    id: "paleontology",
    label: "Paleontology",
    description: "The player studies fossils, extinct life, and deep time.",
    emotionalReward: "Wonder at ancient life beneath present map cells.",
    cucumberFeatures: [spineFeature, "features/field-guide-paleontology.feature"],
    requiredActions: [
      playerActions.viewPaleontologyGuide,
      playerActions.inspectFossilRecord,
    ],
  }),
  genetics: capability({
    id: "genetics",
    label: "Genetics",
    description:
      "The player studies inherited traits, variation, and how life changes across generations.",
    emotionalReward: "Pattern recognition and possibility.",
    cucumberFeatures: [spineFeature, "features/field-guide-genetics.feature"],
    requiredActions: [
      playerActions.viewGeneticsGuide,
      playerActions.inspectTraitInheritance,
    ],
  }),
  archaeology: capability({
    id: "archaeology",
    label: "Archaeology",
    description:
      "The player studies artifacts, ruins, and human traces in places.",
    emotionalReward: "Uncovering hidden human history.",
    cucumberFeatures: [spineFeature, "features/field-guide-archaeology.feature"],
    requiredActions: [
      playerActions.viewArchaeologyGuide,
      playerActions.inspectArtifactRecord,
    ],
  }),
  explorationDiscoveryLifecycle: capability({
    id: "exploration-discovery-lifecycle",
    label: "Exploration-Discovery Lifecycle",
    description:
      "The player turns walking and map cell entry into unidentified finds, identification reveals, known finds, and find stories.",
    emotionalReward: "Every walk can become a meaningful find and a story I keep.",
    cucumberFeatures: [
      spineFeature,
      "features/exploration-discovery-discovery.feature",
      "features/exploration-discovery-pack.feature",
      "features/exploration-discovery-identification.feature",
    ],
    requiredActions: [
      playerActions.continueDiscoveryReward,
      playerActions.openPack,
      playerActions.inspectPackFind,
      playerActions.identifyUnidentifiedFind,
      playerActions.revealIdentification,
    ],
    workflows: [playerActionWorkflows.discoveryOwnership],
  }),
  livingWorld: capability({
    id: "living-world",
    label: "Living World",
    description:
      "The player discovers NPC venues in real places, unlocks NPC-led feature entries in Town, and opens those features through local authored roles.",
    emotionalReward: "The world feels inhabited by helpful local experts rather than abstract menus.",
    cucumberFeatures: [
      spineFeature,
      "features/living-world-town.feature",
      "features/progression-release-to-wild.feature",
    ],
    requiredActions: [
      playerActions.discoverNpcVenue,
      playerActions.openTown,
      playerActions.openNpcLedFeature,
      playerActions.openReleaseToWild,
    ],
    workflows: [
      playerActionWorkflows.npcFeatureUnlock,
      playerActionWorkflows.releaseToWild,
    ],
  }),
  progressionPermanence: capability({
    id: "progression-permanence",
    label: "Progression-Permanence",
    description:
      "The player turns finds into durable progress through the field guide, collections, sanctuary growth, buddy care, lineage, and stewardship.",
    emotionalReward: "My discoveries become a lasting world that is mine.",
    cucumberFeatures: [
      spineFeature,
      "features/progression-field-guide.feature",
      "features/progression-conservation.feature",
      "features/progression-release-to-wild.feature",
      "features/progression-orb-crafting.feature",
      "features/progression-collections.feature",
      "features/progression-sanctuary.feature",
      "features/progression-buddy.feature",
      "features/progression-lineage.feature",
    ],
    requiredActions: [
      playerActions.openFieldGuide,
      playerActions.inspectFieldGuideEntry,
      playerActions.viewConservationGoal,
      playerActions.contributeToConservation,
      playerActions.openReleaseToWild,
      playerActions.inspectReleaseBundle,
      playerActions.releaseAnimalToWild,
      playerActions.useOrbOnAnimal,
      playerActions.openCollections,
      playerActions.addFindToCollection,
      playerActions.openSanctuary,
      playerActions.placeFindInSanctuary,
      playerActions.selectBuddy,
      playerActions.careForBuddy,
      playerActions.pairLineage,
      playerActions.inspectLineageOffspring,
    ],
    workflows: [
      playerActionWorkflows.conservationContribution,
      playerActionWorkflows.releaseToWild,
      playerActionWorkflows.orbCrafting,
      playerActionWorkflows.collectionCommitment,
      playerActionWorkflows.sanctuaryPlacement,
      playerActionWorkflows.buddyCare,
      playerActionWorkflows.lineageBreeding,
    ],
  }),
  motivation: capability({
    id: "motivation",
    label: "Motivation",
    description:
      "The player gets reasons to return, goals to pursue, milestones to celebrate, and recaps that explain what changed.",
    emotionalReward: "I know what to do next and feel proud of what I have done.",
    cucumberFeatures: [
      spineFeature,
      "features/motivation-quests.feature",
      "features/motivation-achievements.feature",
      "features/motivation-recap.feature",
    ],
    requiredActions: [
      playerActions.openQuestBoard,
      playerActions.inspectQuest,
      playerActions.claimQuestReward,
      playerActions.viewAchievements,
      playerActions.inspectAchievement,
      playerActions.viewRecap,
      playerActions.dismissRecap,
    ],
    workflows: [
      playerActionWorkflows.questRewards,
      playerActionWorkflows.recapAcknowledgement,
    ],
  }),
  multiplayer: capability({
    id: "multiplayer",
    label: "Multiplayer",
    description:
      "The player participates in shared progress, community events, trading, and multiplayer meaning without losing the cozy solo loop.",
    emotionalReward: "I am part of a larger living world with other explorers.",
    cucumberFeatures: [
      spineFeature,
      "features/multiplayer-community.feature",
      "features/multiplayer-economy.feature",
    ],
    requiredActions: [
      playerActions.openCommunity,
      playerActions.inspectCommunityEvent,
      playerActions.contributeToCommunityProgress,
      playerActions.openEconomy,
      playerActions.offerTrade,
      playerActions.acceptTrade,
    ],
    workflows: [
      playerActionWorkflows.communityContribution,
      playerActionWorkflows.tradeExchange,
    ],
  }),
} as const;
