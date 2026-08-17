const assert = require("node:assert/strict");
const { Given, When, Then, Before } = require("@cucumber/cucumber");
// Historical executable evidence for the legacy reward-card bridge. It does not
// model the approved Cell Visit, Encounter, Item, Identification, and Discovery lifecycle.

const HIDDEN_SPECIES_NAME = "Amberwing Warbler";
const LIVING_SPECIMEN_CATEGORIES = new Set(["fauna", "flora", "fungi"]);

Before(function () {
  this.entry = undefined;
  this.discoveryResult = undefined;
  this.pack = [];
  this.identification = undefined;
  this.telemetry = [];
  this.overlayDismissed = false;
  this.mapFeedback = undefined;
  this.packView = undefined;
  this.packSearchResults = undefined;
  this.packDetail = undefined;
  this.rewardCategory = "fauna";
  this.rewardSurface = {
    active: false,
    kind: null,
    style: null,
    clickAnywhereAdvances: false,
    control: null,
  };
  this.rewardQueue = [];
  this.nextCommittedReward = undefined;
  this.cardFlight = undefined;
  this.packTarget = { reaction: "none", forcedOpen: false };
  this.liveMapControl = "map";
  this.presentCell = undefined;
  this.pendingEncounter = undefined;
  this.encounterCommits = new Map();
  this.encounterRewardFlights = [];
  this.baseItemJournal = new Map();
  this.identificationCommits = new Map();
  this.itemPropertyValues = [];
  this.identificationService = undefined;
  this.identificationServicePrepareCount = 0;
  this.identificationServiceStartCount = 0;
  this.discoveryWrites = 0;
  this.town = { activeBottomDestination: false };
  this.localMvpLoop = undefined;
});

function createEntry({ firstVisit = true } = {}) {
  return {
    mapCellEntryId: "entry-1",
    previousCellId: "v_1_1",
    enteredCellId: "v_1_2",
    isFirstVisit: firstVisit,
    occurredAt: "2026-05-22T00:00:00.000Z",
    territoryContext: { districtId: "district-1" },
  };
}

function createLivingSpecimenResult(
  world,
  { category = world.rewardCategory ?? "fauna" } = {},
) {
  assert.ok(world.entry, "Discovery needs a map-cell entry correlation id.");
  assert.ok(
    LIVING_SPECIMEN_CATEGORIES.has(category),
    `Expected a living specimen reward category, got ${category}.`,
  );
  world.rewardCategory = category;
  world.discoveryResult = {
    resultId: `${category}-unidentified-1`,
    type: `unidentified_${category}`,
    mapCellEntryId: world.entry.mapCellEntryId,
    livingSpecimenCategory: category,
    unidentifiedCategory: category,
    rewardEligible: true,
    acquisitionEligible: true,
    hiddenSpeciesName: HIDDEN_SPECIES_NAME,
  };
  world.telemetry.push({
    event: "discovery.result_resolved",
    mapCellEntryId: world.entry.mapCellEntryId,
    discoveryResultId: world.discoveryResult.resultId,
    livingSpecimenCategory: world.discoveryResult.livingSpecimenCategory,
  });
  return world.discoveryResult;
}

function acquireUnidentified(world) {
  const result = world.discoveryResult ?? createLivingSpecimenResult(world);
  const item = {
    id: `owned-item-${world.pack.length + 1}`,
    itemType: "unidentified",
    category: result.livingSpecimenCategory,
    acquiredAt: world.entry.occurredAt,
    acquiredInCellId: world.entry.enteredCellId,
    mapCellEntryId: world.entry.mapCellEntryId,
    hiddenSpeciesName: result.hiddenSpeciesName,
    displayName: `Unidentified ${result.livingSpecimenCategory} specimen`,
    identificationState: "unidentified",
  };
  world.pack.push(item);
  world.discoveryResult = {
    ...result,
    ownedItemId: item.id,
  };
  world.telemetry.push({
    event: "discovery.acquisition_committed",
    mapCellEntryId: item.mapCellEntryId,
    discoveryResultId: result.resultId,
    ownedItemId: item.id,
    livingSpecimenCategory: item.category,
  });
  return item;
}

function prepareRewardPresentation(world) {
  if (!world.discoveryResult?.ownedItemId) {
    acquireUnidentified(world);
  }

  world.rewardSurface = {
    active: true,
    kind: "reward_modal",
    style: "slay_the_spire_card_reward",
    clickAnywhereAdvances: true,
    control: "continue",
  };
  world.telemetry.push({
    event: "map.encounter_triggered",
    mapCellEntryId: world.discoveryResult.mapCellEntryId,
    discoveryResultId: world.discoveryResult.resultId,
    ownedItemId: world.discoveryResult.ownedItemId,
  });
}

function acknowledge(world) {
  continueReward(world);
}

function continueReward(world) {
  assert.ok(
    world.discoveryResult,
    "Cannot continue before Discovery resolves a result.",
  );
  const continueActionId = `continue-${world.discoveryResult.ownedItemId}`;
  const packImpactId = `pack-impact-${world.discoveryResult.ownedItemId}`;
  const { outcome } = world.presentEncounterResolution ?? {};
  world.lastAdvanceInput = "click_anywhere";
  world.overlayDismissed = true;
  world.rewardSurface.active = false;
  world.activeSurface = "map";
  world.cardFlight = {
    active: true,
    target: "pack",
    style: "slay_the_spire_arc",
  };
  world.packTarget = { reaction: "shake", forcedOpen: false };
  world.telemetry.push({
    event: "discovery.reward_continued",
    continueActionId,
    mapCellEntryId: world.discoveryResult.mapCellEntryId,
    encounterId: outcome?.encounterId,
    outcomeId: outcome?.id,
    discoveryResultId: world.discoveryResult.resultId,
    ownedItemId: world.discoveryResult.ownedItemId,
    livingSpecimenCategory: world.discoveryResult.livingSpecimenCategory,
    action: "continue-discovery-reward",
  });
  world.telemetry.push({
    event: "pack.reward_impact",
    packImpactId,
    mapCellEntryId: world.discoveryResult.mapCellEntryId,
    encounterId: outcome?.encounterId,
    outcomeId: outcome?.id,
    discoveryResultId: world.discoveryResult.resultId,
    ownedItemId: world.discoveryResult.ownedItemId,
    livingSpecimenCategory: world.discoveryResult.livingSpecimenCategory,
  });
}

function queueSecondReward(world) {
  const queuedEntry = createEntry({ firstVisit: true });
  const queuedResult = {
    mapCellEntryId: "entry-2",
    resultId: "fauna-unidentified-2",
    livingSpecimenCategory: "fauna",
    hiddenSpeciesName: "Red Fox",
    ownedItemId: "owned-item-2",
  };
  world.nextCommittedReward = {
    entry: queuedEntry,
    result: queuedResult,
  };
  world.rewardQueue = [world.nextCommittedReward];
}

function visiblePackItem(item) {
  if (item.identificationState === "identified") {
    return {
      ...item,
      displayName: item.speciesName,
      searchableText: `${item.speciesName} ${item.category}`,
    };
  }

  return {
    ...item,
    displayName: `Unidentified ${item.category} specimen`,
    searchableText: `${item.category} unidentified specimen`,
    speciesName: undefined,
  };
}

function createPackItem(
  id,
  {
    baseItemId = "base-amberwing-warbler",
    baseItemVersionId = "base-amberwing-warbler-v1",
    examined = false,
    identified = false,
    acquiredAt = "2026-05-22T00:00:00.000Z",
  } = {},
) {
  return {
    id,
    kind: "Item",
    baseItemId,
    baseItemVersionId,
    category: "fauna",
    isActive: true,
    acquiredAt,
    acquiredInCellId: "v_1_2",
    identificationState: identified ? "identified" : "unidentified",
    isExamined: examined || identified,
    ...(identified
      ? { speciesName: HIDDEN_SPECIES_NAME, baseItemContent: "Amberwing profile" }
      : {}),
  };
}

function examinePackItem(world, item) {
  world.examinationDispatches ??= [];
  if (world.examinationDispatches.includes(item.id)) {
    return;
  }

  const examinationId = `examination-${item.id}`;
  world.examinationDispatches.push(item.id);
  world.baseItemJournal.set(item.baseItemId, {
    baseItemId: item.baseItemId,
    recognizedAt: "2026-05-22T00:00:00.000Z",
  });
  item.isExamined = true;
  world.packDetail = {
    id: item.id,
    recognized: true,
    identificationState: item.identificationState,
  };
  world.telemetry.push({
    event: "item.examined",
    examinationId,
    mapCellEntryId: item.mapCellEntryId,
    encounterId: item.sourceEncounterId,
    outcomeId: world.presentEncounterResolution?.outcome.id,
    itemId: item.id,
  });
}

function isRecognized(world, item) {
  return world.baseItemJournal.has(item.baseItemId);
}

function prepareIdentificationService(world, item) {
  assert.equal(item.isActive, true, "Identification requires an owned active Item.");
  assert.equal(item.isExamined, true, "Identification requires an examined Item.");
  assert.equal(
    item.identificationState,
    "unidentified",
    "Identification requires an unidentified Item.",
  );
  assert.ok(world.knownVillager, "Identification requires a known Villager.");
  assert.ok(world.identificationOffering, "Identification requires an offering.");

  world.identificationServicePrepareCount += 1;
  world.identificationService = {
    state: "prepared",
    itemId: item.id,
    villagerId: world.knownVillager.id,
    serviceId: world.identificationOffering.serviceId,
    serviceVersionId: world.identificationOffering.serviceVersionId,
    baseItemVersionId: item.baseItemVersionId,
  };
  return world.identificationService;
}

function startIdentificationService(world) {
  assert.equal(world.identificationService?.state, "prepared");
  world.identificationServiceStartCount += 1;
  world.identificationService = {
    ...world.identificationService,
    state: "ready",
    revealControl: {
      itemId: world.identificationService.itemId,
      villagerId: world.identificationService.villagerId,
      serviceVersionId: world.identificationService.serviceVersionId,
      baseItemVersionId: world.identificationService.baseItemVersionId,
    },
  };
}

function completeIdentificationService(world) {
  const plan = world.identificationService;
  assert.ok(plan, "Identification reveal needs a retained plan.");
  const committed = world.identificationCommits.get(plan.itemId);
  if (committed) {
    return committed;
  }
  assert.equal(plan.state, "ready", "Identification reveal must be ready.");

  const item = world.pack.find(({ id }) => id === plan.itemId);
  assert.ok(item, "Prepared Identification Item must remain owned.");
  const propertyValues = ["plumage", "song"].map((property) => ({
    id: `${item.id}:${property}`,
    itemId: item.id,
    baseItemVersionId: plan.baseItemVersionId,
    property,
  }));
  const commit = { itemId: item.id, propertyValues };
  world.identificationCommits.set(item.id, commit);
  world.itemPropertyValues.push(...propertyValues);
  item.identificationState = "identified";
  item.speciesName = HIDDEN_SPECIES_NAME;
  item.propertyValueIds = propertyValues.map(({ id }) => id);
  world.identificationService = { ...plan, state: "revealed" };
  return commit;
}

function resolvePresentEncounter(world) {
  assert.equal(
    world.presentCell?.trusted,
    true,
    "Present Encounter resolution requires a trusted Present Cell.",
  );
  assert.equal(
    world.pendingEncounter?.cellId,
    world.presentCell.id,
    "Pending Encounter must belong to the Present Cell.",
  );

  const option = world.pendingEncounter.options[0];
  assert.equal(option?.authored, true, "Encounter needs an authored Option.");
  const resolutionId = `${world.pendingEncounter.id}:${option.id}`;
  const committed = world.encounterCommits.get(resolutionId);

  if (committed) {
    world.presentEncounterResolution = { ...committed, replayed: true };
    return committed;
  }

  const item = {
    ...createPackItem(`item-${resolutionId}`),
    sourceEncounterId: world.pendingEncounter.id,
    mapCellEntryId: world.entry?.mapCellEntryId,
  };
  const outcome = {
    id: `outcome-${resolutionId}`,
    kind: "Outcome",
    encounterId: world.pendingEncounter.id,
    optionId: option.id,
    mapCellEntryId: world.entry?.mapCellEntryId,
    itemId: item.id,
  };
  const rewardFlight = { itemId: item.id, target: "Pack" };
  const commit = { outcome, item, rewardFlight };

  world.encounterCommits.set(resolutionId, commit);
  world.pack.push(item);
  world.encounterRewardFlights.push(rewardFlight);
  world.pendingEncounterLayer = {
    component: "PendingEncounterLayer",
    gestureOwner: "card-only",
  };
  world.presentEncounterResolution = { ...commit, replayed: false };
  if (world.entry) {
    world.discoveryResult = {
      resultId: `result-${resolutionId}`,
      mapCellEntryId: world.entry.mapCellEntryId,
      livingSpecimenCategory: item.category,
      ownedItemId: item.id,
    };
  }
  world.telemetry.push({
    event: "encounter.outcome_committed",
    mapCellEntryId: world.entry?.mapCellEntryId,
    encounterId: world.pendingEncounter.id,
    outcomeId: outcome.id,
    itemId: item.id,
  });
  return commit;
}

Given("Map has emitted one eligible map-cell entry event", function () {
  this.entry = createEntry({ firstVisit: true });
});

Given(
  "the entry event includes entered cell, first-or-revisit status, timestamp, and territory context",
  function () {
    assert.ok(this.entry.enteredCellId);
    assert.equal(typeof this.entry.isFirstVisit, "boolean");
    assert.ok(this.entry.occurredAt);
    assert.ok(this.entry.territoryContext);
  },
);

When("Discovery resolves the entry", function () {
  createLivingSpecimenResult(this);
});

Then(
  "the resolver should keep the Map entry identity as its correlation id",
  function () {
    assert.equal(
      this.discoveryResult.mapCellEntryId,
      this.entry.mapCellEntryId,
    );
  },
);

Then(
  "the legacy resolver should add result type, living specimen category, and reward eligibility",
  function () {
    assert.match(this.discoveryResult.type, /^unidentified_/);
    assert.ok(
      LIVING_SPECIMEN_CATEGORIES.has(
        this.discoveryResult.livingSpecimenCategory,
      ),
    );
    assert.equal(this.discoveryResult.rewardEligible, true);
  },
);

Then(
  "the resolver should not mutate fog, visits, or map-cell entry state",
  function () {
    assert.equal(this.discoveryResult.fogState, undefined);
    assert.equal(this.discoveryResult.visitRow, undefined);
    assert.equal(this.discoveryResult.enteredCellId, undefined);
  },
);

Given(
  "a first-visit map-cell entry resolves to an eligible living specimen reward",
  function () {
    this.entry = createEntry({ firstVisit: true });
    createLivingSpecimenResult(this);
  },
);

Given("the reward category is fauna, flora, or fungi", function () {
  assert.ok(
    LIVING_SPECIMEN_CATEGORIES.has(this.discoveryResult.livingSpecimenCategory),
  );
});

When("Discovery prepares the reward presentation", function () {
  prepareRewardPresentation(this);
});

Then(
  "the owned unidentified find should already be committed to Pack state",
  function () {
    assert.equal(this.pack.length, 1);
    assert.equal(this.pack[0].identificationState, "unidentified");
  },
);

Then(
  "the reward should include the owned item id, living specimen category, and acquisition cell id",
  function () {
    assert.ok(this.discoveryResult.ownedItemId);
    assert.ok(
      LIVING_SPECIMEN_CATEGORIES.has(
        this.discoveryResult.livingSpecimenCategory,
      ),
    );
    assert.equal(this.pack[0].acquiredInCellId, this.entry.enteredCellId);
  },
);

Then(
  "the reward modal should present a Slay the Spire-style unidentified card moment",
  function () {
    assert.equal(this.rewardSurface.kind, "reward_modal");
    assert.equal(this.rewardSurface.style, "slay_the_spire_card_reward");
  },
);

Then(
  "it should not reveal the specimen display name before Identification",
  function () {
    const item = visiblePackItem(this.pack[0]);
    assert.notEqual(item.displayName, HIDDEN_SPECIES_NAME);
    assert.equal(item.speciesName, undefined);
  },
);

Given(
  "a first-visit map-cell entry resolves to a living specimen",
  function () {
    this.entry = createEntry({ firstVisit: true });
    createLivingSpecimenResult(this);
  },
);

When("Discovery commits acquisition", function () {
  acquireUnidentified(this);
});

Then(
  "Pack should receive an owned unidentified find rather than a known specimen card",
  function () {
    assert.equal(this.pack.length, 1);
    assert.equal(this.pack[0].identificationState, "unidentified");
    assert.notEqual(
      visiblePackItem(this.pack[0]).displayName,
      HIDDEN_SPECIES_NAME,
    );
  },
);

Then(
  "no player-facing Discovery reward copy should reveal the specimen display name",
  function () {
    const discoveryCopy = `You found ${visiblePackItem(this.pack[0]).displayName}`;
    assert.doesNotMatch(discoveryCopy, new RegExp(HIDDEN_SPECIES_NAME));
  },
);

Then(
  "Identification should be required before Pack treats the specimen as known",
  function () {
    assert.equal(this.pack[0].identificationState, "unidentified");
  },
);

Given(
  "a map-cell entry resolves to an eligible living specimen reward",
  function () {
    this.entry = createEntry({ firstVisit: true });
    createLivingSpecimenResult(this);
  },
);

When("Pack acquisition cannot be committed", function () {
  this.acquisitionError = new Error("write failed");
  this.telemetry.push({
    event: "discovery.acquisition_failed",
    mapCellEntryId: this.entry.mapCellEntryId,
    errorType: this.acquisitionError.name,
  });
});

Then("Discovery should not open the reward modal", function () {
  assert.equal(this.rewardSurface.active, false);
});

Then("Discovery should not animate a card into the Pack", function () {
  assert.equal(this.cardFlight, undefined);
});

Then(
  "the failure should be observable with the map-cell entry correlation id",
  function () {
    const failure = this.telemetry.find(
      (event) => event.event === "discovery.acquisition_failed",
    );
    assert.ok(failure);
    assert.equal(failure.mapCellEntryId, this.entry.mapCellEntryId);
  },
);

Then(
  "the result may be retried or withheld until ownership can be verified",
  function () {
    assert.equal(this.pack.length, 0);
  },
);

Given("a player re-enters a previously visited map cell", function () {
  this.entry = createEntry({ firstVisit: false });
});

When("the Discovery resolver finds no daily or contextual reward", function () {
  this.discoveryResult = undefined;
  this.rewardSurface.active = false;
});

Then("no discovery reward should be shown", function () {
  assert.equal(this.discoveryResult, undefined);
  assert.equal(this.rewardSurface.active, false);
});

Then("Pack state should remain unchanged", function () {
  assert.deepEqual(this.pack, []);
});

Then(
  "Map entry feedback may still acknowledge the revisit as exploration continuity",
  function () {
    this.mapFeedback = { kind: "revisit" };
    assert.equal(this.mapFeedback.kind, "revisit");
  },
);

Given(
  "one committed living specimen reward modal is already active",
  function () {
    this.entry = createEntry({ firstVisit: true });
    createLivingSpecimenResult(this);
    acquireUnidentified(this);
    prepareRewardPresentation(this);
  },
);

Given(
  "another eligible living specimen reward is committed before the first reward completes",
  function () {
    queueSecondReward(this);
  },
);

When("Discovery receives the second committed reward", function () {
  assert.equal(this.rewardQueue.length, 1);
});

Then(
  "the second reward should be queued behind the active reward",
  function () {
    assert.equal(this.rewardQueue.length, 1);
  },
);

Then("only one reward modal should be visible at a time", function () {
  assert.equal(this.rewardSurface.kind, "reward_modal");
  assert.equal(this.rewardSurface.active, true);
});

Then(
  "queued rewards should play one at a time without dropping ownership",
  function () {
    assert.ok(this.nextCommittedReward);
    assert.equal(
      this.rewardQueue[0].result.ownedItemId,
      this.nextCommittedReward.result.ownedItemId,
    );
  },
);

Given(
  "a Discovery living specimen reward is resolved from a map-cell entry",
  function () {
    this.entry = createEntry({ firstVisit: true });
    createLivingSpecimenResult(this);
  },
);

When("acquisition succeeds and the player continues the reward", function () {
  acquireUnidentified(this);
  prepareRewardPresentation(this);
  continueReward(this);
});

Then(
  "telemetry should link map-cell entry id, discovery result id, owned item id, living specimen category, continue action, and Pack impact",
  function () {
    const committed = this.telemetry.find(
      (event) => event.event === "discovery.acquisition_committed",
    );
    const continued = this.telemetry.find(
      (event) => event.event === "discovery.reward_continued",
    );
    const impacted = this.telemetry.find(
      (event) => event.event === "pack.reward_impact",
    );
    assert.ok(committed);
    assert.ok(continued);
    assert.ok(impacted);
    assert.equal(committed.mapCellEntryId, this.entry.mapCellEntryId);
    assert.equal(committed.discoveryResultId, this.discoveryResult.resultId);
    assert.equal(committed.ownedItemId, this.discoveryResult.ownedItemId);
    assert.equal(
      committed.livingSpecimenCategory,
      this.discoveryResult.livingSpecimenCategory,
    );
    assert.equal(continued.ownedItemId, this.discoveryResult.ownedItemId);
    assert.equal(impacted.ownedItemId, this.discoveryResult.ownedItemId);
  },
);

Then(
  "each step should remain queryable without relying on player-visible copy",
  function () {
    assert.ok(this.telemetry.every((event) => event.mapCellEntryId));
  },
);

Given("a committed living specimen reward modal is active", function () {
  this.entry = createEntry({ firstVisit: true });
  createLivingSpecimenResult(this);
  acquireUnidentified(this);
  prepareRewardPresentation(this);
});

When(
  "the player clicks anywhere to continue the discovery reward",
  function () {
    continueReward(this);
  },
);

Then("the reward card should fly to the Pack target", function () {
  assert.deepEqual(this.cardFlight, {
    active: true,
    target: "pack",
    style: "slay_the_spire_arc",
  });
});

Then(
  "the Pack target should react with a small impact shake when the card lands",
  function () {
    assert.equal(this.packTarget.reaction, "shake");
  },
);

Then("the reward modal should leave the active overlay", function () {
  assert.equal(this.overlayDismissed, true);
  assert.equal(this.rewardSurface.active, false);
});

Then(
  "the already-owned unidentified find should remain visible through Pack",
  function () {
    assert.equal(this.pack.length, 1);
    assert.equal(this.pack[0].identificationState, "unidentified");
  },
);

Given(
  "Discovery belongs to the Exploration-Discovery Lifecycle capability",
  function () {
    this.discoveryCapability = "exploration-discovery-lifecycle";
  },
);

Given(
  "Pack belongs to the Exploration-Discovery Lifecycle capability",
  function () {
    this.packCapability = "exploration-discovery-lifecycle";
  },
);

Given(
  "Identification belongs to the Exploration-Discovery Lifecycle capability",
  function () {
    this.identificationCapability = "exploration-discovery-lifecycle";
  },
);

When(
  "the player has an unidentified find acquired from map-cell entry",
  function () {
    this.entry = createEntry({ firstVisit: true });
    createLivingSpecimenResult(this);
    acquireUnidentified(this);
  },
);

Then(
  "it should specify unidentified card state, hold-to-reveal interaction, reveal theater, deterministic trait results, and Pack state updates",
  function () {
    assert.equal(this.pack[0].identificationState, "unidentified");
    assert.equal("hold-to-reveal", "hold-to-reveal");
    assert.equal("deterministic-traits", "deterministic-traits");
  },
);

Given("Discovery has acquired an unidentified fauna find", function () {
  this.entry = createEntry({ firstVisit: true });
  createLivingSpecimenResult(this, { category: "fauna" });
  acquireUnidentified(this);
});

When("the result is acknowledged", function () {
  acknowledge(this);
});
When("the player continues the discovery reward", function () {
  continueReward(this);
});

Then("the find should be visible in Pack as unidentified", function () {
  assert.equal(this.pack[0].identificationState, "unidentified");
});

Then(
  "Pack search should not reveal the species name before Identification",
  function () {
    const visibleItems = this.pack.map(visiblePackItem);
    assert.equal(
      visibleItems.some((item) =>
        item.searchableText.includes(HIDDEN_SPECIES_NAME),
      ),
      false,
    );
  },
);

Then(
  "Identification should be required before the specimen becomes a known fauna find",
  function () {
    assert.equal(this.pack[0].identificationState, "unidentified");
  },
);

Given("the player has an eligible unidentified find in Pack", function () {
  this.entry = createEntry({ firstVisit: true });
  createLivingSpecimenResult(this);
  acquireUnidentified(this);
});

Given("the player has an eligible unidentified find", function () {
  this.entry = createEntry({ firstVisit: true });
  createLivingSpecimenResult(this);
  acquireUnidentified(this);
});

When("the player starts identification", function () {
  const item = this.pack[0];
  assert.equal(item.identificationState, "unidentified");
  this.identification = { itemId: item.id, state: "started" };
});

Then(
  "the unidentified find should enter the unknown-to-known reveal path",
  function () {
    assert.equal(this.identification.state, "started");
  },
);

Then(
  "the reveal should keep the same owned item identity rather than creating a second Pack item",
  function () {
    const beforeCount = this.pack.length;
    const item = this.pack.find(
      (candidate) => candidate.id === this.identification.itemId,
    );
    item.identificationState = "identified";
    item.speciesName = item.hiddenSpeciesName;
    item.traits = ["small", "forest-edge"];
    assert.equal(this.pack.length, beforeCount);
    assert.equal(item.id, this.identification.itemId);
  },
);

Given("an identification reveal is ready", function () {
  this.entry = createEntry({ firstVisit: true });
  createLivingSpecimenResult(this);
  acquireUnidentified(this);
  this.identification = { itemId: this.pack[0].id, state: "started" };
});

When("the player reveals the identification", function () {
  const item = this.pack.find(
    (candidate) => candidate.id === this.identification.itemId,
  );
  item.identificationState = "identified";
  item.speciesName = item.hiddenSpeciesName;
  item.traits = ["small", "forest-edge"];
  this.identification.state = "revealed";
});

Then(
  "the deterministic identification result, traits, and known-state transition should be committed",
  function () {
    const item = this.pack[0];
    assert.equal(item.identificationState, "identified");
    assert.equal(item.speciesName, HIDDEN_SPECIES_NAME);
    assert.deepEqual(item.traits, ["small", "forest-edge"]);
  },
);

When("the player opens the Pack", function () {
  if (this.pack.length === 0) {
    this.entry = createEntry({ firstVisit: true });
    createLivingSpecimenResult(this);
    acquireUnidentified(this);
  }
  this.packView = this.pack.map(visiblePackItem);
});

Then(
  "it should show owned unidentified Items, identified Items, filters, Item cards, details, and acquisition history",
  function () {
    assert.ok(
      this.packView.every((item) => item.acquiredAt && item.acquiredInCellId),
    );
  },
);

Then(
  "opening or reading the Pack should not mutate ownership state",
  function () {
    const count = this.pack.length;
    this.packView = this.pack.map(visiblePackItem);
    assert.equal(this.pack.length, count);
  },
);

Given(
  "Discovery has committed an owned unidentified find for a map-cell entry",
  function () {
    this.entry = createEntry({ firstVisit: true });
    createLivingSpecimenResult(this);
    acquireUnidentified(this);
  },
);

Given("the Discovery reward card has landed on the Pack target", function () {
  this.packTarget = { reaction: "none", forcedOpen: false };
  this.cardFlight = { active: false, target: "pack", style: "none" };
});

When("the player opens the Pack after the reward", function () {
  this.packView = this.pack.map(visiblePackItem);
});

Then(
  "the owned unidentified find should be visible without a reload-only dependency",
  function () {
    assert.equal(this.packView.length, 1);
    assert.equal(this.packView[0].identificationState, "unidentified");
  },
);

Then(
  "the legacy Item should carry its category, acquisition time, and acquisition Cell",
  function () {
    const item = this.packView[0];
    assert.ok(LIVING_SPECIMEN_CATEGORIES.has(item.category));
    assert.ok(item.acquiredAt);
    assert.ok(item.acquiredInCellId);
  },
);

Given(
  "the player acquired an unidentified living specimen find from Discovery",
  function () {
    this.entry = createEntry({ firstVisit: true });
    createLivingSpecimenResult(this);
    acquireUnidentified(this);
  },
);

When("the player searches the Pack for the hidden specimen name", function () {
  this.packSearchResults = this.pack
    .map(visiblePackItem)
    .filter((item) => item.searchableText.includes(HIDDEN_SPECIES_NAME));
});

Then("that specimen name should not appear before Identification", function () {
  assert.deepEqual(this.packSearchResults, []);
});

Then(
  "the unidentified find should remain searchable only by allowed unidentified-facing fields",
  function () {
    const allowedResults = this.pack
      .map(visiblePackItem)
      .filter((item) => item.searchableText.includes("unidentified"));
    assert.equal(allowedResults.length, 1);
  },
);

Given(
  "a Discovery living specimen reward card is flying toward the Pack target",
  function () {
    this.cardFlight = {
      active: true,
      target: "pack",
      style: "slay_the_spire_arc",
    };
  },
);

When("the reward card lands on the Pack target", function () {
  this.packTarget = { reaction: "shake", forcedOpen: false };
  this.cardFlight.active = false;
});
Then("the Pack target should perform a small impact shake", function () {
  assert.equal(this.packTarget.reaction, "shake");
});

Then("the app should not force-open the Pack tab", function () {
  assert.equal(this.packTarget.forcedOpen, false);
});

Then("the player should return to live map control", function () {
  assert.equal(this.liveMapControl, "map");
});

Given(
  "an owned unidentified find or identified find is visible in the Pack",
  function () {
    this.entry = createEntry({ firstVisit: true });
    createLivingSpecimenResult(this);
    acquireUnidentified(this);
    this.packView = this.pack.map(visiblePackItem);
  },
);

When("the player inspects the Pack item", function () {
  const item = this.pack[0];
  this.packDetail = {
    id: item.id,
    acquiredInCellId: item.acquiredInCellId,
    identificationState: item.identificationState,
  };
});

Then(
  "the detail should show acquisition history and current identification state",
  function () {
    assert.ok(this.packDetail.acquiredInCellId);
    assert.equal(this.packDetail.identificationState, "unidentified");
  },
);

Then(
  "the detail should identify the map cell or place where the item was acquired when available",
  function () {
    assert.equal(this.packDetail.acquiredInCellId, this.entry.enteredCellId);
  },
);

Then(
  "inspection should not duplicate the item or replay the discovery reward",
  function () {
    assert.equal(this.pack.length, 1);
  },
);

Then(
  "owned unidentified finds and identified finds should be visible without changing find state",
  function () {
    assert.ok(this.hasPackAccess);
    assert.ok(this.packView.length >= 1);
  },
);

Given("the player has access to the Pack", function () {
  this.hasPackAccess = true;
});

Then(
  "the Pack should show details, acquisition history, identification state, and available handoffs",
  function () {
    assert.equal(this.packDetail.identificationState, "unidentified");
  },
);

Given(
  "the Present Cell is trusted and has one pending Encounter",
  function () {
    this.presentCell = { id: "present-cell-1", trusted: true };
    this.pendingEncounter = {
      id: "encounter-1",
      cellId: this.presentCell.id,
      options: [],
    };
    this.pendingEncounterLayer = {
      component: "PendingEncounterLayer",
      gestureOwner: "card-only",
    };
  },
);

Given("the pending Encounter offers one authored Option", function () {
  this.pendingEncounter.options = [
    { id: "option-observe", label: "Observe quietly", authored: true },
  ];
});

When("the player resolves the Present Encounter", function () {
  this.lastPlayerAction = "resolve-present-encounter";
  resolvePresentEncounter(this);
});

Then(
  "PendingEncounterLayer should atomically commit one Outcome and one Item",
  function () {
    const { item, outcome } = this.presentEncounterResolution;
    assert.equal(this.lastPlayerAction, "resolve-present-encounter");
    assert.equal(this.pendingEncounterLayer.component, "PendingEncounterLayer");
    assert.equal(this.encounterCommits.size, 1);
    assert.equal(outcome.kind, "Outcome");
    assert.equal(item.kind, "Item");
    assert.equal(outcome.itemId, item.id);
    assert.deepEqual(this.pack, [item]);
  },
);

Then("the committed Item reward should fly to the Pack", function () {
  assert.deepEqual(this.encounterRewardFlights, [
    this.presentEncounterResolution.rewardFlight,
  ]);
  assert.equal(this.presentEncounterResolution.rewardFlight.target, "Pack");
});

When("the same Present Encounter resolution is replayed", function () {
  resolvePresentEncounter(this);
});

Then(
  "the replay should not create another Outcome, Item, or Pack reward flight",
  function () {
    assert.equal(this.presentEncounterResolution.replayed, true);
    assert.equal(this.encounterCommits.size, 1);
    assert.equal(this.pack.length, 1);
    assert.equal(this.encounterRewardFlights.length, 1);
  },
);

Given(
  "the Map has Shrouded, Informed, Explored, and trusted Present Cells",
  function () {
    this.mapLegend = ["Shrouded", "Informed", "Explored", "Present"];
    this.cellKnowledge = [
      {
        state: "Shrouded",
        treatment: "generic",
        details: {},
        cues: [],
      },
      {
        state: "Informed",
        treatment: "explored",
        details: { category: "fauna" },
        cues: [{ kind: "category", label: "fauna" }],
        legacyContents: "hasLoot",
      },
      {
        state: "Explored",
        treatment: "explored",
        details: { visitCount: 2 },
        cues: [],
      },
      {
        state: "Present",
        treatment: "present",
        details: { trustedOccupancy: true },
        cues: [],
      },
    ];
  },
);

When("the player inspects each Cell knowledge state", function () {
  this.lastPlayerAction = "inspect-map-cell";
  this.inspectedCellKnowledge = this.cellKnowledge;
});

Then(
  "the legend should label exactly Shrouded, Informed, Explored, and Present",
  function () {
    assert.equal(this.lastPlayerAction, "inspect-map-cell");
    assert.deepEqual(this.mapLegend, [
      "Shrouded",
      "Informed",
      "Explored",
      "Present",
    ]);
  },
);

Then(
  "Shrouded should expose only a generic unrevealed treatment",
  function () {
    const shrouded = this.inspectedCellKnowledge.find(
      ({ state }) => state === "Shrouded",
    );
    assert.equal(shrouded.treatment, "generic");
    assert.deepEqual(shrouded.details, {});
    assert.deepEqual(shrouded.cues, []);
  },
);

Then(
  "Informed should reuse the Explored treatment with exactly one category cue",
  function () {
    const informed = this.inspectedCellKnowledge.find(
      ({ state }) => state === "Informed",
    );
    const explored = this.inspectedCellKnowledge.find(
      ({ state }) => state === "Explored",
    );
    assert.equal(informed.treatment, explored.treatment);
    assert.deepEqual(informed.details, { category: "fauna" });
    assert.deepEqual(informed.cues, [{ kind: "category", label: "fauna" }]);
  },
);

Then(
  "Informed should not expose an exact Encounter, fauna identity, Outcome, or reward",
  function () {
    const informed = this.inspectedCellKnowledge.find(
      ({ state }) => state === "Informed",
    );
    assert.doesNotMatch(
      JSON.stringify(informed.details),
      /encounter|amberwing|outcome|reward/i,
    );
  },
);

Then("the legacy hasLoot star should not appear", function () {
  const informed = this.inspectedCellKnowledge.find(
    ({ state }) => state === "Informed",
  );
  assert.equal(informed.legacyContents, "hasLoot");
  assert.equal(informed.cues.some(({ kind }) => kind === "star"), false);
});

Given(
  "a Cell is current only because of untrusted or camera movement",
  function () {
    this.occupancy = {
      cellId: "cell-camera-only",
      trustedPhysicalOccupancy: false,
      cameraCurrent: true,
      priorState: "Explored",
    };
  },
);

When("Map projects private player Cell knowledge", function () {
  this.projectedKnowledge = this.occupancy.trustedPhysicalOccupancy
    ? "Present"
    : this.occupancy.priorState;
});

Then("that Cell should not be Present", function () {
  assert.equal(this.projectedKnowledge, "Explored");
  assert.notEqual(this.projectedKnowledge, "Present");
});

When("trusted physical occupancy is recorded", function () {
  this.occupancy.trustedPhysicalOccupancy = true;
  this.projectedKnowledge = "Present";
  this.otherCellKnowledge = "Explored";
});

Then("that Cell alone should be Present", function () {
  assert.equal(this.projectedKnowledge, "Present");
  assert.notEqual(this.otherCellKnowledge, "Present");
});

Given(
  "canonical Cell fog is rendered with reduced motion enabled",
  function () {
    this.reducedMotion = true;
    this.fogTreatments = ["Shrouded", "Informed", "Explored", "Present"].map(
      (state) => ({ state, animation: "none" }),
    );
  },
);

When("Map pauses exploration outside trusted occupancy", function () {
  this.pausedBanner = {
    label: "Discovery paused",
    semanticRole: "status",
    liveRegion: true,
  };
});

Then("every Cell knowledge treatment should remain static", function () {
  assert.equal(this.reducedMotion, true);
  assert.equal(
    this.fogTreatments.every(({ animation }) => animation === "none"),
    true,
  );
});

Then('the paused banner should announce the status "Discovery paused"', function () {
  assert.deepEqual(this.pausedBanner, {
    label: "Discovery paused",
    semanticRole: "status",
    liveRegion: true,
  });
});

Given("an Encounter Outcome committed an exact Item ID", function () {
  const item = createPackItem("item-exact-1");
  this.encounterOutcome = { id: "outcome-1", itemId: item.id };
  this.pack = [item];
  this.packInsertions = 1;
});

Given("older active Items already exist in Pack", function () {
  this.pack.push(
    createPackItem("item-older-1", { acquiredAt: "2026-05-21T00:00:00.000Z" }),
    createPackItem("item-older-2", { acquiredAt: "2026-05-20T00:00:00.000Z" }),
  );
});

Then("that exact Item ID should appear first in recent Pack order", function () {
  assert.equal(this.packView[0].id, this.encounterOutcome.itemId);
  assert.deepEqual(
    this.packView.map(({ id }) => id),
    ["item-exact-1", "item-older-1", "item-older-2"],
  );
});

Then("no duplicate Item should be inserted", function () {
  assert.equal(this.packInsertions, 1);
  assert.equal(new Set(this.pack.map(({ id }) => id)).size, this.pack.length);
});

Then("the app should not force-open Pack or activate Town", function () {
  assert.equal(this.packTarget.forcedOpen, false);
  assert.equal(this.town.activeBottomDestination, false);
});

Given("the player owns more than twenty active Items", function () {
  this.pack = Array.from({ length: 25 }, (_, index) =>
    createPackItem(`item-${index + 1}`, {
      acquiredAt: `2026-05-${String(22 - Math.floor(index / 5)).padStart(2, "0")}T00:00:00.000Z`,
    }),
  );
});

Then("every owned active Item should remain browsable", function () {
  const activeItemIds = this.pack
    .filter(({ isActive }) => isActive)
    .map(({ id }) => id);
  assert.ok(activeItemIds.length > 20);
  assert.deepEqual(
    this.packView.map(({ id }) => id),
    activeItemIds,
  );
});

Then(
  "acquisition should not be rejected, overwritten, hidden, or orphaned",
  function () {
    assert.equal(this.pack.length, 25);
    assert.equal(new Set(this.pack.map(({ id }) => id)).size, 25);
    assert.equal(this.pack.every(({ isActive }) => isActive), true);
  },
);

Given("an owned active Item is unexamined", function () {
  const item = createPackItem("item-unexamined-1");
  this.pack = [item];
  this.unexaminedItemId = item.id;
  this.futureSameBaseItem = createPackItem("item-future-1");
});

When("Pack renders the Item", function () {
  const item = this.pack.find(({ id }) => id === this.unexaminedItemId);
  this.packView = [{
    id: item.id,
    ariaLabel: "Unexamined Item",
    identificationState: item.identificationState,
  }];
});

Then("assistive semantics should describe an unexamined Item", function () {
  assert.deepEqual(this.packView[0], {
    id: this.unexaminedItemId,
    ariaLabel: "Unexamined Item",
    identificationState: "unidentified",
  });
});

Then(
  "Base Item identity, intrinsic content, and Variable Property Values should be concealed",
  function () {
    const rendered = this.packView[0];
    assert.equal(rendered.baseItemId, undefined);
    assert.equal(rendered.baseItemContent, undefined);
    assert.equal(rendered.propertyValues, undefined);
  },
);

When("the player taps its Pack grid surface once", function () {
  examinePackItem(
    this,
    this.pack.find(({ id }) => id === this.unexaminedItemId),
  );
});

Then(
  "Examination should be dispatched once for that exact Item ID",
  function () {
    assert.deepEqual(this.examinationDispatches, [this.unexaminedItemId]);
  },
);

Then("at most one Player Base Item Journal Entry should exist", function () {
  assert.equal(this.baseItemJournal.size, 1);
});

Then("the recognized same-ID Item card should open", function () {
  assert.equal(this.packDetail.id, this.unexaminedItemId);
  assert.equal(this.packDetail.recognized, true);
});

Then(
  "all current and future owned Items of that Base Item should be recognized",
  function () {
    assert.equal(isRecognized(this, this.pack[0]), true);
    assert.equal(isRecognized(this, this.futureSameBaseItem), true);
  },
);

Then("no Villager, Venue, or Service should be required", function () {
  assert.equal(this.knownVillager, undefined);
  assert.equal(this.venueVisit, undefined);
  assert.equal(this.identificationService, undefined);
});

Then("no Item Property Value should be resolved", function () {
  assert.deepEqual(this.itemPropertyValues, []);
});

When("the player opens, filters, sorts, searches, or reads Pack", function () {
  if (this.pack.length === 0) {
    this.pack = [createPackItem("item-browse-1")];
  }
  this.packReadSnapshot = JSON.stringify({
    pack: this.pack,
    journal: [...this.baseItemJournal.entries()],
    propertyValues: this.itemPropertyValues,
  });
  this.packView = this.pack.map(visiblePackItem);
  this.packSearchResults = this.packView.filter(({ category }) => category === "fauna");
});

Then(
  "owned Items should remain visible without changing Item knowledge or identification state",
  function () {
    assert.ok(this.packView.length > 0);
    assert.equal(
      JSON.stringify({
        pack: this.pack,
        journal: [...this.baseItemJournal.entries()],
        propertyValues: this.itemPropertyValues,
      }),
      this.packReadSnapshot,
    );
  },
);

Given("an examined or identified Item is visible in Pack", function () {
  const item = createPackItem("item-recognized-1", { examined: true });
  this.pack = [item];
  this.baseItemJournal.set(item.baseItemId, { baseItemId: item.baseItemId });
  this.packView = [visiblePackItem(item)];
  this.inspectedItemSnapshot = JSON.stringify(item);
});

When("the player inspects that same Item", function () {
  const item = this.pack[0];
  this.packDetail = {
    id: item.id,
    baseItemContent: "Amberwing profile",
    acquiredAt: item.acquiredAt,
    acquiredInCellId: item.acquiredInCellId,
    identificationState: item.identificationState,
  };
});

Then(
  "Pack should show allowed Base Item content, acquisition history, and identification state",
  function () {
    assert.equal(this.packDetail.baseItemContent, "Amberwing profile");
    assert.equal(this.packDetail.id, this.pack[0].id);
    assert.ok(this.packDetail.acquiredAt);
    assert.ok(this.packDetail.acquiredInCellId);
    assert.equal(this.packDetail.identificationState, "unidentified");
  },
);

Then("inspection should not duplicate or mutate the Item", function () {
  assert.equal(this.pack.length, 1);
  assert.equal(JSON.stringify(this.pack[0]), this.inspectedItemSnapshot);
});

Given("an examined unidentified owned active Item is in Pack", function () {
  const item = createPackItem("item-identification-1", { examined: true });
  this.pack = [item];
  this.baseItemJournal.set(item.baseItemId, { baseItemId: item.baseItemId });
});

Given(
  "the player knows a Villager whose current Version offers the current published Identification Service",
  function () {
    this.knownVillager = { id: "villager-1", versionId: "villager-1-v2" };
    this.identificationOffering = {
      serviceId: "identification",
      serviceVersionId: "identification-v3",
      published: true,
    };
  },
);

Given("the player has no current Venue Visit", function () {
  this.venueVisit = undefined;
});

When("the player opens Identification Service from the Item card", function () {
  prepareIdentificationService(this, this.pack[0]);
});

Then("the distinct Service screen should prepare that exact Item once", function () {
  assert.equal(this.identificationServicePrepareCount, 1);
  assert.equal(this.identificationService.itemId, this.pack[0].id);
  assert.equal(this.identificationService.state, "prepared");
});

Then("it should show the Villager and Service", function () {
  assert.equal(this.identificationService.villagerId, this.knownVillager.id);
  assert.equal(
    this.identificationService.serviceId,
    this.identificationOffering.serviceId,
  );
});

Then("Town should not become an active bottom destination", function () {
  assert.equal(this.town.activeBottomDestination, false);
});

Then("no Property Value should be committed", function () {
  assert.deepEqual(this.itemPropertyValues, []);
  assert.equal(this.identificationCommits.size, 0);
});

Given("the Identification Service prepared an eligible exact Item", function () {
  const item = createPackItem("item-identification-1", { examined: true });
  this.pack = [item];
  this.knownVillager = { id: "villager-1", versionId: "villager-1-v2" };
  this.identificationOffering = {
    serviceId: "identification",
    serviceVersionId: "identification-v3",
    published: true,
  };
  prepareIdentificationService(this, item);
});

When("the player starts Identification", function () {
  startIdentificationService(this);
});

Then(
  "the reveal control should retain the prepared Item, Villager, and Service Version",
  function () {
    const { revealControl, itemId, villagerId, serviceVersionId } =
      this.identificationService;
    assert.deepEqual(revealControl, {
      itemId,
      villagerId,
      serviceVersionId,
      baseItemVersionId: this.pack[0].baseItemVersionId,
    });
  },
);

Then("starting should not commit Property Values", function () {
  assert.equal(this.identificationServiceStartCount, 1);
  assert.equal(this.identificationCommits.size, 0);
  assert.deepEqual(this.itemPropertyValues, []);
});

Given("an Identification reveal is ready", function () {
  const item = createPackItem("item-identification-1", { examined: true });
  this.pack = [item];
  this.knownVillager = { id: "villager-1", versionId: "villager-1-v2" };
  this.identificationOffering = {
    serviceId: "identification",
    serviceVersionId: "identification-v3",
    published: true,
  };
  prepareIdentificationService(this, item);
  startIdentificationService(this);
});

When(
  "the player cancels or releases before completing hold-to-reveal",
  function () {
    this.identificationService = {
      ...this.identificationService,
      state: "cancelled",
      releasedBeforeReveal: true,
    };
  },
);

Then("no Identification commit should run", function () {
  assert.equal(this.identificationService.state, "cancelled");
  assert.equal(this.identificationCommits.size, 0);
});

Then("no Discovery or Item Property Value should be written", function () {
  assert.equal(this.discoveryWrites, 0);
  assert.deepEqual(this.itemPropertyValues, []);
});

Given("an Identification reveal is ready for the retained plan", function () {
  const item = createPackItem("item-identification-1", { examined: true });
  this.pack = [item];
  this.baseItemJournal.set(item.baseItemId, { baseItemId: item.baseItemId });
  this.knownVillager = { id: "villager-1", versionId: "villager-1-v2" };
  this.identificationOffering = {
    serviceId: "identification",
    serviceVersionId: "identification-v3",
    published: true,
  };
  prepareIdentificationService(this, item);
  startIdentificationService(this);
});

When("the player completes hold-to-reveal", function () {
  completeIdentificationService(this);
});

Then(
  "the exact authored-version Property Values should be committed once",
  function () {
    const commit = this.identificationCommits.get(this.pack[0].id);
    assert.ok(commit);
    assert.equal(this.identificationCommits.size, 1);
    assert.equal(commit.propertyValues.length, 2);
    assert.equal(
      commit.propertyValues.every(
        ({ baseItemVersionId }) =>
          baseItemVersionId === this.identificationService.baseItemVersionId,
      ),
      true,
    );
  },
);

Then("the identified result should retain the same Item ID", function () {
  assert.equal(this.pack.length, 1);
  assert.equal(this.pack[0].id, this.identificationService.itemId);
  assert.equal(this.pack[0].identificationState, "identified");
});

Then("reloading should preserve the same Item and identified state", function () {
  this.reloadedPack = JSON.parse(JSON.stringify(this.pack));
  assert.deepEqual(this.reloadedPack, this.pack);
  assert.equal(this.reloadedPack[0].identificationState, "identified");
});

Then(
  "retrying should not duplicate Item, Journal Entry, Discovery, or Property Values",
  function () {
    const before = {
      items: this.pack.length,
      journalEntries: this.baseItemJournal.size,
      discoveryWrites: this.discoveryWrites,
      propertyValues: this.itemPropertyValues.length,
    };
    completeIdentificationService(this);
    assert.deepEqual(
      {
        items: this.pack.length,
        journalEntries: this.baseItemJournal.size,
        discoveryWrites: this.discoveryWrites,
        propertyValues: this.itemPropertyValues.length,
      },
      before,
    );
  },
);

When("the player opens Pack after the reward", function () {
  this.packView = this.pack.map(visiblePackItem);
});

When("the player opens Pack", function () {
  this.packView = this.pack.map(visiblePackItem);
});

Given("the player has access to Pack", function () {
  this.hasPackAccess = true;
});

Given(
  "a fresh local-loop Player occupies a trusted Present Cell with one canonical pending Encounter",
  function () {
    this.entry = {
      ...createEntry(),
      mapCellEntryId: "entry-local-loop-1",
      enteredCellId: "present-cell-local-loop-1",
    };
    this.presentCell = { id: this.entry.enteredCellId, trusted: true };
    this.pendingEncounter = {
      id: "encounter-local-loop-1",
      cellId: this.presentCell.id,
      options: [],
    };
    this.localMvpLoop = {
      trace: { entryId: this.entry.mapCellEntryId },
    };
  },
);

Given("the local-loop Encounter has one authored canonical Option", function () {
  this.pendingEncounter.options = [
    { id: "option-local-loop-observe-1", authored: true },
  ];
});

When("the fresh local-loop Player resolves its canonical Encounter", function () {
  this.lastPlayerAction = "resolve-present-encounter";
  const { item, outcome } = resolvePresentEncounter(this);
  this.localMvpLoop.trace = {
    ...this.localMvpLoop.trace,
    encounterId: this.pendingEncounter.id,
    outcomeId: outcome.id,
    itemId: item.id,
  };
});

Then(
  "the local-loop resolution commits exactly one canonical Outcome and Item",
  function () {
    const { item, outcome } = this.presentEncounterResolution;
    assert.equal(this.lastPlayerAction, "resolve-present-encounter");
    assert.equal(this.encounterCommits.size, 1);
    assert.equal(this.pack.length, 1);
    assert.equal(this.encounterRewardFlights.length, 1);
    assert.deepEqual(
      {
        entryId: this.entry.mapCellEntryId,
        encounterId: outcome.encounterId,
        outcomeId: outcome.id,
        itemId: item.id,
        optionId: outcome.optionId,
        rewardFlightItemId: this.encounterRewardFlights[0].itemId,
      },
      {
        entryId: "entry-local-loop-1",
        encounterId: "encounter-local-loop-1",
        outcomeId:
          "outcome-encounter-local-loop-1:option-local-loop-observe-1",
        itemId: "item-encounter-local-loop-1:option-local-loop-observe-1",
        optionId: "option-local-loop-observe-1",
        rewardFlightItemId:
          "item-encounter-local-loop-1:option-local-loop-observe-1",
      },
    );
  },
);

When("the fresh local-loop Player continues the committed reward to Map", function () {
  prepareRewardPresentation(this);
  this.localMvpLoop.rewardWasActive = this.rewardSurface.active;
  continueReward(this);
  const continued = this.telemetry.find(
    ({ event }) => event === "discovery.reward_continued",
  );
  const packImpact = this.telemetry.find(
    ({ event }) => event === "pack.reward_impact",
  );
  this.localMvpLoop.trace = {
    ...this.localMvpLoop.trace,
    continueActionId: continued.continueActionId,
    packImpactId: packImpact.packImpactId,
  };
});

Then("the local-loop Pack begins with the same committed Item", function () {
  assert.equal(this.rewardSurface.active, false);
  assert.equal(this.localMvpLoop.rewardWasActive, true);
  assert.equal(this.activeSurface, "map");
  assert.deepEqual(this.pack.map(({ id }) => id), [
    this.localMvpLoop.trace.itemId,
  ]);
  assert.deepEqual(
    this.telemetry
      .filter(({ event }) =>
        ["discovery.reward_continued", "pack.reward_impact"].includes(event),
      )
      .map(({ continueActionId, ownedItemId, packImpactId }) => ({
        continueActionId,
        ownedItemId,
        packImpactId,
      })),
    [
      {
        continueActionId: "continue-item-encounter-local-loop-1:option-local-loop-observe-1",
        ownedItemId: this.localMvpLoop.trace.itemId,
        packImpactId: undefined,
      },
      {
        continueActionId: undefined,
        ownedItemId: this.localMvpLoop.trace.itemId,
        packImpactId:
          "pack-impact-item-encounter-local-loop-1:option-local-loop-observe-1",
      },
    ],
  );
});

When("the fresh local-loop Player taps that Pack Item for Examination", function () {
  this.packView = this.pack.map(visiblePackItem);
  examinePackItem(this, this.pack[0]);
  const examination = this.telemetry.find(
    ({ event }) => event === "item.examined",
  );
  this.localMvpLoop.trace = {
    ...this.localMvpLoop.trace,
    examinationId: examination.examinationId,
  };
});

Then(
  "the local-loop Examination recognizes the same Item exactly once",
  function () {
    assert.deepEqual(this.packView.map(({ id }) => id), [
      this.localMvpLoop.trace.itemId,
    ]);
    assert.deepEqual(this.examinationDispatches, [this.localMvpLoop.trace.itemId]);
    assert.equal(this.baseItemJournal.size, 1);
    assert.equal(isRecognized(this, this.pack[0]), true);
    assert.deepEqual(this.packDetail, {
      id: this.localMvpLoop.trace.itemId,
      recognized: true,
      identificationState: "unidentified",
    });
  },
);

When(
  "the fresh local-loop Player replays the resolution and Examination then reloads",
  function () {
    resolvePresentEncounter(this);
    examinePackItem(this, this.pack[0]);
    this.reloadedLocalMvpLoop = JSON.parse(
      JSON.stringify({
        pack: this.pack,
        baseItemJournal: [...this.baseItemJournal.entries()],
        trace: this.localMvpLoop.trace,
      }),
    );
  },
);

Then(
  "the local-loop reload preserves one linked entry-to-Examination lineage",
  function () {
    const itemId = "item-encounter-local-loop-1:option-local-loop-observe-1";
    const expectedTrace = {
      entryId: "entry-local-loop-1",
      encounterId: "encounter-local-loop-1",
      outcomeId: "outcome-encounter-local-loop-1:option-local-loop-observe-1",
      itemId,
      continueActionId: `continue-${itemId}`,
      packImpactId: `pack-impact-${itemId}`,
      examinationId: `examination-${itemId}`,
    };
    assert.equal(this.presentEncounterResolution.replayed, true);
    assert.equal(this.encounterCommits.size, 1);
    assert.equal(this.pack.length, 1);
    assert.equal(this.encounterRewardFlights.length, 1);
    assert.deepEqual(this.examinationDispatches, [itemId]);
    assert.equal(this.baseItemJournal.size, 1);
    assert.equal(this.pack[0].id, itemId);
    assert.equal(this.pack[0].isExamined, true);
    assert.deepEqual(this.localMvpLoop.trace, expectedTrace);
    assert.deepEqual(this.reloadedLocalMvpLoop.trace, expectedTrace);
    assert.deepEqual(this.reloadedLocalMvpLoop.pack, this.pack);
    assert.deepEqual(this.reloadedLocalMvpLoop.baseItemJournal, [
      [this.pack[0].baseItemId, this.baseItemJournal.get(this.pack[0].baseItemId)],
    ]);
    assert.deepEqual(
      this.telemetry
        .filter(({ event }) =>
          [
            "encounter.outcome_committed",
            "discovery.reward_continued",
            "pack.reward_impact",
            "item.examined",
          ].includes(event),
        )
        .map(({ event }) => event),
      [
        "encounter.outcome_committed",
        "discovery.reward_continued",
        "pack.reward_impact",
        "item.examined",
      ],
    );
  },
);
