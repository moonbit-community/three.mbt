// KTX2Loader / ktx-parse / ColorSpaces / WorkerPool differential test: upstream
// (examples/jsm, `three` -> src/Three.js via register.mjs) against the MoonBit port
// (moon build --target js of ./src/harness). Run:
//   moon build --target js && node --import ../register.mjs run.mjs [--quick] [--filter re]
//   (DUMP=1 / ALLDUMP=1 write the compared values to diff/.out/addons_ktx2)
import fs from 'node:fs';
import path from 'node:path';
import { install, BASE, fnv, stats } from '../env.mjs';
import { UPSTREAM, REPO, outDir } from '../../../lib/env.mjs';
install();

const ROOT = UPSTREAM + '/';
const J = 'three/addons/';
const { KTX2Loader } = await import(J + 'loaders/KTX2Loader.js');
const { WorkerPool } = await import(J + 'utils/WorkerPool.js');
const KTXParse = await import(J + 'libs/ktx-parse.module.js');
const CS = await import(J + 'math/ColorSpaces.js');
const THREE = await import('three');
const MB = await import('./_build/js/debug/build/ktx2diff/real/harness/harness.js');

const workerBodies = [];
{
  const create = URL.createObjectURL;
  URL.createObjectURL = (blob) => {
    const text = blob && blob.__bytes ? new TextDecoder().decode(blob.__bytes) : '';
    if (text.startsWith('/* constants */')) workerBodies.push(text);
    return create(blob);
  };
}
const args = process.argv.slice(2);
const QUICK = args.includes('--quick');
const fi = args.indexOf('--filter');
const FILTER = fi >= 0 ? new RegExp(args[fi + 1]) : null;
const TRANSCODER = BASE + 'jsm/libs/basis/';

// ---------------------------------------------------------------- normalisation
function norm(v, seen = new Set()) {
  if (v === undefined) return '<undef>';
  if (v === null) return null;
  if (typeof v === 'number') return Number.isFinite(v) ? (Object.is(v, -0) ? '-0' : v) : String(v);
  if (typeof v === 'string' || typeof v === 'boolean') return v;
  if (typeof v === 'function') return '<fn>';
  if (ArrayBuffer.isView(v)) {
    const bytes = new Uint8Array(v.buffer, v.byteOffset, v.byteLength);
    return { $ta: v.constructor.name, length: v.length, byteOffset: v.byteOffset, bufferBytes: v.buffer.byteLength, hash: fnv(bytes) };
  }
  if (v instanceof ArrayBuffer) return { $ab: v.byteLength, hash: fnv(new Uint8Array(v)) };
  if (v instanceof Set) return { $set: Array.from(v).map((x) => norm(x, seen)) };
  if (seen.has(v)) return '<cycle>';
  seen.add(v);
  let out;
  if (Array.isArray(v)) out = v.map((x) => norm(x, seen));
  else { out = {}; for (const k of Object.keys(v)) out[k] = norm(v[k], seen); }
  seen.delete(v);
  return out;
}
const S = (v) => JSON.stringify(norm(v));

function firstDiff(a, b, path = '$') {
  if (JSON.stringify(a) === JSON.stringify(b)) return null;
  if (a && b && typeof a === 'object' && typeof b === 'object') {
    const keys = new Set([...Object.keys(a), ...Object.keys(b)]);
    for (const k of keys) { const d = firstDiff(a[k], b[k], path + '.' + k); if (d) return d; }
    return `${path}: key sets differ`;
  }
  return `${path}: upstream=${JSON.stringify(a)} port=${JSON.stringify(b)}`;
}

let checks = 0, failures = 0;
const failed = [];
const allDump = [];
function compare(name, up, mb) {
  checks++;
  const a = norm(up), b = norm(mb);
  if (process.env.ALLDUMP) allDump.push([name, a]);
  const d = firstDiff(a, b);
  if (d) { failures++; failed.push(name); console.log('FAIL', name, '\n   ', d.slice(0, 600)); if (process.env.DUMP) { fs.writeFileSync(path.join(outDir('addons_ktx2'), 'dump_up.json'), JSON.stringify(a, null, 1)); fs.writeFileSync(path.join(outDir('addons_ktx2'), 'dump_port.json'), JSON.stringify(b, null, 1)); } }
  else if (process.env.VERBOSE) console.log('ok  ', name);
}

// ---------------------------------------------------------------- console capture
let log = null;
const realWarn = console.warn, realError = console.error;
console.warn = (...a) => { if (log) log.push('warn: ' + a.map(String).join(' ')); else realWarn(...a); };
console.error = (...a) => { if (log) log.push('error: ' + a.map(String).join(' ')); else realError(...a); };
async function captured(f) {
  const prev = log; log = [];
  try { const value = await f(); return { value, console: log }; } finally { log = prev; }
}

// ---------------------------------------------------------------- upstream texture description
function dimg(d) {
  if (d === null || d === undefined) return d;
  return { data: d.data, width: d.width, height: d.height, depth: d.depth, mipmaps: d.mipmaps ? d.mipmaps.map(dimg) : undefined };
}
function describeUp(t) {
  const img = t.image;
  return {
    cls: t.constructor.name,
    isCompressedTexture: t.isCompressedTexture === true,
    isCubeTexture: t.isCubeTexture === true,
    image: Array.isArray(img) ? img.map(dimg) : dimg(img),
    // CompressedCubeTexture leaves `mipmaps` undefined upstream; the port's is [].
    mipmaps: (t.mipmaps || []).map(dimg),
    format: t.format, type: t.type, colorSpace: t.colorSpace, premultiplyAlpha: t.premultiplyAlpha,
    generateMipmaps: t.generateMipmaps, minFilter: t.minFilter, magFilter: t.magFilter,
    wrapS: t.wrapS, wrapT: t.wrapT, wrapR: 'wrapR' in t ? t.wrapR : 'n/a', mapping: t.mapping, flipY: t.flipY,
    unpackAlignment: t.unpackAlignment, anisotropy: t.anisotropy, normalized: t.normalized,
    version: t.version, sourceVersion: t.source.version, userData: t.userData,
    layerUpdates: t.layerUpdates ? Array.from(t.layerUpdates) : undefined,
  };
}
const errStr = (e) => (e && e.message !== undefined ? `${e.constructor && e.constructor.name}: ${e.message}` : 'value: ' + String(e));

// Both sides expose: newLoader(config), load(loader, url) -> {texture desc | error}, parse, dispose.
const UP = {
  name: 'upstream',
  newLoader(config) { const l = new KTX2Loader().setTranscoderPath(TRANSCODER); l.workerConfig = config ? { ...config } : null; return l; },
  load(l, url, cb, eb) { l.load(url, (t) => cb(describeUp(t), t), undefined, eb); },
  parse(l, buffer, cb, eb) { l.parse(buffer, (t) => cb(describeUp(t), t), eb); },
  init(l) { return l.init(); },
  limit(l, n) { return l.setWorkerLimit(n) === l; },
  dispose(l) { l.dispose(); },
  state(l) { return { transcoderPath: l.transcoderPath, workerSourceURL: !!l.workerSourceURL, transcoderPending: !!l.transcoderPending, transcoderBinary: l.transcoderBinary, workerConfig: l.workerConfig, pool: poolStateUp(l.workerPool) }; },
};
const PORT = {
  name: 'port',
  newLoader(config) { return MB.ktx2_new_loader(config ? { ...config } : null, TRANSCODER); },
  load(l, url, cb, eb) { MB.ktx2_load(l, url, cb, eb); },
  parse(l, buffer, cb, eb) { MB.ktx2_parse(l, buffer, cb, eb); },
  init(l) { return MB.ktx2_init(l); },
  limit(l, n) { return MB.ktx2_set_worker_limit(l, n); },
  dispose(l) { MB.ktx2_dispose(l); },
  state(l) { return MB.ktx2_loader_state(l); },
};
function poolStateUp(p) {
  return { pool: p.pool, workerStatus: p.workerStatus, queue: p.queue.length, workers: p.workers.length, workersDefined: p.workers.filter(Boolean).length, workersResolve: p.workersResolve.length };
}

const loadP = (side, l, url) => new Promise((res) => {
  try { side.load(l, url, (d) => res({ ok: d }), (e) => res({ error: errStr(e) })); } catch (e) { res({ thrown: errStr(e) }); }
});
const parseP = (side, l, buf) => new Promise((res) => {
  try { side.parse(l, buf, (d) => res({ ok: d }), (e) => res({ error: errStr(e) })); } catch (e) { res({ thrown: errStr(e) }); }
});

// ---------------------------------------------------------------- configs and files
const CONFIGS = {
  bc: { astcSupported: false, astcHDRSupported: false, etc1Supported: false, etc2Supported: true, dxtSupported: true, bptcSupported: true, pvrtcSupported: false },
  astc: { astcSupported: true, astcHDRSupported: true, etc1Supported: true, etc2Supported: true, dxtSupported: false, bptcSupported: false, pvrtcSupported: false },
  etc_pvrtc: { astcSupported: false, astcHDRSupported: false, etc1Supported: true, etc2Supported: false, dxtSupported: false, bptcSupported: false, pvrtcSupported: true },
  none: { astcSupported: false, astcHDRSupported: false, etc1Supported: false, etc2Supported: false, dxtSupported: false, bptcSupported: false, pvrtcSupported: false },
};
const KTX2_DIR = ROOT + 'examples/textures/ktx2/';
const FILES = fs.readdirSync(KTX2_DIR).filter((f) => f.endsWith('.ktx2')).sort().map((f) => 'textures/ktx2/' + f);
const OTHER = ['textures/spiritedaway.ktx2', ...fs.readdirSync(ROOT + 'examples/textures/pmrem').filter((f) => f.endsWith('.ktx2')).sort().map((f) => 'textures/pmrem/' + f)];
const ALL = [...FILES, ...OTHER];
const sel = (list) => (FILTER ? list.filter((f) => FILTER.test(f)) : list);

// ---------------------------------------------------------------- 1. ktx-parse read
for (const f of sel(ALL)) {
  const bytes = new Uint8Array(fs.readFileSync(ROOT + 'examples/' + f));
  const tryRead = (fn) => { try { return fn(bytes); } catch (e) { return { thrown: errStr(e) }; } };
  compare('read ' + f, tryRead(KTXParse.read), tryRead(MB.ktx_read));
}
{
  const bad = new Uint8Array(64);
  const e1 = (() => { try { KTXParse.read(bad); } catch (e) { return errStr(e); } })();
  const e2 = (() => { try { MB.ktx_read(bad); } catch (e) { return errStr(e); } })();
  compare('read invalid identifier', e1, e2);
  const short = new Uint8Array(5);
  const s1 = (() => { try { KTXParse.read(short); } catch (e) { return errStr(e); } })();
  const s2 = (() => { try { MB.ktx_read(short); } catch (e) { return errStr(e); } })();
  compare('read short buffer', s1, s2);
  // each identifier byte corrupted in turn
  const good = new Uint8Array(fs.readFileSync(KTX2_DIR + '2d_rgba8.ktx2'));
  const res = [[], []];
  for (let k = 0; k < 12; k++) {
    const b = good.slice(); b[k] ^= 0x40;
    for (const [i, f] of [[0, KTXParse.read], [1, MB.ktx_read]]) { try { f(b); res[i].push('ok'); } catch (e) { res[i].push(errStr(e)); } }
  }
  compare('read corrupted identifier bytes (12)', res[0], res[1]);
}

// ---------------------------------------------------------------- 2. ColorSpaces
function colorSpacesUp() {
  const CM = THREE.ColorManagement;
  const sp = (s) => ({ primaries: s.primaries, whitePoint: s.whitePoint, transfer: s.transfer, toXYZ: s.toXYZ.elements, fromXYZ: s.fromXYZ.elements,
    luminanceCoefficients: s.luminanceCoefficients, workingColorSpaceConfig: s.workingColorSpaceConfig, outputColorSpaceConfig: s.outputColorSpaceConfig && { drawingBufferColorSpace: s.outputColorSpaceConfig.drawingBufferColorSpace, toneMappingMode: s.outputColorSpaceConfig.toneMappingMode } });
  const names = { DisplayP3ColorSpace: CS.DisplayP3ColorSpace, LinearDisplayP3ColorSpace: CS.LinearDisplayP3ColorSpace, LinearRec2020ColorSpace: CS.LinearRec2020ColorSpace, ExtendedSRGBColorSpace: CS.ExtendedSRGBColorSpace };
  const impls = { DisplayP3ColorSpaceImpl: sp(CS.DisplayP3ColorSpaceImpl), LinearDisplayP3ColorSpaceImpl: sp(CS.LinearDisplayP3ColorSpaceImpl), LinearRec2020ColorSpaceImpl: sp(CS.LinearRec2020ColorSpaceImpl), ExtendedSRGBColorSpaceImpl: sp(CS.ExtendedSRGBColorSpaceImpl) };
  const sharing = { p3PrimariesShared: CS.DisplayP3ColorSpaceImpl.primaries === CS.LinearDisplayP3ColorSpaceImpl.primaries, p3MatrixShared: CS.DisplayP3ColorSpaceImpl.toXYZ === CS.LinearDisplayP3ColorSpaceImpl.toXYZ, extendedSharesSRGB: CS.ExtendedSRGBColorSpaceImpl.primaries === CM.spaces[THREE.SRGBColorSpace].primaries };
  CM.define({ [CS.DisplayP3ColorSpace]: CS.DisplayP3ColorSpaceImpl, [CS.LinearDisplayP3ColorSpace]: CS.LinearDisplayP3ColorSpaceImpl, [CS.LinearRec2020ColorSpace]: CS.LinearRec2020ColorSpaceImpl, [CS.ExtendedSRGBColorSpace]: CS.ExtendedSRGBColorSpaceImpl });
  const spaces = [THREE.SRGBColorSpace, THREE.LinearSRGBColorSpace, CS.DisplayP3ColorSpace, CS.LinearDisplayP3ColorSpace, CS.LinearRec2020ColorSpace, CS.ExtendedSRGBColorSpace];
  const inputs = [[0.3, 0.5, 0.7], [1.0, 0.5, 0.01], [0, 0, 0], [1, 1, 1], [-0.2, 1.3, 0.04]];
  const conversions = [];
  for (const s of spaces) for (const d of spaces) for (const i of inputs) { const c = new THREE.Color(i[0], i[1], i[2]); CM.convert(c, s, d); conversions.push([s, d, c.r, c.g, c.b]); }
  const misc = spaces.map((s) => { const c = new THREE.Color().setRGB(1.0, 0.5, 0.01, s); const sp2 = CM.spaces[s];
    return [s, c.r, c.g, c.b, c.getStyle(s), CM.getTransfer(s), sp2.outputColorSpaceConfig ? CM.getToneMappingMode(s) : '-', sp2.outputColorSpaceConfig ? CM._getDrawingBufferColorSpace(s) : '-', sp2.workingColorSpaceConfig ? CM._getUnpackColorSpace(s) : '-']; });
  return { names, impls, sharing, conversions, misc };
}
{
  const up = colorSpacesUp();
  const mb = MB.color_spaces_dump();
  compare('ColorSpaces constants and impls', { names: up.names, impls: up.impls, sharing: up.sharing }, { names: mb.names, impls: mb.impls, sharing: mb.sharing });
  compare('ColorSpaces conversions (' + up.conversions.length + ')', up.conversions, mb.conversions);
  compare('ColorSpaces setRGB/getStyle/transfer', up.misc, mb.misc);
}

// ---------------------------------------------------------------- 3. WorkerPool
const POOL_WORKER = URL.createObjectURL(new Blob([`
let n = 0;
self.addEventListener( 'message', ( e ) => {
  const d = e.data; n ++; const seen = n; let t = 0;
  const reply = () => { if ( t ++ < d.delay ) { setTimeout( reply, 0 ); return; }
    self.postMessage( { id: d.id, seen, bytes: d.buf ? d.buf.byteLength : - 1 } ); };
  reply();
} );`]));
async function poolScenario(side, limit, delays, changeLimitAt) {
  const events = [];
  const pool = side === 'up' ? new WorkerPool() : MB.worker_pool_new(POOL_WORKER, limit);
  if (side === 'up') { if (limit > 0) pool.setWorkerLimit(limit); pool.setWorkerCreator(() => new Worker(POOL_WORKER)); }
  const state = () => (side === 'up' ? poolStateUp(pool) : MB.worker_pool_state(pool));
  const ps = [];
  for (let i = 0; i < delays.length; i++) {
    if (i === changeLimitAt) { if (side === 'up') pool.setWorkerLimit(1); else MB.worker_pool_set_limit(pool, 1); }
    const buf = new ArrayBuffer(8 + i);
    const msg = { id: i, delay: delays[i], buf };
    const p = side === 'up' ? pool.postMessage(msg, [buf]) : MB.worker_pool_post(pool, msg, [buf]);
    events.push(['post', i, buf.byteLength, state()]);
    ps.push(p.then((e) => { events.push(['done', e.data, state()]); }));
    // interleave microtasks so resolutions can race the next posts
    if (i % 3 === 2) await new Promise((r) => setTimeout(r, 0));
  }
  await Promise.all(ps);
  events.push(['end', state()]);
  if (side === 'up') pool.dispose(); else MB.worker_pool_dispose(pool);
  events.push(['disposed', state()]);
  return events;
}
for (const [name, limit, delays, change] of [
  ['limit2', 2, [3, 0, 2, 1, 0, 4, 0], -1],
  ['default4', 0, [5, 1, 0, 3, 2, 0, 1, 0, 6], -1],
  ['limit1', 1, [0, 2, 1, 0], -1],
  ['shrink', 3, [4, 4, 4, 0, 1, 2, 0], 4],
]) {
  compare('WorkerPool ' + name, await poolScenario('up', limit, delays, change), await poolScenario('mb', limit, delays, change));
}


// detectSupport( WebGLRenderer ) on the recording mock WebGL 2 context
{
  const { createRequire } = await import('node:module');
  const require = createRequire(import.meta.url);
  const WG = path.join(REPO, 'diff/core/webgl/harness') + '/';
  const { createMockGL } = require(WG + 'mock_gl.cjs');
  const { createMockCanvas } = require(WG + 'scenarios/renderer_common.cjs');
  const BASE_EXT = ['EXT_color_buffer_float', 'EXT_color_buffer_half_float', 'OES_texture_float_linear', 'EXT_texture_filter_anisotropic'];
  const ALL_C = ['WEBGL_compressed_texture_astc', 'WEBGL_compressed_texture_etc1', 'WEBGL_compressed_texture_etc', 'WEBGL_compressed_texture_s3tc', 'EXT_texture_compression_bptc', 'WEBGL_compressed_texture_pvrtc'];
  const cases = [
    ['all, astc hdr', ALL_C, ['ldr', 'hdr'], null],
    ['all, astc ldr only', ALL_C, ['ldr'], null],
    ['webkit pvrtc, s3tc', ['WEBKIT_WEBGL_compressed_texture_pvrtc', 'WEBGL_compressed_texture_s3tc'], null, null],
    ['none', [], null, null],
    ['all on desktop Linux', ALL_C, ['ldr', 'hdr'], { platform: 'Linux x86_64', userAgent: 'Mozilla/5.0 (X11; Linux x86_64)' }],
    ['all on Android', ALL_C, ['ldr', 'hdr'], { platform: 'Linux armv8l', userAgent: 'Mozilla/5.0 (Linux; Android 14)' }],
    ['astc etc2 bptc s3tc on Linux', ['WEBGL_compressed_texture_astc', 'WEBGL_compressed_texture_etc', 'EXT_texture_compression_bptc', 'WEBGL_compressed_texture_s3tc'], ['ldr'], { platform: 'Linux x86_64', userAgent: 'X11' }],
  ];
  const navDesc = Object.getOwnPropertyDescriptor(globalThis, 'navigator');
  for (const [name, ext, profiles, nav] of cases) {
    const run = (side) => {
      if (nav) Object.defineProperty(globalThis, 'navigator', { value: nav, configurable: true, writable: true });
      try {
        const gl = createMockGL({ extensions: BASE_EXT.concat(ext) });
        if (profiles) { const e = gl.getExtension('WEBGL_compressed_texture_astc'); e.getSupportedProfiles = () => profiles.slice(); }
        const canvas = createMockCanvas(gl, 64, 32);
        let result;
        if (side === 'up') {
          const renderer = new THREE.WebGLRenderer({ canvas, context: gl });
          gl.__log.length = 0;
          const l = new KTX2Loader();
          result = { chained: l.detectSupport(renderer) === l, config: l.workerConfig };
        } else {
          result = MB.ktx2_detect_support_webgl(gl, canvas);
        }
        return { result, log: gl.__log.slice() };
      } finally {
        if (nav) Object.defineProperty(globalThis, 'navigator', navDesc);
      }
    };
    compare('detectSupport WebGL: ' + name, await captured(() => run('up')), await captured(() => run('mb')));
  }
}

// ---------------------------------------------------------------- 4. KTX2Loader on every file
// init() alone, twice on one loader, and two active loaders (warning)
await both('init and active loaders', async (side) => {
  const a = side.newLoader(CONFIGS.bc);
  const b = side.newLoader(CONFIGS.none);
  const p1 = side.init(a), p2 = side.init(a);
  const out = [p1 === p2];
  await p1;
  out.push(side.state(a));
  await side.init(b);
  out.push(side.state(b));
  side.dispose(a); side.dispose(b);
  out.push(side.state(a));
  // the worker source: constants, basis_transcoder.js and the BasisWorker body
  const body = workerBodies.splice(0);
  out.push(body.map((t) => [t.length, fnv(new TextEncoder().encode(t))]));
  out.push(body[0] === body[1]);
  return out;
});

async function sideRun(side, f) { return captured(() => f(side)); }
async function both(name, f) {
  const a = await sideRun(UP, f);
  const b = await sideRun(PORT, f);
  compare(name, a, b);
}
const cfgs = QUICK ? ['bc', 'none'] : Object.keys(CONFIGS);
for (const c of cfgs) {
  const files = sel(QUICK ? FILES.concat(['textures/spiritedaway.ktx2', OTHER[1]]) : ALL);
  await both(`config ${c}: ${files.length} files`, async (side) => {
    const l = side.newLoader(CONFIGS[c]);
    const out = [];
    for (const f of files) out.push([f, await loadP(side, l, BASE + f)]);
    out.push(['state', side.state(l)]);
    side.dispose(l);
    out.push(['disposed', side.state(l)]);
    return out;
  });
}

// concurrent loads on one loader: completion order, the FileLoader dedup and _taskCache
for (const limit of [1, 4]) await both(`concurrent loads, worker limit ${limit} (completion order, duplicate URLs)`, async (side) => {
  const l = side.newLoader(CONFIGS.bc);
  const chained = side.limit(l, limit);
  const order = [];
  const list = sel(FILES.concat(['textures/spiritedaway.ktx2', 'textures/ktx2/2d_etc1s.ktx2', 'textures/ktx2/2d_rgba8.ktx2', 'textures/ktx2/2d_uastc.ktx2']));
  const textures = [];
  await Promise.all(list.map((f, i) => new Promise((res) => {
    side.load(l, BASE + f, (d, t) => { order.push([i, f, d.cls, d.format]); textures.push([f, t]); res(); }, (e) => { order.push([i, f, 'error', errStr(e)]); res(); });
  })));
  // several workers finish in wall-clock order (each compiles the wasm): compare sorted
  if (limit > 1) order.sort((x, y) => x[0] - y[0]);
  order.push(['chained', chained]);
  // identical texture objects for duplicate Basis URLs (task cache), distinct ones for raw files
  const same = (name) => { const ts = textures.filter((x) => x[0] === name).map((x) => x[1]); return ts.length === 2 ? ts[0] === ts[1] : 'n/a'; };
  order.push(['same etc1s', same('textures/ktx2/2d_etc1s.ktx2')], ['same rgba8', same('textures/ktx2/2d_rgba8.ktx2')], ['same uastc', same('textures/ktx2/2d_uastc.ktx2')]);
  order.push(['state', side.state(l)]);
  side.dispose(l);
  return order;
});


// microtask timing: how many microtask steps after parse() (or after the worker's reply
// event) each callback runs, counted by a bounded ticker chain
let tick = 0, tickGen = 0;
function startTicker(n = 80) {
  tick = 0;
  const g = ++tickGen;
  const step = () => { if (g !== tickGen) return; tick++; if (tick < n) Promise.resolve().then(step); };
  Promise.resolve().then(step);
}
{
  const deliver = Worker.prototype._deliver;
  Worker.prototype._deliver = function (event) { if (event && event.data && event.data.type === 'transcode') startTicker(); return deliver.call(this, event); };
}
await both('microtask timing of callbacks', async (side) => {
  const l = side.newLoader(CONFIGS.astc);
  const file = (f) => new Uint8Array(fs.readFileSync(KTX2_DIR + f)).buffer;
  // warm up: zstd decoder and transcoder
  await parseP(side, l, file('2d_uastc_hdr4x4.ktx2'));
  await parseP(side, l, file('2d_uastc.ktx2'));
  const out = [];
  const timed = (name, buf, sync = true) => new Promise((res) => {
    if (sync) startTicker();
    side.parse(l, buf, () => { out.push([name, 'load', tick]); res(); }, (e) => { out.push([name, 'error', tick, errStr(e)]); res(); });
  });
  await timed('raw rgba8', file('2d_rgba8.ktx2'));
  await timed('raw bc1', file('2d_bc1.ktx2'));
  await timed('raw zstd astc hdr', file('2d_uastc_hdr4x4.ktx2'));
  await timed('raw bad vkFormat', patched('2d_rgba8.ktx2', (dv) => dv.setUint32(12, 1, true)));
  await timed('not ktx2', new ArrayBuffer(64));
  const basis = file('2d_etc1s.ktx2');
  await timed('basis (ticks after worker reply)', basis, false);
  await timed('basis cached', basis);
  // two flows racing in one microtask queue
  startTicker();
  await Promise.all([['a raw zstd', file('2d_uastc_hdr4x4.ktx2')], ['b raw plain', file('2d_rgba8_linear.ktx2')], ['c cached', basis], ['d error', new ArrayBuffer(16)]].map(([n, b]) => timed(n, b, false)));
  side.dispose(l);
  return out;
});

// parse() twice on one Basis buffer: the second call takes the _taskCache path
await both('parse twice on one buffer', async (side) => {
  const l = side.newLoader(CONFIGS.bc);
  const buf = new Uint8Array(fs.readFileSync(KTX2_DIR + '2d_uastc.ktx2')).buffer;
  const events = [];
  const results = [];
  await Promise.all([0, 1, 2].map((k) => new Promise((res) => {
    side.parse(l, buf, (d, t) => { events.push(['load', k, buf.byteLength]); results.push(t); res(); }, (e) => { events.push(['error', k, errStr(e)]); res(); });
    events.push(['called', k, buf.byteLength]);
  })));
  events.push(['same', results[0] === results[1], results[1] === results[2]]);
  side.dispose(l);
  return events;
});

// error paths and patched headers
function patched(file, patch) {
  const b = new Uint8Array(fs.readFileSync(KTX2_DIR + file));
  const dv = new DataView(b.buffer);
  patch(dv, dv.getUint32(48, true) /* dfdByteOffset */);
  return b.buffer;
}
const PATCHES = [
  ['not a ktx2 file', () => new Uint8Array(fs.readFileSync(ROOT + 'examples/textures/uv_grid_opengl.jpg')).buffer],
  ['unsupported vkFormat', () => patched('2d_rgba8.ktx2', (dv) => dv.setUint32(12, 1, true))],
  ['unsupported supercompression', () => patched('2d_rgba8.ktx2', (dv) => dv.setUint32(44, 3, true))],
  ['compressed pixelDepth', () => patched('2d_bc1.ktx2', (dv) => dv.setUint32(28, 1, true))],
  ['data 3d texture', () => patched('2d_rgba8.ktx2', (dv) => dv.setUint32(28, 4, true))],
  ['raw compressed cube', () => patched('2d_bc7.ktx2', (dv) => dv.setUint32(36, 6, true))],
  ['raw data levelCount 0', () => patched('2d_rgba16_linear.ktx2', (dv) => dv.setUint32(40, 0, true))],
  ['raw compressed levelCount 0', () => patched('2d_bc3.ktx2', (dv) => dv.setUint32(40, 0, true))],
  ['display p3 srgb', () => patched('2d_rgba8.ktx2', (dv, a) => dv.setUint8(a + 13, 10))],
  ['display p3 linear', () => patched('2d_rgba32_linear.ktx2', (dv, a) => dv.setUint8(a + 13, 10))],
  ['unspecified primaries', () => patched('2d_bc4.ktx2', (dv, a) => dv.setUint8(a + 13, 0))],
  ['unsupported primaries', () => patched('2d_bc5.ktx2', (dv, a) => dv.setUint8(a + 13, 5))],
  ['basis premultiplied alpha', () => patched('2d_uastc.ktx2', (dv, a) => dv.setUint8(a + 15, 1))],
  ['basis display p3', () => patched('2d_etc1s.ktx2', (dv, a) => dv.setUint8(a + 13, 10))],
  ['basis with layers', () => patched('2d_uastc.ktx2', (dv) => dv.setUint32(32, 1, true))],
  ['basis truncated', () => new Uint8Array(fs.readFileSync(KTX2_DIR + '2d_uastc.ktx2')).slice(0, 1200).buffer],
];
for (const c of QUICK ? ['bc'] : ['bc', 'none', 'astc']) {
  await both(`patched files, config ${c}`, async (side) => {
    const l = side.newLoader(CONFIGS[c]);
    const out = [];
    for (const [name, make] of PATCHES) out.push([name, await parseP(side, l, make())]);
    side.dispose(l);
    return out;
  });
}

// missing workerConfig: load and parse throw
await both('missing workerConfig', async (side) => {
  const l = side.newLoader(null);
  const out = [await loadP(side, l, BASE + 'textures/ktx2/2d_rgba8.ktx2'), await parseP(side, l, new ArrayBuffer(8)), side.state(l)];
  side.dispose(l);
  return out;
});

{
  // the BasisWorker source the port embeds, against Function.prototype.toString upstream
  compare('BasisWorker source verbatim', KTX2Loader.BasisWorker.toString(), MB.ktx2_basis_worker_source());
  const tables = ['BasisFormat', 'TranscoderFormat', 'EngineFormat', 'EngineType'].map((k) => JSON.stringify(KTX2Loader[k]));
  compare('static tables (JSON)', tables, MB.ktx2_tables_json());
}
if (process.env.ALLDUMP) fs.writeFileSync(path.join(outDir('addons_ktx2'), 'all_up.json'), JSON.stringify(allDump));
console.log(`\n${checks - failures}/${checks} checks identical` + (failures ? `; FAILED: ${failed.join(', ')}` : ''));
console.log(`(${stats.workers} workers, ${stats.fetches.length} fetches)`);
process.exit(failures ? 1 : 0);
