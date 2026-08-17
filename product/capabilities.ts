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
      "The player experiences the real world as a playable map with trusted position, fog, Cell Visits, territory scale, and event cues; the legacy map-cell-entry evidence is not the approved Encounter model.",
    emotionalReward:
      "My real world is becoming a playable map that grows as I move.",
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
    description:
      "The player studies animals, behavior, tracks, and migrations.",
    emotionalReward: "Index-led curiosity about animal life.",
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
      "Legacy capability evidence only. Mycology is not one of the five resolved EarthNova Disciplines.",
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
    cucumberFeatures: [
      spineFeature,
      "features/field-guide-paleontology.feature",
    ],
    requiredActions: [
      playerActions.viewPaleontologyGuide,
      playerActions.inspectFossilRecord,
    ],
  }),
  genetics: capability({
    id: "genetics",
    label: "Genetics",
    description:
      "Legacy capability evidence only. Genetics is not one of the five resolved EarthNova Disciplines, and lineage behavior remains open.",
    emotionalReward: "Historical evidence only; no current Discipline promise.",
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
    cucumberFeatures: [
      spineFeature,
      "features/field-guide-archaeology.feature",
    ],
    requiredActions: [
      playerActions.viewArchaeologyGuide,
      playerActions.inspectArtifactRecord,
    ],
  }),
  explorationDiscoveryLifecycle: capability({
    id: "exploration-discovery-lifecycle",
    label: "Exploration-Discovery Lifecycle",
    description:
      "Exploration records Cell Visits; each Visit may create one Encounter, whose Outcomes may generate exact Items. Pack projects every owned active Item newest first. Examination records durable Base Item Journal knowledge, while a distinct known-Villager Identification Service resolves only the examined Item's exact-version Property Values.",
    emotionalReward:
      "Every walk can become a meaningful Item whose identity and exact properties are learned deliberately.",
    cucumberFeatures: [
      spineFeature,
      "features/exploration-discovery-discovery.feature",
      "features/exploration-discovery-mvp-loop.feature",
      "features/exploration-discovery-pack.feature",
      "features/exploration-discovery-identification.feature",
    ],
    requiredActions: [
      playerActions.resolvePresentEncounter,
      playerActions.continueDiscoveryReward,
      playerActions.openPack,
      playerActions.inspectPackFind,
      playerActions.examinePackItem,
      playerActions.openIdentificationService,
      playerActions.identifyUnidentifiedFind,
      playerActions.revealIdentification,
    ],
    workflows: [playerActionWorkflows.discoveryOwnership],
  }),
  livingWorld: capability({
    id: "living-world",
    label: "Living World",
    description:
      "The approved target presents known Venues, Villagers, and their Services in Town. Existing NPC-led feature evidence is legacy terminology and does not establish target implementation.",
    emotionalReward:
      "The world feels inhabited by helpful local experts rather than abstract menus.",
    cucumberFeatures: [
      spineFeature,
      "features/living-world-town.feature",
      "features/progression-release-to-wild.feature",
    ],
    requiredActions: [
      playerActions.discoverNpcVenue,
      playerActions.openTown,
      playerActions.openNpcLedFeature,
      playerActions.openNpcVenueDetail,
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
      "The approved target keeps durable knowledge in Index and one personal Home. Legacy Field Guide, Sanctuary, Orb crafting, and other progression evidence remain explicitly open or historical rather than active target behavior.",
    emotionalReward:
      "My identified Items and Discoveries become a lasting world that is mine.",
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
      "Aspirational historical capability evidence for quests, achievements, and recaps; this entry does not authorize or assert current target behavior.",
    emotionalReward:
      "I know what to do next and feel proud of what I have done.",
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
      "Aspirational historical capability evidence for community events, trading, and multiplayer; this entry does not authorize or assert current target behavior.",
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
