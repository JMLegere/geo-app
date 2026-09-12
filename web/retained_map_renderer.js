/* Retained geographic rendering for MapLibre GL JS 4.7.1. No gameplay state. */
(function (root) {
  'use strict';
  const CELLS = 'earthnova-cells', EDGES = 'earthnova-edges', OUTSIDE = 'earthnova-outside';
  const layerIds = ['earthnova-outside-fill', 'earthnova-cell-fill', 'earthnova-seam-glow', 'earthnova-seam'];
  const collection = features => ({type: 'FeatureCollection', features});
  const feature = (id, geometry, properties = {}) => ({type: 'Feature', id, properties, geometry});
  const pointKey = p => `${p[0]},${p[1]}`;
  const cueIcons = {
    fauna: '<circle cx="11" cy="4" r="2"/><circle cx="18" cy="8" r="2"/><circle cx="20" cy="16" r="2"/><path d="M9 10a5 5 0 0 1 5 5v3.5a3.5 3.5 0 0 1-6.84 1.05A3.5 3.5 0 0 1 1 17.5V16a6 6 0 0 1 6-6Z"/>',
    flora: '<path d="M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 2 17 2c0 4 2 6 2 10a8 8 0 0 1-8 8Z"/><path d="M2 21c0-3 1.85-5.36 5.08-6.94C9.22 13 12 12 16 12"/>',
    mineral: '<path d="M6 3h12l4 6-10 13L2 9Z"/><path d="m12 22 4-13-3-6M12 22 8 9l3-6M2 9h20"/>',
    fossil: '<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5M12 7v5l4 2"/>',
    artifact: '<path d="M3 22h18M6 18v-7m4 7v-7m4 7v-7m4 7v-7M4 7h16L12 2Z"/>',
    food: '<path d="M3 2v7a2 2 0 0 0 2 2h4a2 2 0 0 0 2-2V2M7 2v20M21 15V2a5 5 0 0 0-5 5v6a2 2 0 0 0 2 2h3Zm0 0v7"/>',
    orb: '<circle cx="12" cy="12" r="9"/>',
  };
  const area = ring => ring.reduce((sum, p, i) => {
    const q = ring[(i + 1) % ring.length];
    return sum + p[0] * q[1] - q[0] * p[1];
  }, 0) / 2;
  function contains(p, ring) {
    let inside = false;
    for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      const a = ring[i], b = ring[j];
      if ((a[1] > p[1]) !== (b[1] > p[1]) &&
          p[0] < (b[0] - a[0]) * (p[1] - a[1]) / (b[1] - a[1]) + a[0]) inside = !inside;
    }
    return inside;
  }

  // The cell working set is a tessellation. Cancel shared directed edges before
  // tracing its union perimeter: touching cell rings must not become overlapping
  // holes in the outside mask. Interior holes become opaque islands instead.
  function topology(geometry) {
    const edges = new Map(), incident = new Map(), centers = new Map();
    for (const cell of geometry.features) {
      const ids = new Set(); incident.set(cell.id, ids);
      let lng = 0, mercatorY = 0, count = 0;
      for (const polygon of cell.geometry.coordinates) {
        for (let r = 0; r < polygon.length; r++) {
          let ring = polygon[r].map(p => p.map(n => Math.round(n * 1e9) / 1e9));
          if (pointKey(ring[0]) === pointKey(ring.at(-1))) ring.pop();
          if (ring.length < 3) continue;
          if (r === 0) for (const p of polygon[r]) {
            lng += p[0];
            mercatorY += Math.log(Math.tan(Math.PI / 4 + p[1] * Math.PI / 360));
            count++;
          }
          if ((area(ring) > 0) !== (r === 0)) ring = ring.reverse();
          for (let i = 0; i < ring.length; i++) {
            const a = ring[i], b = ring[(i + 1) % ring.length];
            const ka = pointKey(a), kb = pointKey(b);
            if (ka === kb) continue;
            const key = ka < kb ? `${ka}|${kb}` : `${kb}|${ka}`;
            let edge = edges.get(key);
            if (!edge) { edge = {id: edges.size, a, b, sides: []}; edges.set(key, edge); }
            edge.sides.push(cell.id); ids.add(edge.id);
          }
        }
      }
      if (count) centers.set(cell.id, [lng / count, (2 * Math.atan(Math.exp(mercatorY / count)) - Math.PI / 2) * 180 / Math.PI]);
    }
    const boundary = [...edges.values()].filter(e => e.sides.length === 1);
    const outgoing = new Map();
    for (const e of boundary) {
      const key = pointKey(e.a);
      if (!outgoing.has(key)) outgoing.set(key, []);
      outgoing.get(key).push(e);
    }
    const unused = new Set(boundary), loops = [];
    while (unused.size) {
      const first = unused.values().next().value;
      const ring = [first.a]; let edge = first;
      do {
        unused.delete(edge); ring.push(edge.b);
        if (pointKey(edge.b) === pointKey(first.a)) break;
        const candidates = (outgoing.get(pointKey(edge.b)) || []).filter(e => unused.has(e));
        // At a point-touch choose the sharpest left turn, keeping each island
        // separate instead of manufacturing a self-intersecting mask hole.
        const incoming = Math.atan2(edge.b[1] - edge.a[1], edge.b[0] - edge.a[0]);
        candidates.sort((a, b) => {
          const turn = e => (Math.atan2(e.b[1] - e.a[1], e.b[0] - e.a[0]) - incoming + Math.PI * 2) % (Math.PI * 2);
          return turn(b) - turn(a);
        });
        edge = candidates[0];
        if (!edge) throw new Error('Cell coverage has an open union boundary');
      } while (edge !== first);
      loops.push({ring, area: area(ring)});
    }
    const world = [[-180,-85.051129],[180,-85.051129],[180,85.051129],[-180,85.051129],[-180,-85.051129]];
    const polygons = [[world]];
    const islands = loops.filter(l => l.area < 0).map(l => ({...l, polygon: [l.ring.slice().reverse()]}));
    polygons.push(...islands.map(l => l.polygon));
    for (const loop of loops.filter(l => l.area > 0)) {
      const parent = islands.filter(l => Math.abs(l.area) > loop.area && contains(loop.ring[0], l.ring))
        .sort((a,b) => Math.abs(a.area) - Math.abs(b.area))[0];
      (parent ? parent.polygon : polygons[0]).push(loop.ring.slice().reverse());
    }
    return {edges: [...edges.values()], incident, centers,
      outside: collection([feature(0, {type: 'MultiPolygon', coordinates: polygons})])};
  }

  function attach(map) {
    if (!map || typeof map.setFeatureState !== 'function') return null;
    if (!map.isStyleLoaded() && map.getStyle?.()?.version !== 8) return null;
    const counters = {geometryUploads: 0, featureStateUpdates: 0, playerUpdates: 0, cameraFrames: 0};
    let disposed = false, geometry = collection([]), graph = topology(geometry), pending = null;
    let states = new Map(), edgeStates = new Map(), player = null, cameraFrame = null, target = null;
    const cues = new Map(), venues = new Map(), waiters = [];
    const canvas = map.getCanvas?.(), originalLabel = canvas?.getAttribute('aria-label');
    const handle = {counters, onCellTap: null, get isAttached() { return !disposed; }, updateScene, updatePlayer, updateCameraTarget, dispose};
    function source(id, data) {
      const existing = map.getSource(id);
      if (existing) existing.setData(data);
      else map.addSource(id, {type:'geojson', data, ...(id === CELLS ? {promoteId:'cellId'} : {})});
      counters.geometryUploads++;
    }
    function upload() {
      source(OUTSIDE, graph.outside);
      source(CELLS, collection(geometry.features.map(f => ({...f, properties:{...f.properties,cellId:f.id}}))));
      source(EDGES, collection(graph.edges.map(e => feature(e.id, {type:'LineString',coordinates:[e.a,e.b]}))));
      const knowledge = ['coalesce', ['feature-state','knowledge'], 'shrouded'];
      const relationship = ['coalesce', ['feature-state','relationship'], 'unknown'];
      const layers = [
        {id:layerIds[0],type:'fill',source:OUTSIDE,paint:{'fill-color':'#1b1b1b','fill-antialias':true}},
        {id:layerIds[1],type:'fill',source:CELLS,paint:{
          'fill-color':'#1b1b1b',
          'fill-opacity':['case',
            ['==',knowledge,'present'],0,
            ['==',knowledge,'informed'],112/255,
            ['==',knowledge,'explored'],56/255,
            ['==',relationship,'frontier'],184/255,
            1],
          'fill-antialias':true}},
        {id:layerIds[2],type:'line',source:EDGES,paint:{
          'line-color':['coalesce',['feature-state','color'],'rgba(0,0,0,0)'],
          'line-width':['coalesce',['feature-state','glowWidth'],0],
          'line-blur':['coalesce',['feature-state','blur'],0]}},
        {id:layerIds[3],type:'line',source:EDGES,paint:{
          'line-color':['coalesce',['feature-state','color'],'rgba(0,0,0,0)'],
          'line-width':['coalesce',['feature-state','width'],0]}},
      ];
      for (const layer of layers) if (!map.getLayer(layer.id)) map.addLayer(layer);
      states = new Map(); edgeStates = new Map();
    }
    function setState(source, id, state) {
      map.setFeatureState({source,id},state); counters.featureStateUpdates++;
    }
    function canonicalRelationship(state) {
      if (!state) return 'unknown';
      if (state.knowledge === 'present') return 'present';
      if (state.knowledge === 'informed' || state.knowledge === 'explored') return 'explored';
      return state.relationship === 'frontier' ? 'frontier' : 'unknown';
    }
    function seam(edge) {
      const sides = edge.sides.map(id => canonicalRelationship(states.get(id)));
      const strongest = sides.includes('present') ? 'present'
        : sides.includes('explored') ? 'explored'
        : sides.includes('frontier') ? 'frontier' : 'unknown';
      if (strongest === 'unknown' ||
          (sides.length > 1 && strongest !== 'explored' && sides.every(side=>side===strongest))) {
        return {color:'rgba(0,0,0,0)',width:0,glowWidth:0,blur:0};
      }
      if (strongest === 'present') {
        return {color:'rgba(232,232,232,0.9019607843)',width:1,glowWidth:1.65,blur:0.7};
      }
      if (strongest === 'explored') {
        return {color:'rgba(92,92,92,0.7215686275)',width:0.6,glowWidth:1,blur:0.4};
      }
      return {color:'rgba(92,92,92,0.6)',width:0.8,glowWidth:0.8,blur:0.3};
    }
    function marker(element, position) {
      element.style.pointerEvents = 'none';
      return new root.maplibregl.Marker({element,anchor:'center',subpixelPositioning:true}).setLngLat(position).addTo(map);
    }
    function updateCue(state) {
      const old = cues.get(state.id), center = graph.centers.get(state.id);
      const icon = cueIcons[state.category];
      if (state.knowledge !== 'informed' || !state.cue || !icon || !center) {
        old?.remove(); cues.delete(state.id); return;
      }
      const draw = element => {
        element.innerHTML = `<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#e8e8e8" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icon}</svg>`;
        element.setAttribute('aria-label',`Informed: ${state.category}`);
      };
      if (old) {
        draw(old.getElement());
        old.setLngLat(center); return;
      }
      const element = root.document.createElement('div');
      element.className = 'earthnova-category-cue';
      element.style.cssText = 'box-sizing:border-box;width:24px;height:24px;display:flex;align-items:center;justify-content:center;border-radius:50%;border:1.5px solid #e8e8e8;background:#1b1b1b;pointer-events:none;';
      draw(element);
      element.setAttribute('role','img');
      cues.set(state.id, marker(element,center));
    }
    function updateVenues(next) {
      const ids = new Set();
      for (const venue of next) {
        ids.add(venue.id);
        const signature = JSON.stringify(venue), old = venues.get(venue.id);
        if (old?.signature === signature) continue;
        old?.marker.remove();
        const element = root.document.createElement('div');
        element.className = 'earthnova-venue-marker';
        element.style.cssText = 'display:flex;align-items:center;gap:4px;pointer-events:none;';
        element.setAttribute('role','img'); element.setAttribute('aria-label',`${venue.name}, Venue`);
        const words = (venue.name || '').trim().split(/\s+/).filter(Boolean);
        const initials = words.length > 1 ? words.slice(0,2).map(w=>Array.from(w)[0]).join('') : Array.from(words[0] || 'V').slice(0,2).join('');
        const pin = root.document.createElement('span');
        pin.textContent = initials.toUpperCase();
        pin.style.cssText = 'box-sizing:content-box;width:32px;height:32px;display:flex;align-items:center;justify-content:center;background:#203e2f;border:1.4px solid #06110c;border-radius:999px;box-shadow:0 3px 10px rgba(6,17,12,.28);color:#ffedc8;font:900 10.5px/1 sans-serif;letter-spacing:-.4px;';
        element.appendChild(pin);
        if (venue.present) {
          const label = root.document.createElement('span');
          const kind = (venue.kind || '').split(/[-_]/).filter(Boolean).map(w=>w[0].toUpperCase()+w.slice(1)).join(' ') || 'Venue';
          label.textContent = kind.length <= 18 ? kind : venue.name;
          label.style.cssText = 'white-space:nowrap;padding:4px 8px;border-radius:999px;border:1px solid #06110c;background:#203e2f;color:#ffedc8;font:800 11px/1 sans-serif;letter-spacing:-.1px;box-shadow:0 3px 10px rgba(6,17,12,.24);';
          element.appendChild(label);
        }
        // VenueMarker's glyph is anchored, not the combined glyph+label width.
        const anchor = root.document.createElement('div');
        anchor.style.cssText = 'width:32px;height:32px;pointer-events:none;';
        anchor.appendChild(element);
        venues.set(venue.id,{signature,marker:marker(anchor,[venue.lng,venue.lat])});
      }
      for (const [id,old] of venues) if (!ids.has(id)) { old.marker.remove(); venues.delete(id); }
    }
    function apply() {
      if (disposed || !pending || (!map.isStyleLoaded() && !map.getSource(CELLS))) return;
      if (pending.geometry || !map.getSource(CELLS)) {
        if (pending.geometry) { geometry = pending.geometry; graph = topology(geometry); }
        upload();
        for (const cue of cues.values()) cue.remove(); cues.clear();
      }
      const dirty = new Set();
      for (const state of pending.states) {
        const previous = states.get(state.id);
        if (previous && previous.knowledge === state.knowledge && previous.relationship === state.relationship && previous.category === state.category && previous.cue === state.cue) continue;
        states.set(state.id,state); setState(CELLS,state.id,{
          knowledge:state.knowledge,
          relationship:canonicalRelationship(state),
        });
        for (const id of graph.incident.get(state.id) || []) dirty.add(id);
        updateCue(state);
      }
      for (const id of dirty) {
        const next = seam(graph.edges[id]), signature = JSON.stringify(next);
        if (edgeStates.get(id) === signature) continue;
        edgeStates.set(id,signature); setState(EDGES,id,next);
      }
      updateVenues(pending.venues || []);
      if (canvas) {
        const counts = {shrouded:0,informed:0,explored:0,present:0};
        for (const state of states.values()) counts[state.knowledge]++;
        canvas.setAttribute('aria-label',`Exploration Map: ${counts.shrouded} Shrouded, ${counts.informed} Informed, ${counts.explored} Explored, ${counts.present} Present Cells. Outside loaded Cells is Shrouded.`);
      }
      pending = {...pending,geometry:null};
      map.triggerRepaint();
    }
    function updateScene(payload) {
      if (disposed) return Promise.resolve();
      // A newer state-only call must keep geometry awaiting a style reload.
      pending = {...payload, geometry:payload.geometry || pending?.geometry || null};
      const done = new Promise(resolve => waiters.push(resolve));
      apply(); return done;
    }
    function rendered() {
      if (pending && (!map.getSource(CELLS) || pending.geometry) && map.isStyleLoaded()) {
        apply();
        return; // The upload above cannot have appeared in this render yet.
      }
      if (!map.getSource(CELLS) || pending?.geometry) return;
      if (map.isSourceLoaded && [CELLS,EDGES,OUTSIDE].some(id => !map.isSourceLoaded(id))) return;
      for (const resolve of waiters.splice(0)) resolve();
    }
    function updatePlayer(position) {
      if (disposed) return;
      counters.playerUpdates++;
      if (!player) {
        const element = root.document.createElement('div');
        element.className = 'earthnova-player-marker';
        element.style.cssText = 'width:48px;height:48px;pointer-events:none;position:relative;';
        element.setAttribute('role','img');
        const ring = root.document.createElement('div');
        ring.style.cssText = 'position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);box-sizing:border-box;border-radius:50%;transition:width 600ms ease-out,height 600ms ease-out,background-color 600ms ease-out,border-color 600ms ease-out,box-shadow 600ms ease-out;';
        const disc = root.document.createElement('div');
        disc.style.cssText = 'position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);box-sizing:content-box;width:17.5px;height:17.5px;border-radius:50%;border:2.5px solid #0b1a14;transition:background-color 600ms ease-out;';
        const dot = root.document.createElement('div');
        dot.style.cssText = 'position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);width:6px;height:6px;border-radius:50%;background:#0b1a14;';
        element.appendChild(ring);element.appendChild(disc);element.appendChild(dot);
        player = {element,ring,disc,dot,marker:marker(element,[position.lng,position.lat])};
      }
      player.marker.setLngLat([position.lng,position.lat]);
      const trust = position.trust || 'trusted';
      const showRing = position.isRing || trust !== 'trusted';
      const trustLabel = trust === 'lowConfidence' ? 'low confidence'
        : trust === 'paused' ? 'paused' : 'trusted';
      player.element.setAttribute('aria-label',`Player location ${trustLabel}`);
      player.ring.style.width = player.ring.style.height = showRing ? '44px' : '20px';
      player.ring.style.backgroundColor = showRing ? 'rgba(178,195,182,.18)' : 'rgba(178,195,182,0)';
      player.ring.style.border = showRing ? '2px solid rgba(178,195,182,.86)' : '0 solid rgba(178,195,182,0)';
      player.ring.style.boxShadow = showRing ? '0 0 0 2px rgba(11,26,20,.92)' : 'none';
      player.disc.style.backgroundColor = showRing ? '#b2c3b6' : '#ffedc8';
    }
    function tick() {
      cameraFrame = null;
      if (disposed || !target) return;
      const center = map.getCenter(), dy = target.lat-center.lat;
      const dx = ((target.lng-center.lng+540)%360)-180;
      const lat = (target.lat+center.lat)*Math.PI/360;
      const gap = 6371000*Math.hypot(dy*Math.PI/180,dx*Math.PI/180*Math.cos(lat));
      if (gap < .1) return;
      const factor = .18 + (.55-.18)*Math.min(1,Math.log1p(gap)/Math.log1p(80));
      map.jumpTo({center:[center.lng+dx*factor,center.lat+dy*factor]});
      counters.cameraFrames++;
      cameraFrame = root.requestAnimationFrame(tick);
    }
    function updateCameraTarget(next) {
      if (disposed) return;
      target = next;
      if (cameraFrame === null) cameraFrame = root.requestAnimationFrame(tick);
    }
    function click(event) {
      if (disposed || !map.getLayer(layerIds[1])) return;
      const cell = map.queryRenderedFeatures(event.point,{layers:[layerIds[1]]})[0];
      if (cell) handle.onCellTap?.(String(cell.properties?.cellId ?? cell.id));
    }
    function reload() { if (pending) apply(); }
    function dispose() {
      if (disposed) return;
      disposed = true;
      if (cameraFrame !== null) root.cancelAnimationFrame(cameraFrame);
      cameraFrame = null;
      map.off('style.load',reload);map.off('render',rendered);map.off('click',click);map.off('remove',dispose);
      player?.marker.remove();
      for (const cue of cues.values()) cue.remove();
      for (const venue of venues.values()) venue.marker.remove();
      // MapLibre destroys its style before emitting remove.
      if (map.getStyle()) {
        for (const id of [...layerIds].reverse()) if (map.getLayer(id)) map.removeLayer(id);
        for (const id of [CELLS,EDGES,OUTSIDE]) if (map.getSource(id)) map.removeSource(id);
      }
      for (const resolve of waiters.splice(0)) resolve();
      if (canvas) {
        if (originalLabel === null) canvas.removeAttribute('aria-label');
        else canvas.setAttribute('aria-label', originalLabel);
      }
      cues.clear();venues.clear();states.clear();edgeStates.clear();pending=null;
    }
    map.on('style.load',reload);map.on('render',rendered);map.on('click',click);map.on('remove',dispose);
    return handle;
  }
  const api = {attach};
  root.EarthNovaRetainedMapRenderer = api;
  if (typeof module !== 'undefined') module.exports = api;
})(typeof window === 'undefined' ? globalThis : window);
