import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'responsiveness callbacks defer bounded summaries to the timer',
    () async {
      final result = await Process.run('node', [
        '-e',
        r'''
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const html = fs.readFileSync('web/index.html', 'utf8');
const start = html.indexOf('function installResponsivenessTelemetry()');
const end = html.indexOf('function pointerValues()', start);
assert.ok(start >= 0 && end > start, 'telemetry function must be extractable');

let now = 0;
let frame;
let observeTasks;
let attrsCalls = 0;
let layoutCalls = 0;
let storageCalls = 0;
const events = [];
const timers = [];
const document = {visibilityState: 'visible', documentElement: {}};
class PerformanceObserver {
  constructor(callback) { observeTasks = callback; }
  observe() {}
}
const sandbox = {
  document,
  PerformanceObserver,
  performance: {now: () => now},
  Date: class extends Date { static now() { return now; } },
  requestAnimationFrame: callback => { frame = callback; },
  setInterval: (callback, delay) => { timers.push({callback, delay}); },
  getComputedStyle: () => { layoutCalls++; return {}; },
  localStorage: {
    getItem: () => { storageCalls++; return null; },
    setItem: () => { storageCalls++; },
    removeItem: () => { storageCalls++; },
  },
  round: value => typeof value === 'number' && Number.isFinite(value)
    ? Math.round(value * 1000) / 1000 : null,
  nowMs: () => now,
  lowLevelAttrs: (_category, _state, _target, attrs) => {
    attrsCalls++;
    return attrs;
  },
  push: (category, name, source, attrs) => {
    events.push({category, name, source, attrs});
  },
};
sandbox.window = sandbox;
vm.runInNewContext(html.slice(start, end) + '\ninstallResponsivenessTelemetry();', sandbox);
assert.equal(typeof frame, 'function');
assert.equal(typeof observeTasks, 'function');
const task = (duration, startTime = now, name = 'task', attribution = []) => {
  observeTasks({getEntries: () => [{duration, startTime, name, attribution}]});
};
const raf = at => { now = at; frame(at); };
const assertCallbacksQuiet = count => {
  assert.equal(events.length, count, 'callbacks must not push telemetry');
  assert.equal(attrsCalls, count, 'callbacks must not compute low-level attributes');
  assert.equal(layoutCalls, 0, 'callbacks must not read computed styles');
  assert.equal(storageCalls, 0, 'callbacks must not access localStorage directly');
};

// A burst must not turn the observer itself into thousands of writes.
task(49);
for (let i = 0; i < 3000; i++) {
  task(i === 1234 ? 200 : 60, i, i === 1234 ? 'worst' : 'task',
    i === 1234 ? [{}, {}] : []);
}
for (let at = 0; at <= 10020; at += 20) raf(at);
assertCallbacksQuiet(0);
const drains = timers.filter(timer => timer.delay === 10000);
assert.equal(drains.length, 1, 'one 10-second drain owns both summaries');
const drain = drains[0].callback;
document.visibilityState = 'hidden';
drain();
assert.equal(events.length, 2);
assert.equal(attrsCalls, 2);
assert.ok(events.every(event => event.category === 'low_level'));
const longTasks = () => events.filter(event => event.name === 'long_task');
const frames = () => events.filter(event => event.name === 'frame_pacing_sample');
assert.equal(longTasks().length, 1);
assert.equal(frames().length, 1);
const long = longTasks()[0].attrs;
assert.equal(long.task_count, 3000);
assert.equal(long.total_duration_ms, 180140);
assert.equal(long.total_blocking_duration_ms, 30140);
assert.equal(long.duration_ms, 200, 'duration keeps its worst individual task meaning');
assert.equal(long.blocking_duration_ms, 150);
assert.equal(long.start_time_ms, 1234);
assert.equal(long.long_task_name, 'worst');
assert.equal(long.attribution_count, 2);
assert.equal(long.visibility_state, 'visible', 'capture visibility before drain');
assert.equal(long.aggregation, 'window');
assert.ok(long.sample_window_ms >= 10000);
const pacing = frames()[0].attrs;
assert.equal(pacing.frame_count, 500);
assert.equal(pacing.sample_window_ms, 10000);
assert.equal(pacing.avg_frame_delta_ms, 20);
assert.equal(pacing.worst_frame_delta_ms, 20);
assert.equal(pacing.fps_estimate, 50);
assert.equal(pacing.long_frame_count, 0);
assert.equal(pacing.dropped_frame_count, 0);
assert.equal(pacing.visibility_state, 'visible');
drain();
assertCallbacksQuiet(2);

// Empty/subthreshold windows stay silent; threshold tasks still count.
now = 20020;
task(49);
drain();
assertCallbacksQuiet(2);
task(50, 6);
task(100, 7, 'second');
assertCallbacksQuiet(2);
now = 30020;
drain();
assert.equal(events.length, 3);
assert.equal(longTasks().length, 2);
const second = longTasks()[1].attrs;
assert.equal(second.task_count, 2);
assert.equal(second.total_duration_ms, 150);
assert.equal(second.total_blocking_duration_ms, 50);
assert.equal(second.duration_ms, 100);
assert.equal(second.blocking_duration_ms, 50);
assert.equal(second.start_time_ms, 7);
assert.equal(second.long_task_name, 'second');
assert.equal(second.attribution_count, 0);
assert.equal(second.visibility_state, 'hidden');
drain();
assertCallbacksQuiet(3);

// Background gaps must not inflate the first resumed pacing window.
raf(31000);
document.visibilityState = 'visible';
for (let at = 31020; at <= 41000; at += 20) raf(at);
assertCallbacksQuiet(3);
drain();
assert.equal(events.length, 4);
assert.equal(frames().length, 2);
const resumed = frames()[1].attrs;
assert.equal(resumed.frame_count, 499);
assert.equal(resumed.avg_frame_delta_ms, 20);
assert.equal(resumed.worst_frame_delta_ms, 20);
assert.equal(resumed.long_frame_count, 0);

// Only the latest completed window survives a delayed drain.
for (let at = 41020; at <= 51000; at += 20) raf(at);
for (let at = 51040; at <= 61000; at += 40) raf(at);
assertCallbacksQuiet(4);
drain();
assert.equal(events.length, 5);
assert.equal(frames().length, 3);
const latest = frames()[2].attrs;
assert.equal(latest.frame_count, 250);
assert.equal(latest.sample_window_ms, 10000);
assert.equal(latest.avg_frame_delta_ms, 40);
assert.equal(latest.worst_frame_delta_ms, 40);
assert.equal(latest.long_frame_count, 0);
assert.equal(latest.dropped_frame_count, 250);
drain();
assertCallbacksQuiet(5);
''',
      ]);

      expect(
        result.exitCode,
        0,
        reason:
            'Node telemetry regression failed.\n'
            'stdout: ${result.stdout}\nstderr: ${result.stderr}',
      );
    },
  );
}
