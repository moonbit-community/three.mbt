// Shared helpers: seeded RNG, spec -> three.js objects, result encoding.
import { upstreamURL } from '../../lib/env.mjs';
const THREE = await import(upstreamURL('src/Three.js'));
export { THREE };

export function rng(seed) {
  let a = seed >>> 0;
  const next = () => {
    a = (a + 0x6D2B79F5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  const r = {
    next,
    f: (lo = 0, hi = 1) => lo + (hi - lo) * next(),
    i: (lo, hi) => lo + Math.floor(next() * (hi - lo)),
    b: (p = 0.5) => next() < p,
    pick: (xs) => xs[Math.floor(next() * xs.length)],
  };
  return r;
}

export function buildGeometry(g) {
  const geo = new THREE.BufferGeometry();
  if (g.interleaved) {
    const ib = new THREE.InterleavedBuffer(new Float32Array(g.interleaved.array), g.interleaved.stride);
    geo.setAttribute('position', new THREE.InterleavedBufferAttribute(ib, 3, 0));
    if (g.interleaved.uvOffset !== null) geo.setAttribute('uv', new THREE.InterleavedBufferAttribute(ib, 2, g.interleaved.uvOffset));
  } else if (g.position) {
    geo.setAttribute('position', new THREE.Float32BufferAttribute(g.position, 3));
  }
  if (g.index) geo.setIndex(g.index);
  if (g.uv) geo.setAttribute('uv', new THREE.Float32BufferAttribute(g.uv, 2));
  if (g.uv1) geo.setAttribute('uv1', new THREE.Float32BufferAttribute(g.uv1, 2));
  if (g.uvNorm) geo.setAttribute('uv', new THREE.BufferAttribute(new Int16Array(g.uvNorm), 2, true));
  if (g.normal) geo.setAttribute('normal', new THREE.Float32BufferAttribute(g.normal, 3));
  if (g.skinIndex) geo.setAttribute('skinIndex', new THREE.Uint16BufferAttribute(g.skinIndex, 4));
  if (g.skinWeight) geo.setAttribute('skinWeight', new THREE.Float32BufferAttribute(g.skinWeight, 4));
  if (g.morph) {
    geo.morphAttributes.position = g.morph.map((a, i) => {
      const attr = new THREE.Float32BufferAttribute(a, 3);
      if (i % 2 === 0) attr.name = 'm' + i;
      return attr;
    });
    geo.morphTargetsRelative = g.morphRelative;
  }
  if (g.groups) for (const [s, c, m] of g.groups) geo.addGroup(s, c === null ? Infinity : c, m);
  if (g.drawRange) geo.setDrawRange(g.drawRange[0], g.drawRange[1] === null ? Infinity : g.drawRange[1]);
  return geo;
}

function makeMaterial(m, Cls) {
  const material = new Cls();
  if (m) material.side = m.side;
  return material;
}

export function applyTransform(o, t) {
  o.position.set(...t.p);
  o.quaternion.set(...t.q);
  o.scale.set(...t.s);
}

function buildSkeleton(spec) {
  const bones = spec.parents.map(() => new THREE.Bone());
  const roots = [];
  spec.parents.forEach((p, i) => { applyTransform(bones[i], spec.rest[i]); if (p < 0) roots.push(bones[i]); else bones[p].add(bones[i]); });
  for (const r of roots) r.updateMatrixWorld(true);
  return { bones, roots, skeleton: new THREE.Skeleton(bones) };
}

export function poseBones(built, spec) {
  spec.posed.forEach((t, i) => applyTransform(built.bones[i], t));
  for (const r of built.roots) r.updateMatrixWorld(true);
}

export function buildNode(n) {
  let o;
  const material = () => {
    const cls = { mesh: THREE.MeshBasicMaterial, skinned: THREE.MeshBasicMaterial, instanced: THREE.MeshBasicMaterial, line: THREE.LineBasicMaterial, lineLoop: THREE.LineBasicMaterial, lineSegments: THREE.LineBasicMaterial, points: THREE.PointsMaterial }[n.type];
    if (n.materials) return n.materials.map((m) => makeMaterial(m, cls));
    return makeMaterial(n.material, cls);
  };
  switch (n.type) {
    case 'mesh': o = new THREE.Mesh(buildGeometry(n.geometry), material()); break;
    case 'line': o = new THREE.Line(buildGeometry(n.geometry), material()); break;
    case 'lineLoop': o = new THREE.LineLoop(buildGeometry(n.geometry), material()); break;
    case 'lineSegments': o = new THREE.LineSegments(buildGeometry(n.geometry), material()); break;
    case 'points': o = new THREE.Points(buildGeometry(n.geometry), material()); break;
    case 'group': o = new THREE.Group(); break;
    case 'sprite': {
      const m = new THREE.SpriteMaterial();
      m.rotation = n.rotation; m.sizeAttenuation = n.sizeAttenuation;
      o = new THREE.Sprite(m); o.center.set(...n.center); break;
    }
    case 'instanced': {
      o = new THREE.InstancedMesh(buildGeometry(n.geometry), material(), n.count);
      for (let i = 0; i < n.count; i++) o.setMatrixAt(i, new THREE.Matrix4().fromArray(n.matrices, i * 16));
      break;
    }
    case 'skinned': {
      o = new THREE.SkinnedMesh(buildGeometry(n.geometry), material());
      break;
    }
    case 'lod': {
      o = new THREE.LOD();
      for (const l of n.levels) o.addLevel(buildNode(l.node), l.distance, l.hysteresis);
      break;
    }
  }
  if (n.influences) n.influences.forEach((v, i) => { o.morphTargetInfluences[i] = v; });
  applyTransform(o, n.transform);
  if (n.type === 'skinned') {
    o.bindMode = n.bindMode;
    o.updateMatrixWorld(true);
    const built = buildSkeleton(n.skeleton);
    o.bind(built.skeleton, n.bindMatrix ? new THREE.Matrix4().fromArray(n.bindMatrix) : undefined);
    poseBones(built, n.skeleton);
    built.skeleton.update();
    o.userData.built = built;
  }
  for (const c of n.children || []) o.add(buildNode(c));
  return o;
}

export function buildCamera(c) {
  let cam;
  if (c.type === 'perspective') cam = new THREE.PerspectiveCamera(c.fov, c.aspect, c.near, c.far);
  else cam = new THREE.OrthographicCamera(c.left, c.right, c.top, c.bottom, c.near, c.far);
  applyTransform(cam, c.transform);
  if (c.zoom) cam.zoom = c.zoom;
  if (c.webgpu) cam.coordinateSystem = THREE.WebGPUCoordinateSystem;
  if (c.reversed) cam._reversedDepth = true;
  cam.updateProjectionMatrix();
  cam.updateMatrixWorld(true);
  return cam;
}

const v = (x) => (x === undefined || x === null ? null : x.toArray ? x.toArray() : x);

export function encodeHit(h) {
  return {
    distance: h.distance,
    distanceToRay: h.distanceToRay ?? null,
    point: v(h.point),
    index: h.index ?? null,
    face: h.face ? { a: h.face.a, b: h.face.b, c: h.face.c, normal: v(h.face.normal), materialIndex: h.face.materialIndex } : null,
    faceIndex: h.faceIndex ?? null,
    barycoord: v(h.barycoord),
    uv: v(h.uv), uv1: v(h.uv1), normal: v(h.normal),
    instanceId: h.instanceId ?? null,
    batchId: h.batchId ?? null,
  };
}

export const encodeNumbers = (out) => JSON.stringify(out, (k, x) => {
  if (x === undefined) return '@undefined';
  if (typeof x === 'number') {
    if (Number.isNaN(x)) return '@NaN';
    if (x === Infinity) return '@Inf';
    if (x === -Infinity) return '@-Inf';
    if (Object.is(x, -0)) return '@-0';
  }
  return x;
});
