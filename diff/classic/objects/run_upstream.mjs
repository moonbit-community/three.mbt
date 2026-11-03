import fs from 'fs';
import { THREE, buildNode, buildCamera, encodeHit, encodeNumbers, applyTransform, poseBones } from './common.mjs';
import { buildBatched, applyBatchedOp, batchedState } from './batched.mjs';

const [, , inPath, outPath] = process.argv;
const scenarios = JSON.parse(fs.readFileSync(inPath, 'utf8'));
const console_warn = console.warn; console.warn = () => {}; console.error = () => {};

const raycasterFor = (r) => {
  const rc = new THREE.Raycaster(new THREE.Vector3(...r.o), new THREE.Vector3(...r.d), r.near, r.far === null ? Infinity : r.far);
  rc.params.Line.threshold = r.lineT; rc.params.Points.threshold = r.pointsT;
  return rc;
};

function needsCamera(o) { let b = false; o.traverse((c) => { b = b || c.isSprite; }); return b; }
const fixedCamera = () => { const c = new THREE.PerspectiveCamera(60, 1, 0.1, 100); c.position.set(0, 0, 9); c.updateMatrixWorld(true); return c; };

function prepare(node, o) {
  // postBuild steps which depend on the node's extras
  const walk = (n, obj) => {
    if (n.computeDistances && obj.geometry.index === null) obj.computeLineDistances();
    if (n.computeBox) obj.computeBoundingBox();
    if (n.normalize) obj.normalizeSkinWeights();
    (n.children || []).forEach((c, i) => walk(c, obj.children[i]));
  };
  walk(node, o);
}

function run(s) {
  switch (s.kind) {
    case 'raycast': {
      let o = buildNode(s.node);
      prepare(s.node, o);
      o.updateMatrixWorld(true);
      if (s.clone) { o = o.clone(); o.updateMatrixWorld(true); }
      const cam = fixedCamera();
      const out = {};
      if (s.node.computeDistances && o.geometry.index === null) out.lineDistances = Array.from(o.geometry.attributes.lineDistance.array);
      out.hits = s.rays.map((r) => {
        const rc = raycasterFor(r);
        rc.camera = cam;
        return rc.intersectObject(o, true).map(encodeHit);
      });
      if (s.node.type === 'instanced') {
        o.computeBoundingBox();
        out.box = [o.boundingBox.min.toArray(), o.boundingBox.max.toArray(), o.boundingSphere ? [o.boundingSphere.center.toArray(), o.boundingSphere.radius] : null];
      }
      return out;
    }
    case 'sprite': {
      const o = buildNode(s.node);
      o.updateMatrixWorld(true);
      const cam = buildCamera(s.camera);
      const inv = new THREE.Vector3();
      const center = o.getWorldPosition(new THREE.Vector3()).project(cam);
      const hits = s.ndc.map((ndc) => {
        const rc = new THREE.Raycaster();
        rc.near = s.near; rc.far = s.far === null ? Infinity : s.far;
        rc.setFromCamera(ndc ? new THREE.Vector2(...ndc) : new THREE.Vector2(center.x, center.y), cam);
        const hit = rc.intersectObject(o).map(encodeHit);
        return { ray: [rc.ray.origin.toArray(), rc.ray.direction.toArray()], hit };
      });
      return { hits };
    }
    case 'skinning': {
      const o = buildNode(s.node);
      prepare(s.node, o);
      o.updateMatrixWorld(true);
      const skel = o.skeleton;
      const count = o.geometry.getAttribute('position').count;
      const out = { boneMatrices: Array.from(skel.boneMatrices), bindInverse: o.bindMatrixInverse.toArray(), v3: [], v4: [], verts: [] };
      for (let i = 0; i < count; i++) {
        const t = s.vectors[i % s.vectors.length];
        const v3 = new THREE.Vector3(t[0], t[1], t[2]);
        out.v3.push(o.applyBoneTransform(i, v3).toArray());
        const v4 = new THREE.Vector4(t[0], t[1], t[2], t[3]);
        out.v4.push(o.applyBoneTransform(i, v4).toArray());
        out.verts.push(o.getVertexPosition(i, new THREE.Vector3()).toArray());
      }
      o.computeBoundingBox(); o.computeBoundingSphere();
      out.box = [o.boundingBox.min.toArray(), o.boundingBox.max.toArray()];
      out.sphere = [o.boundingSphere.center.toArray(), o.boundingSphere.radius];
      o.pose();
      o.updateMatrixWorld(true);
      out.posed = o.userData.built.bones.map((b) => [b.position.toArray(), b.quaternion.toArray(), b.scale.toArray(), b.matrixWorld.toArray()]);
      return out;
    }
    case 'skeleton': {
      const spec = s.spec;
      const bones = spec.parents.map(() => new THREE.Bone());
      const roots = [];
      spec.parents.forEach((p, i) => { applyTransform(bones[i], spec.rest[i]); if (p < 0) roots.push(bones[i]); else bones[p].add(bones[i]); });
      for (const r of roots) r.updateMatrixWorld(true);
      const skel = new THREE.Skeleton(bones);
      const out = { inverses: skel.boneInverses.map((m) => m.toArray()), rounds: [] };
      skel.computeBoneTexture();
      out.textureSize = skel.boneTexture.image.width; out.textureLength = skel.boneMatrices.length;
      for (let r = 0; r < s.rounds; r++) {
        spec.posed.forEach((t, i) => { if ((i + r) % 2 === 0) applyTransform(bones[i], t); });
        for (const b of roots) b.updateMatrixWorld(true);
        skel.update();
        const m = Array.from(skel.boneMatrices);
        skel.pose();
        for (const b of roots) b.updateMatrixWorld(true);
        out.rounds.push([m, bones.map((b) => [b.position.toArray(), b.quaternion.toArray(), b.scale.toArray()]), skel.boneTexture.version]);
      }
      const json = skel.toJSON();
      out.json = [json.bones.length, JSON.parse(JSON.stringify(json.boneInverses))];
      return out;
    }
    case 'box3': {
      const o = buildNode(s.node);
      prepare(s.node, o);
      o.updateMatrixWorld(true);
      const box = (b) => [b.min.toArray(), b.max.toArray()];
      const out = {};
      out.coarse = box(new THREE.Box3().setFromObject(o));
      out.precise = box(new THREE.Box3().setFromObject(o, true));
      if (s.start) {
        const b = new THREE.Box3(new THREE.Vector3(...s.start[0]), new THREE.Vector3(...s.start[1]));
        out.expanded = box(b.clone().expandByObject(o));
        out.expandedPrecise = box(b.clone().expandByObject(o, true));
      }
      return out;
    }
    case 'triangle': {
      const a = s.attr;
      let attribute;
      if (a.mode === 'float') attribute = new THREE.Float32BufferAttribute(a.array, a.itemSize);
      else if (a.mode === 'int16norm') attribute = new THREE.BufferAttribute(new Int16Array(a.array), a.itemSize, true);
      else attribute = new THREE.InterleavedBufferAttribute(new THREE.InterleavedBuffer(new Float32Array(a.array), a.itemSize + 1), a.itemSize, a.offset);
      return s.calls.map((c) => {
        const b = new THREE.Vector3(...c.bary);
        const [i1, i2, i3] = c.i;
        const t = new THREE.Triangle().setFromAttributeAndIndices(attribute, i1, i2, i3);
        return {
          v2: THREE.Triangle.getInterpolatedAttribute(attribute, i1, i2, i3, b, new THREE.Vector2(9, 9)).toArray(),
          v3: THREE.Triangle.getInterpolatedAttribute(attribute, i1, i2, i3, b, new THREE.Vector3(9, 9, 9)).toArray(),
          v4: THREE.Triangle.getInterpolatedAttribute(attribute, i1, i2, i3, b, new THREE.Vector4(9, 9, 9, 9)).toArray(),
          tri: [t.a.toArray(), t.b.toArray(), t.c.toArray()],
        };
      });
    }
    case 'frustum': {
      const o = buildNode(s.node);
      prepare(s.node, o);
      o.updateMatrixWorld(true);
      const cam = buildCamera(s.camera);
      const m = new THREE.Matrix4().multiplyMatrices(cam.projectionMatrix, cam.matrixWorldInverse);
      const f = new THREE.Frustum().setFromProjectionMatrix(m, cam.coordinateSystem, cam.reversedDepth);
      const out = { viaMethod: o.intersectsFrustum(f) };
      out.direct = o.isSprite ? f.intersectsSprite(o) : f.intersectsObject(o);
      return out;
    }
    case 'frustumArray': {
      const cams = s.cameras.map(buildCamera);
      const array = new THREE.ArrayCamera(cams);
      const fa = new THREE.FrustumArray();
      const out = [];
      const objs = s.nodes.map((n) => { const o = buildNode(n); prepare(n, o); o.updateMatrixWorld(true); return o; });
      for (let r = 0; r < s.rounds; r++) {
        array.cameras = cams.slice(r % cams.length);
        fa.setFromArrayCamera(array);
        out.push([fa._count, objs.map((o) => [o.isSprite ? fa.intersectsSprite(o) : fa.intersectsObject(o), o.intersectsFrustum(fa)]), fa._frustums.map((x) => x.planes.map((p) => [...p.normal.toArray(), p.constant]))]);
      }
      return out;
    }
    case 'batched': {
      const built = buildBatched(s);
      for (const op of s.ops) applyBatchedOp(built, s, op);
      return { out: built.out, state: batchedState(built.mesh) };
    }
  }
}

const results = scenarios.map((s, i) => { try { return run(s); } catch (e) { return { error: String(e) }; } });
fs.writeFileSync(outPath, encodeNumbers(results));
const errors = results.filter((r) => r && r.error);
console.log('upstream ran', results.length, 'errors', errors.length, errors.slice(0, 5).map((e) => e.error));
