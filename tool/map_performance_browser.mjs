// No browser dependency. Import from an existing Puppeteer tab/runtime:
// const {runMapPerformance} = await import('/absolute/repo/tool/map_performance_browser.mjs');
// await runMapPerformance(page, {url:'http://127.0.0.1:8765', outputDir:'/tmp/map-perf'});
// Pass robotoPath pointing to the installed Flutter material_fonts/Roboto-Regular.ttf
// so CanvasKit text can render without contacting Google Fonts.
// Keep the complete call inside tab.run: request interception lasts for that call.
import {mkdir, readFile, writeFile} from 'node:fs/promises';
import {resolve, join} from 'node:path';

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

export const sameCellWASD = Object.freeze({
  keys: Object.freeze(['w', 's', 'd', 'a']),
  keyDownMs: 200,
  keyUpMs: 50,
  canonicalSpeedMetersPerSecond: 100,
  nominalMetersPerKey: 20,
  maxNominalExcursionMeters: 20,
  fixtureNominalRadiusMeters: 36,
});

// Shared by the browser injection and the regression test; no DOM dependencies.
export function meaningfulInputRendered(sample, frame) {
  if (sample.superseded) return false;
  const point = sample.kind === 'wasd' ? frame.player : frame.center;
  if (!point || !sample.before) return false;
  const followsDirection = (after, before) => {
    const lat = after.lat - before.lat, lng = after.lng - before.lng;
    return ({KeyW: lat > 1e-10, KeyS: lat < -1e-10,
      KeyA: lng < -1e-10, KeyD: lng > 1e-10})[sample.code] === true;
  };
  if (sample.kind === 'drag') {
    return Math.abs(point.lat - sample.before.lat) +
      Math.abs(point.lng - sample.before.lng) > 1e-10;
  }
  // A marker still easing from an earlier W must not satisfy a fresh W.
  // The supplied marker must follow a new direction-matching raw target.
  return frame.playerTargetRevision > sample.targetRevision &&
    !!sample.rawTarget && !!frame.playerTarget &&
    followsDirection(frame.playerTarget, sample.rawTarget) &&
    Math.abs(point.lat - sample.before.lat) +
      Math.abs(point.lng - sample.before.lng) > 1e-10;
}

export function responseAccepted(recordedInputs, latency) {
  return recordedInputs > 1 && latency.count === recordedInputs &&
    Number.isFinite(latency.p95) && latency.p95 <= 100;
}

export function scheduleMarkerPresentation(sample, frame, {
  qualifies, requestFrame, now, complete,
}) {
  if (!qualifies(sample, frame)) return false;
  // updatePlayer has returned: the native DOM marker style is already updated.
  // Freeze that submission, rather than inspecting a later interpolation tick.
  const submitted = {...sample, after: {...frame.player},
    renderedRawTarget: {...frame.playerTarget},
    renderedTargetRevision: frame.playerTargetRevision,
    domUpdateSubmissionMs: now() - sample.at};
  requestFrame(() => requestFrame(() => complete({
    ...submitted, domMarkerPresentationOpportunityMs: now() - sample.at,
  })));
  return true;
}

// Inline contextual backdrop: no network tiles/fonts/sprites. This is a rendering
// fixture, not a claim of production tile-loading or geographic visual parity.
const fixtureStyle = {
  version: 8,
  sources: {
    'fixture-roads': {type: 'geojson', data: {type: 'FeatureCollection', features:
      Array.from({length: 30}, (_, i) => ({type: 'Feature', properties: {}, geometry: {
        type: 'LineString', coordinates: i % 2
          ? [[-66.65 + i * .0005, 45.95], [-66.65 + i * .0005, 45.98]]
          : [[-66.66, 45.957 + i * .0004], [-66.62, 45.957 + i * .0004]],
      }})),
    }},
  },
  layers: [
    {id: 'background', type: 'background', paint: {'background-color': '#cbd5c1'}},
    {id: 'roads', type: 'line', source: 'fixture-roads', paint: {'line-color': '#f2efe9', 'line-width': 3}},
  ],
};

export function installMeasurement(meaningfulInputRendered, responseAccepted, scheduleMarkerPresentation) {
  const state = {
    phase: 'warmup', map: null, handle: null, player: null,
    target: null, targetRevision: 0, playerTarget: null, playerTargetRevision: 0,
    pending: [], presenting: [], samples: {wasd: [], drag: []}, frames: {wasd: [], drag: []},
    nativeFrames: {wasd: [], drag: []}, inputs: {wasd: 0, drag: 0},
    sourceAdds: 0, geometryUploads: 0, featureStateUpdates: 0,
    uploadedFeatures: 0, sceneCalls: 0, geometrySceneCalls: 0,
    lastFrame: null, lastRender: null, raf: null,
  };
  const center = () => {
    const p = state.map?.getCenter();
    return p ? {lat: p.lat, lng: p.lng} : null;
  };
  const snapshotCounters = () => ({
    sourceAdds: state.sourceAdds,
    geometryUploads: state.geometryUploads,
    uploadedFeatures: state.uploadedFeatures,
    featureStateUpdates: state.featureStateUpdates,
    sceneCalls: state.sceneCalls,
    geometrySceneCalls: state.geometrySceneCalls,
    renderer: {...state.handle?.counters},
  });
  function sourceUpload(data) {
    state.geometryUploads++;
    state.uploadedFeatures += data?.features?.length ?? 0;
  }
  function instrumentMap(map) {
    if (state.map === map) return;
    state.map = map;
    const addSource = map.addSource;
    const setFeatureState = map.setFeatureState;
    map.addSource = function(id, source) {
      state.sourceAdds++;
      if (source.type === 'geojson') sourceUpload(source.data);
      const result = addSource.call(this, id, source);
      const instance = this.getSource(id);
      if (instance?.setData) {
        const setData = instance.setData;
        instance.setData = function(data) {
          sourceUpload(data);
          return setData.call(this, data);
        };
      }
      return result;
    };
    map.setFeatureState = function(...args) {
      state.featureStateUpdates++;
      return setFeatureState.apply(this, args);
    };
    map.on('render', () => {
      const now = performance.now();
      if (state.nativeFrames[state.phase]) {
        if (state.lastRender !== null) state.nativeFrames[state.phase].push(now - state.lastRender);
        state.lastRender = now;
      }
      const currentCenter = center();
      const frame = {center: currentCenter};
      state.pending = state.pending.filter(sample => {
        if (sample.kind !== 'drag' || !meaningfulInputRendered(sample, frame)) return true;
        sample.nativeRenderMs = now - sample.at;
        sample.after = {...currentCenter};
        state.samples[sample.kind].push(sample);
        // Native render is authoritative draw completion. Double-rAF is only a
        // separate presentation opportunity estimate, not GPU/compositor timing.
        requestAnimationFrame(() => requestAnimationFrame(() => {
          sample.presentationOpportunityMs = performance.now() - sample.at;
        }));
        return false;
      });
    });
  }
  let renderer;
  Object.defineProperty(window, 'EarthNovaRetainedMapRenderer', {
    configurable: true,
    get: () => renderer,
    set(value) {
      renderer = value;
      const attach = value.attach;
      value.attach = function(map) {
        instrumentMap(map);
        const handle = attach.call(this, map);
        if (!handle) return handle;
        state.handle = handle;
        const updatePlayer = handle.updatePlayer;
        const updateScene = handle.updateScene;
        const updateCameraTarget = handle.updateCameraTarget;
        handle.updateCameraTarget = function(payload) {
          const result = updateCameraTarget.call(this, payload);
          if (!state.target || state.target.lat !== payload.lat || state.target.lng !== payload.lng) {
            state.target = {lat: payload.lat, lng: payload.lng};
            state.targetRevision++;
          }
          return result;
        };
        handle.updatePlayer = function(payload) {
          const result = updatePlayer.call(this, payload);
          state.player = {lat: payload.lat, lng: payload.lng};
          state.playerTarget = state.target ? {...state.target} : null;
          state.playerTargetRevision = state.targetRevision;
          const frame = {player: state.player, playerTarget: state.playerTarget,
            playerTargetRevision: state.playerTargetRevision};
          state.pending = state.pending.filter(sample => {
            if (sample.kind !== 'wasd') return true;
            const scheduled = scheduleMarkerPresentation(sample, frame, {
              qualifies: meaningfulInputRendered,
              requestFrame: callback => requestAnimationFrame(callback),
              now: () => performance.now(),
              complete: completed => {
                state.presenting.splice(state.presenting.indexOf(sample), 1);
                state.samples.wasd.push(completed);
              },
            });
            if (scheduled) state.presenting.push(sample);
            return !scheduled;
          });
          return result;
        };
        handle.updateScene = function(payload) {
          state.sceneCalls++;
          if (payload.geometry) state.geometrySceneCalls++;
          return updateScene.call(this, payload);
        };
        return handle;
      };
    },
  });
  function capture(event, kind) {
    if (state.phase !== kind || !event.isTrusted || event.repeat) return;
    if (kind === 'wasd' && !['KeyW', 'KeyA', 'KeyS', 'KeyD'].includes(event.code)) return;
    if (kind === 'drag' && !(event.buttons & 1)) return;
    const before = kind === 'wasd' ? state.player : center();
    if (kind === 'wasd') {
      // Never let the next key's movement rescue an unanswered previous key.
      for (const sample of state.pending) {
        if (sample.kind === kind) sample.superseded = true;
      }
    }
    state.inputs[kind]++;
    state.pending.push({kind, code: event.code ?? null,
      at: event.timeStamp, handlerAt: performance.now(),
      rawTarget: state.target ? {...state.target} : null,
      targetRevision: state.targetRevision,
      before: before ? {...before} : null});
  }
  const keyListener = e => capture(e, 'wasd');
  const dragListener = e => capture(e, 'drag');
  window.addEventListener('keydown', keyListener, true);
  window.addEventListener('pointermove', dragListener, true);
  function frame(now) {
    if (state.frames[state.phase]) {
      if (state.lastFrame !== null) state.frames[state.phase].push(now - state.lastFrame);
      state.lastFrame = now;
    }
    state.raf = requestAnimationFrame(frame);
  }
  state.raf = requestAnimationFrame(frame);
  const summary = values => {
    const sorted = values.filter(Number.isFinite).sort((a, b) => a - b);
    const quantile = p => sorted.length ? sorted[Math.max(0, Math.ceil(sorted.length * p) - 1)] : null;
    return {count: sorted.length, median: quantile(.5), p95: quantile(.95), max: quantile(1)};
  };
  window.__mapPerformance = {
    ready: () => !!state.handle && state.player !== null && state.target !== null,
    phase(name) {state.phase = name; state.lastFrame = state.lastRender = null;},
    counters: snapshotCounters,
    finish() {
      state.phase = 'finished';
      cancelAnimationFrame(state.raf);
      window.removeEventListener('keydown', keyListener, true);
      window.removeEventListener('pointermove', dragListener, true);
      const report = {};
      for (const kind of ['wasd', 'drag']) {
        const samples = state.samples[kind];
        const latency = summary(samples.map(s => kind === 'wasd'
          ? s.domMarkerPresentationOpportunityMs : s.nativeRenderMs));
        const unresolved = [...state.pending, ...state.presenting].filter(s => s.kind === kind);
        const raf = summary(state.frames[kind]);
        report[kind] = {
          trustedInputs: state.inputs[kind], completedSamples: samples.length,
          unresolvedInputs: unresolved.length,
          unresolvedSamples: unresolved,
          inputToMeaningfulResponseMs: latency,
          responseTimingBasis: kind === 'wasd'
            ? 'DOM-marker double-rAF presentation-opportunity estimate, not GPU/physical-pixel proof'
            : 'Native MapLibre render after changed camera',
          inputToMeaningfulNativeRenderMs: kind === 'drag' ? latency : null,
          domUpdateSubmissionMs: kind === 'wasd' ? summary(samples.map(s => s.domUpdateSubmissionMs)) : null,
          domMarkerPresentationOpportunityEstimateMs: kind === 'wasd' ? latency : null,
          latencyPopulation: 'Completed inputs only; any unresolved input fails response acceptance',
          presentationOpportunityEstimateMs: kind === 'wasd'
            ? latency : summary(samples.map(s => s.presentationOpportunityMs)),
          rafFrameIntervalEstimateMs: raf,
          nativeRenderIntervalMs: summary(state.nativeFrames[kind]),
          responseWithin100ms: responseAccepted(state.inputs[kind], latency),
          rafEstimateWithin32ms: raf.count > 1 && raf.p95 <= 32,
          samples,
        };
      }
      return {metrics: report, counters: snapshotCounters()};
    },
  };
}

export async function runMapPerformance(page, {
  url = 'http://127.0.0.1:8765', outputDir = '/tmp/earthnova-map-performance',
  buildDir = resolve('build/web'), warmupMs = 3000, durationMs = 10000,
  robotoPath,
} = {}) {
  const origin = new URL(url).origin;
  if (!['127.0.0.1', 'localhost', '[::1]'].includes(new URL(url).hostname)) {
    throw new Error('Refusing non-loopback performance target');
  }
  await mkdir(outputDir, {recursive: true});
  const roboto = robotoPath ? await readFile(robotoPath) : null;
  const blocked = [], errors = [];
  const onError = error => errors.push(String(error));
  page.on('pageerror', onError);
  await page.setRequestInterception(true);
  const intercept = async request => {
    try {
      const target = new URL(request.url());
      if (target.protocol === 'data:' || target.protocol === 'blob:') return request.continue();
      if (target.origin === origin && request.method() === 'GET') {
        if (target.pathname.endsWith('/base-map-style.json')) {
          return request.respond({status: 200, contentType: 'application/json', body: JSON.stringify(fixtureStyle)});
        }
        return request.continue();
      }
      // Flutter may request its CDN CanvasKit even though build/web contains it.
      // Fulfil from disk without ever contacting that origin.
      const canvasKitPath = target.pathname.match(/^\/(?:flutter-)?canvaskit\/(.+)$/);
      if (target.hostname === 'www.gstatic.com' && canvasKitPath) {
        const parts = canvasKitPath[1].split('/');
        if (/^[a-f0-9]{20,}$/.test(parts[0])) parts.shift();
        const file = resolve(buildDir, 'canvaskit', ...parts);
        if (!file.startsWith(resolve(buildDir, 'canvaskit') + '/')) throw new Error('Unsafe CanvasKit path');
        const body = await readFile(file);
        return request.respond({status: 200, headers: {'access-control-allow-origin': '*'},
          contentType: file.endsWith('.wasm') ? 'application/wasm' : 'application/javascript', body});
      }
      if (roboto && request.method() === 'GET' &&
          target.hostname === 'fonts.gstatic.com' &&
          /^\/s\/roboto\/[^/]+\/[^/]+\.(?:woff2?|ttf)$/.test(target.pathname)) {
        return request.respond({status: 200, contentType: 'font/ttf',
          headers: {'access-control-allow-origin': '*'}, body: roboto});
      }
      blocked.push({url: request.url(), method: request.method()});
      return request.abort('blockedbyclient');
    } catch (error) {
      errors.push(`interception: ${error}`);
      if (!request.isInterceptResolutionHandled()) await request.abort('blockedbyclient');
    }
  };
  page.on('request', intercept);
  const injection = await page.evaluateOnNewDocument(
    `(${installMeasurement})(${meaningfulInputRendered}, ${responseAccepted}, ${scheduleMarkerPresentation});`);
  let originalFailure;
  try {
    await page.setOfflineMode(false);
    await page.setViewport({width: 1280, height: 800, deviceScaleFactor: 1});
    await page.goto(url, {waitUntil: 'domcontentloaded'});
    // OMP's default page evaluation may use an isolated world; application
    // globals and the pre-document instrumentation belong to the main realm.
    const realm = page.mainFrame().mainRealm();
    await realm.waitForFunction(() => window.__mapPerformance?.ready() &&
      ['usable', 'syncing', 'degraded'].includes(JSON.parse(window.earthNovaMapFixture.snapshot()).readiness),
      {timeout: 60000});
    await sleep(warmupMs);
    const initial = await realm.evaluate(() => ({
      fixture: JSON.parse(window.earthNovaMapFixture.snapshot()),
      counters: window.__mapPerformance.counters(),
    }));
    if (initial.fixture.cellCount < 1000) throw new Error('Fixture below 1000 cells');
    await page.screenshot({path: join(outputDir, 'normal.png')});
    await realm.evaluate(() => window.earthNovaMapFixture.pause());
    await sleep(300);
    const paused = await realm.evaluate(() => JSON.parse(window.earthNovaMapFixture.snapshot()));
    await page.screenshot({path: join(outputDir, 'paused.png')});
    await realm.evaluate(() => window.earthNovaMapFixture.resume());
    await sleep(300);
    // Native mouse/keyboard events through Puppeteer, never dispatchEvent().
    const dimensions = await realm.evaluate(() => ({width: innerWidth, height: innerHeight}));
    const x = dimensions.width * .5, y = dimensions.height * .5;
    await realm.evaluate(() => window.__mapPerformance.phase('wasd'));
    const wasdStart = Date.now();
    let i = 0;
    while (Date.now() - wasdStart < durationMs) {
      const key = sameCellWASD.keys[i++ % sameCellWASD.keys.length];
      await page.keyboard.down(key);
      await sleep(sameCellWASD.keyDownMs);
      await page.keyboard.up(key);
      await sleep(sameCellWASD.keyUpMs);
    }
    const wasdDurationMs = Date.now() - wasdStart;
    await realm.evaluate(() => window.__mapPerformance.phase('settling'));
    await sleep(500);
    await page.screenshot({path: join(outputDir, 'after-wasd-before-drag.png')});
    await page.mouse.move(x, y);
    await page.mouse.down();
    await realm.evaluate(() => window.__mapPerformance.phase('drag'));
    const dragStart = Date.now();
    i = 0;
    while (Date.now() - dragStart < durationMs) {
      const angle = i++ * .15;
      await page.mouse.move(x + Math.sin(angle) * 90, y + Math.cos(angle) * 60);
      await sleep(32);
    }
    await page.mouse.up();
    const dragDurationMs = Date.now() - dragStart;
    await realm.evaluate(() => window.__mapPerformance.phase('settling'));
    await sleep(500);
    await page.screenshot({path: join(outputDir, 'after-drag.png')});
    const result = await realm.evaluate(() => ({
      ...window.__mapPerformance.finish(),
      fixture: JSON.parse(window.earthNovaMapFixture.snapshot()),
    }));
    const report = {...result, initial, paused, warmupMs,
      workload: {requestedDurationMs: durationMs, wasdDurationMs, dragDurationMs,
        wasd: {...sameCellWASD, directionCycle: sameCellWASD.keys,
          cadenceMs: sameCellWASD.keyDownMs + sameCellWASD.keyUpMs,
          expectedInputs: Math.floor(durationMs / (sameCellWASD.keyDownMs + sameCellWASD.keyUpMs)),
          boundary: 'Held-key traversal at canonical 100m/s: paired w,s and d,a excursions, nominally 20m per 200ms hold. The warped fixture has nominal 36m cell radius. Same-cell state is checked; short-tap scheduling is a separate scenario.'},
        drag: 'real pointer held down, elliptical movements every >=32ms'},
      viewport: dimensions, localRobotoPath: robotoPath ?? null,
      requestPolicy: 'loopback GET only; inline synthetic style; CDN CanvasKit and exact Roboto font requests fulfilled from local disk; all beacons/other external traffic aborted',
      measurement: 'WASD: input -> new direction-correct raw target -> distinct target-dependent DOM marker submission -> double-rAF presentation opportunity (not GPU/physical-pixel proof). Drag: changed camera -> native MapLibre render, with separate double-rAF estimate. Preserves interpolation; unanswered inputs fail acceptance.',
      screenshots: ['normal.png', 'paused.png', 'after-wasd-before-drag.png', 'after-drag.png'],
      blockedRequests: blocked, errors};
    await writeFile(join(outputDir, 'metrics.json'), JSON.stringify(report, null, 2));
    if (result.fixture.currentCellId !== initial.fixture.currentCellId ||
        result.counters.sceneCalls !== initial.counters.sceneCalls) {
      throw new Error('Same-cell workload crossed a cell or changed its scene; inspect saved evidence');
    }
    if (!result.metrics.wasd.responseWithin100ms) {
      const {trustedInputs, completedSamples, unresolvedInputs} = result.metrics.wasd;
      throw new Error(`WASD acceptance failed: ${trustedInputs} trusted, ${completedSamples} completed, ${unresolvedInputs} unresolved, p95 ${result.metrics.wasd.inputToMeaningfulResponseMs.p95}ms; inspect saved evidence`);
    }
    console.log(JSON.stringify({...report, metrics: Object.fromEntries(Object.entries(report.metrics).map(([key, value]) => {
      const {samples, ...summary} = value;
      return [key, summary];
    }))}, null, 2));
    return report;
  } catch (error) {
    originalFailure = error;
    try {
      await writeFile(join(outputDir, 'failure.json'), JSON.stringify({
        error: String(error), stack: error?.stack ?? null,
        requestedUrl: url, errors, blockedRequests: blocked,
      }, null, 2));
    } catch (reportError) {
      console.error('Could not write performance failure evidence:', reportError);
    }
    throw error;
  } finally {
    try {
      // Preserve the rendered/failing page for inspection while blocking beacons
      // after the scoped interceptor is removed, including on exceptions.
      await page.setOfflineMode(true);
      for (const key of ['w', 'a', 's', 'd']) await page.keyboard.up(key);
      try {
        await page.mouse.up();
      } catch (error) {
        if (!String(error).includes('is not pressed')) throw error;
      }
      page.off('request', intercept);
      page.off('pageerror', onError);
      await page.removeScriptToEvaluateOnNewDocument(injection.identifier);
      await page.setRequestInterception(false);
    } catch (cleanupError) {
      if (!originalFailure) throw cleanupError;
      console.error('Performance cleanup failed after original error:', cleanupError);
    }
  }
}
