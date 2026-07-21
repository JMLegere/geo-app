export const playerActionWorkflows = {
  mapExploration: "map-exploration",
  discoveryOwnership: "discovery-ownership",
  conservationContribution: "conservation-contribution",
  releaseToWild: "release-to-wild",
  orbCrafting: "orb-crafting",
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
    "Record a Cell Visit",
    "Physical movement plus Map cell overlay",
    "records Exploration as one Cell Visit when movement is eligible; the retained border-crossing identifier is legacy geometric evidence, not an Encounter or Discovery",
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
    "lets the player inspect a reachable cue without forcing an Encounter, Item, or Discovery",
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
    "View Zoology Index",
    "Index Zoology section",
    "opens Fauna knowledge; the legacy guide identifier remains only for evidence compatibility",
  ),
  inspectAnimalRecord: viewAction(
    "inspect-animal-record",
    "Inspect an animal record",
    "Index animal record",
    "shows animal facts, observations, habitats, and discovered history without changing ownership",
  ),
  viewBotanyGuide: navigationAction(
    "view-botany-guide",
    "View Botany Index",
    "Index Botany section",
    "opens Flora knowledge; the legacy guide identifier remains only for evidence compatibility",
  ),
  inspectPlantRecord: viewAction(
    "inspect-plant-record",
    "Inspect a plant record",
    "Index plant record",
    "shows plant facts, observations, growth context, and discovered history without changing ownership",
  ),
  viewMycologyGuide: navigationAction(
    "view-mycology-guide",
    "View Mycology guide",
    "Index Mycology section",
    "opens fungi-focused knowledge organized around fungi, substrates, spores, and hidden conditions",
  ),
  inspectFungusRecord: viewAction(
    "inspect-fungus-record",
    "Inspect a fungus record",
    "Index fungus record",
    "shows fungal facts, observations, substrate context, and discovered history without changing ownership",
  ),
  viewGeologyGuide: navigationAction(
    "view-geology-guide",
    "View Geology Index",
    "Index Geology section",
    "opens Mineral knowledge; the legacy guide identifier remains only for evidence compatibility",
  ),
  inspectRockMineralRecord: viewAction(
    "inspect-rock-mineral-record",
    "Inspect a rock or mineral record",
    "Index geology record",
    "shows specimen facts, landform context, and discovered history without changing ownership",
  ),
  viewPaleontologyGuide: navigationAction(
    "view-paleontology-guide",
    "View Paleontology Index",
    "Index Paleontology section",
    "opens Fossil knowledge; the legacy guide identifier remains only for evidence compatibility",
  ),
  inspectFossilRecord: viewAction(
    "inspect-fossil-record",
    "Inspect a fossil record",
    "Index fossil record",
    "shows fossil facts, deep-time context, and discovered history without changing ownership",
  ),
  viewGeneticsGuide: navigationAction(
    "view-genetics-guide",
    "View Genetics guide",
    "Index Genetics section",
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
    "View Archaeology Index",
    "Index Archaeology section",
    "opens Artifact knowledge; the legacy guide identifier remains only for evidence compatibility",
  ),
  inspectArtifactRecord: viewAction(
    "inspect-artifact-record",
    "Inspect an artifact record",
    "Index artifact record",
    "shows artifact facts, human-history context, and discovered history without changing ownership",
  ),

  continueDiscoveryReward: mutationAction(
    "continue-discovery-reward",
    "Continue legacy reward card",
    "Legacy reward modal evidence",
    "preserves a historical reward-card continuation identifier; it does not define approved Encounter, Item, Identification, or Discovery behavior",
    playerActionWorkflows.discoveryOwnership,
  ),
  openPack: navigationAction(
    "open-pack",
    "Open the Pack",
    "Pack tab",
    "opens the player's Items without changing Item state",
    playerActionWorkflows.discoveryOwnership,
  ),
  inspectPackFind: viewAction(
    "inspect-pack-find",
    "Inspect a Pack Item",
    "Pack Item detail",
    "shows Item provenance, Identification state, and available handoffs without mutating ownership",
    playerActionWorkflows.discoveryOwnership,
  ),
  identifyUnidentifiedFind: mutationAction(
    "identify-unidentified-find",
    "Identify an Item",
    "Identification surface",
    "starts Identification for an eligible Item. Target rules bind its exact Base Item Version and may record Discovery; this catalog does not claim implementation",
    playerActionWorkflows.discoveryOwnership,
  ),
  revealIdentification: mutationAction(
    "reveal-identification",
    "Reveal an Item identification",
    "Identification reveal surface",
    "records the result of an eligible Identification. Exact Selector resolution, Property Values, and Discovery remain target rules rather than implemented evidence",
    playerActionWorkflows.discoveryOwnership,
  ),

  discoverNpcVenue: mutationAction(
    "discover-npc-venue",
    "Reveal a Venue (legacy identifier)",
    "Legacy map Venue evidence",
    "retains a legacy identifier. In the approved target, a Reveal Venue Outcome makes a Venue known; it does not discover an NPC or mutate Items or Identification",
    playerActionWorkflows.npcFeatureUnlock,
  ),
  openTown: navigationAction(
    "open-town",
    "Open Town",
    "Town tab",
    "opens Town's known Venues, Villagers, and Services; legacy feature-directory behavior is not target implementation",
    playerActionWorkflows.npcFeatureUnlock,
  ),
  openNpcLedFeature: navigationAction(
    "open-npc-led-feature",
    "Open a Service (legacy identifier)",
    "Town Service entry",
    "retains a legacy identifier; target Town surfaces known Services provided by Villagers at Venues",
    playerActionWorkflows.npcFeatureUnlock,
  ),
  openNpcVenueDetail: navigationAction(
    "open-npc-venue-detail",
    "Open Venue detail (legacy identifier)",
    "Venue detail",
    "retains a legacy identifier; target language is Venue, Villager, and Service",
    playerActionWorkflows.npcFeatureUnlock,
  ),

  openFieldGuide: navigationAction(
    "open-field-guide",
    "Open Index",
    "Index section",
    "retains a legacy identifier; opens the player-facing projection of Discovered Base Items without mutating progress",
  ),
  inspectFieldGuideEntry: viewAction(
    "inspect-field-guide-entry",
    "Inspect an Index entry",
    "Index entry",
    "retains a legacy identifier; shows durable Discovery knowledge, not Pack ownership",
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
    "Open legacy Release to Wild evidence",
    "Legacy Venue Service evidence",
    "retains unimplemented historical behavior; no release rule is approved target behavior",
    playerActionWorkflows.releaseToWild,
  ),
  inspectReleaseBundle: viewAction(
    "inspect-release-bundle",
    "Inspect a local release program",
    "Release to Wild local program detail",
    "shows visible program slots, requested habitat/type/trait predicates, strict matching rules, nearby/missing match suggestions, release consequences, and extra rewards before any animal is released",
    playerActionWorkflows.releaseToWild,
  ),
  releaseAnimalToWild: mutationAction(
    "release-animal-to-wild",
    "Release an animal (legacy evidence)",
    "Legacy Release to Wild evidence",
    "retains unimplemented historical behavior; it must not be read as an active Pack mutation or Orb reward mechanic",
    playerActionWorkflows.releaseToWild,
  ),
  useOrbOnAnimal: mutationAction(
    "use-orb-on-animal",
    "Use an Orb (open behavior)",
    "Open Orb behavior",
    "Orb purpose and behavior are unresolved; this legacy identifier does not authorize consumption, rerolls, rarity, or any active target mechanic",
    playerActionWorkflows.orbCrafting,
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
    "Add an Item to a collection",
    "Collection detail flow",
    "commits an eligible owned Item into a collection only in legacy evidence; collection rules remain open",
    playerActionWorkflows.collectionCommitment,
  ),
  openSanctuary: navigationAction(
    "open-sanctuary",
    "Open Home",
    "Home",
    "retains a legacy identifier; every Player has one Home, while Home Module and placement behavior remain unresolved",
    playerActionWorkflows.sanctuaryPlacement,
  ),
  placeFindInSanctuary: mutationAction(
    "place-find-in-sanctuary",
    "Place an Item in Home (open behavior)",
    "Home",
    "retains a legacy identifier; Home Module and Item placement behavior remain unresolved",
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
export type PlayerActionId = (typeof actionCapabilities)[PlayerActionKey]["id"];

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
