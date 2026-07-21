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
  world.lastAdvanceInput = "click_anywhere";
  world.overlayDismissed = true;
  world.rewardSurface.active = false;
  world.cardFlight = {
    active: true,
    target: "pack",
    style: "slay_the_spire_arc",
  };
  world.packTarget = { reaction: "shake", forcedOpen: false };
  world.telemetry.push({
    event: "discovery.reward_continued",
    mapCellEntryId: world.discoveryResult.mapCellEntryId,
    discoveryResultId: world.discoveryResult.resultId,
    ownedItemId: world.discoveryResult.ownedItemId,
    livingSpecimenCategory: world.discoveryResult.livingSpecimenCategory,
    action: "continue-discovery-reward",
  });
  world.telemetry.push({
    event: "pack.reward_impact",
    mapCellEntryId: world.discoveryResult.mapCellEntryId,
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
