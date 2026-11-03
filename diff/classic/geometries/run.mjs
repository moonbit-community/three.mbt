import { execSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { upstreamURL } from '../../lib/env.mjs';
// GEOMETRIES_MODULE_DIR: build and load the MoonBit side from another module dir (mutate.py).
const here = process.env.GEOMETRIES_MODULE_DIR ? path.resolve(process.env.GEOMETRIES_MODULE_DIR) : path.dirname(fileURLToPath(import.meta.url));
const T = await import(upstreamURL('src/Three.js'));

if (!process.env.SKIP_BUILD) {
  // A failed build must stop the run: the previous artifact would otherwise be tested.
  try { execSync('moon build --target js', { cwd: here, stdio: 'pipe' }); }
  catch (e) { console.log('BUILD FAILED\n' + String(e.stdout).split('\n').filter(l => /Error|error/.test(l)).slice(0, 20).join('\n')); process.exit(2); }
}
const M = await import(pathToFileURL(path.join(here, '_build/js/debug/build/moonbit-community/three-diff-geometries/main/main.js')).href);

console.warn = console.error = () => {};
const log = console.log;

const P = Math.PI;
// positional argument names of each upstream constructor
const ARGS = {
  Box: ['width', 'height', 'depth', 'widthSegments', 'heightSegments', 'depthSegments'],
  Plane: ['width', 'height', 'widthSegments', 'heightSegments'],
  Circle: ['radius', 'segments', 'thetaStart', 'thetaLength'],
  Ring: ['innerRadius', 'outerRadius', 'thetaSegments', 'phiSegments', 'thetaStart', 'thetaLength'],
  Sphere: ['radius', 'widthSegments', 'heightSegments', 'phiStart', 'phiLength', 'thetaStart', 'thetaLength'],
  Cylinder: ['radiusTop', 'radiusBottom', 'height', 'radialSegments', 'heightSegments', 'openEnded', 'thetaStart', 'thetaLength'],
  Cone: ['radius', 'height', 'radialSegments', 'heightSegments', 'openEnded', 'thetaStart', 'thetaLength'],
  Capsule: ['radius', 'height', 'capSegments', 'radialSegments', 'heightSegments'],
  Torus: ['radius', 'tube', 'radialSegments', 'tubularSegments', 'arc', 'thetaStart', 'thetaLength'],
  TorusKnot: ['radius', 'tube', 'tubularSegments', 'radialSegments', 'p', 'q'],
  Polyhedron: ['vertices', 'indices', 'radius', 'detail'],
  Tetrahedron: ['radius', 'detail'], Octahedron: ['radius', 'detail'], Icosahedron: ['radius', 'detail'], Dodecahedron: ['radius', 'detail'],
  Lathe: ['points', 'segments', 'phiStart', 'phiLength'],
};

function applyOps(target, ops) {
  for (const [op, ...a] of ops) {
    if (op === 'splineThru') target.splineThru(a[0].map(p => new T.Vector2(...p)));
    else target[op](...a);
  }
}
const pts2 = (p) => p.map(q => new T.Vector2(...q));
function buildPath(spec) {
  if (spec.points) return new T.Path(pts2(spec.points));
  const p = new T.Path(); applyOps(p, spec.ops); return p;
}
function buildShape(spec, registry) {
  let s;
  if (spec.points) s = new T.Shape(pts2(spec.points));
  else { s = new T.Shape(); applyOps(s, spec.ops); }
  if (spec.holes) s.holes = spec.holes.map(buildPath);
  registry[s.uuid] = s;
  return s;
}
function buildCurve(spec) {
  if (spec === undefined) return undefined;
  const p = spec.points.map(q => new T.Vector3(...q));
  if (spec.type === 'CatmullRomCurve3') return new T.CatmullRomCurve3(p, spec.closed, spec.curveType, spec.tension);
  return new T[spec.type](...p);
}
const customUV = {
  generateTopUV: (_, v, a, b, c) => [a, b, c].map(i => new T.Vector2(v[i * 3] * 2, v[i * 3 + 1])),
  generateSideWallUV: (_, v, a, b, c, d) => [a, b, c, d].map(i => new T.Vector2(v[i * 3 + 2], v[i * 3] + 0.25)),
};
let registry = {};
function buildUpstream(spec) {
  let g;
  if (spec.custom) {
    g = new T.BufferGeometry();
    g.setAttribute('position', new T.Float32BufferAttribute(spec.custom.position, 3));
    if (spec.custom.index) g.setIndex(spec.custom.index);
    if (spec.custom.groups) for (let i = 0; i < spec.custom.groups.length; i += 3) g.addGroup(spec.custom.groups[i], spec.custom.groups[i + 1], spec.custom.groups[i + 2]);
  } else {
    const { name, args } = spec;
    const Cls = T[name + 'Geometry'];
    if (name === 'Shape') {
      const shapes = args.shapes ? args.shapes.map(x => buildShape(x, registry)) : (args.shape ? buildShape(args.shape, registry) : undefined);
      g = new Cls(shapes, args.curveSegments);
    } else if (name === 'Extrude') {
      const shapes = args.shapes ? args.shapes.map(x => buildShape(x, registry)) : undefined;
      if (args.options) {
        const { customUV: c, extrudePath: path, ...rest } = args.options;
        const o = { ...rest };
        if (path) o.extrudePath = buildCurve(path);
        if (c) o.UVGenerator = customUV;
        g = new Cls(shapes, o);
      } else g = new Cls(shapes);
    } else if (name === 'Tube') g = new Cls(buildCurve(args.path), args.tubularSegments, args.radius, args.radialSegments, args.closed);
    else if (name === 'Edges') g = new Cls(args.geometry === undefined ? undefined : buildUpstream(args.geometry), args.thresholdAngle);
    else if (name === 'Wireframe') g = new Cls(args.geometry === undefined ? undefined : buildUpstream(args.geometry));
    else {
      const a = ARGS[name].map(k => args[k]);
      if (name === 'Lathe' && args.points) a[0] = args.points.map(p => args.vector3 ? new T.Vector3(...p) : new T.Vector2(...p));
      g = new Cls(...a);
    }
  }
  if (spec.nonIndexed) g = g.toNonIndexed();
  if (spec.translate) g.translate(0.5, 0.25, -0.125);
  return g;
}

const attr = a => ({ array: a.array, itemSize: a.itemSize, count: a.count, normalized: a.normalized });
function snapshot(g) {
  const attributes = {};
  for (const k in g.attributes) attributes[k] = attr(g.attributes[k]);
  const r = {
    type: g.type, name: g.name, attributes, index: g.index ? attr(g.index) : undefined,
    groups: g.groups.map(x => [x.start, x.count, x.materialIndex]),
    drawRange: [g.drawRange.start, g.drawRange.count],
    toJSON: JSON.stringify(g.toJSON()),
  };
  if (g.parameters) {
    r.parameters = JSON.stringify(g.parameters);
    r.parameterKeys = Object.keys(g.parameters);
    if (g.parameters.shapes !== undefined) {
      // upstream holds the Shape objects; `values` holds what toJSON turns them into
      r.shapesInParams = true;
      const s = g.parameters.shapes;
      r.shapes = (Array.isArray(s) ? s : [s]).map(x => JSON.stringify(x.toJSON()));
    }
  }
  return r;
}
function caseUpstream(spec) {
  const result = {};
  const g = buildUpstream(spec);
  result.plain = snapshot(g);
  const bounds = g.clone();
  bounds.computeBoundingSphere(); bounds.computeBoundingBox();
  result.boundingSphere = bounds.boundingSphere ? { center: bounds.boundingSphere.center.toArray(), radius: bounds.boundingSphere.radius } : undefined;
  result.boundingBox = bounds.boundingBox ? { min: bounds.boundingBox.min.toArray(), max: bounds.boundingBox.max.toArray() } : undefined;
  result.boundedJSON = JSON.stringify(bounds.toJSON());
  const clone = g.clone();
  result.clone = snapshot(clone);
  result.cloneIdentity = clone.uuid !== g.uuid && clone.id !== g.id;
  const target = new T.BoxGeometry();
  target.copy(g);
  result.copyOntoBox = snapshot(target);
  const transformed = g.clone();
  transformed.rotateX(0.5);
  result.transformed = snapshot(transformed);
  const Cls = spec.name && T[spec.name + 'Geometry'];
  const jsonText = JSON.stringify(g.toJSON());
  if (Cls && Cls.fromJSON) {
    result.hasFromJSON = true;
    try { result.fromJSON = snapshot(Cls.fromJSON(JSON.parse(jsonText), registry)); } catch (e) { result.fromJSONThrew = e.message; }
  }
  if (spec.name === 'Tube') {
    const fr = (x) => ({ tangents: x.tangents.flatMap(v => v.toArray()), normals: x.normals.flatMap(v => v.toArray()), binormals: x.binormals.flatMap(v => v.toArray()) });
    result.frames = fr(g); result.cloneFrames = fr(clone);
  }
  return { result, jsonText: (Cls && Cls.fromJSON) ? jsonText : '' };
}

// Numbers: the text of MoonBit's Json::stringify may spell a number differently, so
// re-serialize through JS. Then uuids are numbered in order of appearance.
const UUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/g;
function normalizeUuids(text) { const m = new Map(); return text.replace(UUID, u => { if (!m.has(u)) m.set(u, 'U' + m.size); return m.get(u); }); }
function normJson(text) { return normalizeUuids(text); }
function normMoon(text) {
  return normalizeUuids(JSON.stringify(JSON.parse(text.replace(/(?<=[:\[,])(-?Infinity|NaN)(?=[,\]}])/g, 'null'))));
}

function bytes(a) { return Buffer.from(a.buffer, a.byteOffset, a.byteLength); }
function cmpAttr(ctx, name, u, m, fail) {
  if (!u !== !m) return fail(`${ctx}.${name}: presence ${!!u} vs ${!!m}`);
  if (!u) return;
  if (u.itemSize !== m.itemSize || u.count !== m.count || u.normalized !== m.normalized) fail(`${ctx}.${name}: itemSize/count/normalized ${u.itemSize},${u.count},${u.normalized} vs ${m.itemSize},${m.count},${m.normalized}`);
  if (u.array.constructor.name !== m.array.constructor.name) return fail(`${ctx}.${name}: array type ${u.array.constructor.name} vs ${m.array.constructor.name}`);
  if (!bytes(u.array).equals(bytes(m.array))) {
    // Element by element. Only the bit pattern of a NaN may differ: V8 gives upstream
    // itself two patterns for the same input depending on the JIT tier.
    const bu = u.array, bm = m.array, size = bu.BYTES_PER_ELEMENT;
    if (bu.length !== bm.length) return fail(`${ctx}.${name}: length ${bu.length} vs ${bm.length}`);
    const xu = bytes(bu), xm = bytes(bm);
    for (let i = 0; i < bu.length; i++) {
      if (xu.compare(xm, i * size, (i + 1) * size, i * size, (i + 1) * size) === 0) continue;
      if (Number.isNaN(bu[i]) && Number.isNaN(bm[i])) { stats.nanBitPatternOnly++; continue; }
      return fail(`${ctx}.${name}: bytes differ at ${i}/${bu.length}: ${bu[i]} vs ${bm[i]}`);
    }
  }
}
function cmpSnap(ctx, u, m, fail) {
  if (u.type !== m.type) fail(`${ctx}.type ${u.type} vs ${m.type}`);
  if (u.name !== m.name) fail(`${ctx}.name`);
  const ku = Object.keys(u.attributes), km = Object.keys(m.attributes);
  if (ku.join() !== km.join()) fail(`${ctx}.attributes keys ${ku} vs ${km}`);
  for (const k of ku) cmpAttr(ctx, k, u.attributes[k], m.attributes[k], fail);
  cmpAttr(ctx, 'index', u.index, m.index, fail);
  if (JSON.stringify(u.groups) !== JSON.stringify(m.groups)) fail(`${ctx}.groups ${JSON.stringify(u.groups)} vs ${JSON.stringify(m.groups)}`);
  if (JSON.stringify(u.drawRange) !== JSON.stringify(m.drawRange)) fail(`${ctx}.drawRange`);
  if ((u.parameterKeys || []).join() !== (m.parameterKeys || []).join()) fail(`${ctx}.parameterKeys ${u.parameterKeys} vs ${m.parameterKeys}`);
  if (u.parameters !== undefined && !u.shapesInParams) {
    const a = normJson(u.parameters), b = normMoon(m.parameters);
    if (a !== b) fail(`${ctx}.parameters\n  U ${a.slice(0, 400)}\n  M ${b.slice(0, 400)}`);
  }
  if (u.shapes) {
    const us = u.shapes.map(normJson), ms = [...m.shapes].map(normMoon);
    if (us.join() !== ms.join()) fail(`${ctx}.shapes\n  U ${us.join().slice(0, 300)}\n  M ${ms.join().slice(0, 300)}`);
  }
  let a = normJson(u.toJSON), b = normMoon(m.toJSON);
  // Deviations reported to the user, counted rather than hidden. See KNOWN.
  if (a !== b) { let i = 0; while (a[i] === b[i]) i++; fail(`${ctx}.toJSON at ${i}\n  U ${a.slice(Math.max(0, i - 80), i + 120)}\n  M ${b.slice(Math.max(0, i - 80), i + 120)}`); }
}
const stats = { fromJSONCompared: 0, fromJSONBothThrow: 0, nanBitPatternOnly: 0 };
const failClasses = {};
const throwClasses = {};
const known = { transformedExtraKeys: 0, copyOntoBoxShapes: 0 };
function eqNums(x, y) { return x === y || (x.length === y.length && x.every((v, i) => Object.is(v, y[i]))); }
function compare(u, m, fail) {
  if (u.frames) for (const key of ['frames', 'cloneFrames']) for (const k of ['tangents', 'normals', 'binormals'])
    if (!eqNums(u[key][k], m[key][k])) fail(`${key}.${k} differ (${u[key][k].length} vs ${m[key][k].length})`);
  cmpSnap('plain', u.plain, m.plain, fail);
  for (const key of ['clone', 'copyOntoBox', 'transformed']) cmpSnap(key, u[key], m[key], fail);
  if (u.hasFromJSON) {
    if (!!u.fromJSONThrew !== !!m.fromJSONThrew) fail(`fromJSON throw mismatch: upstream=${u.fromJSONThrew} moon=${m.fromJSONThrew}`);
    else if (u.fromJSONThrew) stats.fromJSONBothThrow++;
    else { stats.fromJSONCompared++; cmpSnap('fromJSON', u.fromJSON, m.fromJSON, fail); }
  }
  if (u.cloneIdentity !== m.cloneIdentity) fail('cloneIdentity');
  const bs = (x) => x ? [...x.center, x.radius] : [];
  if (!eqNums(bs(u.boundingSphere), bs(m.boundingSphere))) fail(`boundingSphere ${bs(u.boundingSphere)} vs ${bs(m.boundingSphere)}`);
  const bb = (x) => x ? [...x.min, ...x.max] : [];
  if (!eqNums(bb(u.boundingBox), bb(m.boundingBox))) fail(`boundingBox ${bb(u.boundingBox)} vs ${bb(m.boundingBox)}`);
  const a = normJson(u.boundedJSON), b = normMoon(m.boundedJSON);
  if (a !== b) fail(`boundedJSON\n  U ${a.slice(0, 300)}\n  M ${b.slice(0, 300)}`);
}

const { grid } = await import('./grid.mjs');
const cases = grid(T);
const filter = process.env.ONLY;
let pass = 0, failN = 0, bothThrow = 0; const byName = {};
for (const spec of cases) {
  const label = JSON.stringify(spec).slice(0, 160);
  if (filter && !label.includes(filter)) continue;
  const n = spec.name || 'custom';
  registry = {};
  const rec = byName[n] ??= { pass: 0, fail: 0, bothThrow: 0 };
  let u, ue, m, me;
  try { u = caseUpstream(spec); } catch (e) { ue = e; }
  try {
    m = M.snapshot_case(spec);
    if (u && u.result.hasFromJSON) {
      try { m.fromJSON = M.from_json_case(spec.name, m.ownJSON ?? u.jsonText); } catch (e) { m.fromJSONThrew = e.message || 'threw'; }
    }
  } catch (e) { me = e; }
  const fails = [];
  const fail = (s) => fails.push(s);
  if (ue || me) {
    if (ue && me) {
      bothThrow++; rec.bothThrow++;
      const c = `${n}: ${String(ue.message).slice(0, 60)}  <->  ${String(me.message || me).split('\n')[0].slice(0, 60)}`;
      throwClasses[c] = (throwClasses[c] || 0) + 1;
      continue;
    }
    fail(`throw mismatch: upstream=${ue?.message} moon=${me?.message} ${me?.stack?.split('\n').slice(0, 4).join(' | ')}`);
  } else {
    if (['Shape', 'Extrude', 'Tube'].includes(spec.name)) u.result.transformed.dropTransformed = true;
    compare(u.result, m, fail);
  }
  if (fails.length) {
    failN++; rec.fail++;
    for (const f of fails) { const c = n + ' ' + f.split(/[ :\n]/)[0]; failClasses[c] = (failClasses[c] || 0) + 1; }
    if (failN <= (+process.env.SHOW || 12)) log('FAIL', label, '\n ', fails.slice(0, 5).join('\n  '));
  } else { pass++; rec.pass++; }
}
log(JSON.stringify(byName));
log('KNOWN deviations neutralised:', JSON.stringify(known));
log('fromJSON:', JSON.stringify(stats));
log('failure classes:', JSON.stringify(failClasses));
for (const [k, v] of Object.entries(throwClasses)) log('  bothThrow', v, k);
log(`cases=${pass + failN + bothThrow} pass=${pass} bothThrow=${bothThrow} fail=${failN}`);
process.exitCode = failN ? 1 : 0;
