export const playerActionWorkflows = {
  mapExploration: "map-exploration",
  discoveryOwnership: "discovery-ownership",
  conservationContribution: "conservation-contribution",
  releaseToWild: "release-to-wild",
  npcFeatureUnlock: "npc-feature-unlock",
  collectionCommitment: "collection-commitment",
  sanctuaryPlacement: "sanctuary-placement",
  buddyCare: "buddy-care",
  lineageBreeding: "lineage-breeding",
  questRewards: "quest-rewards",
  recapAcknowledgement: "recap-acknowledgement",
  communityContribution: "community-contribution",
  tradeExchange: "trade-exchange",
} as const;

export type PlayerActionWorkflowKey = keyof typeof playerActionWorkflows;
export type PlayerActionWorkflowId =
  (typeof playerActionWorkflows)[PlayerActionWorkflowKey];

type ActionInput = {
  id: string;
  label: string;
  kind: "navigation" | "inspection" | "mutation" | "physical";
  actor: "player";
  surface: string;
  risk: "low" | "medium";
  auth: "authenticated player";
  boundary: string;
  workflow: PlayerActionWorkflowId | null;
  verification: { required: string[] };
};

const action = <const Spec extends ActionInput>(spec: Spec) => spec;

const viewAction = <const Id extends string>(
  id: Id,
  label: string,
  surface: string,
  boundary: string,
  workflow: PlayerActionWorkflowId | null = null,
) =>
  action({
    id,
    label,
    kind: "inspection",
    actor: "player",
    surface,
    risk: "low",
    auth: "authenticated player",
    boundary,
    workflow,
    verification: { required: ["bdd", "manual"] },
  });

const navigationAction = <const Id extends string>(
  id: Id,
  label: string,
  surface: string,
  boundary: string,
  workflow: PlayerActionWorkflowId | null = null,
) =>
  action({
    id,
    label,
    kind: "navigation",
    actor: "player",
    surface,
    risk: "low",
    auth: "authenticated player",
    boundary,
    workflow,
    verification: { required: ["bdd", "manual"] },
  });

const physicalAction = <const Id extends string>(
  id: Id,
  label: string,
  surface: string,
  boundary: string,
  workflow: PlayerActionWorkflowId | null = null,
) =>
  action({
    id,
    label,
    kind: "physical",
    actor: "player",
    surface,
    risk: "low",
    auth: "authenticated player",
    boundary,
    workflow,
    verification: { required: ["bdd", "manual"] },
  });

const mutationAction = <const Id extends string>(
  id: Id,
  label: string,
  surface: string,
  boundary: string,
  workflow: PlayerActionWorkflowId | null = null,
) =>
  action({
    id,
    label,
    kind: "mutation",
    actor: "player",
    surface,
    risk: "medium",
    auth: "authenticated player",
    boundary,
    workflow,
    verification: { required: ["bdd", "unit"] },
  });

export const actionCapabilities = {
  openMap: navigationAction(
    "open-map",
    "Open the Map",
    "Map tab",
    "makes the GPS-level Map the active play surface without granting exploration progress",
    playerActionWorkflows.mapExploration,
  ),
  readMapStatus: viewAction(
    "read-map-status",
    "Read map status",
    "Map status bar and readiness overlays",
    "shows current playability, pending visits, and map readiness without mutating progression",
    playerActionWorkflows.mapExploration,
  ),
  moveInRealWorld: physicalAction(
    "move-in-real-world",
    "Move in the real world",
    "Physical movement interpreted by the Map",
    "updates location, camera, and marker state through trusted movement gates",
    playerActionWorkflows.mapExploration,
  ),
  crossMapCellBorder: mutationAction(
    "cross-map-cell-border",
    "Enter a different map cell",
    "Physical movement plus Map cell overlay",
    "turns eligible movement into one reward-clean map-cell entry event; crossing a Voronoi border is the geometric detection detail",
    playerActionWorkflows.mapExploration,
  ),
  inspectMapCell: viewAction(
    "inspect-map-cell",
    "Inspect a map cell",
    "Map cell detail sheet",
    "opens read-only map cell context, visit facts, territory context, and handoff affordances",
    playerActionWorkflows.mapExploration,
  ),
  inspectNearbyOpportunity: viewAction(
    "inspect-nearby-opportunity",
    "Inspect a nearby opportunity",
    "Nearby opportunity layer",
    "lets the player inspect a reachable cue without forcing a quest or discovery reward",
  ),
  inspectWorldEventCue: viewAction(
    "inspect-world-event-cue",
    "Inspect a world event cue",
    "World event cue layer",
    "opens optional event context while event-specific rewards remain downstream",
  ),
  changeTerritoryScale: navigationAction(
    "change-territory-scale",
    "Change territory scale",
    "Map zoom ladder",
    "moves between GPS, District, City, State, Country, and World map scopes",
  ),
  browseTerritoryProgress: viewAction(
    "browse-territory-progress",
    "Browse territory progress",
    "District, City, State, Country, and World views",
    "reads rolled-up exploration progress without changing visit history",
  ),

  viewZoologyGuide: navigationAction(
    "view-zoology-guide",
    "View Zoology guide",
    "Field Guide Zoology section",
    "opens animal-focused knowledge organized around fauna, behavior, signs, and migrations",
  ),
  inspectAnimalRecord: viewAction(
    "inspect-animal-record",
    "Inspect an animal record",
    "Field Guide animal record",
    "shows animal facts, observations, habitats, and discovered history without changing ownership",
  ),
  viewBotanyGuide: navigationAction(
    "view-botany-guide",
    "View Botany guide",
    "Field Guide Botany section",
    "opens plant-focused knowledge organized around flora, growth, habitats, and seasons",
  ),
  inspectPlantRecord: viewAction(
    "inspect-plant-record",
    "Inspect a plant record",
    "Field Guide plant record",
    "shows plant facts, observations, growth context, and discovered history without changing ownership",
  ),
  viewMycologyGuide: navigationAction(
    "view-mycology-guide",
    "View Mycology guide",
    "Field Guide Mycology section",
    "opens fungi-focused knowledge organized around fungi, substrates, spores, and hidden conditions",
  ),
  inspectFungusRecord: viewAction(
    "inspect-fungus-record",
    "Inspect a fungus record",
    "Field Guide fungus record",
    "shows fungal facts, observations, substrate context, and discovered history without changing ownership",
  ),
  viewGeologyGuide: navigationAction(
    "view-geology-guide",
    "View Geology guide",
    "Field Guide Geology section",
    "opens earth-material knowledge organized around rocks, minerals, and landforms",
  ),
  inspectRockMineralRecord: viewAction(
    "inspect-rock-mineral-record",
    "Inspect a rock or mineral record",
    "Field Guide geology record",
    "shows specimen facts, landform context, and discovered history without changing ownership",
  ),
  viewPaleontologyGuide: navigationAction(
    "view-paleontology-guide",
    "View Paleontology guide",
    "Field Guide Paleontology section",
    "opens fossil knowledge organized around extinct life, fossil records, and deep time",
  ),
  inspectFossilRecord: viewAction(
    "inspect-fossil-record",
    "Inspect a fossil record",
    "Field Guide fossil record",
    "shows fossil facts, deep-time context, and discovered history without changing ownership",
  ),
  viewGeneticsGuide: navigationAction(
    "view-genetics-guide",
    "View Genetics guide",
    "Field Guide Genetics section",
    "opens trait and inheritance knowledge organized around variation and generations",
  ),
  inspectTraitInheritance: viewAction(
    "inspect-trait-inheritance",
    "Inspect trait inheritance",
    "Genetics trait view",
    "shows inherited traits, variation, and lineage implications without mutating lineage state",
  ),
  viewArchaeologyGuide: navigationAction(
    "view-archaeology-guide",
    "View Archaeology guide",
    "Field Guide Archaeology section",
    "opens artifact and human-trace knowledge organized around material culture and place history",
  ),
  inspectArtifactRecord: viewAction(
    "inspect-artifact-record",
    "Inspect an artifact record",
    "Field Guide artifact record",
    "shows artifact facts, human-history context, and discovered history without changing ownership",
  ),

  continueDiscoveryReward: mutationAction(
    "continue-discovery-reward",
    "Continue discovery reward",
    "Discovery reward modal",
    "advances a committed living-specimen reward card into the Pack target without revealing its hidden identity",
    playerActionWorkflows.discoveryOwnership,
  ),
  openPack: navigationAction(
    "open-pack",
    "Open the Pack",
    "Pack tab",
    "opens unidentified and identified finds without changing find state",
    playerActionWorkflows.discoveryOwnership,
  ),
  inspectPackFind: viewAction(
    "inspect-pack-find",
    "Inspect a Pack find",
    "Pack find detail",
    "shows unidentified or identified-find details, acquisition history, identification state, and available handoffs without mutating ownership",
    playerActionWorkflows.discoveryOwnership,
  ),
  identifyUnidentifiedFind: mutationAction(
    "identify-unidentified-find",
    "Identify an unidentified find",
    "Identification surface",
    "starts an eligible unknown-to-known identification reveal for an unidentified find",
    playerActionWorkflows.discoveryOwnership,
  ),
  revealIdentification: mutationAction(
    "reveal-identification",
    "Reveal an identification",
    "Identification reveal theater",
    "commits deterministic identification result, traits, and known-state transition for an unidentified find",
    playerActionWorkflows.discoveryOwnership,
  ),

  discoverNpcVenue: mutationAction(
    "discover-npc-venue",
    "Discover an NPC venue",
    "Map cell entry and NPC venue layer",
    "unlocks an authored NPC venue and its Town feature entry from eligible map-cell entry without mutating items or identification",
    playerActionWorkflows.npcFeatureUnlock,
  ),
  openTown: navigationAction(
    "open-town",
    "Open Town",
    "Town tab",
    "opens the unlocked NPC-led feature directory without creating NPCs, items, or progress",
    playerActionWorkflows.npcFeatureUnlock,
  ),
  openNpcLedFeature: navigationAction(
    "open-npc-led-feature",
    "Open an NPC-led feature",
    "Town NPC-led feature entry",
    "binds an unlocked feature UI to the nearest eligible NPC of that authored type",
    playerActionWorkflows.npcFeatureUnlock,
  ),

  openFieldGuide: navigationAction(
    "open-field-guide",
    "Open the Field Guide",
    "Field Guide section",
    "opens persistent knowledge indexes without mutating player progress",
  ),
  inspectFieldGuideEntry: viewAction(
    "inspect-field-guide-entry",
    "Inspect a Field Guide entry",
    "Field Guide entry",
    "shows learned observations, known finds, and science context without changing inventory",
  ),
  viewConservationGoal: viewAction(
    "view-conservation-goal",
    "View a conservation goal",
    "Conservation surface",
    "shows stewardship context, threat status meaning, and goal progress without applying contribution",
    playerActionWorkflows.conservationContribution,
  ),
  contributeToConservation: mutationAction(
    "contribute-to-conservation",
    "Contribute to conservation",
    "Conservation flow",
    "commits an eligible stewardship contribution to a conservation goal or species/place care context",
    playerActionWorkflows.conservationContribution,
  ),
  openReleaseToWild: navigationAction(
    "open-release-to-wild",
    "Open Release to Wild",
    "Wildlife Rehabilitation Center Release to Wild surface",
    "opens the rehabilitation center's base release slot and local programs without changing animal ownership",
    playerActionWorkflows.releaseToWild,
  ),
  inspectReleaseBundle: viewAction(
    "inspect-release-bundle",
    "Inspect a local release program",
    "Release to Wild local program detail",
    "shows visible program slots, accepted animal requirements, release consequences, and extra rewards before any animal is released",
    playerActionWorkflows.releaseToWild,
  ),
  releaseAnimalToWild: mutationAction(
    "release-animal-to-wild",
    "Release an animal to the wild",
    "Release to Wild commit flow",
    "commits an eligible owned animal into the base release slot or an optional local program, removes it from active Pack, preserves release history, and grants Orb rewards exactly once",
    playerActionWorkflows.releaseToWild,
  ),
  openCollections: navigationAction(
    "open-collections",
    "Open Collections",
    "Collections section",
    "opens collection catalog and set progress without changing collection membership",
    playerActionWorkflows.collectionCommitment,
  ),
  addFindToCollection: mutationAction(
    "add-find-to-collection",
    "Add a find to a collection",
    "Collection detail flow",
    "commits an eligible owned find into a collection slot, bundle, or set",
    playerActionWorkflows.collectionCommitment,
  ),
  openSanctuary: navigationAction(
    "open-sanctuary",
    "Open the Sanctuary",
    "Sanctuary section",
    "opens the player's persistent base without changing placement state",
    playerActionWorkflows.sanctuaryPlacement,
  ),
  placeFindInSanctuary: mutationAction(
    "place-find-in-sanctuary",
    "Place a find in the Sanctuary",
    "Sanctuary placement flow",
    "commits an eligible owned find placement into the player's persistent sanctuary state",
    playerActionWorkflows.sanctuaryPlacement,
  ),
  selectBuddy: mutationAction(
    "select-buddy",
    "Select a buddy",
    "Buddy slot",
    "sets the active companion used for buddy presence, care, and future map expression",
    playerActionWorkflows.buddyCare,
  ),
  careForBuddy: mutationAction(
    "care-for-buddy",
    "Care for a buddy",
    "Buddy care panel",
    "commits an eligible tamagotchi-style care interaction to the active buddy state",
    playerActionWorkflows.buddyCare,
  ),
  pairLineage: mutationAction(
    "pair-lineage",
    "Pair lineage candidates",
    "Lineage breeding flow",
    "commits an eligible breeding pair and starts offspring result resolution",
    playerActionWorkflows.lineageBreeding,
  ),
  inspectLineageOffspring: viewAction(
    "inspect-lineage-offspring",
    "Inspect lineage offspring",
    "Lineage result and family tree",
    "shows offspring traits, inherited variation, and family-tree context without starting a new pairing",
    playerActionWorkflows.lineageBreeding,
  ),

  openQuestBoard: navigationAction(
    "open-quest-board",
    "Open the quest board",
    "Quest board",
    "opens directed field goals without changing quest progress",
  ),
  inspectQuest: viewAction(
    "inspect-quest",
    "Inspect a quest",
    "Quest detail",
    "shows quest requirements, progress, science intent, and rewards without claiming anything",
    playerActionWorkflows.questRewards,
  ),
  claimQuestReward: mutationAction(
    "claim-quest-reward",
    "Claim a quest reward",
    "Quest reward flow",
    "commits an eligible completed quest reward exactly once",
    playerActionWorkflows.questRewards,
  ),
  viewAchievements: navigationAction(
    "view-achievements",
    "View achievements",
    "Achievements section",
    "opens achievement lists and milestone progress without mutating unlock state",
  ),
  inspectAchievement: viewAction(
    "inspect-achievement",
    "Inspect an achievement",
    "Achievement detail",
    "shows achievement requirements, progress, diary context, and unlock history without claiming rewards",
  ),
  viewRecap: viewAction(
    "view-recap",
    "View recap",
    "Return recap surface",
    "shows progress deltas, world changes, and reasons to return without applying new progress",
    playerActionWorkflows.recapAcknowledgement,
  ),
  dismissRecap: mutationAction(
    "dismiss-recap",
    "Dismiss recap",
    "Return recap surface",
    "marks recap items as seen so the same return summary is not replayed as new",
    playerActionWorkflows.recapAcknowledgement,
  ),

  openCommunity: navigationAction(
    "open-community",
    "Open Community",
    "Community section",
    "opens shared progress, events, and community milestones without changing shared state",
  ),
  inspectCommunityEvent: viewAction(
    "inspect-community-event",
    "Inspect a community event",
    "Community event detail",
    "shows shared event context, eligibility, and progress without contributing automatically",
    playerActionWorkflows.communityContribution,
  ),
  contributeToCommunityProgress: mutationAction(
    "contribute-to-community-progress",
    "Contribute to community progress",
    "Community event/progress flow",
    "commits an eligible player contribution into an aggregate community goal",
    playerActionWorkflows.communityContribution,
  ),
  openEconomy: navigationAction(
    "open-economy",
    "Open Economy",
    "Economy section",
    "opens duplicate value, trade surfaces, and market signals without changing ownership",
    playerActionWorkflows.tradeExchange,
  ),
  offerTrade: mutationAction(
    "offer-trade",
    "Offer a trade",
    "Trading flow",
    "creates or updates an eligible trade offer from owned surplus or duplicate value",
    playerActionWorkflows.tradeExchange,
  ),
  acceptTrade: mutationAction(
    "accept-trade",
    "Accept a trade",
    "Trading flow",
    "commits an eligible exchange between players and updates ownership exactly once",
    playerActionWorkflows.tradeExchange,
  ),
} as const;

export type PlayerActionKey = keyof typeof actionCapabilities;
export type PlayerActionId =
  (typeof actionCapabilities)[PlayerActionKey]["id"];

export const playerActions = Object.fromEntries(
  Object.entries(actionCapabilities).map(([key, capability]) => [
    key,
    capability.id,
  ]),
) as {
  readonly [Key in PlayerActionKey]: (typeof actionCapabilities)[Key]["id"];
};

export const mutationPlayerActions = Object.values(actionCapabilities)
  .filter((capability) => capability.kind === "mutation")
  .map((capability) => capability.id) as PlayerActionId[];
