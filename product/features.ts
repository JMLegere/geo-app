type FeatureInput = {
  id: string;
  label: string;
  capability: string;
  description: string;
  kind: "app-section" | "surface" | "data-model" | "game-system";
};

const feature = (spec: FeatureInput) => spec;

export const productFeatures = {
  mapFrame: feature({
    id: "map-frame",
    label: "Map Frame",
    capability: "map",
    kind: "surface",
    description:
      "GPS-first map shell that answers where am I, where have I been, and where should I go without exposing raw debug mechanics.",
  }),
  mapDebugControls: feature({
    id: "map-debug-controls",
    label: "Map Debug Controls",
    capability: "map",
    kind: "surface",
    description:
      "Developer-only on-screen controls for moving the gameplay marker and injecting map gestures so map state can be tested without real walking.",
  }),
  playerMarkerAccuracyRing: feature({
    id: "player-marker-accuracy-ring",
    label: "Player Marker + Accuracy Ring",
    capability: "map",
    kind: "surface",
    description:
      "Trusted gameplay position surface with marker smoothing, accuracy ring, and suspended-exploration ring state for unreliable GPS.",
  }),
  fogOverlay: feature({
    id: "fog-overlay",
    label: "Fog Overlay",
    capability: "map",
    kind: "surface",
    description:
      "Visual reveal layer for present, explored, frontier, unknown, and beyond states, tuned to make movement feel like cozy accumulation.",
  }),
  mapCellDetailSheet: feature({
    id: "map-cell-detail-sheet",
    label: "Map Cell Detail Sheet",
    capability: "map",
    kind: "surface",
    description:
      "Tap/detail sheet that describes the current Voronoi map cell before deeper discovery or collection systems take over.",
  }),
  nearbyOpportunityLayer: feature({
    id: "nearby-opportunity-layer",
    label: "Nearby Opportunity Layer",
    capability: "map",
    kind: "surface",
    description:
      "Reachable tease layer for nearby unexplored map cells and possible activity, so the map says where should I go next.",
  }),
  worldEventCueLayer: feature({
    id: "world-event-cue-layer",
    label: "World Event Cue Layer",
    capability: "map",
    kind: "surface",
    description:
      "Aspirational map-event cue evidence; event timing, eligibility, and Encounter integration are not approved target behavior.",
  }),
  districts: feature({
    id: "districts",
    label: "Districts",
    capability: "map",
    kind: "app-section",
    description:
      "Aspirational atlas surface for the canonical District geography level; the UI and progression rollup are not approved here.",
  }),
  cities: feature({
    id: "cities",
    label: "Cities",
    capability: "map",
    kind: "app-section",
    description:
      "Aspirational atlas surface for the canonical City geography level; the UI and progression rollup are not approved here.",
  }),
  states: feature({
    id: "states",
    label: "States",
    capability: "map",
    kind: "app-section",
    description:
      "Aspirational atlas surface for the canonical State geography level; the UI and progression rollup are not approved here.",
  }),
  countries: feature({
    id: "countries",
    label: "Countries",
    capability: "map",
    kind: "app-section",
    description:
      "Aspirational atlas surface for the canonical Country geography level; the UI and progression rollup are not approved here.",
  }),
  world: feature({
    id: "world",
    label: "World",
    capability: "map",
    kind: "app-section",
    description:
      "Aspirational atlas surface for the canonical World geography level; global progress behavior is not approved here.",
  }),
  territoryNavigation: feature({
    id: "territory-navigation",
    label: "Territory Navigation",
    capability: "map",
    kind: "surface",
    description:
      "Aspirational navigation evidence for the canonical Cell → District → City → State → Country → World hierarchy; zoom behavior is not approved here.",
  }),
  explorationEligibilityState: feature({
    id: "exploration-eligibility-state",
    label: "Exploration Eligibility State",
    capability: "map",
    kind: "data-model",
    description:
      "Determines whether Exploration may record a Cell Visit and reveal fog. Selector, Encounter, and Condition behavior remains target routing, not implementation evidence.",
  }),
  cellEntryModel: feature({
    id: "cell-entry-model",
    label: "Cell Visit evidence",
    capability: "map",
    kind: "data-model",
    description:
      "Legacy map-cell-entry identifier retained for evidence compatibility. The approved target records a Cell Visit, which resolves a Selector to None or one Encounter.",
  }),
  fogStateModel: feature({
    id: "fog-state-model",
    label: "Fog State Model",
    capability: "map",
    kind: "data-model",
    description:
      "Computed fog relationship model derived from current marker cell, visit history, and shared map-cell borders without persisted fog snapshots.",
  }),
  globalMapStateModel: feature({
    id: "global-map-state-model",
    label: "Global Map State Model",
    capability: "map",
    kind: "data-model",
    description:
      "Legacy shared-cadence map-state evidence. It does not settle Encounter rates, Selector weights, or future recurrence rules.",
  }),
  territoryProgressModel: feature({
    id: "territory-progress-model",
    label: "Territory Progress Model",
    capability: "map",
    kind: "data-model",
    description:
      "Aspirational rollup evidence for canonical geography levels; progress formulas and rewards are not approved target behavior.",
  }),
  worldEventInstanceModel: feature({
    id: "world-event-instance-model",
    label: "World Event Instance Model",
    capability: "map",
    kind: "data-model",
    description:
      "Aspirational event-instance evidence; event timing, eligibility, presentation, and Outcomes are not approved target behavior.",
  }),

  zoology: feature({
    id: "zoology",
    label: "Zoology",
    capability: "zoology",
    kind: "app-section",
    description:
      "Animal-focused Discipline section surfaced through Index for Fauna knowledge. Discipline tuning remains open.",
  }),
  botany: feature({
    id: "botany",
    label: "Botany",
    capability: "botany",
    kind: "app-section",
    description:
      "Plant-focused Discipline section surfaced through Index for Flora knowledge. Discipline tuning remains open.",
  }),
  mycology: feature({
    id: "mycology",
    label: "Mycology",
    capability: "mycology",
    kind: "app-section",
    description:
      "Legacy Mycology evidence; the current canonical Discipline mappings are limited to the five resolved knowledge Item Categories.",
  }),
  geology: feature({
    id: "geology",
    label: "Geology",
    capability: "geology",
    kind: "app-section",
    description:
      "Mineral-focused Discipline section surfaced through Index for Mineral knowledge. Discipline tuning remains open.",
  }),
  paleontology: feature({
    id: "paleontology",
    label: "Paleontology",
    capability: "paleontology",
    kind: "app-section",
    description:
      "Fossil-focused Discipline section surfaced through Index for Fossil knowledge. Discipline tuning remains open.",
  }),
  genetics: feature({
    id: "genetics",
    label: "Genetics",
    capability: "genetics",
    kind: "data-model",
    description:
      "Legacy genetics evidence; it is not a current canonical Discipline or a settled target model.",
  }),
  archaeology: feature({
    id: "archaeology",
    label: "Archaeology",
    capability: "archaeology",
    kind: "app-section",
    description:
      "Artifact-focused Discipline section surfaced through Index for Artifact knowledge. Discipline tuning remains open.",
  }),

  discovery: feature({
    id: "discovery",
    label: "Discovery",
    capability: "exploration-discovery-lifecycle",
    kind: "game-system",
    description:
      "Discovery is the durable first-identification milestone for one Base Item and feeds Index. The retained legacy reward-bridge evidence must not be read as Cell entry, Encounter, or Item acquisition being Discovery.",
  }),
  pack: feature({
    id: "pack",
    label: "Pack",
    capability: "exploration-discovery-lifecycle",
    kind: "app-section",
    description:
      "Newest-first, unlimited projection of the Player's owned active Items. Unexamined Items are semantic silhouettes; Examination recognizes shared Base Item identity and content without identifying exact Item Property Values.",
  }),
  identification: feature({
    id: "identification",
    label: "Identification",
    capability: "exploration-discovery-lifecycle",
    kind: "surface",
    description:
      "Distinct Service screen for an examined, unidentified, owned active Item. A known Villager's current published Identification Service is prepared on entry; only hold/reveal commits the retained exact-version Property Values, while cancellation writes nothing.",
  }),

  town: feature({
    id: "town",
    label: "Town",
    capability: "living-world",
    kind: "app-section",
    description:
      "Player-facing index of known Venues, Villagers, and Services. Existing NPC/place/feature binding evidence is legacy only.",
  }),
  npcVenues: feature({
    id: "npc-venues",
    label: "Venues",
    capability: "living-world",
    kind: "data-model",
    description:
      "Legacy identifier retained for evidence compatibility. The approved target uses Venues, Villagers, and Services; placement and reveal behavior are not implemented by this catalog.",
  }),
  wildlifeRehabilitationCenter: feature({
    id: "wildlife-rehabilitation-center",
    label: "Wildlife Rehabilitation Center",
    capability: "living-world",
    kind: "surface",
    description:
      "Legacy example of a Venue and Service. Its role and release behavior do not establish approved target implementation.",
  }),

  fieldGuide: feature({
    id: "field-guide",
    label: "Index",
    capability: "progression-permanence",
    kind: "app-section",
    description:
      "Legacy identifier retained for evidence compatibility. Index projects the Base Items the player has Discovered; it is distinct from Pack and its implementation remains outside this catalog.",
  }),
  conservation: feature({
    id: "conservation",
    label: "Conservation",
    capability: "progression-permanence",
    kind: "game-system",
    description:
      "Aspirational conservation-system evidence. Conservation Status remains factual Item content; goals and contribution mechanics are not approved here.",
  }),
  releaseToWild: feature({
    id: "release-to-wild",
    label: "Release to Wild",
    capability: "progression-permanence",
    kind: "game-system",
    description:
      "Legacy release-loop evidence. Orb rewards and release rules are not approved target mechanics.",
  }),
  orbCrafting: feature({
    id: "orb-crafting",
    label: "Orb Crafting",
    capability: "progression-permanence",
    kind: "game-system",
    description:
      "Explicitly open: Orb purpose and behavior are unresolved. This legacy crafting identifier and its reroll model do not describe an active target mechanic.",
  }),
  collections: feature({
    id: "collections",
    label: "Collections",
    capability: "progression-permanence",
    kind: "app-section",
    description:
      "Aspirational collection-system evidence; bundle, donation, commitment, and reward rules are not approved target behavior.",
  }),
  sanctuary: feature({
    id: "sanctuary",
    label: "Home",
    capability: "progression-permanence",
    kind: "app-section",
    description:
      "Legacy identifier retained for evidence compatibility. Every Player has one Home; Home Module behavior remains unresolved.",
  }),
  buddy: feature({
    id: "buddy",
    label: "Buddy",
    capability: "progression-permanence",
    kind: "app-section",
    description:
      "Aspirational companion-system evidence; buddy ownership, care, and map-presence behavior are not part of the frozen foundation.",
  }),
  lineage: feature({
    id: "lineage",
    label: "Lineage",
    capability: "progression-permanence",
    kind: "game-system",
    description:
      "Legacy lineage evidence. Rarity is not a current mechanic; pairing and offspring behavior remain open.",
  }),

  quests: feature({
    id: "quests",
    label: "Quests",
    capability: "motivation",
    kind: "app-section",
    description:
      "Aspirational quest-system evidence; quest progression and rewards are not approved target behavior.",
  }),
  achievements: feature({
    id: "achievements",
    label: "Achievements",
    capability: "motivation",
    kind: "app-section",
    description:
      "Aspirational achievement-system evidence; milestone and diary behavior are not approved target behavior.",
  }),
  recap: feature({
    id: "recap",
    label: "Recap",
    capability: "motivation",
    kind: "surface",
    description:
      "Aspirational recap-surface evidence; recap contents and acknowledgement behavior are not approved target behavior.",
  }),

  community: feature({
    id: "community",
    label: "Community",
    capability: "multiplayer",
    kind: "app-section",
    description:
      "Aspirational multiplayer evidence; community progress, events, and shared milestones are not approved target behavior.",
  }),
  economy: feature({
    id: "economy",
    label: "Economy",
    capability: "multiplayer",
    kind: "game-system",
    description:
      "Aspirational economy evidence; trading, markets, and exchangeable value are not approved target behavior.",
  }),
} as const;
