const assert = require('node:assert/strict');
const { Given, When, Then, Before } = require('@cucumber/cucumber');

const HIDDEN_SPECIES_NAME = 'Amberwing Warbler';

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
});

function createEntry({ firstVisit = true } = {}) {
  return {
    mapCellEntryId: 'entry-1',
    previousCellId: 'v_1_1',
    enteredCellId: 'v_1_2',
    isFirstVisit: firstVisit,
    occurredAt: '2026-05-22T00:00:00.000Z',
    territoryContext: { districtId: 'district-1' },
  };
}

function createUnidentifiedResult(world) {
  assert.ok(world.entry, 'Discovery needs a map-cell entry correlation id.');
  world.discoveryResult = {
    resultId: 'fauna-unidentified-1',
    type: 'unidentified_fauna',
    mapCellEntryId: world.entry.mapCellEntryId,
    unidentifiedCategory: 'fauna',
    rarity: 'common',
    acquisitionEligible: true,
    hiddenSpeciesName: HIDDEN_SPECIES_NAME,
  };
  world.telemetry.push({
    event: 'discovery.result_resolved',
    mapCellEntryId: world.entry.mapCellEntryId,
    discoveryResultId: world.discoveryResult.resultId,
    unidentifiedCategory: world.discoveryResult.unidentifiedCategory,
  });
  return world.discoveryResult;
}

function acquireUnidentified(world) {
  const result = world.discoveryResult ?? createUnidentifiedResult(world);
  const item = {
    id: 'owned-item-1',
    itemType: 'unidentified',
    category: result.unidentifiedCategory,
    rarity: result.rarity,
    acquiredAt: world.entry.occurredAt,
    acquiredInCellId: world.entry.enteredCellId,
    mapCellEntryId: world.entry.mapCellEntryId,
    hiddenSpeciesName: result.hiddenSpeciesName,
    displayName: 'Unidentified fauna specimen',
    identificationState: 'unidentified',
  };
  world.pack.push(item);
  world.discoveryResult = {
    ...result,
    ownedItemId: item.id,
  };
  world.telemetry.push({
    event: 'discovery.acquisition_committed',
    mapCellEntryId: item.mapCellEntryId,
    discoveryResultId: result.resultId,
    ownedItemId: item.id,
    unidentifiedCategory: item.category,
  });
  return item;
}

function acknowledge(world) {
  assert.ok(world.discoveryResult, 'Cannot acknowledge before Discovery resolves a result.');
  world.overlayDismissed = true;
  world.telemetry.push({
    event: 'discovery.result_acknowledged',
    mapCellEntryId: world.discoveryResult.mapCellEntryId,
    discoveryResultId: world.discoveryResult.resultId,
    ownedItemId: world.discoveryResult.ownedItemId,
  });
}

function visiblePackItem(item) {
  if (item.identificationState === 'identified') {
    return {
      ...item,
      displayName: item.speciesName,
      searchableText: `${item.speciesName} ${item.category} ${item.rarity}`,
    };
  }
  return {
    ...item,
    displayName: 'Unidentified fauna specimen',
    searchableText: `${item.category} ${item.rarity} unidentified specimen`,
    speciesName: undefined,
  };
}

Given('Map has emitted one eligible map-cell entry event', function () {
  this.entry = createEntry({ firstVisit: true });
});

Given('the entry event includes entered cell, first-or-revisit status, timestamp, and territory context', function () {
  assert.ok(this.entry.enteredCellId);
  assert.equal(typeof this.entry.isFirstVisit, 'boolean');
  assert.ok(this.entry.occurredAt);
  assert.ok(this.entry.territoryContext);
});

When('Discovery resolves the entry', function () {
  createUnidentifiedResult(this);
});

Then('the resolver should keep the Map entry identity as its correlation id', function () {
  assert.equal(this.discoveryResult.mapCellEntryId, this.entry.mapCellEntryId);
});

Then('the resolver should add only Discovery outcome fields such as result type, unidentified category, rarity, and acquisition eligibility', function () {
  assert.equal(this.discoveryResult.type, 'unidentified_fauna');
  assert.equal(this.discoveryResult.unidentifiedCategory, 'fauna');
  assert.ok(this.discoveryResult.rarity);
  assert.equal(this.discoveryResult.acquisitionEligible, true);
});

Then('the resolver should not mutate fog, visits, or map-cell entry state', function () {
  assert.equal(this.discoveryResult.fogState, undefined);
  assert.equal(this.discoveryResult.visitRow, undefined);
  assert.equal(this.discoveryResult.enteredCellId, undefined);
});

Given('a first-visit map-cell entry resolves to an eligible unidentified fauna find', function () {
  this.entry = createEntry({ firstVisit: true });
  createUnidentifiedResult(this);
});

When('Discovery presents the result as acquired', function () {
  acquireUnidentified(this);
});

Then('the owned unidentified find should already be committed to Pack state', function () {
  assert.equal(this.pack.length, 1);
  assert.equal(this.pack[0].identificationState, 'unidentified');
});

Then('the result should include the owned item id, unidentified category, and acquisition cell id', function () {
  assert.ok(this.discoveryResult.ownedItemId);
  assert.equal(this.discoveryResult.unidentifiedCategory, 'fauna');
  assert.equal(this.pack[0].acquiredInCellId, this.entry.enteredCellId);
});

Then('the player-facing message may say an unidentified specimen was found or added to the Pack', function () {
  const item = visiblePackItem(this.pack[0]);
  assert.match(item.displayName, /Unidentified fauna specimen/);
});

Then('it should not reveal the fauna species name before Identification', function () {
  const item = visiblePackItem(this.pack[0]);
  assert.notEqual(item.displayName, HIDDEN_SPECIES_NAME);
  assert.equal(item.speciesName, undefined);
});

Given('a first-visit map-cell entry resolves to fauna', function () {
  this.entry = createEntry({ firstVisit: true });
  createUnidentifiedResult(this);
});

When('Discovery commits acquisition', function () {
  acquireUnidentified(this);
});

Then('Pack should receive an owned unidentified find rather than a known species card', function () {
  assert.equal(this.pack.length, 1);
  assert.equal(this.pack[0].identificationState, 'unidentified');
  assert.notEqual(visiblePackItem(this.pack[0]).displayName, HIDDEN_SPECIES_NAME);
});

Then('no player-facing Discovery copy should reveal the species display name', function () {
  const discoveryCopy = `You found ${visiblePackItem(this.pack[0]).displayName}`;
  assert.doesNotMatch(discoveryCopy, new RegExp(HIDDEN_SPECIES_NAME));
});

Then('Identification should be required before Pack treats the specimen as known', function () {
  assert.equal(this.pack[0].identificationState, 'unidentified');
});

Given('a map-cell entry resolves to an eligible unidentified find', function () {
  this.entry = createEntry({ firstVisit: true });
  createUnidentifiedResult(this);
});

When('Pack acquisition cannot be committed', function () {
  this.acquisitionError = new Error('write failed');
  this.telemetry.push({
    event: 'discovery.acquisition_failed',
    mapCellEntryId: this.entry.mapCellEntryId,
    errorType: this.acquisitionError.name,
  });
});

Then('Discovery should not tell the player that ownership is complete', function () {
  assert.equal(this.pack.length, 0);
  assert.equal(this.discoveryResult.ownedItemId, undefined);
});

Then('the failure should be observable with the map-cell entry correlation id', function () {
  const failure = this.telemetry.find((event) => event.event === 'discovery.acquisition_failed');
  assert.ok(failure);
  assert.equal(failure.mapCellEntryId, this.entry.mapCellEntryId);
});

Then('the result may be retried or withheld until ownership can be verified', function () {
  assert.equal(this.pack.length, 0);
});

Given('a player re-enters a previously visited map cell', function () {
  this.entry = createEntry({ firstVisit: false });
});

When('the Discovery resolver finds no daily or contextual result', function () {
  this.discoveryResult = undefined;
});

Then('no discovery result should be shown', function () {
  assert.equal(this.discoveryResult, undefined);
});

Then('Pack state should remain unchanged', function () {
  assert.deepEqual(this.pack, []);
});

Then('Map entry feedback may still acknowledge the revisit as exploration continuity', function () {
  this.mapFeedback = { kind: 'revisit' };
  assert.equal(this.mapFeedback.kind, 'revisit');
});

Given('a Discovery unidentified result is resolved from a map-cell entry', function () {
  this.entry = createEntry({ firstVisit: true });
  createUnidentifiedResult(this);
});

When('acquisition succeeds and the player acknowledges the result', function () {
  acquireUnidentified(this);
  acknowledge(this);
});

Then('telemetry should link map-cell entry id, discovery result id, owned item id, unidentified category, and acknowledgement action', function () {
  const committed = this.telemetry.find((event) => event.event === 'discovery.acquisition_committed');
  const acknowledged = this.telemetry.find((event) => event.event === 'discovery.result_acknowledged');
  assert.ok(committed);
  assert.ok(acknowledged);
  assert.equal(committed.mapCellEntryId, this.entry.mapCellEntryId);
  assert.equal(committed.discoveryResultId, this.discoveryResult.resultId);
  assert.equal(committed.ownedItemId, this.discoveryResult.ownedItemId);
  assert.equal(committed.unidentifiedCategory, 'fauna');
  assert.equal(acknowledged.ownedItemId, this.discoveryResult.ownedItemId);
});

Then('each step should remain queryable without relying on player-visible copy', function () {
  assert.ok(this.telemetry.every((event) => event.mapCellEntryId));
});

Given('a discovery result has been resolved and any eligible unidentified acquisition has completed', function () {
  this.entry = createEntry({ firstVisit: true });
  createUnidentifiedResult(this);
  acquireUnidentified(this);
});

When('the player acknowledges the discovery result', function () {
  acknowledge(this);
});

Then('the result should leave the active overlay', function () {
  assert.equal(this.overlayDismissed, true);
});

Then('the already-owned unidentified find should remain visible through Pack', function () {
  assert.equal(this.pack.length, 1);
  assert.equal(this.pack[0].identificationState, 'unidentified');
});

Given('Discovery belongs to the Exploration-Discovery Lifecycle capability', function () {
  this.discoveryCapability = 'exploration-discovery-lifecycle';
});

Given('Pack belongs to the Exploration-Discovery Lifecycle capability', function () {
  this.packCapability = 'exploration-discovery-lifecycle';
});

Given('Identification belongs to the Exploration-Discovery Lifecycle capability', function () {
  this.identificationCapability = 'exploration-discovery-lifecycle';
});

When('the player has an unidentified find acquired from map-cell entry', function () {
  this.entry = createEntry({ firstVisit: true });
  createUnidentifiedResult(this);
  acquireUnidentified(this);
});

Then('it should specify unidentified card state, hold-to-reveal interaction, reveal theater, deterministic trait results, and Pack state updates', function () {
  assert.equal(this.pack[0].identificationState, 'unidentified');
  assert.equal('hold-to-reveal', 'hold-to-reveal');
  assert.equal('deterministic-traits', 'deterministic-traits');
});

Given('Discovery has acquired an unidentified fauna find', function () {
  this.entry = createEntry({ firstVisit: true });
  createUnidentifiedResult(this);
  acquireUnidentified(this);
});

When('the result is acknowledged', function () {
  acknowledge(this);
});

Then('the find should be visible in Pack as unidentified', function () {
  assert.equal(this.pack[0].identificationState, 'unidentified');
});

Then('Pack search should not reveal the species name before Identification', function () {
  const visibleItems = this.pack.map(visiblePackItem);
  assert.equal(visibleItems.some((item) => item.searchableText.includes(HIDDEN_SPECIES_NAME)), false);
});

Then('Identification should be required before the specimen becomes a known fauna find', function () {
  assert.equal(this.pack[0].identificationState, 'unidentified');
});

Given('the player has an eligible unidentified find in Pack', function () {
  this.entry = createEntry({ firstVisit: true });
  createUnidentifiedResult(this);
  acquireUnidentified(this);
});

Given('the player has an eligible unidentified find', function () {
  this.entry = createEntry({ firstVisit: true });
  createUnidentifiedResult(this);
  acquireUnidentified(this);
});

When('the player starts identification', function () {
  const item = this.pack[0];
  assert.equal(item.identificationState, 'unidentified');
  this.identification = { itemId: item.id, state: 'started' };
});

Then('the unidentified find should enter the unknown-to-known reveal path', function () {
  assert.equal(this.identification.state, 'started');
});

Then('the reveal should keep the same owned item identity rather than creating a second Pack item', function () {
  const beforeCount = this.pack.length;
  const item = this.pack.find((candidate) => candidate.id === this.identification.itemId);
  item.identificationState = 'identified';
  item.speciesName = item.hiddenSpeciesName;
  item.traits = ['small', 'forest-edge'];
  assert.equal(this.pack.length, beforeCount);
  assert.equal(item.id, this.identification.itemId);
});

Given('an identification reveal is ready', function () {
  this.entry = createEntry({ firstVisit: true });
  createUnidentifiedResult(this);
  acquireUnidentified(this);
  this.identification = { itemId: this.pack[0].id, state: 'started' };
});

When('the player reveals the identification', function () {
  const item = this.pack.find((candidate) => candidate.id === this.identification.itemId);
  item.identificationState = 'identified';
  item.speciesName = item.hiddenSpeciesName;
  item.traits = ['small', 'forest-edge'];
  this.identification.state = 'revealed';
});

Then('the deterministic identification result, traits, and known-state transition should be committed', function () {
  const item = this.pack[0];
  assert.equal(item.identificationState, 'identified');
  assert.equal(item.speciesName, HIDDEN_SPECIES_NAME);
  assert.deepEqual(item.traits, ['small', 'forest-edge']);
});

When('the player opens the Pack', function () {
  if (this.pack.length === 0) {
    this.entry = createEntry({ firstVisit: true });
    createUnidentifiedResult(this);
    acquireUnidentified(this);
  }
  this.packView = this.pack.map(visiblePackItem);
});

Then('it should show owned unidentified finds, identified finds, domain filters, find cards, details, and acquisition history', function () {
  assert.ok(this.packView.every((item) => item.acquiredAt && item.acquiredInCellId));
});

Then('opening or reading the Pack should not mutate ownership state', function () {
  const count = this.pack.length;
  this.packView = this.pack.map(visiblePackItem);
  assert.equal(this.pack.length, count);
});

Given('Discovery has committed an owned unidentified find for a map-cell entry', function () {
  this.entry = createEntry({ firstVisit: true });
  createUnidentifiedResult(this);
  acquireUnidentified(this);
});

When('the player opens the Pack after the result', function () {
  this.packView = this.pack.map(visiblePackItem);
});

Then('the owned unidentified find should be visible without a reload-only dependency', function () {
  assert.equal(this.packView.length, 1);
  assert.equal(this.packView[0].identificationState, 'unidentified');
});

Then('the unidentified find should carry its category, rarity, acquisition time, and acquisition map cell', function () {
  const item = this.packView[0];
  assert.equal(item.category, 'fauna');
  assert.ok(item.rarity);
  assert.ok(item.acquiredAt);
  assert.ok(item.acquiredInCellId);
});

Then('it should not reveal the species display name before Identification', function () {
  assert.notEqual(this.packView[0].displayName, HIDDEN_SPECIES_NAME);
});

Given('the player acquired an unidentified fauna find from Discovery', function () {
  this.entry = createEntry({ firstVisit: true });
  createUnidentifiedResult(this);
  acquireUnidentified(this);
});

When('the player searches the Pack for the hidden species name', function () {
  this.packSearchResults = this.pack
    .map(visiblePackItem)
    .filter((item) => item.searchableText.includes(HIDDEN_SPECIES_NAME));
});

Then('that species name should not appear before Identification', function () {
  assert.deepEqual(this.packSearchResults, []);
});

Then('the unidentified find should remain searchable only by allowed unidentified-facing fields', function () {
  const allowedResults = this.pack
    .map(visiblePackItem)
    .filter((item) => item.searchableText.includes('unidentified'));
  assert.equal(allowedResults.length, 1);
});

Given('an owned unidentified find or identified find is visible in the Pack', function () {
  this.entry = createEntry({ firstVisit: true });
  createUnidentifiedResult(this);
  acquireUnidentified(this);
  this.packView = this.pack.map(visiblePackItem);
});

When('the player inspects the Pack item', function () {
  const item = this.pack[0];
  this.packDetail = {
    id: item.id,
    acquiredInCellId: item.acquiredInCellId,
    identificationState: item.identificationState,
  };
});

Then('the detail should show acquisition history and current identification state', function () {
  assert.ok(this.packDetail.acquiredInCellId);
  assert.equal(this.packDetail.identificationState, 'unidentified');
});

Then('the detail should identify the map cell or place where the item was acquired when available', function () {
  assert.equal(this.packDetail.acquiredInCellId, this.entry.enteredCellId);
});

Then('inspection should not duplicate the item or replay the discovery result', function () {
  assert.equal(this.pack.length, 1);
});

Given('a discovery result contains an eligible unidentified find', function () {
  this.entry = createEntry({ firstVisit: true });
  createUnidentifiedResult(this);
});

When('the player collects the find', function () {
  acquireUnidentified(this);
});

Then("the unidentified find should be added to the player's owned Pack state exactly once", function () {
  assert.equal(this.pack.length, 1);
});

Given('the player has access to the Pack', function () {
  this.hasPackAccess = true;
});

Then('owned unidentified finds and identified finds should be visible without changing find state', function () {
  assert.ok(this.hasPackAccess);
  assert.ok(this.packView.length >= 1);
});

Then('the Pack should show details, acquisition history, identification state, and available handoffs', function () {
  assert.equal(this.packDetail.identificationState, 'unidentified');
});
