import test from 'node:test';
import assert from 'node:assert/strict';
import {meaningfulInputRendered, responseAccepted, sameCellWASD, scheduleMarkerPresentation} from './map_performance_browser.mjs';

const sample = {kind: 'wasd', code: 'KeyW', before: {lat: 1, lng: 2},
  rawTarget: {lat: 1.001, lng: 2}, targetRevision: 7};

test('held traversal pairs opposing keys within one cell', () => {
  assert.deepEqual(sameCellWASD.keys, ['w', 's', 'd', 'a']);
  assert.equal(sameCellWASD.keyDownMs * sameCellWASD.canonicalSpeedMetersPerSecond / 1000, sameCellWASD.nominalMetersPerKey);
  assert.equal(sameCellWASD.maxNominalExcursionMeters, 20);
  assert.equal(sameCellWASD.keyDownMs + sameCellWASD.keyUpMs, 250);
  assert.ok(sameCellWASD.maxNominalExcursionMeters < sameCellWASD.fixtureNominalRadiusMeters);
});

test('old easing cannot satisfy a repeated key before a new raw target and player update', () => {
  const frame = {player: {lat: 1.0001, lng: 2}, playerTarget: sample.rawTarget,
    playerTargetRevision: 7};
  assert.equal(meaningfulInputRendered(sample, frame), false);
  // A camera target update alone cannot satisfy input->marker render.
  assert.equal(meaningfulInputRendered(sample, {...frame,
    target: {lat: 1.002, lng: 2}, targetRevision: 8}), false);
  assert.equal(meaningfulInputRendered(sample, {...frame,
    playerTarget: {lat: 1.002, lng: 2}, playerTargetRevision: 8}), true);
});

test('new raw target must follow the requested direction, not old marker easing', () => {
  assert.equal(meaningfulInputRendered(sample, {
    player: {lat: 1.0001, lng: 2}, playerTarget: {lat: .999, lng: 2},
    playerTargetRevision: 8,
  }), false);
  assert.equal(meaningfulInputRendered({...sample, superseded: true}, {
    player: {lat: 1.0001, lng: 2}, playerTarget: {lat: 1.002, lng: 2},
    playerTargetRevision: 8,
  }), false);
});

test('new south target permits preserved northward interpolation before reversal', () => {
  const south = {...sample, code: 'KeyS'};
  const frame = {player: {lat: 1.0001, lng: 2},
    playerTarget: {lat: 1.0009, lng: 2}, playerTargetRevision: 8};
  assert.equal(meaningfulInputRendered(south, frame), true);
  assert.equal(meaningfulInputRendered(south, {...frame, player: south.before}), false);
});

test('drag requires actual camera change and all recorded inputs must complete', () => {
  const drag = {kind: 'drag', before: {lat: 1, lng: 2}};
  assert.equal(meaningfulInputRendered(drag, {center: drag.before}), false);
  assert.equal(meaningfulInputRendered(drag, {center: {lat: 1, lng: 2.001}}), true);
  assert.equal(responseAccepted(40, {count: 39, p95: 16}), false);
  assert.equal(responseAccepted(40, {count: 40, p95: 16}), true);
  assert.equal(responseAccepted(40, {count: 40, p95: 101}), false);
});

test('DOM marker presentation completes after two frame opportunities without a map render', () => {
  let clock = 20;
  const callbacks = [], completed = [];
  const options = {qualifies: meaningfulInputRendered, now: () => clock,
    requestFrame: callback => callbacks.push(callback),
    complete: result => completed.push(result)};
  const input = {...sample, at: 10};
  const frame = {player: {lat: 1.0001, lng: 2},
    playerTarget: {lat: 1.002, lng: 2}, playerTargetRevision: 8};
  assert.equal(scheduleMarkerPresentation(input, {...frame, playerTargetRevision: 7}, options), false);
  assert.equal(callbacks.length, 0);
  assert.equal(scheduleMarkerPresentation(input, frame, options), true);
  // Later interpolation changes must not rewrite the attributed DOM snapshot.
  frame.player.lat = 9;
  clock = 32;
  callbacks.shift()();
  assert.equal(completed.length, 0);
  clock = 48;
  callbacks.shift()();
  assert.equal(completed.length, 1);
  assert.equal(completed[0].domUpdateSubmissionMs, 10);
  assert.equal(completed[0].domMarkerPresentationOpportunityMs, 38);
  assert.deepEqual(completed[0].after, {lat: 1.0001, lng: 2});
  assert.equal(completed[0].nativeRenderMs, undefined);
});
