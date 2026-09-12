const {test} = require('node:test');
const assert = require('node:assert/strict');
const {attach} = require('../../web/retained_map_renderer.js');

class Element {
  constructor() { this.style = {}; this.children = []; this.dataset = {}; }
  appendChild(child) { this.children.push(child); return child; }
  setAttribute(key, value) { this[key] = value; }
  getAttribute(key) { return this[key] ?? null; }
  removeAttribute(key) { delete this[key]; }
  addEventListener() {}
  remove() { this.removed = true; }
}
global.document = {createElement: () => new Element()};
const markers = [];
global.maplibregl = {Marker: class {
  constructor({element, subpixelPositioning}) { this.element = element; this.subpixelPositioning = subpixelPositioning; markers.push(this); }
  setLngLat(point) { this.point = point; return this; }
  addTo() { return this; }
  getElement() { return this.element; }
  remove() { this.removed = true; }
}};
let frameId = 0;
const frames = new Map();
global.requestAnimationFrame = cb => { frames.set(++frameId, cb); return frameId; };
global.cancelAnimationFrame = id => frames.delete(id);
function frame() { const pending = [...frames.values()]; frames.clear(); pending.forEach(cb => cb()); }
function map() {
  const sources = new Map(), layers = new Map(), listeners = new Map();
  const canvas = new Element();
  return {
    sources, layers, listeners, stateCalls: [], center: {lng: 0, lat: 0}, loaded: true,
    getCanvas() { return canvas; }, sourcesLoaded: true,
    isSourceLoaded() { return this.sourcesLoaded; },
    isStyleLoaded() { return this.loaded; },
    addSource(id, source) { sources.set(id, {...source, uploads: 0, setData(data) { this.data = data; this.uploads++; }}); },
    getSource: id => sources.get(id), removeSource: id => sources.delete(id),
    addLayer(layer) { layers.set(layer.id, layer); }, getLayer: id => layers.get(id), removeLayer: id => layers.delete(id),
    setFeatureState(feature, state) { this.stateCalls.push({feature, state}); },
    on(event, cb) { if (!listeners.has(event)) listeners.set(event, new Set()); listeners.get(event).add(cb); },
    off(event, cb) { listeners.get(event)?.delete(cb); },
    emit(event) { for (const cb of [...(listeners.get(event) || [])]) cb({}); },
    triggerRepaint() { queueMicrotask(() => this.emit('render')); },
    getCenter() { return this.center; }, jumpTo({center}) { this.center = {lng:center[0],lat:center[1]}; },
    queryRenderedFeatures() { return [{id:'a'}]; },
  };
}
const ring = (x,y,w=1) => [[x,y],[x+w,y],[x+w,y+w],[x,y+w],[x,y]];
const feature = (id, polygons) => ({type:'Feature',id,properties:{},geometry:{type:'MultiPolygon',coordinates:polygons}});
const collection = features => ({type:'FeatureCollection',features});
const state = (id, knowledge, relationship='unknown') => ({id,knowledge,relationship,category:null,cue:null});
const scene = (features, states) => ({geometry: features && collection(features),states,venues:[]});
function insideRing(p,r) { let yes=false; for(let i=0,j=r.length-1;i<r.length;j=i++) {const a=r[i],b=r[j]; if((a[1]>p[1])!==(b[1]>p[1]) && p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0]) yes=!yes;} return yes; }
function covered(p, geometry) { return geometry.coordinates.some(poly => insideRing(p,poly[0]) && !poly.slice(1).some(r => insideRing(p,r))); }

test('player retains fractional positioning rather than quantizing walking to pixels', () => {
  const start=markers.length,h=attach(map());
  try {
    h.updatePlayer({lat:0.001,lng:0.001,isRing:false,gapDistance:0,trust:'trusted'});
    assert.equal(markers.at(-1).subpixelPositioning,true);
    const player=markers.at(-1).element;
    assert.equal(player.getAttribute('aria-label'),'Player location trusted');
    assert.equal(player.children.length,3);
    assert.equal(player.children[1].style.backgroundColor,'#ffedc8');
  } finally { h.dispose();markers.length=start; }
});

test('retains geometry through state changes and movement; updates only changed cells and incident seams', async () => {
  const m=map(), h=attach(m);
  await h.updateScene(scene([feature('a',[[ring(0,0)]]),feature('b',[[ring(1,0)]])],[state('a','present'),state('b','explored')]));
  const uploads=h.counters.geometryUploads;
  m.stateCalls.length=0;
  await h.updateScene(scene(null,[state('a','present'),state('b','explored')]));
  assert.equal(m.stateCalls.length,0);
  await h.updateScene(scene(null,[state('a','explored'),state('b','explored')]));
  assert.deepEqual(m.stateCalls.filter(c => c.feature.source==='earthnova-cells').map(c=>c.feature.id),['a']);
  for(let i=0;i<100;i++) {h.updatePlayer({lat:0,lng:i/10000,isRing:false,gapDistance:0,trust:'trusted'});h.updateCameraTarget({lat:0,lng:i/10000});frame();}
  assert.equal(h.counters.geometryUploads,uploads);
  assert.equal(markers.filter(p=>!p.removed).length,1);
  h.updatePlayer({lat:0,lng:0,isRing:false,gapDistance:100,trust:'lowConfidence'});
  assert.equal(markers.filter(p=>!p.removed).length,1);
  const player=markers.at(-1).element;
  assert.equal(player.getAttribute('aria-label'),'Player location low confidence');
  assert.equal(player.children[0].style.width,'44px');
  assert.equal(player.children[0].style.boxShadow,'0 0 0 2px rgba(11,26,20,.92)');
  assert.equal(player.children[1].style.backgroundColor,'#b2c3b6');
  h.updatePlayer({lat:0,lng:0,isRing:true,gapDistance:100,trust:'paused'});
  assert.equal(player.getAttribute('aria-label'),'Player location paused');
  h.dispose(); assert.equal(frames.size,0);
});

test('outside shroud is complement of adjacent cells, holes, and disconnected polygons', async () => {
  const m=map(), h=attach(m);
  await h.updateScene(scene([
    feature('a',[[ring(0,0,3),ring(1,1)], [ring(6,0)]]),
    feature('b',[[ring(3,0,3)]])
  ],[state('a','present'),state('b','explored')]));
  const mask=m.sources.get('earthnova-outside').data.features[0].geometry;
  for(const p of [[.5,.5],[3.5,.5],[6.5,.5]]) assert.equal(covered(p,mask),false,`${p} stays clear of backdrop`);
  for(const p of [[1.5,1.5],[9,0],[.5,4]]) assert.equal(covered(p,mask),true,`${p} stays shrouded`);
  const edges=m.sources.get('earthnova-edges').data.features;
  const shared=edges.filter(e => e.geometry.coordinates.every(p=>p[0]===3));
  assert.equal(shared.length,1,'one shared seam');
  h.dispose();
});

test('venue markers retain the current neutral design palette', async () => {
  const m=map(), h=attach(m);
  await h.updateScene({
    ...scene([feature('a',[[ring(0,0)]])],[state('a','present')]),
    venues:[{id:'v',name:'River Cafe',kind:'coffee-shop',lat:.5,lng:.5,present:true}],
  });
  const anchor=markers.filter(marker=>!marker.removed).at(-1).element;
  const venue=anchor.children[0], pin=venue.children[0], label=venue.children[1];
  assert.equal(venue.getAttribute('aria-label'),'River Cafe, Venue');
  for(const element of [pin,label]) {
    assert.match(element.style.cssText,/#203e2f/);
    assert.match(element.style.cssText,/#06110c/);
    assert.match(element.style.cssText,/#ffedc8/);
  }
  assert.equal(label.textContent,'Coffee Shop');
  h.dispose();
});

test('matches current monochrome fog and frontier treatments', async () => {
  const m=map(), h=attach(m);
  await h.updateScene(scene(
    [feature('a',[[ring(0,0)]])],
    [state('a','shrouded','frontier')],
  ));
  assert.equal(m.layers.get('earthnova-outside-fill').paint['fill-color'],'#1b1b1b');
  assert.deepEqual(m.layers.get('earthnova-cell-fill').paint,{
    'fill-color':'#1b1b1b',
    'fill-opacity':['case',
      ['==',['coalesce',['feature-state','knowledge'],'shrouded'],'present'],0,
      ['==',['coalesce',['feature-state','knowledge'],'shrouded'],'informed'],112/255,
      ['==',['coalesce',['feature-state','knowledge'],'shrouded'],'explored'],56/255,
      ['==',['coalesce',['feature-state','relationship'],'unknown'],'frontier'],184/255,
      1],
    'fill-antialias':true,
  });
  assert.deepEqual(
    m.stateCalls.filter(c=>c.feature.source==='earthnova-cells').at(-1).state,
    {knowledge:'shrouded',relationship:'frontier'},
  );
  assert.ok(m.stateCalls.some(c=>c.feature.source==='earthnova-edges' &&
    c.state.color==='rgba(92,92,92,0.6)' && c.state.width===0.8 &&
    c.state.glowWidth===0.8 && c.state.blur===0.3));
  await h.updateScene(scene(null,[state('a','shrouded')]));
  assert.deepEqual(
    m.stateCalls.filter(c=>c.feature.source==='earthnova-cells').at(-1).state,
    {knowledge:'shrouded',relationship:'unknown'},
  );
  assert.equal(m.stateCalls.filter(c=>c.feature.source==='earthnova-edges').at(-1).state.width,0);
  h.dispose();
});

test('unsupported attach, style reload, latest pending scene, click, and disposal are safe', async () => {
  assert.equal(attach(null),null);
  const m=map();m.loaded=false;assert.equal(attach(m),null);m.loaded=true;
  const h=attach(m); let tapped;h.onCellTap=id=>tapped=id;
  await h.updateScene(scene([feature('a',[[ring(0,0)]])],[state('a','present')]));
  m.emit('click');assert.equal(tapped,'a');
  m.loaded=false;m.sources.clear();m.layers.clear();
  const old=h.updateScene(scene(null,[state('a','shrouded')]));
  const latest=h.updateScene(scene(null,[state('a','explored')]));
  m.loaded=true;m.emit('style.load');await Promise.all([old,latest]);
  assert.equal(m.stateCalls.filter(c=>c.feature.source==='earthnova-cells').at(-1).state.knowledge,'explored');
  const pending=h.updateScene(scene(null,[state('a','present')]));h.dispose();await pending;
  assert.equal(m.sources.size,0);assert.equal(m.layers.size,0);
  assert.equal([...m.listeners.values()].reduce((n,s)=>n+s.size,0),0);
});

test('render readiness waits for worker data and latest state; informed cue remains labelled', async () => {
  const m=map(), h=attach(m);m.sourcesLoaded=false;
  let ready=false;
  const first=h.updateScene(scene([feature('a',[[ring(0,0)]])],[state('a','present')])).then(()=>ready=true);
  await Promise.resolve();assert.equal(ready,false,'an unrelated render cannot open readiness');
  const next=h.updateScene(scene(null,[{id:'a',knowledge:'informed',category:'fauna',cue:'F'}]));
  await Promise.resolve();assert.equal(ready,false);
  m.sourcesLoaded=true;m.emit('render');await Promise.all([first,next]);
  assert.equal(ready,true);
  assert.match(m.getCanvas().getAttribute('aria-label'),/1 Informed/);
  assert.equal(markers.filter(p=>!p.removed).at(-1).element.getAttribute('aria-label'),'Informed: fauna');
  const categoryMarker=markers.filter(p=>!p.removed).at(-1).element;
  assert.match(categoryMarker.innerHTML,/^<svg /);
  assert.match(categoryMarker.style.cssText,/#e8e8e8.*#1b1b1b/);
  await h.updateScene(scene(null,[{id:'a',knowledge:'informed',category:'flora',cue:'L'}]));
  assert.equal(markers.filter(p=>!p.removed).at(-1).element.getAttribute('aria-label'),'Informed: flora');
  const icons=new Set();
  for(const category of ['fauna','flora','mineral','fossil','artifact','food','orb']) {
    await h.updateScene(scene(null,[{id:'a',knowledge:'informed',category,cue:category}]));
    const element=markers.filter(p=>!p.removed).at(-1).element;
    assert.equal(element.getAttribute('aria-label'),`Informed: ${category}`);
    assert.match(element.innerHTML,/^<svg /);
    icons.add(element.innerHTML);
  }
  assert.equal(icons.size,7,'every category retains a distinct monochrome glyph');
  await h.updateScene(scene(null,[state('a','explored')]));
  assert.equal(markers.filter(p=>!p.removed).length,0);
  h.dispose();assert.equal(m.getCanvas().getAttribute('aria-label'),null);
});

test('early style-ready bridge attaches but delays scene until native style finishes', async () => {
  const m=map();m.loaded=false;
  m.getStyle=()=>({version:8,sources:{},layers:[]});
  const h=attach(m);
  assert.ok(h,'available native map is supported even while style sources load');
  const first=h.updateScene(scene([feature('a',[[ring(0,0)]])],[state('a','present')]));
  const latest=h.updateScene(scene(null,[state('a','explored')]));
  assert.equal(m.sources.size,0,'no addSource before style load');
  let painted=false;latest.then(()=>{painted=true;});
  m.loaded=true;m.emit('render');
  await Promise.resolve();
  assert.equal(painted,false,'upload during render cannot prove its own paint');
  m.emit('render');
  await Promise.all([first,latest]);
  assert.equal(m.stateCalls.filter(c=>c.feature.source==='earthnova-cells').at(-1).state.knowledge,'explored');
  h.dispose();
});
