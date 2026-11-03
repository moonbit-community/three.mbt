// Differential checks of JSON number writing and of constructor uuid/id order.
//
//   node run.mjs [--no-build] [--only substring]
//
// 1. fresh: each class built with its defaults, with Math.random reseeded identically
//    on both sides. Compares, for the object and every object it creates (geometry,
//    material, light target, shadow camera, children, texture source, ...), the uuid it
//    drew and its id relative to the id counter, plus `toJSON()` text where the class has
//    one. A constructor that draws uuids in another order than upstream shows up here.
// 2. nonfinite: the scenes of ../loaders/nonfinite_fixtures.mjs (numeric fields set
//    to Infinity, -Infinity, NaN), built on both sides; `JSON.stringify(o.toJSON())`
//    against the port's `to_json().stringify()`, byte for byte (uuids included). The port
//    text must also be valid JSON.
// 3. roundtrip: upstream's text of each nonfinite scene read back by ObjectLoader on both
//    sides and written again (readers must accept null as upstream does).
import { execSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { nonfiniteBuilders } from '../loaders/nonfinite_fixtures.mjs';
import { upstreamURL } from '../../lib/env.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const only = args.includes('--only') ? args[args.indexOf('--only') + 1] : null;
if (!args.includes('--no-build')) {
  try { execSync('moon build --target js', { cwd: here, stdio: 'pipe' }); }
  catch (e) { console.log('BUILD FAILED\n' + String(e.stdout).split('\n').filter((l) => /Error|error/.test(l)).slice(0, 20).join('\n')); process.exit(2); }
}
const M = await import(pathToFileURL(path.join(here, '_build/js/debug/build/moonbit-community/three-diff-json-uuid/main/main.js')).href);
const SRC = upstreamURL('src') + '/';
const T = await import(SRC + 'Three.js');
const { ClippingGroup } = await import(SRC + 'objects/ClippingGroup.js');
const { default: IESSpotLight } = await import(SRC + 'lights/webgpu/IESSpotLight.js');
const { default: ProjectorLight } = await import(SRC + 'lights/webgpu/ProjectorLight.js');
const { ExternalTexture } = await import(SRC + 'textures/ExternalTexture.js');
const { CubeDepthTexture } = await import(SRC + 'textures/CubeDepthTexture.js').catch(() => ({}));
console.warn = console.error = () => {};

let seed = 0;
function reseed(s) {
  seed = s >>> 0;
  Math.random = () => {
    seed = (seed + 0x6D2B79F5) >>> 0;
    let t = seed;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

let passed = 0, failed = 0;
function compare(name, expected, actual) {
  if (expected === actual) { passed++; return true; }
  failed++;
  let i = 0;
  while (i < expected.length && expected[i] === actual[i]) i++;
  console.log(`MISMATCH ${name} at char ${i} (upstream ${expected.length}, port ${actual.length})`);
  console.log('  up: ' + expected.slice(Math.max(0, i - 150), i + 150));
  console.log('  mb: ' + actual.slice(Math.max(0, i - 150), i + 150));
  return false;
}
function guarded(name, f) {
  try { return f(); } catch (e) { failed++; console.log(`ERROR ${name}: ${e && e.stack ? e.stack.split('\n').slice(0, 3).join(' | ') : e}`); return undefined; }
}

// 1. fresh
const base = () => ({ o: new T.Object3D().id + 1, g: new T.BufferGeometry().id + 1, m: new T.Material().id + 1, t: new T.Texture().id + 1, s: new T.Source().id + 1 });
const entry = (p, uuid, id) => [p, uuid, id];
function probeTexture(t, p, b, out) { out.push(entry(p, t.uuid, t.id - b.t)); out.push(entry(p + '.source', t.source.uuid, t.source.id - b.s)); }
function probeMaterial(m, p, b, out) {
  if (Array.isArray(m)) m.forEach((x, i) => out.push(entry(`${p}[${i}]`, x.uuid, x.id - b.m)));
  else out.push(entry(p, m.uuid, m.id - b.m));
}
function probeObject(o, p, b, out) {
  out.push(entry(p, o.uuid, o.id - b.o));
  if (o.geometry) out.push(entry(p + '.geometry', o.geometry.uuid, o.geometry.id - b.g));
  if (o.material) probeMaterial(o.material, p + '.material', b, out);
  if (o.isLight) {
    if (o.target) probeObject(o.target, p + '.target', b, out);
    if (o.shadow) probeObject(o.shadow.camera, p + '.shadow.camera', b, out);
  }
  o.children.forEach((c, i) => probeObject(c, `${p}.children[${i}]`, b, out));
}
const F = {
  Object3D: () => ['O', new T.Object3D()], Group: () => ['O', new T.Group()], Bone: () => ['O', new T.Bone()],
  Scene: () => ['O', new T.Scene()], LOD: () => ['O', new T.LOD()], ClippingGroup: () => ['O', new ClippingGroup()],
  Mesh: () => ['O', new T.Mesh()], Line: () => ['O', new T.Line()], LineSegments: () => ['O', new T.LineSegments()],
  LineLoop: () => ['O', new T.LineLoop()], Points: () => ['O', new T.Points()],
  Sprite: () => ['O', new T.Sprite()], Sprite2: () => ['O', new T.Sprite()],
  SkinnedMesh: () => ['O', new T.SkinnedMesh()], InstancedMesh: () => ['O', new T.InstancedMesh(undefined, undefined, 2)],
  BatchedMesh: () => ['O', new T.BatchedMesh(4, 10, 20)],
  Camera: () => ['O', new T.Camera()], PerspectiveCamera: () => ['O', new T.PerspectiveCamera()],
  OrthographicCamera: () => ['O', new T.OrthographicCamera()], ArrayCamera: () => ['O', new T.ArrayCamera()],
  CubeCamera: () => { const rt = new T.RenderTarget(4, 4); return ['O', new T.CubeCamera(0.1, 2000, rt)]; },
  StereoCamera: () => ['Stereo', new T.StereoCamera()],
  Light: () => ['O', new T.Light()], AmbientLight: () => ['O', new T.AmbientLight()],
  DirectionalLight: () => ['O', new T.DirectionalLight()], HemisphereLight: () => ['O', new T.HemisphereLight()],
  PointLight: () => ['O', new T.PointLight()], SpotLight: () => ['O', new T.SpotLight()],
  RectAreaLight: () => ['O', new T.RectAreaLight()], LightProbe: () => ['O', new T.LightProbe()],
  IESSpotLight: () => ['O', new IESSpotLight()], ProjectorLight: () => ['O', new ProjectorLight()],
  BufferGeometry: () => ['G', new T.BufferGeometry()], InstancedBufferGeometry: () => ['G', new T.InstancedBufferGeometry()],
  InterleavedBuffer: () => ['IB', new T.InterleavedBuffer(new Float32Array(6), 3)],
  InstancedInterleavedBuffer: () => ['IB', new T.InstancedInterleavedBuffer(new Float32Array(6), 3)],
  Skeleton: () => ['Skel', new T.Skeleton([new T.Bone(), new T.Bone()])],
};
for (const m of ['Material', 'LineBasicMaterial', 'LineDashedMaterial', 'MeshBasicMaterial', 'MeshDepthMaterial', 'MeshDistanceMaterial', 'MeshLambertMaterial', 'MeshMatcapMaterial', 'MeshNormalMaterial', 'MeshPhongMaterial', 'MeshPhysicalMaterial', 'MeshStandardMaterial', 'MeshToonMaterial', 'PointsMaterial', 'RawShaderMaterial', 'ShaderMaterial', 'ShadowMaterial', 'SpriteMaterial']) F[m] = () => ['M', new T[m]()];
Object.assign(F, {
  Texture: () => ['T', new T.Texture()], DataTexture: () => ['T', new T.DataTexture()], Data3DTexture: () => ['T', new T.Data3DTexture()],
  DataArrayTexture: () => ['T', new T.DataArrayTexture()], CubeTexture: () => ['T', new T.CubeTexture()],
  CompressedTexture: () => ['T', new T.CompressedTexture()], CompressedArrayTexture: () => ['T', new T.CompressedArrayTexture()],
  DepthTexture: () => ['T', new T.DepthTexture(4, 4)], CubeDepthTexture: () => ['T', new (CubeDepthTexture || T.CubeDepthTexture)(4)],
  FramebufferTexture: () => ['T', new T.FramebufferTexture(4, 4)], CanvasTexture: () => ['T', new T.CanvasTexture()],
  VideoFrameTexture: () => ['T', new T.VideoFrameTexture()], ExternalTexture: () => ['T', new ExternalTexture()],
  RenderTarget: () => ['RT', new T.RenderTarget(4, 4)], RenderTarget3D: () => ['RT', new T.RenderTarget3D(4, 4, 2)],
});
for (const g of ['Box', 'Capsule', 'Circle', 'Cone', 'Cylinder', 'Dodecahedron', 'Edges', 'Extrude', 'Icosahedron', 'Lathe', 'Octahedron', 'Plane', 'Polyhedron', 'Ring', 'Shape', 'Sphere', 'Tetrahedron', 'Torus', 'TorusKnot', 'Tube', 'Wireframe']) F[g + 'Geometry'] = () => ['G', new T[g + 'Geometry']()];
F.Shape = () => ['Shape', new T.Shape()];
F.AnimationClip = () => ['Clip', new T.AnimationClip('c')];

function upstreamFresh(name, s) {
  const b = base();
  reseed(s);
  const [kind, x] = F[name]();
  const out = [];
  let json = null;
  switch (kind) {
    case 'O': probeObject(x, '', b, out); json = x.toJSON(); break;
    case 'G': out.push(entry('', x.uuid, x.id - b.g)); json = x.toJSON(); break;
    case 'M': probeMaterial(x, '', b, out); json = x.toJSON(); break;
    case 'T': probeTexture(x, '', b, out); break;
    case 'RT': x.textures.forEach((t, i) => probeTexture(t, `.textures[${i}]`, b, out)); if (x.depthTexture) probeTexture(x.depthTexture, '.depthTexture', b, out); break;
    case 'Stereo': probeObject(x.cameraL, '.cameraL', b, out); probeObject(x.cameraR, '.cameraR', b, out); break;
    case 'Skel': out.push(entry('', x.uuid, 0)); x.bones.forEach((bone, i) => probeObject(bone, `${i}`, b, out)); json = x.toJSON(); break;
    case 'IB': out.push(entry('', x.uuid, 0)); break;
    case 'Shape': out.push(entry('', x.uuid, 0)); json = x.toJSON(); break;
    case 'Clip': out.push(entry('', x.uuid, 0)); json = T.AnimationClip.toJSON(x); break;
  }
  return JSON.stringify({ probes: out, json });
}

let freshCount = 0;
for (const [k, name] of Object.keys(F).entries()) {
  if (only && !name.includes(only)) continue;
  freshCount++;
  const s = 7000 + k;
  const expected = guarded('fresh upstream ' + name, () => upstreamFresh(name, s));
  globalThis.__reseed = () => reseed(s);
  const actual = guarded('fresh ' + name, () => M.fresh(name));
  if (expected !== undefined && actual !== undefined && compare('fresh ' + name, expected, actual)) console.log(`ok       fresh ${name}`);
}

// 2. nonfinite writers, 3. readers
const B = nonfiniteBuilders(T);
let nfCount = 0;
for (const [k, name] of Object.keys(B).entries()) {
  if (only && !name.includes(only)) continue;
  nfCount++;
  reseed(500 + k);
  const object = B[name]();
  object.updateMatrixWorld(true);
  const expected = JSON.stringify(object.toJSON());
  reseed(500 + k);
  const actual = guarded('nonfinite ' + name, () => M.nonfinite(name));
  if (actual !== undefined) {
    let valid = true;
    try { JSON.parse(actual); } catch { valid = false; failed++; console.log(`INVALID  nonfinite ${name}: port output is not JSON`); }
    if (valid && compare('nonfinite ' + name, expected, actual)) console.log(`ok       nonfinite ${name} (${expected.length} chars)`);
  }
  if (B[name].writerOnly) continue;
  reseed(42);
  const back = JSON.stringify(new T.ObjectLoader().parse(JSON.parse(expected)).toJSON());
  reseed(42);
  const backPort = guarded('roundtrip ' + name, () => M.roundtrip(expected));
  if (backPort !== undefined && compare('roundtrip ' + name, back, backPort)) console.log(`ok       roundtrip ${name}`);
}
console.log(`\n${passed} passed, ${failed} failed (${freshCount} fresh, ${nfCount} nonfinite scenes)`);
process.exit(failed ? 1 : 0);
