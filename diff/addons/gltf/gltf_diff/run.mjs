// GLTFLoader differential test: loads each model with upstream GLTFLoader and with
// the port, both against env.mjs (fake fetch/createImageBitmap/Worker), Math.random
// reseeded identically per side, and compares the canonical dumps entry by entry.
//
//   node --import ../register.mjs run.mjs [--no-build] [model-substring ...]
import { execSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { install, BASE } from '../env.mjs';
import { dumpGLTF } from './dump_up.mjs';
import { MODELS } from './models.mjs';
import fs from 'node:fs';
import { FIXTURES } from '../env.mjs';
import './gen_fixtures.mjs'; // (re)writes FIXTURES
const ALL = [...MODELS.map((m) => 'models/gltf/' + m), ...fs.readdirSync(FIXTURES).sort().map((f) => '__fixtures__/' + f),
  'models/gltf/coffeemat.glb?nodeps', 'models/gltf/duck.glb?nodeps', '__fixtures__/scene_features.gltf?plugin', 'models/gltf/ClearcoatTest/ClearcoatTest.glb?plugin'];

install();
const here = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const filters = args.filter((a) => !a.startsWith('--'));
if (!args.includes('--no-build')) {
  try { execSync('moon build --target js', { cwd: here, stdio: 'pipe' }); }
  catch (e) { console.log('BUILD FAILED\n' + String(e.stdout) + String(e.stderr)); process.exit(2); }
}
const M = await import(pathToFileURL(path.join(here, '_build/js/debug/build/gltfdiff/h/harness/harness.js')).href);
const J = 'three/addons/';
const T = await import('three');
const { GLTFLoader } = await import(J + 'loaders/GLTFLoader.js');
const { DRACOLoader } = await import(J + 'loaders/DRACOLoader.js');
const { KTX2Loader } = await import(J + 'loaders/KTX2Loader.js');
const { MeshoptDecoder } = await import(J + 'libs/meshopt_decoder.module.js');
await MeshoptDecoder.ready;

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

const opts = { dracoPath: BASE + 'jsm/libs/draco/gltf/', basisPath: BASE + 'jsm/libs/basis/', meshopt: MeshoptDecoder };

class TestPlugin {
  constructor(parser) { this.parser = parser; this.name = 'TEST_plugin'; }
  beforeRoot() { this.parser.json.__beforeRoot = true; return Promise.resolve(); }
  afterRoot(result) { result.userData.afterRoot = result.scenes.length; return Promise.resolve(); }
  createNodeAttachment(index) {
    const def = this.parser.json.nodes[index];
    if (def.name !== 'Cam') return null;
    const o = new T.Object3D(); o.name = 'attach_' + index; return Promise.resolve(o);
  }
  getMaterialType(index) { return this.parser.json.materials[index].name === 'mask_default' ? T.MeshBasicMaterial : null; }
  extendMaterialParams(index, params) {
    if (this.parser.json.materials[index].name !== 'mask_default') return null;
    params.opacity = 0.5; return Promise.resolve();
  }
}
const testPluginCallback = (parser) => new TestPlugin(parser);
function loadUpstream(url, nodeps, plugin) {
  return new Promise((resolve, reject) => {
    const draco = new DRACOLoader().setDecoderPath(opts.dracoPath).setWorkerLimit(1);
    const ktx2 = new KTX2Loader().setTranscoderPath(opts.basisPath).setWorkerLimit(1);
    ktx2.workerConfig = { astcSupported: false, astcHDRSupported: false, etc1Supported: false, etc2Supported: true, dxtSupported: true, bptcSupported: true, pvrtcSupported: false };
    const loader = new GLTFLoader();
    if (plugin) { loader.register(testPluginCallback); loader.register(testPluginCallback); }
    if (!nodeps) loader.setDRACOLoader(draco).setKTX2Loader(ktx2).setMeshoptDecoder(opts.meshopt);
    loader.load(url, (gltf) => { const d = dumpGLTF(T, gltf); draco.dispose(); ktx2.dispose(); resolve(d); }, undefined, (e) => { draco.dispose(); ktx2.dispose(); reject(e); });
  });
}

function captureLogs() {
  const out = [];
  const w = console.warn, e = console.error, l = console.log;
  console.log = (...a) => { const t = a.map(String).join(' '); if (t.startsWith('THREE.')) out.push('warn: ' + t); else l(...a); };
  console.warn = (...a) => out.push('warn: ' + a.map(String).join(' '));
  console.error = (...a) => out.push('error: ' + a.map((x) => (x instanceof Error ? 'Error: ' + x.message : String(x))).join(' '));
  return { out, restore: () => { console.warn = w; console.error = e; console.log = l; } };
}

// Entry-by-entry comparison; returns the list of differing paths.
function diff(a, b, p, outList, limit = 20) {
  if (outList.length >= limit) return;
  if (a === b) return;
  if (typeof a === 'number' && typeof b === 'number' && Number.isNaN(a) && Number.isNaN(b)) return;
  if (a && b && typeof a === 'object' && typeof b === 'object') {
    if (Array.isArray(a) !== Array.isArray(b)) { outList.push(`${p}: array vs object`); return; }
    const keys = Array.isArray(a) ? [...Array(Math.max(a.length, b.length)).keys()] : [...new Set([...Object.keys(a), ...Object.keys(b)])];
    if (Array.isArray(a) && a.length !== b.length) outList.push(`${p}: length ${a.length} vs ${b.length}`);
    for (const k of keys) diff(a[k], b[k], `${p}.${k}`, outList, limit);
    return;
  }
  outList.push(`${p}: up=${JSON.stringify(a)?.slice(0, 300)} mb=${JSON.stringify(b)?.slice(0, 300)}`);
}

const withTimeout = (p, ms = 30000) => Promise.race([p, new Promise((_, rej) => setTimeout(() => rej(new Error('TIMEOUT')), ms))]);
let pass = 0, fail = 0;
const summary = [];
for (const model of ALL) {
  if (filters.length && !filters.some((f) => model.includes(f))) continue;
  const url = BASE + model;
  const nodeps = model.includes('nodeps');
  const plugin = model.includes('plugin');
  let up, mb, upLogs, mbLogs, upErr = null, mbErr = null;
  let c = captureLogs();
  reseed(1234);
  try { up = await withTimeout(loadUpstream(url, nodeps, plugin)); } catch (e) { upErr = String(e && e.message || e); }
  c.restore(); upLogs = c.out.filter((l) => !l.includes('Unable to serialize Texture'));
  c = captureLogs();
  reseed(1234);
  try { mb = await withTimeout(M.load_model(url, { ...opts, nodeps, plugin })); } catch (e) { mbErr = String(e && e.message || e); }
  c.restore(); mbLogs = c.out.filter((l) => !l.includes('Unable to serialize Texture'));
  const diffs = [];
  if (upErr || mbErr) {
    if (upErr !== mbErr) diffs.push(`error: up=${upErr} mb=${mbErr}`);
  } else {
    diff(up, mb, '$', diffs);
  }
  diff(upLogs, mbLogs, 'logs', diffs);
  const stats = up ? `${up.objects.length} obj, ${up.geometries.length} geo, ${up.materials.length} mat, ${up.textures.length} tex, ${up.animations.length} anim, ${up.associations.length} assoc` : `error ${upErr}`;
  if (diffs.length === 0) { pass++; console.log(`PASS ${model} (${stats})`); }
  else { fail++; console.log(`FAIL ${model} (${stats})`); for (const d of diffs) console.log('   ' + d); }
  summary.push({ model, pass: diffs.length === 0, stats });
}
console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
