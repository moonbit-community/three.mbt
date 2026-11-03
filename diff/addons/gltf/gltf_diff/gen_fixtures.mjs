// Writes synthetic glTF assets to diff/.out/addons_gltf/fixtures (FIXTURES in ../env.mjs;
// run.mjs regenerates them on every run), covering what the example models do not:
// lights, cameras, sparse / interleaved / normalized accessors, line, point, strip and
// fan primitives, CUBICSPLINE / STEP animations, shared meshes, lights and cameras,
// multi-scene reuse, node matrices, pivots, extras, unknown extensions, texture
// transforms and texCoord, samplers, unlit, and the error paths.
import fs from 'node:fs';
import path from 'node:path';
import { upstreamPath } from '../../../lib/env.mjs';
import { FIXTURES as OUT } from '../env.mjs';

fs.mkdirSync(OUT, { recursive: true });

// 1x1 PNGs (different colors) so images hash differently.
const PNG_RED = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==';
const PNG_GREEN = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

class Builder {
  constructor() { this.chunks = []; this.length = 0; this.json = { asset: { version: '2.0', generator: 'a2_gltf fixtures' }, buffers: [], bufferViews: [], accessors: [] }; }
  bytes(u8, align = 4) {
    while (this.length % align) { this.chunks.push(new Uint8Array(1)); this.length++; }
    const off = this.length;
    this.chunks.push(u8); this.length += u8.length;
    return off;
  }
  view(typed, extra = {}) {
    const u8 = new Uint8Array(typed.buffer, typed.byteOffset, typed.byteLength);
    const byteOffset = this.bytes(u8.slice());
    this.json.bufferViews.push({ buffer: 0, byteOffset, byteLength: u8.length, ...extra });
    return this.json.bufferViews.length - 1;
  }
  accessor(typed, type, extra = {}) {
    const ct = { Float32Array: 5126, Uint16Array: 5123, Uint8Array: 5121, Int16Array: 5122, Int8Array: 5120, Uint32Array: 5125 }[typed.constructor.name];
    const size = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT4: 16 }[type];
    const bufferView = this.view(typed);
    const acc = { bufferView, componentType: ct, count: typed.length / size, type, ...extra };
    if (type === 'VEC3' && ct === 5126 && !extra.noMinMax) {
      const min = [Infinity, Infinity, Infinity], max = [-Infinity, -Infinity, -Infinity];
      for (let i = 0; i < typed.length; i += 3) for (let k = 0; k < 3; k++) { min[k] = Math.min(min[k], typed[i + k]); max[k] = Math.max(max[k], typed[i + k]); }
      acc.min = min; acc.max = max;
    }
    delete acc.noMinMax;
    this.json.accessors.push(acc);
    return this.json.accessors.length - 1;
  }
  finish(name, { glb = false } = {}) {
    const bin = new Uint8Array(this.length);
    let o = 0; for (const c of this.chunks) { bin.set(c, o); o += c.length; }
    const json = this.json;
    if (glb) {
      json.buffers = [{ byteLength: bin.length }];
      const jsonText = new TextEncoder().encode(JSON.stringify(json));
      const jl = Math.ceil(jsonText.length / 4) * 4, bl = Math.ceil(bin.length / 4) * 4;
      const out = new Uint8Array(12 + 8 + jl + 8 + bl);
      const dv = new DataView(out.buffer);
      out.set(new TextEncoder().encode('glTF'), 0); dv.setUint32(4, 2, true); dv.setUint32(8, out.length, true);
      dv.setUint32(12, jl, true); dv.setUint32(16, 0x4E4F534A, true); out.fill(0x20, 20, 20 + jl); out.set(jsonText, 20);
      dv.setUint32(20 + jl, bl, true); dv.setUint32(24 + jl, 0x004E4942, true); out.set(bin, 28 + jl);
      fs.writeFileSync(path.join(OUT, name), out);
    } else {
      json.buffers = [{ byteLength: bin.length, uri: 'data:application/octet-stream;base64,' + Buffer.from(bin).toString('base64') }];
      fs.writeFileSync(path.join(OUT, name), JSON.stringify(json, null, 1));
    }
  }
}

const tri = () => new Float32Array([0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0]);

// --- scene_features.gltf: lights, cameras, shared meshes, matrices, pivots, extras --------
{
  const b = new Builder();
  const j = b.json;
  j.extensionsUsed = ['KHR_lights_punctual', 'KHR_materials_unlit', 'KHR_texture_transform', 'KHR_materials_emissive_strength', 'EXT_unknown_test', 'KHR_materials_variants'];
  j.extensionsRequired = ['EXT_unknown_required'];
  j.extensions = { KHR_lights_punctual: { lights: [
    { type: 'directional', color: [1, 0.5, 0.25], intensity: 3, name: 'Sun', extras: { kind: 'dir' } },
    { type: 'point', range: 10, intensity: 2 },
    { type: 'spot', spot: { innerConeAngle: 0.2, outerConeAngle: 0.6 }, name: 'Spot' },
    { type: 'spot' },
  ] }, EXT_unknown_test: { root: true } };
  j.extras = { rootExtra: 1 };
  const pos = b.accessor(tri(), 'VEC3');
  const nrm = b.accessor(new Float32Array([0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]), 'VEC3');
  const uv = b.accessor(new Float32Array([0, 0, 1, 0, 0, 1, 1, 1]), 'VEC2');
  const uv1 = b.accessor(new Float32Array([0, 0, 0.5, 0, 0, 0.5, 0.5, 0.5]), 'VEC2');
  const idx = b.accessor(new Uint16Array([0, 1, 2, 2, 1, 3]), 'SCALAR');
  const strip = b.accessor(new Uint16Array([0, 1, 2, 3]), 'SCALAR');
  const col = b.accessor(new Uint8Array([255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255]), 'VEC4', { normalized: true });
  j.images = [
    { uri: 'data:image/png;base64,' + PNG_RED, name: 'red' },
    { bufferView: b.view(Buffer.from(PNG_GREEN, 'base64')), mimeType: 'image/png' },
    { uri: 'data:image/png;base64,' + PNG_GREEN },
  ];
  j.samplers = [{ magFilter: 9728, minFilter: 9728, wrapS: 33071, wrapT: 33648 }, { minFilter: 9985 }, {}];
  j.textures = [{ source: 0, sampler: 0, name: 'tex0' }, { source: 1, sampler: 1 }, { source: 2 }, { source: 0, sampler: 2 }];
  j.materials = [
    { name: 'unlit', extensions: { KHR_materials_unlit: {} }, pbrMetallicRoughness: { baseColorFactor: [0.5, 0.6, 0.7, 0.8], baseColorTexture: { index: 0 } }, alphaMode: 'BLEND', doubleSided: true, normalTexture: { index: 1 } },
    { name: 'std', pbrMetallicRoughness: { baseColorTexture: { index: 0, texCoord: 1, extensions: { KHR_texture_transform: { offset: [0.1, 0.2], rotation: 0.3, scale: [2, 3] } } }, metallicRoughnessTexture: { index: 2, extensions: { KHR_texture_transform: { texCoord: 1 } } }, metallicFactor: 0.25 },
      normalTexture: { index: 1, scale: 0.5 }, occlusionTexture: { index: 3, strength: 0.7 }, emissiveFactor: [1, 0.5, 0], emissiveTexture: { index: 2, extensions: { KHR_texture_transform: { scale: [1, 1] } } }, alphaMode: 'MASK', alphaCutoff: 0.3,
      extensions: { KHR_materials_emissive_strength: { emissiveStrength: 4 }, EXT_unknown_test: { onMaterial: 1 } }, extras: { m: 'x' } },
    { name: 'mask_default', alphaMode: 'MASK', extras: 'primitive-extras' },
  ];
  j.meshes = [
    { name: 'Tri', primitives: [{ attributes: { POSITION: pos, NORMAL: nrm, TEXCOORD_0: uv, TEXCOORD_1: uv1 }, indices: idx, material: 1, extensions: { EXT_unknown_test: { prim: 1 } } }], extras: { meshExtra: true } },
    { name: 'Multi', primitives: [
      { attributes: { POSITION: pos, COLOR_0: col }, material: 0, mode: 4 },
      { attributes: { POSITION: pos }, mode: 1 },
      { attributes: { POSITION: pos }, mode: 3, material: 2 },
      { attributes: { POSITION: pos }, mode: 2 },
      { attributes: { POSITION: pos }, mode: 0, material: 1 },
      { attributes: { POSITION: pos, NORMAL: nrm }, indices: strip, mode: 5 },
      { attributes: { POSITION: pos, NORMAL: nrm }, indices: strip, mode: 6 },
      { attributes: { POSITION: pos, NORMAL: nrm }, mode: 5 },
    ], extensions: { EXT_unknown_test: { mesh: 1 } } },
    { primitives: [{ attributes: { POSITION: pos, NORMAL: nrm, TEXCOORD_0: uv }, indices: idx }] },
  ];
  j.cameras = [
    { type: 'perspective', perspective: { yfov: 0.8, znear: 0.1, zfar: 100, aspectRatio: 1.5 }, name: 'Persp' },
    { type: 'orthographic', orthographic: { xmag: 2, ymag: 1.5, znear: 0.01, zfar: 50 } },
    { type: 'perspective', perspective: { yfov: 1.0, znear: 0.5 }, extras: { cam: 1 } },
  ];
  j.nodes = [
    { name: 'Root', children: [1, 2, 3, 4, 5, 6, 7, 8, 9], translation: [1, 2, 3], rotation: [0, 0.3826834, 0, 0.9238795], scale: [2, 2, 2], extras: { nodeExtra: [1, 2] }, extensions: { EXT_unknown_test: { node: 1 } } },
    { name: 'TriA', mesh: 0 },
    { name: 'TriB', mesh: 0, matrix: [1, 0, 0, 0, 0, 0, -1, 0, 0, 1, 0, 0, 5, 6, 7, 1] },
    { name: 'Multi', mesh: 1 },
    { name: 'Light A', extensions: { KHR_lights_punctual: { light: 0 } } },
    { name: 'LightB', extensions: { KHR_lights_punctual: { light: 0 } }, translation: [0, 5, 0] },
    { extensions: { KHR_lights_punctual: { light: 1 } } },
    { name: 'SpotNode', extensions: { KHR_lights_punctual: { light: 2 } }, camera: 0, mesh: 2 },
    { name: 'Cam', camera: 1, children: [10] },
    { name: 'Pivot', translation: [3, 3, 3], extras: { pivot: [1, 1, 1] }, children: [11] },
    { name: 'Cam', camera: 0, extensions: { KHR_lights_punctual: { light: 3 } } },
    { name: 'PivotChild', translation: [-1, -1, -1], mesh: 2 },
    { name: 'Orphan', mesh: 2 },
    { name: 'Root', camera: 2 },
  ];
  j.scenes = [{ name: 'Main', nodes: [0, 13], extras: { s: 1 } }, { name: 'Main', nodes: [3, 12], extensions: { EXT_unknown_test: { scene: 2 } } }];
  j.scene = 1;
  b.finish('scene_features.gltf');
}

// --- accessors.glb: sparse, interleaved, normalized, morph targets, skins, animations --------
{
  const b = new Builder();
  const j = b.json;
  j.extensionsUsed = ['KHR_mesh_quantization'];
  // Interleaved position(3f)+uv(2f) stride 20, two slices.
  const n = 6;
  const inter = new Float32Array(n * 5 * 2);
  for (let i = 0; i < inter.length; i++) inter[i] = Math.sin(i * 0.7) * 3;
  const iv = b.view(inter, { byteStride: 20 });
  const P = j.accessors.push({ bufferView: iv, componentType: 5126, count: n, type: 'VEC3', min: [-3, -3, -3], max: [3, 3, 3] }) - 1;
  const UV = j.accessors.push({ bufferView: iv, byteOffset: 12, componentType: 5126, count: n, type: 'VEC2' }) - 1;
  const P2 = j.accessors.push({ bufferView: iv, byteOffset: 20 * n, componentType: 5126, count: n, type: 'VEC3', min: [-3, -3, -3], max: [3, 3, 3] }) - 1;
  // Quantized normals (Int8 normalized, padded to 4 bytes stride).
  const qn = new Int8Array(n * 4); for (let i = 0; i < qn.length; i++) qn[i] = (i * 37) % 255 - 127;
  const qv = b.view(qn, { byteStride: 4 });
  const N = j.accessors.push({ bufferView: qv, componentType: 5120, normalized: true, count: n, type: 'VEC3' }) - 1;
  // Quantized positions (Uint16 normalized) with min/max.
  const qp = new Uint16Array(n * 3); for (let i = 0; i < qp.length; i++) qp[i] = (i * 9973) % 65535;
  const QP = b.accessor(qp, 'VEC3', { normalized: true, min: [0, 0, 0], max: [60000, 60000, 60000] });
  // Sparse: with base bufferView and without.
  const sIdx = b.view(new Uint16Array([1, 4]));
  const sVal = b.view(new Float32Array([9, 9, 9, 8, 8, 8]));
  const SP = j.accessors.push({ bufferView: b.view(new Float32Array(n * 3).fill(1)), componentType: 5126, count: n, type: 'VEC3', min: [1, 1, 1], max: [9, 9, 9], sparse: { count: 2, indices: { bufferView: sIdx, componentType: 5123 }, values: { bufferView: sVal } } }) - 1;
  const SP0 = j.accessors.push({ componentType: 5126, count: n, type: 'VEC3', sparse: { count: 2, indices: { bufferView: sIdx, componentType: 5123 }, values: { bufferView: sVal } } }) - 1;
  const EMPTY = j.accessors.push({ componentType: 5126, count: n, type: 'VEC3' }) - 1;
  // Morph targets (no min/max on one).
  const MT0 = b.accessor(new Float32Array(n * 3).map((_, i) => i * 0.01), 'VEC3');
  const MT1 = b.accessor(new Float32Array(n * 3).map((_, i) => -i * 0.02), 'VEC3', { noMinMax: true });
  const MC = b.accessor(new Float32Array(n * 4).fill(0.5), 'VEC4');
  // Skin.
  const J = b.accessor(new Uint8Array(n * 4).map((_, i) => (i % 4 === 0 ? 1 : 0)), 'VEC4');
  const W = b.accessor(new Float32Array(n * 4).map((_, i) => (i % 4 === 0 ? 0.6 : i % 4 === 1 ? 0.6 : 0)), 'VEC4');
  const ibm = new Float32Array(32); ibm.set([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0.5, 0, 0, 1]); ibm.set([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, -1, 0, 1], 16);
  const IBM = b.accessor(ibm, 'MAT4');
  // Animations.
  const T = b.accessor(new Float32Array([0, 0.5, 1.25, 2]), 'SCALAR');
  const TR = b.accessor(new Float32Array(4 * 3 * 3).map((_, i) => Math.cos(i)), 'VEC3');
  const RO = b.accessor(new Float32Array(4 * 3 * 4).map((_, i) => Math.sin(i + 1)), 'VEC4');
  const SC = b.accessor(new Float32Array([1, 1, 1, 2, 2, 2, 3, 3, 3, 1, 1, 1]), 'VEC3');
  const WT = b.accessor(new Float32Array([0, 1, 0.5, 0.5, 1, 0, 0.25, 0.75]), 'SCALAR');
  const WQ = b.accessor(new Uint8Array([0, 255, 128, 64, 255, 0, 10, 20]), 'SCALAR', { normalized: true });
  const RQ = b.accessor(new Int16Array([0, 0, 0, 32767, 0, 23170, 0, 23170, 0, 32767, 0, 0, 0, 0, 0, 32767]), 'VEC4', { normalized: true });
  j.meshes = [
    { name: 'Morph', primitives: [{ attributes: { POSITION: P, TEXCOORD_0: UV, NORMAL: N }, targets: [{ POSITION: MT0, COLOR_0: MC }, { POSITION: MT1, NORMAL: N }], material: 0 }], weights: [0.25, 0.5], extras: { targetNames: ['a', 'b'] } },
    { name: 'Morph', primitives: [{ attributes: { POSITION: P2, NORMAL: N }, targets: [{ POSITION: MT0 }] }, { attributes: { POSITION: P2 }, targets: [{ POSITION: MT1 }] }], extras: { targetNames: ['only'] , other: 2 } },
    { name: 'Quant', primitives: [{ attributes: { POSITION: QP, NORMAL: N } }, { attributes: { POSITION: SP } }, { attributes: { POSITION: SP0 } }, { attributes: { POSITION: EMPTY } }] },
    { name: 'Skinned', primitives: [{ attributes: { POSITION: P, JOINTS_0: J, WEIGHTS_0: W } }] },
    { name: 'NoSkinAttrs', primitives: [{ attributes: { POSITION: P } }] },
  ];
  j.materials = [{ name: 'm', pbrMetallicRoughness: { baseColorFactor: [1, 0, 0, 1] } }];
  j.skins = [{ joints: [3, 4], inverseBindMatrices: IBM, skeleton: 3 }, { joints: [4, 3] }];
  j.nodes = [
    { name: 'morph', mesh: 0, weights: [0.75, 0.125] },
    { name: 'morph2', mesh: 1 },
    { name: 'quant', mesh: 2 },
    { name: 'bone0', children: [4], translation: [0, 1, 0] },
    { name: 'bone1', translation: [0, 1, 0] },
    { name: 'skinned', mesh: 3, skin: 0 },
    { name: 'skinned2', mesh: 4, skin: 1 },
    { name: 'morph', mesh: 0 },
  ];
  j.animations = [
    { name: 'cubic', channels: [{ sampler: 0, target: { node: 3, path: 'translation' } }, { sampler: 1, target: { node: 4, path: 'rotation' } }, { sampler: 2, target: { node: 0, path: 'weights' } }, { sampler: 3, target: { path: 'scale' } }],
      samplers: [{ input: T, output: TR, interpolation: 'CUBICSPLINE' }, { input: T, output: RO, interpolation: 'CUBICSPLINE' }, { input: T, output: WT }, { input: T, output: SC }], extras: { clip: 1 } },
    { channels: [{ sampler: 0, target: { node: 3, path: 'scale' } }, { sampler: 1, target: { node: 1, path: 'weights' } }, { sampler: 2, target: { node: 4, path: 'rotation' } }, { sampler: 3, target: { node: 7, path: 'pointer' } }],
      samplers: [{ input: T, output: SC, interpolation: 'STEP' }, { input: T, output: WQ, interpolation: 'LINEAR' }, { input: T, output: RQ }, { input: T, output: WT }] },
  ];
  j.scenes = [{ nodes: [0, 1, 2, 3, 5, 6, 7] }];
  b.finish('accessors.glb', { glb: true });
}


// --- materials_edge.gltf: ior 0, sheen color texture, normalized sparse ------------------
{
  const b = new Builder();
  const j = b.json;
  j.extensionsUsed = ['KHR_materials_ior', 'KHR_materials_sheen', 'KHR_materials_specular', 'KHR_materials_clearcoat', 'KHR_materials_iridescence', 'KHR_materials_anisotropy', 'EXT_materials_bump', 'KHR_materials_dispersion', 'KHR_materials_diffuse_roughness', 'KHR_materials_transmission', 'KHR_materials_volume'];
  const pos = b.accessor(tri(), 'VEC3');
  const base = b.view(new Uint8Array([10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160]));
  const sIdx = b.view(new Uint8Array([2, 0, 0, 0]));
  const sVal = b.view(new Uint8Array([255, 128, 0, 64]));
  const COL = j.accessors.push({ bufferView: base, componentType: 5121, normalized: true, count: 4, type: 'VEC4', sparse: { count: 1, indices: { bufferView: sIdx, componentType: 5121 }, values: { bufferView: sVal } } }) - 1;
  j.images = [{ uri: 'data:image/png;base64,' + PNG_RED }, { uri: 'data:image/png;base64,' + PNG_GREEN }];
  j.textures = [{ source: 0 }, { source: 1 }];
  j.materials = [
    { name: 'ior0', extensions: { KHR_materials_ior: { ior: 0 } } },
    { name: 'iorDefault', extensions: { KHR_materials_ior: {} } },
    { name: 'sheen', extensions: { KHR_materials_sheen: { sheenColorFactor: [0.1, 0.2, 0.3], sheenColorTexture: { index: 1 }, sheenRoughnessFactor: 0.4, sheenRoughnessTexture: { index: 0 } } } },
    { name: 'spec', extensions: { KHR_materials_specular: { specularFactor: 0.3, specularColorFactor: [0.5, 0.5, 1], specularTexture: { index: 0 } } } },
    { name: 'all', extensions: { KHR_materials_clearcoat: { clearcoatFactor: 0.5, clearcoatRoughnessFactor: 0.25, clearcoatNormalTexture: { index: 0, scale: 0.3 } },
      KHR_materials_iridescence: { iridescenceFactor: 1, iridescenceIor: 1.8, iridescenceThicknessMinimum: 50, iridescenceThicknessMaximum: 300, iridescenceThicknessTexture: { index: 0 } },
      KHR_materials_anisotropy: { anisotropyStrength: 0.6, anisotropyRotation: 1.2, anisotropyTexture: { index: 0 } }, EXT_materials_bump: { bumpFactor: 2, bumpTexture: { index: 0 } },
      KHR_materials_dispersion: { dispersion: 0.1 }, KHR_materials_diffuse_roughness: { diffuseRoughnessFactor: 0.7 }, KHR_materials_transmission: { transmissionFactor: 0.9 },
      KHR_materials_volume: { thicknessFactor: 2, attenuationDistance: 3, attenuationColor: [1, 0.5, 0.25] } } },
    { name: 'empty_ext', extensions: { KHR_materials_volume: {}, KHR_materials_dispersion: {}, KHR_materials_diffuse_roughness: {}, KHR_materials_specular: {} } },
  ];
  j.meshes = [{ primitives: j.materials.map((_, i) => ({ attributes: { POSITION: pos, COLOR_0: COL }, material: i })) }];
  j.nodes = [{ mesh: 0 }];
  j.scenes = [{ nodes: [0] }];
  b.finish('materials_edge.gltf');
}

// --- duck_normalized.glb: duck.glb with a normalized Draco TEXCOORD_0 accessor ----------
{
  const src = fs.readFileSync(upstreamPath('examples/models/gltf/duck.glb'));
  const jl = src.readUInt32LE(12);
  const json = JSON.parse(src.subarray(20, 20 + jl).toString());
  const prim = json.meshes[0].primitives[0];
  json.accessors[prim.attributes.TEXCOORD_0].normalized = true;
  const rest = src.subarray(20 + jl);
  let text = Buffer.from(JSON.stringify(json));
  const pad = Math.ceil(text.length / 4) * 4;
  text = Buffer.concat([text, Buffer.alloc(pad - text.length, 0x20)]);
  const header = Buffer.alloc(20);
  header.write('glTF'); header.writeUInt32LE(2, 4); header.writeUInt32LE(20 + pad + rest.length, 8);
  header.writeUInt32LE(pad, 12); header.writeUInt32LE(0x4E4F534A, 16);
  fs.writeFileSync(path.join(OUT, 'duck_normalized.glb'), Buffer.concat([header, text, rest]));
}

// --- error and edge fixtures ------------------------------------------------------------
fs.writeFileSync(path.join(OUT, 'old_version.gltf'), JSON.stringify({ asset: { version: '1.0' } }));
fs.writeFileSync(path.join(OUT, 'no_scenes.gltf'), JSON.stringify({ asset: { version: '2.0' }, extensionsUsed: ['KHR_draco_mesh_compression', 'EXT_required_missing'], extensionsRequired: ['EXT_required_missing'] }));
fs.writeFileSync(path.join(OUT, 'bad_light.gltf'), JSON.stringify({ asset: { version: '2.0' }, extensionsUsed: ['KHR_lights_punctual'], extensions: { KHR_lights_punctual: { lights: [{ type: 'area' }] } }, nodes: [{ extensions: { KHR_lights_punctual: { light: 0 } } }], scenes: [{ nodes: [0] }] }));
fs.writeFileSync(path.join(OUT, 'missing_buffer.gltf'), JSON.stringify({ asset: { version: '2.0' }, buffers: [{ uri: 'nope.bin', byteLength: 12 }], bufferViews: [{ buffer: 0, byteLength: 12 }], accessors: [{ bufferView: 0, componentType: 5126, count: 1, type: 'VEC3' }], meshes: [{ primitives: [{ attributes: { POSITION: 0 } }] }], nodes: [{ mesh: 0 }], scenes: [{ nodes: [0] }] }));
fs.writeFileSync(path.join(OUT, 'missing_image.gltf'), JSON.stringify({ asset: { version: '2.0' }, images: [{ uri: 'nope.png' }, { uri: 'x.jpg?x=1' }], textures: [{ source: 0 }, { source: 1 }], materials: [{ pbrMetallicRoughness: { baseColorTexture: { index: 0 } }, emissiveTexture: { index: 1 } }], meshes: [{ primitives: [{ attributes: {}, material: 0 }] }], nodes: [{ mesh: 0 }], scenes: [{ nodes: [0] }] }));
fs.writeFileSync(path.join(OUT, 'bad_header.glb'), Buffer.concat([Buffer.from('glTF'), Buffer.from([1, 0, 0, 0, 20, 0, 0, 0])]));
const empty = Buffer.alloc(12); empty.write('glTF'); empty.writeUInt32LE(2, 4); empty.writeUInt32LE(12, 8);
fs.writeFileSync(path.join(OUT, 'no_json.glb'), empty);
fs.writeFileSync(path.join(OUT, 'basisu_required_nodeps.gltf'), JSON.stringify({ asset: { version: '2.0' }, extensionsUsed: ['KHR_texture_basisu'], extensionsRequired: ['KHR_texture_basisu'], images: [{ uri: 'a.ktx2' }], textures: [{ source: 0, extensions: { KHR_texture_basisu: { source: 0 } } }], materials: [{ pbrMetallicRoughness: { baseColorTexture: { index: 0 } } }], meshes: [{ primitives: [{ attributes: {}, material: 0 }] }], nodes: [{ mesh: 0 }], scenes: [{ nodes: [0] }] }));
fs.copyFileSync(path.join(OUT, 'no_scenes.gltf'), path.join(OUT, 'no_scenes_nodeps.gltf'));
if (process.argv.includes('--verbose')) console.log('fixtures written to', OUT, fs.readdirSync(OUT));
