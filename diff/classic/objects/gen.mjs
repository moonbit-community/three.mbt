// Writes scenarios.json: inputs for both runners.
import fs from 'fs';
import { rng, THREE, buildNode } from './common.mjs';

const [, , outPath, seedArg, scaleArg] = process.argv;
const R = rng(Number(seedArg || 1));
const scale = Number(scaleArg || 1);
const round = (x) => Math.fround(x); // inputs stored in Float32 upstream anyway

const vec = (n, lo, hi) => Array.from({ length: n }, () => R.f(lo, hi));
function quat() { const q = new THREE.Quaternion(R.f(-1, 1), R.f(-1, 1), R.f(-1, 1), R.f(-1, 1)).normalize(); return q.toArray(); }
function transform(kind = R.pick(['identity', 'uniform', 'nonuniform', 'negative'])) {
  if (kind === 'identity') return { p: [0, 0, 0], q: [0, 0, 0, 1], s: [1, 1, 1] };
  const p = vec(3, -5, 5), q = quat();
  if (kind === 'uniform') { const s = R.f(0.3, 3); return { p, q, s: [s, s, s] }; }
  if (kind === 'nonuniform') return { p, q, s: vec(3, 0.3, 3) };
  return { p, q, s: [R.f(0.3, 3) * -1, R.f(0.3, 3), R.f(0.3, 3)] };
}

function triangleGeometry(opts = {}) {
  const tris = opts.tris ?? R.i(1, 30);
  const indexed = opts.indexed ?? R.b();
  const vcount = indexed ? R.i(3, tris * 2 + 3) : tris * 3;
  const position = vec(vcount * 3, -2, 2).map(round);
  const g = { position };
  if (indexed) g.index = Array.from({ length: tris * 3 }, () => R.i(0, vcount));
  if (R.b(0.7) && !opts.noUv) g.uv = vec(vcount * 2, -1, 2);
  else if (R.b(0.3) && !opts.noUv) g.uvNorm = Array.from({ length: vcount * 2 }, () => R.i(-32768, 32768));
  if (R.b(0.4) && !opts.noUv) g.uv1 = vec(vcount * 2, 0, 1);
  if (R.b(0.6) && !opts.noUv) g.normal = vec(vcount * 3, -1, 1);
  if (!indexed && R.b(0.2) && !opts.noUv) {
    // interleaved position + uv
    const stride = 5, array = [];
    for (let i = 0; i < vcount; i++) array.push(position[i * 3], position[i * 3 + 1], position[i * 3 + 2], R.f(), R.f());
    delete g.position; delete g.uv; delete g.uvNorm;
    g.interleaved = { array, stride, uvOffset: 3 };
  }
  const elementCount = indexed ? tris * 3 : vcount;
  if (opts.morph !== false && R.b(0.3)) {
    const n = R.i(1, 4);
    g.morph = Array.from({ length: n }, () => vec(vcount * 3, -1, 1));
    g.morphRelative = R.b();
  }
  if (opts.groups !== false && R.b(0.3)) {
    g.groups = [];
    let s = 0;
    while (s < elementCount) { const c = 3 * R.i(1, 6); g.groups.push([s, R.b(0.1) ? null : c, R.i(0, 3)]); s += c; }
  }
  if (R.b(0.3)) g.drawRange = [3 * R.i(0, 3), R.b(0.3) ? null : 3 * R.i(0, tris + 2)];
  return g;
}

function ray(target) {
  // aim at a random point near the object, or just anywhere
  const o = vec(3, -8, 8);
  const t = target ?? vec(3, -3, 3);
  const d = new THREE.Vector3(t[0] - o[0], t[1] - o[1], t[2] - o[2]).normalize().toArray();
  const near = R.b(0.8) ? 0 : R.f(0, 2);
  const far = R.b(0.7) ? null : R.f(4, 20);
  return { o, d, near, far, lineT: R.pick([1, 0.1, 0.02, 0.5]), pointsT: R.pick([1, 0.1, 0.3]) };
}

function worldPoints(node) {
  // world positions of vertices of the built object give rays that hit
  const o = buildNode(node);
  o.updateMatrixWorld(true);
  const pts = [];
  const v = new THREE.Vector3(), m = new THREE.Matrix4();
  o.traverse((c) => {
    if (c.isSprite) { pts.push(c.getWorldPosition(new THREE.Vector3()).toArray()); return; }
    const p = c.geometry && c.geometry.getAttribute('position');
    if (!p) return;
    for (let i = 0; i < p.count; i++) {
      v.fromBufferAttribute(p, i);
      if (c.isInstancedMesh && c.count > 0) { c.getMatrixAt(R.i(0, c.count), m); v.applyMatrix4(m); }
      v.applyMatrix4(c.matrixWorld);
      pts.push(v.toArray());
    }
  });
  return pts;
}

function aimedRays(node, n) {
  const pts = worldPoints(node);
  const rays = [];
  for (let i = 0; i < n; i++) {
    if (pts.length === 0 || R.b(0.15)) { rays.push(ray()); continue; }
    // the centroid of a few vertices lands inside triangles often
    const a = R.pick(pts), b = R.pick(pts), c = R.pick(pts);
    const w = R.pick([[1, 0, 0], [0.34, 0.33, 0.33], [0.5, 0.25, 0.25]]);
    rays.push(ray([0, 1, 2].map((k) => a[k] * w[0] + b[k] * w[1] + c[k] * w[2])));
  }
  return rays;
}

function meshNode(type = 'mesh') {
  const geometry = triangleGeometry();
  const node = { type, geometry, transform: transform() };
  if (geometry.groups) node.materials = [0, 1, 2].map(() => ({ side: R.i(0, 3) }));
  else node.material = { side: R.i(0, 3) };
  if (geometry.morph) node.influences = geometry.morph.map(() => R.pick([0, R.f(0, 1), 1]));
  return node;
}

function lineNode() {
  const type = R.pick(['line', 'lineLoop', 'lineSegments']);
  const vcount = R.i(2, 40);
  const g = { position: vec(vcount * 3, -2, 2).map(round) };
  if (R.b()) g.index = Array.from({ length: R.i(2, 60) }, () => R.i(0, vcount));
  if (R.b(0.3)) g.drawRange = [R.i(0, 3), R.b(0.2) ? 0 : R.b(0.5) ? null : R.i(0, 20)];
  const node = { type, geometry: g, transform: transform() };
  if (R.b(0.3)) node.computeDistances = true;
  return node;
}

function pointsNode() {
  const vcount = R.i(1, 60);
  const g = { position: vec(vcount * 3, -2, 2).map(round) };
  if (R.b()) g.index = Array.from({ length: R.i(1, 60) }, () => R.i(0, vcount));
  if (R.b(0.3)) g.drawRange = [R.i(0, 3), R.b(0.5) ? null : R.i(0, 20)];
  return { type: 'points', geometry: g, transform: transform() };
}

function camera(kind = R.pick(['perspective', 'orthographic'])) {
  const eye = { p: vec(3, -6, 6), q: quat(), s: [1, 1, 1] };
  const base = { transform: eye, webgpu: R.b(0.25), reversed: R.b(0.25), zoom: R.b(0.3) ? R.f(0.5, 2) : undefined };
  if (kind === 'perspective') return { type: kind, fov: R.f(30, 100), aspect: R.f(0.5, 2), near: R.f(0.1, 1), far: R.f(50, 500), ...base };
  const w = R.f(1, 8), h = R.f(1, 8);
  return { type: kind, left: -w, right: w, top: h, bottom: -h, near: R.f(0.1, 1), far: R.f(50, 500), ...base };
}

function spriteNode() {
  return { type: 'sprite', center: vec(2, 0, 1), rotation: R.pick([0, R.f(-3, 3)]), sizeAttenuation: R.b(), transform: transform(R.pick(['identity', 'uniform', 'nonuniform'])) };
}

function instancedNode() {
  const geometry = triangleGeometry({ groups: false, tris: R.i(1, 12) });
  const count = R.i(0, 8);
  const matrices = [];
  for (let i = 0; i < count; i++) {
    const t = transform();
    const m = new THREE.Matrix4().compose(new THREE.Vector3(...t.p), new THREE.Quaternion(...t.q), new THREE.Vector3(...t.s));
    matrices.push(...m.toArray());
  }
  return { type: 'instanced', geometry, count, matrices, material: { side: R.i(0, 3) }, transform: transform(), computeBox: R.b() };
}

function skeletonSpec(n) {
  const parents = Array.from({ length: n }, (_, i) => (i === 0 ? -1 : R.b(0.15) ? -1 : R.i(0, i)));
  const rest = parents.map(() => ({ p: vec(3, -1, 1), q: quat(), s: R.b() ? [1, 1, 1] : vec(3, 0.5, 1.5) }));
  const posed = parents.map(() => ({ p: vec(3, -1, 1), q: quat(), s: R.b() ? [1, 1, 1] : vec(3, 0.5, 1.5) }));
  return { parents, rest, posed };
}

function skinnedNode() {
  const geometry = triangleGeometry({ groups: false, tris: R.i(2, 16) });
  const vcount = (geometry.position ? geometry.position.length : geometry.interleaved.array.length / 5 * 3) / 3;
  const bones = R.i(1, 7);
  geometry.skinIndex = Array.from({ length: vcount * 4 }, () => R.i(0, bones));
  geometry.skinWeight = Array.from({ length: vcount * 4 }, () => R.pick([0, R.f(0, 1), R.f(0, 1), 1]));
  const node = { type: 'skinned', geometry, material: { side: R.i(0, 3) }, transform: transform(), bindMode: R.pick(['attached', 'detached']), skeleton: skeletonSpec(bones), normalize: R.b(0.6) };
  if (geometry.morph) node.influences = geometry.morph.map(() => R.f(0, 1));
  if (R.b(0.4)) {
    const t = transform('nonuniform');
    node.bindMatrix = new THREE.Matrix4().compose(new THREE.Vector3(...t.p), new THREE.Quaternion(...t.q), new THREE.Vector3(...t.s)).toArray();
  }
  return node;
}

function lodNode() {
  const n = R.i(1, 4);
  return { type: 'lod', transform: transform(), levels: Array.from({ length: n }, () => ({ node: meshNode(), distance: R.f(-20, 20), hysteresis: R.pick([0, 0.1, 0.3]) })) };
}

function treeNode(depth = 0) {
  const make = R.pick([meshNode, lineNode, pointsNode, spriteNode, instancedNode, skinnedNode, () => ({ type: 'group', transform: transform() })]);
  const node = make();
  if (depth < 2 && R.b(0.5)) node.children = Array.from({ length: R.i(1, 3) }, () => treeNode(depth + 1));
  return node;
}

const scenarios = [];
const n = (k) => Math.round(k * scale);

for (let i = 0; i < n(250); i++) { const node = meshNode(); scenarios.push({ kind: 'raycast', node, clone: R.b(0.2), rays: aimedRays(node, 24) }); }
for (let i = 0; i < n(250); i++) { const node = lineNode(); scenarios.push({ kind: 'raycast', node, clone: R.b(0.2), rays: aimedRays(node, 24) }); }
for (let i = 0; i < n(150); i++) { const node = pointsNode(); scenarios.push({ kind: 'raycast', node, clone: R.b(0.2), rays: aimedRays(node, 24) }); }
for (let i = 0; i < n(200); i++) { const node = instancedNode(); scenarios.push({ kind: 'raycast', node, clone: R.b(0.2), rays: aimedRays(node, 16) }); }
for (let i = 0; i < n(100); i++) { const node = lodNode(); scenarios.push({ kind: 'raycast', node, clone: R.b(0.2), rays: aimedRays(node, 8) }); }
for (let i = 0; i < n(100); i++) { const node = skinnedNode(); scenarios.push({ kind: 'raycast', node, clone: R.b(0.2), rays: aimedRays(node, 16) }); }
for (let i = 0; i < n(100); i++) { const node = treeNode(); scenarios.push({ kind: 'raycast', node, clone: R.b(0.2), rays: aimedRays(node, 12) }); }
for (let i = 0; i < n(250); i++) {
  scenarios.push({ kind: 'sprite', node: spriteNode(), camera: camera(), ndc: Array.from({ length: 24 }, () => (R.b(0.2) ? [R.f(-1, 1), R.f(-1, 1)] : null)), near: R.b(0.8) ? 0 : R.f(0, 3), far: R.b(0.7) ? null : R.f(3, 30) });
}
for (let i = 0; i < n(250); i++) scenarios.push({ kind: 'skinning', node: skinnedNode(), vectors: Array.from({ length: 12 }, () => vec(4, -2, 2)) });
for (let i = 0; i < n(200); i++) scenarios.push({ kind: 'skeleton', spec: skeletonSpec(R.i(0, 9)), rounds: R.i(1, 4) });
for (let i = 0; i < n(250); i++) {
  scenarios.push({ kind: 'box3', node: treeNode(), start: R.b(0.5) ? [vec(3, -1, 0), vec(3, 0, 1)] : null });
}
for (let i = 0; i < n(250); i++) {
  const itemSize = R.pick([1, 2, 3, 4]);
  const count = R.i(3, 12);
  const a = vec(count * itemSize, -3, 3);
  const attr = { array: a, itemSize, mode: R.pick(['float', 'float', 'int16norm', 'interleaved']), offset: 1 };
  if (attr.mode === 'int16norm') attr.array = a.map(() => R.i(-32768, 32768));
  if (attr.mode === 'interleaved') attr.array = vec((count + 1) * (itemSize + 1), -3, 3);
  scenarios.push({ kind: 'triangle', attr, calls: Array.from({ length: 12 }, () => ({ i: [R.i(0, count), R.i(0, count), R.i(0, count)], bary: vec(3, -0.5, 1.5) })) });
}
for (let i = 0; i < n(300); i++) {
  const c = camera();
  scenarios.push({ kind: 'frustum', camera: c, node: R.pick([meshNode, lineNode, pointsNode, spriteNode, instancedNode, skinnedNode])(), near: 0 });
}
for (let i = 0; i < n(200); i++) {
  const cams = Array.from({ length: R.i(1, 5) }, () => camera('perspective'));
  scenarios.push({ kind: 'frustumArray', cameras: cams, nodes: Array.from({ length: 4 }, () => R.pick([meshNode, spriteNode, instancedNode, skinnedNode])()), rounds: R.i(1, 3) });
}

// BatchedMesh: operation lists, kept only while upstream accepts them.
const { buildBatched, applyBatchedOp } = await import('./batched.mjs');
function geometryForBatch(indexed, useUv) {
  const tris = R.i(1, 8);
  const vcount = indexed ? R.i(3, 12) : tris * 3;
  const g = { position: vec(vcount * 3, -2, 2).map(round) };
  if (indexed) g.index = Array.from({ length: tris * 3 }, () => R.i(0, vcount));
  if (useUv) g.uv = vec(vcount * 2, 0, 1);
  return g;
}
for (let i = 0; i < n(200); i++) {
  const indexed = R.b(0.7), useUv = R.b();
  const spec = { kind: 'batched', maxInstances: R.i(2, 16), maxVertices: R.i(40, 300), maxIndices: R.i(40, 500), geometries: Array.from({ length: 6 }, () => geometryForBatch(indexed, useUv)), side: R.i(0, 3), transform: transform(), ops: [] };
  const accepted = [];
  const candidates = R.i(10, 40);
  const pairs = [];
  for (let k = 0; k < candidates; k++) {
    const op = R.pick([
      () => ['addGeometry', R.i(0, 6), R.pick([-1, -1, R.i(12, 30)]), R.pick([-1, -1, R.i(24, 40)])],
      () => ['addGeometry', R.i(0, 6), -1, -1],
      () => ['addInstance', R.i(0, 5)], () => ['addInstance', R.i(0, 5)], () => ['addInstance', R.i(0, 5)],
      () => { const t = transform(); return ['setMatrixAt', R.i(0, 8), new THREE.Matrix4().compose(new THREE.Vector3(...t.p), new THREE.Quaternion(...t.q), new THREE.Vector3(...t.s)).toArray()]; },
      () => ['setColorAt', R.i(0, 8), vec(3, 0, 1)],
      () => ['setVisibleAt', R.i(0, 8), R.b(0.7)],
      () => ['deleteInstance', R.i(0, 8)],
      () => ['deleteGeometry', R.i(0, 5)],
      () => ['optimize'],
      () => ['setInstanceCount', R.i(2, 20)],
      () => ['setGeometrySize', R.i(40, 400), R.i(40, 600)],
      () => ['setGeometryAt', R.i(0, 5), R.i(0, 6)],
      () => ['setGeometryIdAt', R.i(0, 8), R.i(0, 5)],
      () => ['draw', camera(), { sort: R.b(), culled: R.b(), transparent: R.b(), wireframe: R.b(0.2), format: R.pick(['multiDraw', 'merged']) }],
      () => ['raycast', ray()],
      () => ['bounds'],
      () => ['clone'],
    ])();
    try {
      const built = buildBatched(spec);
      for (const a of accepted) applyBatchedOp(built, spec, a);
      applyBatchedOp(built, spec, op);
      accepted.push(op);
    } catch (e) { /* illegal in this state */ }
  }
  spec.ops = accepted;
  scenarios.push(spec);
}

fs.writeFileSync(outPath, JSON.stringify(scenarios));
console.log('scenarios', scenarios.length);
