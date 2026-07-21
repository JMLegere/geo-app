import {
  playerActions,
  playerActionWorkflows,
  type PlayerActionId,
  type PlayerActionWorkflowId,
} from "./actions.ts";

export type WorkflowCoverageKind =
  "states" | "transitions" | "forbidden-transitions";

export type PlayerActionWorkflowTransition = {
  readonly from: string;
  readonly action: PlayerActionId;
  readonly to: string;
};

export type PlayerActionWorkflowForbiddenTransition = {
  readonly state: string;
  readonly action: PlayerActionId;
  readonly reason: string;
};

export type PlayerActionWorkflow = {
  readonly id: PlayerActionWorkflowId;
  readonly label: string;
  readonly initialState: string;
  readonly states: readonly string[];
  readonly events: readonly PlayerActionId[];
  readonly transitions: readonly PlayerActionWorkflowTransition[];
  readonly forbiddenTransitions: readonly PlayerActionWorkflowForbiddenTransition[];
  readonly requiredCoverage: readonly WorkflowCoverageKind[];
  readonly evidence: readonly string[];
};

const workflowEvidence = [
  "product/workflows.ts",
  "features/**/*.feature",
  "mise exec -- eac check",
] as const;

const fullStateCoverage = [
  "states",
  "transitions",
  "forbidden-transitions",
] as const;

const workflow = <const Spec extends PlayerActionWorkflow>(spec: Spec) => spec;

export const userActionWorkflows = {
  mapExploration: workflow({
    id: playerActionWorkflows.mapExploration,
    label: "Map Exploration readiness and legacy Cell Visit proxy",
    initialState: "map-closed",
    states: [
      "map-closed",
      "map-not-ready",
      "browse-only",
      "eligible-in-cell",
      "cell-entered",
      "detail-open",
    ],
    events: [
      playerActions.openMap,
      playerActions.readMapStatus,
      playerActions.moveInRealWorld,
      playerActions.crossMapCellBorder,
      playerActions.inspectMapCell,
    ],
    transitions: [
      {
        from: "map-closed",
        action: playerActions.openMap,
        to: "map-not-ready",
      },
      {
        from: "map-not-ready",
        action: playerActions.readMapStatus,
        to: "browse-only",
      },
      {
        from: "browse-only",
        action: playerActions.moveInRealWorld,
        to: "eligible-in-cell",
      },
      {
        from: "eligible-in-cell",
        action: playerActions.moveInRealWorld,
        to: "eligible-in-cell",
      },
      {
        from: "eligible-in-cell",
        action: playerActions.crossMapCellBorder,
        to: "cell-entered",
      },
      {
        from: "cell-entered",
        action: playerActions.crossMapCellBorder,
        to: "cell-entered",
      },
      {
        from: "cell-entered",
        action: playerActions.inspectMapCell,
        to: "detail-open",
      },
      {
        from: "detail-open",
        action: playerActions.inspectMapCell,
        to: "detail-open",
      },
      {
        from: "detail-open",
        action: playerActions.moveInRealWorld,
        to: "eligible-in-cell",
      },
    ],
    forbiddenTransitions: [
      {
        state: "map-closed",
        action: playerActions.crossMapCellBorder,
        reason:
          "A closed map cannot record visits, reveal fog, or emit map cell entry identity.",
      },
      {
        state: "map-not-ready",
        action: playerActions.crossMapCellBorder,
        reason:
          "Map readiness must settle before visits, fog, or handoffs can mutate.",
      },
      {
        state: "browse-only",
        action: playerActions.crossMapCellBorder,
        reason:
          "Bad or paused GPS can show context but must not count exploration progress.",
      },
      {
        state: "map-not-ready",
        action: playerActions.inspectMapCell,
        reason:
          "Map cell detail requires a resolved current or inspected map cell identity.",
      },
    ],
    requiredCoverage: fullStateCoverage,
    evidence: workflowEvidence,
  }),

  discoveryOwnership: workflow({
    id: playerActionWorkflows.discoveryOwnership,
    label: "Legacy reward-card Item lifecycle (not target Encounter behavior)",
    initialState: "reward-modal-active",
    states: [
      "no-result",
      "reward-modal-active",
      "reward-queued",
      "unidentified",
      "identification-started",
      "identified",
    ],
    events: [
      playerActions.continueDiscoveryReward,
      playerActions.openPack,
      playerActions.inspectPackFind,
      playerActions.identifyUnidentifiedFind,
      playerActions.revealIdentification,
    ],
    transitions: [
      {
        from: "reward-modal-active",
        action: playerActions.continueDiscoveryReward,
        to: "unidentified",
      },
      {
        from: "reward-queued",
        action: playerActions.continueDiscoveryReward,
        to: "unidentified",
      },
      {
        from: "unidentified",
        action: playerActions.openPack,
        to: "unidentified",
      },
      {
        from: "unidentified",
        action: playerActions.inspectPackFind,
        to: "unidentified",
      },
      {
        from: "unidentified",
        action: playerActions.identifyUnidentifiedFind,
        to: "identification-started",
      },
      {
        from: "identification-started",
        action: playerActions.revealIdentification,
        to: "identified",
      },
      {
        from: "identified",
        action: playerActions.inspectPackFind,
        to: "identified",
      },
    ],
    forbiddenTransitions: [
      {
        state: "no-result",
        action: playerActions.continueDiscoveryReward,
        reason: "There is no committed legacy reward modal to continue.",
      },
      {
        state: "no-result",
        action: playerActions.openPack,
        reason:
          "Opening Pack cannot create Item ownership; this legacy reward bridge is not Discovery.",
      },
      {
        state: "reward-modal-active",
        action: playerActions.revealIdentification,
        reason:
          "Identification reveal requires the reward card to land as an unidentified Pack find first.",
      },
      {
        state: "unidentified",
        action: playerActions.revealIdentification,
        reason: "Reveal cannot bypass the identify-unidentified-find step.",
      },
      {
        state: "identified",
        action: playerActions.revealIdentification,
        reason:
          "Identification results are deterministic and must not replay as new progress.",
      },
    ],
    requiredCoverage: fullStateCoverage,
    evidence: workflowEvidence,
  }),

  npcFeatureUnlock: workflow({
    id: playerActionWorkflows.npcFeatureUnlock,
    label: "Legacy NPC venue-to-Town feature evidence",
    initialState: "town-empty",
    states: [
      "town-empty",
      "npc-venue-unlocked",
      "town-open",
      "npc-led-feature-open",
    ],
    events: [
      playerActions.discoverNpcVenue,
      playerActions.openTown,
      playerActions.openNpcLedFeature,
    ],
    transitions: [
      { from: "town-empty", action: playerActions.openTown, to: "town-empty" },
      {
        from: "town-empty",
        action: playerActions.discoverNpcVenue,
        to: "npc-venue-unlocked",
      },
      {
        from: "npc-venue-unlocked",
        action: playerActions.openTown,
        to: "town-open",
      },
      {
        from: "town-open",
        action: playerActions.openNpcLedFeature,
        to: "npc-led-feature-open",
      },
      {
        from: "npc-led-feature-open",
        action: playerActions.openTown,
        to: "town-open",
      },
      {
        from: "npc-led-feature-open",
        action: playerActions.openNpcLedFeature,
        to: "npc-led-feature-open",
      },
    ],
    forbiddenTransitions: [
      {
        state: "town-empty",
        action: playerActions.openNpcLedFeature,
        reason:
          "This legacy feature flow requires its retained venue evidence first; target Town uses Services provided by Villagers at Venues.",
      },
      {
        state: "town-open",
        action: playerActions.discoverNpcVenue,
        reason:
          "Legacy map-cell-entry evidence does not define target Venue reveal behavior.",
      },
      {
        state: "npc-led-feature-open",
        action: playerActions.discoverNpcVenue,
        reason:
          "This historical feature binding cannot establish a target Venue without an approved Encounter Outcome.",
      },
    ],
    requiredCoverage: fullStateCoverage,

    evidence: workflowEvidence,
  }),

  releaseToWild: workflow({
    id: playerActionWorkflows.releaseToWild,
    label: "Legacy Release to Wild evidence (not an active target lifecycle)",
    initialState: "rehab-center-discovered",
    states: [
      "rehab-center-discovered",
      "release-open",
      "local-program-inspected",
      "animal-released",
      "local-program-complete",
    ],
    events: [
      playerActions.openReleaseToWild,
      playerActions.inspectReleaseBundle,
      playerActions.releaseAnimalToWild,
    ],
    transitions: [
      {
        from: "rehab-center-discovered",
        action: playerActions.openReleaseToWild,
        to: "release-open",
      },
      {
        from: "release-open",
        action: playerActions.inspectReleaseBundle,
        to: "local-program-inspected",
      },
      {
        from: "release-open",
        action: playerActions.releaseAnimalToWild,
        to: "animal-released",
      },
      {
        from: "local-program-inspected",
        action: playerActions.releaseAnimalToWild,
        to: "local-program-complete",
      },
      {
        from: "local-program-complete",
        action: playerActions.openReleaseToWild,
        to: "local-program-complete",
      },
    ],
    forbiddenTransitions: [
      {
        state: "rehab-center-discovered",
        action: playerActions.releaseAnimalToWild,
        reason:
          "The player must open Release to Wild before committing an animal.",
      },
      {
        state: "rehab-center-discovered",
        action: playerActions.inspectReleaseBundle,
        reason:
          "Program detail requires the rehabilitation center feature to be open first.",
      },
      {
        state: "local-program-complete",
        action: playerActions.releaseAnimalToWild,
        reason:
          "A completed one-time local program cannot accept duplicate releases as new reward progress.",
      },
    ],
    requiredCoverage: fullStateCoverage,

    evidence: workflowEvidence,
  }),
  orbCrafting: workflow({
    id: playerActionWorkflows.orbCrafting,
    label: "Orb behavior remains open (legacy reroll evidence)",
    initialState: "legacy-crafting-ready",
    states: [
      "legacy-crafting-ready",
      "legacy-orb-missing",
      "legacy-reroll-committed",
    ],
    events: [playerActions.useOrbOnAnimal],
    transitions: [
      {
        from: "legacy-crafting-ready",
        action: playerActions.useOrbOnAnimal,
        to: "legacy-reroll-committed",
      },
    ],
    forbiddenTransitions: [
      {
        state: "legacy-orb-missing",
        action: playerActions.useOrbOnAnimal,
        reason:
          "Historical evidence only: Orb purpose and behavior are unresolved.",
      },
    ],
    requiredCoverage: fullStateCoverage,

    evidence: workflowEvidence,
  }),

  conservationContribution: workflow({
    id: playerActionWorkflows.conservationContribution,
    label: "Conservation contribution lifecycle",
    initialState: "goal-visible",
    states: ["goal-visible", "contribution-eligible", "contribution-recorded"],
    events: [
      playerActions.viewConservationGoal,
      playerActions.contributeToConservation,
    ],
    transitions: [
      {
        from: "goal-visible",
        action: playerActions.viewConservationGoal,
        to: "goal-visible",
      },
      {
        from: "contribution-eligible",
        action: playerActions.contributeToConservation,
        to: "contribution-recorded",
      },
      {
        from: "contribution-recorded",
        action: playerActions.viewConservationGoal,
        to: "contribution-recorded",
      },
    ],
    forbiddenTransitions: [
      {
        state: "goal-visible",
        action: playerActions.contributeToConservation,
        reason:
          "Viewing a goal is not enough; contribution requires an eligible owned find or care context.",
      },
      {
        state: "contribution-recorded",
        action: playerActions.contributeToConservation,
        reason: "The same contribution context cannot be recorded twice.",
      },
    ],
    requiredCoverage: fullStateCoverage,
    evidence: workflowEvidence,
  }),

  collectionCommitment: workflow({
    id: playerActionWorkflows.collectionCommitment,
    label: "Collection slot commitment lifecycle",
    initialState: "owned-find",
    states: ["owned-find", "collection-slot-eligible", "collection-committed"],
    events: [playerActions.openCollections, playerActions.addFindToCollection],
    transitions: [
      {
        from: "owned-find",
        action: playerActions.openCollections,
        to: "collection-slot-eligible",
      },
      {
        from: "collection-slot-eligible",
        action: playerActions.addFindToCollection,
        to: "collection-committed",
      },
      {
        from: "collection-committed",
        action: playerActions.openCollections,
        to: "collection-committed",
      },
    ],
    forbiddenTransitions: [
      {
        state: "owned-find",
        action: playerActions.addFindToCollection,
        reason:
          "A find must be matched to an eligible collection slot before commitment.",
      },
      {
        state: "collection-committed",
        action: playerActions.addFindToCollection,
        reason: "A committed find cannot fill the same collection slot twice.",
      },
    ],
    requiredCoverage: fullStateCoverage,
    evidence: workflowEvidence,
  }),

  sanctuaryPlacement: workflow({
    id: playerActionWorkflows.sanctuaryPlacement,
    label: "Legacy Home-placement evidence (Home Module behavior remains open)",
    initialState: "owned-find",
    states: ["owned-find", "placement-eligible", "placed-in-sanctuary"],
    events: [playerActions.openSanctuary, playerActions.placeFindInSanctuary],
    transitions: [
      {
        from: "owned-find",
        action: playerActions.openSanctuary,
        to: "placement-eligible",
      },
      {
        from: "placement-eligible",
        action: playerActions.placeFindInSanctuary,
        to: "placed-in-sanctuary",
      },
      {
        from: "placed-in-sanctuary",
        action: playerActions.openSanctuary,
        to: "placed-in-sanctuary",
      },
    ],
    forbiddenTransitions: [
      {
        state: "owned-find",
        action: playerActions.placeFindInSanctuary,
        reason:
          "Legacy evidence only: Home Module and Item-placement behavior remain unresolved.",
      },
      {
        state: "placed-in-sanctuary",
        action: playerActions.placeFindInSanctuary,
        reason:
          "Legacy evidence only: Home placement does not define current target growth behavior.",
      },
    ],
    requiredCoverage: fullStateCoverage,
    evidence: workflowEvidence,
  }),

  buddyCare: workflow({
    id: playerActionWorkflows.buddyCare,
    label: "Buddy selection and care lifecycle",
    initialState: "no-active-buddy",
    states: ["no-active-buddy", "buddy-active", "care-cooldown"],
    events: [playerActions.selectBuddy, playerActions.careForBuddy],
    transitions: [
      {
        from: "no-active-buddy",
        action: playerActions.selectBuddy,
        to: "buddy-active",
      },
      {
        from: "buddy-active",
        action: playerActions.selectBuddy,
        to: "buddy-active",
      },
      {
        from: "buddy-active",
        action: playerActions.careForBuddy,
        to: "care-cooldown",
      },
      {
        from: "care-cooldown",
        action: playerActions.selectBuddy,
        to: "buddy-active",
      },
    ],
    forbiddenTransitions: [
      {
        state: "no-active-buddy",
        action: playerActions.careForBuddy,
        reason: "Care requires an active buddy target.",
      },
      {
        state: "care-cooldown",
        action: playerActions.careForBuddy,
        reason:
          "Care cannot bypass cooldown, eligibility, or duplicate-result rules.",
      },
    ],
    requiredCoverage: fullStateCoverage,
    evidence: workflowEvidence,
  }),

  lineageBreeding: workflow({
    id: playerActionWorkflows.lineageBreeding,
    label: "Lineage pairing and offspring lifecycle",
    initialState: "lineage-candidates",
    states: [
      "lineage-candidates",
      "pair-eligible",
      "offspring-pending",
      "offspring-visible",
    ],
    events: [playerActions.pairLineage, playerActions.inspectLineageOffspring],
    transitions: [
      {
        from: "pair-eligible",
        action: playerActions.pairLineage,
        to: "offspring-pending",
      },
      {
        from: "offspring-pending",
        action: playerActions.inspectLineageOffspring,
        to: "offspring-visible",
      },
      {
        from: "offspring-visible",
        action: playerActions.inspectLineageOffspring,
        to: "offspring-visible",
      },
    ],
    forbiddenTransitions: [
      {
        state: "lineage-candidates",
        action: playerActions.pairLineage,
        reason:
          "Pairing requires validated eligible candidates, not just visible lineage options.",
      },
      {
        state: "offspring-pending",
        action: playerActions.pairLineage,
        reason:
          "A new pairing cannot start before the current offspring result is resolved.",
      },
    ],
    requiredCoverage: fullStateCoverage,
    evidence: workflowEvidence,
  }),

  questRewards: workflow({
    id: playerActionWorkflows.questRewards,
    label: "Quest completion reward lifecycle",
    initialState: "quest-in-progress",
    states: ["quest-in-progress", "quest-complete", "reward-claimed"],
    events: [playerActions.inspectQuest, playerActions.claimQuestReward],
    transitions: [
      {
        from: "quest-in-progress",
        action: playerActions.inspectQuest,
        to: "quest-in-progress",
      },
      {
        from: "quest-complete",
        action: playerActions.inspectQuest,
        to: "quest-complete",
      },
      {
        from: "quest-complete",
        action: playerActions.claimQuestReward,
        to: "reward-claimed",
      },
      {
        from: "reward-claimed",
        action: playerActions.inspectQuest,
        to: "reward-claimed",
      },
    ],
    forbiddenTransitions: [
      {
        state: "quest-in-progress",
        action: playerActions.claimQuestReward,
        reason: "Rewards require completed quest criteria.",
      },
      {
        state: "reward-claimed",
        action: playerActions.claimQuestReward,
        reason: "Quest rewards must be claimed exactly once.",
      },
    ],
    requiredCoverage: fullStateCoverage,
    evidence: workflowEvidence,
  }),

  recapAcknowledgement: workflow({
    id: playerActionWorkflows.recapAcknowledgement,
    label: "Return recap acknowledgement lifecycle",
    initialState: "recap-available",
    states: ["recap-available", "recap-viewed", "recap-dismissed"],
    events: [playerActions.viewRecap, playerActions.dismissRecap],
    transitions: [
      {
        from: "recap-available",
        action: playerActions.viewRecap,
        to: "recap-viewed",
      },
      {
        from: "recap-viewed",
        action: playerActions.dismissRecap,
        to: "recap-dismissed",
      },
      {
        from: "recap-dismissed",
        action: playerActions.viewRecap,
        to: "recap-dismissed",
      },
    ],
    forbiddenTransitions: [
      {
        state: "recap-available",
        action: playerActions.dismissRecap,
        reason: "A recap should be exposed before it is marked seen.",
      },
      {
        state: "recap-dismissed",
        action: playerActions.dismissRecap,
        reason: "Dismissed recap items must not replay as new return progress.",
      },
    ],
    requiredCoverage: fullStateCoverage,
    evidence: workflowEvidence,
  }),

  communityContribution: workflow({
    id: playerActionWorkflows.communityContribution,
    label: "Community event contribution lifecycle",
    initialState: "event-visible",
    states: ["event-visible", "contribution-eligible", "contribution-recorded"],
    events: [
      playerActions.inspectCommunityEvent,
      playerActions.contributeToCommunityProgress,
    ],
    transitions: [
      {
        from: "event-visible",
        action: playerActions.inspectCommunityEvent,
        to: "contribution-eligible",
      },
      {
        from: "contribution-eligible",
        action: playerActions.contributeToCommunityProgress,
        to: "contribution-recorded",
      },
      {
        from: "contribution-recorded",
        action: playerActions.inspectCommunityEvent,
        to: "contribution-recorded",
      },
    ],
    forbiddenTransitions: [
      {
        state: "event-visible",
        action: playerActions.contributeToCommunityProgress,
        reason:
          "Community contributions require eligibility context for the specific shared event.",
      },
      {
        state: "contribution-recorded",
        action: playerActions.contributeToCommunityProgress,
        reason:
          "The same contribution cannot be double-counted into shared progress.",
      },
    ],
    requiredCoverage: fullStateCoverage,
    evidence: workflowEvidence,
  }),

  tradeExchange: workflow({
    id: playerActionWorkflows.tradeExchange,
    label: "Trade offer and exchange lifecycle",
    initialState: "economy-open",
    states: ["economy-open", "offer-active", "exchange-committed"],
    events: [
      playerActions.openEconomy,
      playerActions.offerTrade,
      playerActions.acceptTrade,
    ],
    transitions: [
      {
        from: "economy-open",
        action: playerActions.openEconomy,
        to: "economy-open",
      },
      {
        from: "economy-open",
        action: playerActions.offerTrade,
        to: "offer-active",
      },
      {
        from: "offer-active",
        action: playerActions.offerTrade,
        to: "offer-active",
      },
      {
        from: "offer-active",
        action: playerActions.acceptTrade,
        to: "exchange-committed",
      },
      {
        from: "exchange-committed",
        action: playerActions.openEconomy,
        to: "exchange-committed",
      },
    ],
    forbiddenTransitions: [
      {
        state: "economy-open",
        action: playerActions.acceptTrade,
        reason: "Accepting a trade requires an active eligible offer.",
      },
      {
        state: "exchange-committed",
        action: playerActions.acceptTrade,
        reason:
          "A committed exchange cannot be replayed as a second ownership mutation.",
      },
    ],
    requiredCoverage: fullStateCoverage,
    evidence: workflowEvidence,
  }),
} as const satisfies Record<string, PlayerActionWorkflow>;
