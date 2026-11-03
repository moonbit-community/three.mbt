// Dumps an upstream GLTFLoader result into the canonical JSON the MoonBit side
// (src/harness/dump.mbt) also writes. Keep the two in sync field by field.
import { fnv } from '../env.mjs';

export function hashView(a) {
  if (!a) return null;
  return fnv(new Uint8Array(a.buffer, a.byteOffset, a.byteLength));
}

const r = (v) => (v === undefined ? null : v);
const vec = (v, keys) => keys.map((k) => v[k]);

function texImage(image) {
  if (image === null || image === undefined) return null;
  if (image.__bitmap) return { kind: 'bitmap', width: image.width, height: image.height, hash: image.hash };
  if (Array.isArray(image)) return { kind: 'array', items: image.map(texImage) };
  if (image.isTexture) return { kind: 'texture' };
  return { kind: 'data', width: r(image.width), height: r(image.height), depth: r(image.depth), data: image.data ? [image.data.constructor.name, image.data.length, hashView(image.data)] : null };
}

export function dumpGLTF(T, gltf) {
  const ids = { obj: new Map(), geo: new Map(), mat: new Map(), tex: new Map(), attr: new Map(), ib: new Map(), skel: new Map(), src: new Map() };
  const out = { objects: [], geometries: [], materials: [], textures: [], skeletons: [], attributes: [], interleaved: [] };
  const id = (kind, o, f) => {
    const m = ids[kind];
    if (m.has(o)) return m.get(o);
    const i = m.size;
    m.set(o, i);
    f(o, i);
    return i;
  };
  const attrId = (a) => id('attr', a, (a, i) => { out.attributes[i] = null; out.attributes[i] = attrDump(a); });
  const ibId = (ib) => id('ib', ib, (ib, i) => {
    out.interleaved[i] = { stride: ib.stride, count: ib.count, usage: ib.usage, instanced: ib.isInstancedInterleavedBuffer === true, meshPerAttribute: r(ib.meshPerAttribute), type: ib.array.constructor.name, length: ib.array.length, hash: hashView(ib.array) };
  });
  function attrDump(a) {
    if (a.isInterleavedBufferAttribute) {
      return { kind: 'interleaved', name: a.name, itemSize: a.itemSize, offset: a.offset, normalized: a.normalized, count: a.count, data: ibId(a.data) };
    }
    return {
      kind: a.isInstancedBufferAttribute ? 'instanced' : 'buffer', name: a.name, itemSize: a.itemSize, normalized: a.normalized,
      count: a.count, usage: a.usage, gpuType: a.gpuType, meshPerAttribute: a.isInstancedBufferAttribute ? a.meshPerAttribute : null,
      type: a.array.constructor.name, length: a.array.length, hash: hashView(a.array),
    };
  }
  const texId = (t) => (t ? id('tex', t, (t, i) => { out.textures[i] = null; out.textures[i] = texDump(t); }) : null);
  function texDump(t) {
    return {
      class: t.constructor.name, uuid: t.uuid, name: t.name, channel: t.channel, mapping: t.mapping,
      offset: vec(t.offset, ['x', 'y']), repeat: vec(t.repeat, ['x', 'y']), center: vec(t.center, ['x', 'y']), rotation: t.rotation,
      matrixAutoUpdate: t.matrixAutoUpdate, matrix: Array.from(t.matrix.elements),
      wrapS: t.wrapS, wrapT: t.wrapT, magFilter: t.magFilter, minFilter: t.minFilter, anisotropy: t.anisotropy,
      format: t.format, type: t.type, internalFormat: r(t.internalFormat), colorSpace: t.colorSpace, flipY: t.flipY,
      generateMipmaps: t.generateMipmaps, premultiplyAlpha: t.premultiplyAlpha, unpackAlignment: t.unpackAlignment,
      version: t.version, userData: JSON.stringify(t.userData), source: id('src', t.source, () => {}), sourceVersion: t.source.version,
      image: texImage(t.image), mipmaps: (t.mipmaps || []).map(texImage),
    };
  }
  const MAPS = ['map', 'lightMap', 'aoMap', 'emissiveMap', 'bumpMap', 'normalMap', 'displacementMap', 'roughnessMap', 'metalnessMap',
    'alphaMap', 'envMap', 'clearcoatMap', 'clearcoatRoughnessMap', 'clearcoatNormalMap', 'iridescenceMap', 'iridescenceThicknessMap',
    'sheenColorMap', 'sheenRoughnessMap', 'transmissionMap', 'thicknessMap', 'specularIntensityMap', 'specularColorMap',
    'anisotropyMap', 'diffuseRoughnessMap', 'specularMap'];
  const matId = (m) => id('mat', m, (m, i) => { out.materials[i] = null; out.materials[i] = matDump(m); });
  function matDump(m) {
    const maps = {};
    for (const k of MAPS) if (m[k]) maps[k] = texId(m[k]);
    const json = m.toJSON({ geometries: {}, materials: {}, textures: {}, images: {}, shapes: {}, skeletons: {}, animations: {}, nodes: {} });
    return {
      type: m.type, uuid: m.uuid, name: m.name, version: m.version, maps, json: JSON.stringify(json),
      normalScale: m.normalScale ? vec(m.normalScale, ['x', 'y']) : null,
      clearcoatNormalScale: m.clearcoatNormalScale ? vec(m.clearcoatNormalScale, ['x', 'y']) : null,
      flatShading: r(m.flatShading), vertexColors: m.vertexColors, sizeAttenuation: r(m.sizeAttenuation),
      userData: JSON.stringify(m.userData),
    };
  }
  const geoId = (g) => id('geo', g, (g, i) => { out.geometries[i] = null; out.geometries[i] = geoDump(g); });
  function geoDump(g) {
    const attributes = Object.keys(g.attributes).map((k) => [k, attrId(g.attributes[k])]);
    const morph = Object.keys(g.morphAttributes).map((k) => [k, g.morphAttributes[k].map((a) => (a ? attrId(a) : null))]);
    return {
      type: g.type, uuid: g.uuid, name: g.name, attributes, index: g.index ? attrId(g.index) : null, morph,
      morphTargetsRelative: g.morphTargetsRelative, groups: g.groups.map((x) => [x.start, x.count, r(x.materialIndex)]),
      drawRange: [g.drawRange.start, g.drawRange.count],
      boundingBox: g.boundingBox ? [...vec(g.boundingBox.min, ['x', 'y', 'z']), ...vec(g.boundingBox.max, ['x', 'y', 'z'])] : null,
      boundingSphere: g.boundingSphere ? [...vec(g.boundingSphere.center, ['x', 'y', 'z']), g.boundingSphere.radius] : null,
      userData: JSON.stringify(g.userData),
    };
  }
  const skelId = (s) => id('skel', s, (s, i) => {
    out.skeletons[i] = null;
    out.skeletons[i] = { uuid: s.uuid, bones: s.bones.map((b) => objId(b)), boneInverses: s.boneInverses.map((m) => Array.from(m.elements)) };
  });
  const objId = (o) => id('obj', o, (o, i) => { out.objects[i] = null; out.objects[i] = objDump(o); });
  function objDump(o) {
    const d = {
      type: o.type, name: o.name, uuid: o.uuid, parent: null, children: [],
      position: vec(o.position, ['x', 'y', 'z']), quaternion: vec(o.quaternion, ['x', 'y', 'z', 'w']), scale: vec(o.scale, ['x', 'y', 'z']),
      rotation: [o.rotation.x, o.rotation.y, o.rotation.z, o.rotation.order], up: vec(o.up, ['x', 'y', 'z']),
      matrix: Array.from(o.matrix.elements), matrixWorld: Array.from(o.matrixWorld.elements), matrixAutoUpdate: o.matrixAutoUpdate,
      visible: o.visible, castShadow: o.castShadow, receiveShadow: o.receiveShadow, frustumCulled: o.frustumCulled, renderOrder: o.renderOrder,
      layers: o.layers.mask, userData: JSON.stringify(o.userData), pivot: o.pivot ? vec(o.pivot, ['x', 'y', 'z']) : null,
    };
    if (o.isMesh || o.isLine || o.isPoints) {
      d.geometry = geoId(o.geometry);
      d.material = Array.isArray(o.material) ? o.material.map(matId) : matId(o.material);
      d.morphTargetInfluences = o.morphTargetInfluences ? Array.from(o.morphTargetInfluences) : null;
      d.morphTargetDictionary = o.morphTargetDictionary ? Object.entries(o.morphTargetDictionary).sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0)) : null;
    }
    if (o.isSkinnedMesh) {
      d.bindMode = o.bindMode; d.bindMatrix = Array.from(o.bindMatrix.elements); d.bindMatrixInverse = Array.from(o.bindMatrixInverse.elements);
      d.skeleton = o.skeleton ? skelId(o.skeleton) : null;
    }
    if (o.isInstancedMesh) {
      d.count = o.count; d.instanceMatrix = attrId(o.instanceMatrix); d.instanceColor = o.instanceColor ? attrId(o.instanceColor) : null;
    }
    if (o.isPerspectiveCamera) {
      d.camera = ['perspective', o.fov, o.aspect, o.near, o.far, o.zoom, o.focus, o.filmGauge, o.filmOffset, Array.from(o.projectionMatrix.elements)];
    } else if (o.isOrthographicCamera) {
      d.camera = ['orthographic', o.left, o.right, o.top, o.bottom, o.near, o.far, o.zoom, Array.from(o.projectionMatrix.elements)];
    }
    if (o.isLight) {
      d.light = [vec(o.color, ['r', 'g', 'b']), o.intensity, r(o.distance), r(o.decay), r(o.angle), r(o.penumbra)];
    }
    return d;
  }
  function visit(o) {
    const i = objId(o);
    out.objects[i].parent = o.parent ? objId(o.parent) : null;
    out.objects[i].children = o.children.map((c) => visit(c));
    if (o.target && o.isLight) out.objects[i].target = objId(o.target);
    return i;
  }
  const result = {};
  result.scenes = gltf.scenes.map((s) => visit(s));
  result.scene = gltf.scene ? objId(gltf.scene) : null;
  result.cameras = gltf.cameras.map((c) => (c ? visit(c) : null));
  result.animations = gltf.animations.map((clip) => ({
    uuid: clip.uuid, name: clip.name, duration: clip.duration, blendMode: clip.blendMode, userData: JSON.stringify(clip.userData),
    tracks: clip.tracks.map((t) => {
      const interp = t.createInterpolant();
      const n = t.times.length;
      const ts = n ? [t.times[0] - 0.1, t.times[0], (t.times[0] + t.times[n - 1]) / 2, t.times[Math.floor(n / 3)] * 0.75 + t.times[n - 1] * 0.25, t.times[n - 1], t.times[n - 1] + 1] : [];
      return {
        name: t.name, valueTypeName: t.ValueTypeName, times: [t.times.constructor.name, n, hashView(t.times)],
        values: [t.values.constructor.name, t.values.length, hashView(t.values)], interpolation: r(t.getInterpolation()),
        cubic: t.createInterpolant.isInterpolantFactoryMethodGLTFCubicSpline === true,
        samples: ts.map((x) => Array.from(interp.evaluate(x))),
      };
    }),
  }));
  result.associations = [];
  for (const [key, value] of gltf.parser.associations) {
    const kind = key.isMaterial ? 'material' : key.isTexture ? 'texture' : 'object';
    const kid = kind === 'material' ? matId(key) : kind === 'texture' ? texId(key) : objId(key);
    const ref = value ? Object.keys(value).sort().map((k) => [k, value[k]]) : null;
    result.associations.push([kind, kid, ref]);
  }
  result.extensionsUsed = r(gltf.parser.json.extensionsUsed);
  result.userData = JSON.stringify(gltf.userData);
  result.asset = JSON.stringify(gltf.asset);
  Object.assign(result, out);
  return result;
}
