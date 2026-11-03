// Differential test of the HDR/RGBE/EXR/HDRCube/UltraHDR loaders: every .hdr/.exr of
// upstream examples/ plus the generated EXRs (OUT/addons_hdr/exr), loaded on both sides.
//   node run.mjs [--build] [--only hdr,exr,cube,ultra] [--filter re] [--verbose]
// FULL=1 also writes the first mismatching pair to OUT/addons_hdr/mis_{a,b}.json.
import fs from 'node:fs';
import path from 'node:path';
import { execSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import * as env from './env.mjs';
import { EX, HARNESS_URL, HERE, OUT_HDR } from './paths.mjs';
import { ensureExr } from './fixtures.mjs';

const here = HERE;
const args = process.argv.slice(2);
const only = args.includes('--only') ? args[args.indexOf('--only') + 1].split(',') : null;
const verbose = args.includes('--verbose');
const filter = args.includes('--filter') ? new RegExp(args[args.indexOf('--filter') + 1]) : null;
if (args.includes('--build')) execSync('moon build --target js', { cwd: here + '/mod', stdio: 'inherit' });
env.install();
const rejections = [];
process.on('unhandledRejection', (e) => rejections.push(String(e && e.message)));
const quiet = async (f) => { const w = console.warn, e = console.error, l = console.log; console.warn = console.error = console.log = () => {}; try { return await f(); } finally { console.warn = w; console.error = e; console.log = l; } };
const M = await import(HARNESS_URL);
const ex = EX;
const { HDRLoader } = await import(ex + 'jsm/loaders/HDRLoader.js');
const { RGBELoader } = await import(ex + 'jsm/loaders/RGBELoader.js');
const { EXRLoader } = await import(ex + 'jsm/loaders/EXRLoader.js');
const { HDRCubeTextureLoader } = await import(ex + 'jsm/loaders/HDRCubeTextureLoader.js');
const T = await import(ex + '../build/three.module.js');
const { HalfFloatType, FloatType, RGBAFormat, RGFormat, RedFormat, UnsignedByteType } = T;

let pass = 0, fail = 0;
const stats = {};
function cmp(label, a, b) {
  const ja = JSON.stringify(a), jb = JSON.stringify(b);
  const key = label.split(' ')[0];
  stats[key] = stats[key] || { pass: 0, fail: 0 };
  if (ja === jb) { pass++; stats[key].pass++; if (verbose) console.log('ok', label, ja.slice(0, 160)); }
  else {
    fail++; stats[key].fail++;
    console.log('MISMATCH', label);
    console.log('  upstream:', ja.slice(0, 600)); if (process.env.FULL) { fs.writeFileSync(path.join(OUT_HDR, 'mis_a.json'), ja); fs.writeFileSync(path.join(OUT_HDR, 'mis_b.json'), jb); }
    console.log('  port:    ', jb.slice(0, 600));
  }
}
const errJs = (e) => ({ error: String(e && e.message), name: e && e.name });
function upstreamLoad(loader, url) {
  return new Promise((resolve) => {
    loader.load(url, (t, d) => resolve(globalThis.__describe(t, d)), undefined, (e) => resolve(errJs(e)));
  });
}
const portLoad = (f) => new Promise((resolve) => f(resolve));

// --- HDR ---
function findFiles(dir, re) {
  const out = [];
  for (const f of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, f.name);
    if (f.isDirectory()) { if (f.name !== 'node_modules') out.push(...findFiles(p, re)); }
    else if (re.test(f.name)) out.push(p);
  }
  return out.sort();
}
export const hdrFiles = findFiles(ex, /\.hdr$/i).filter((f) => !filter || filter.test(f));
if (!only || only.includes('hdr')) {
  for (const file of hdrFiles) {
    for (const [tn, type] of [['half', HalfFloatType], ['float', FloatType]]) {
      for (const setter of [true, false]) {
        const up = new HDRLoader(); if (setter) up.setDataType(type); else up.type = type;
        const a = await quiet(() => upstreamLoad(up, file));
        const b = await quiet(() => portLoad((done) => M.hdr_load(file, type, setter, done)));
        cmp(`hdr ${path.relative(ex, file)} ${tn} setter=${setter}`, a, b);
      }
    }
    const a = await quiet(() => upstreamLoad(new RGBELoader().setDataType(FloatType), file));
    const b = await quiet(() => portLoad((done) => M.rgbe_load(file, FloatType, done)));
    cmp(`rgbe ${path.relative(ex, file)}`, a, b);
  }
  // unsupported type
  const up = new HDRLoader().setDataType(UnsignedByteType);
  cmp('hdr unsupported-type', await quiet(() => upstreamLoad(up, hdrFiles[0])), await quiet(() => portLoad((d) => M.hdr_load(hdrFiles[0], UnsignedByteType, true, d))));
}

// --- EXR ---
const exrDir = ensureExr();
const exrFiles = [...findFiles(ex, /\.exr$/i), ...(fs.existsSync(exrDir) ? findFiles(exrDir, /\.exr$/i) : [])].filter((f) => !filter || filter.test(f));
const hangs = fs.existsSync(here + '/hangs.json') ? JSON.parse(fs.readFileSync(here + '/hangs.json', 'utf8')) : {};
if (!only || only.includes('exr')) {
  for (const [f, h] of Object.entries(hangs)) {
    const norm = (n) => n.toLowerCase().replace(/_/g, '');
    const same = h.portHangs && JSON.stringify(h.upstream.map(norm)) === JSON.stringify(h.port.filter((n) => n !== 'decode' && !/^_M0/.test(n)).map(norm));
    cmp(`exr-hang ${f}`, 'hangs: ' + h.upstream.join(' < '), same ? 'hangs: ' + h.upstream.join(' < ') : JSON.stringify(h));
  }
  for (const file of exrFiles.filter((f) => !hangs[path.basename(f)])) {
    for (const [tn, type] of [['half', HalfFloatType], ['float', FloatType]]) {
      for (const [fn, format] of [['rgba', RGBAFormat], ['rg', RGFormat], ['red', RedFormat]]) {
        const parts = /multipart/.test(file) ? [0, 1, 5] : [0];
        for (const part of parts) {
          const up = new EXRLoader().setDataType(type).setOutputFormat(format).setPart(part);
          const a = await quiet(() => upstreamLoad(up, file));
          const b = await quiet(() => portLoad((done) => M.exr_load(file, type, format, part, done)));
          cmp(`exr ${file.startsWith(ex) ? path.relative(ex, file) : 'exr/' + path.basename(file)} ${tn} ${fn} part=${part}`, a, b);
        }
      }
    }
  }
}


// --- HDRCubeTextureLoader ---
if (!only || only.includes('cube')) {
  const dir = ex + 'textures/cube/pisaHDR/';
  const faces = ['px.hdr', 'nx.hdr', 'py.hdr', 'ny.hdr', 'pz.hdr', 'nz.hdr'];
  for (const [tn, type] of [['default', 0], ['half', HalfFloatType], ['float', FloatType]]) {
    const up = new HDRCubeTextureLoader().setPath(dir);
    if (type) up.setDataType(type);
    const a = await quiet(() => new Promise((resolve) => up.load(faces, (t) => resolve(env.describeTexture(t)), undefined, (e) => resolve(errJs(e)))));
    const b = await quiet(() => portLoad((done) => M.cube_load(dir, faces, type, done)));
    cmp(`cube pisaHDR ${tn}`, a, b);
  }
  // a missing face: onError, and onLoad never fires
  const bad = ['px.hdr', 'nx.hdr', 'missing.hdr', 'ny.hdr', 'pz.hdr', 'nz.hdr'];
  const a = await quiet(() => new Promise((resolve) => new HDRCubeTextureLoader().setPath(dir).load(bad, (t) => resolve('loaded'), undefined, (e) => resolve(errJs(e)))));
  const b = await quiet(() => portLoad((done) => M.cube_load(dir, bad, 0, done)));
  cmp('cube missing-face', a, b);
  // a corrupt face: the parse error thrown inside FileLoader's callback
  env.routes.set(dir + 'bad.hdr', new Uint8Array([35, 63, 82, 10, 10]));
  for (const faces2 of [['px.hdr', 'nx.hdr', 'bad.hdr', 'ny.hdr', 'pz.hdr', 'nz.hdr'], ['bad.hdr', 'bad.hdr', 'bad.hdr', 'bad.hdr', 'bad.hdr', 'bad.hdr']]) {
    rejections.length = 0;
    const a2 = await quiet(() => new Promise((resolve) => { const errs = []; setTimeout(() => resolve({ errs, timeout: true }), 500); new HDRCubeTextureLoader().setPath(dir).load(faces2, (t) => resolve({ loaded: env.describeTexture(t), errs }), undefined, (e) => { errs.push(errJs(e)); if (errs.length === faces2.filter((f) => f === 'bad.hdr').length) setTimeout(() => resolve({ errs }), 50); }); }));
    await new Promise((r) => setTimeout(r, 50)); a2.rejections = rejections.splice(0);
    const b2 = await quiet(() => new Promise((resolve) => { M.cube_load_errors(dir, faces2, (r) => resolve(r)); setTimeout(() => resolve({ errs: [], timeout: true }), 500); }));
    await new Promise((r) => setTimeout(r, 50)); b2.rejections = rejections.splice(0);
    cmp('cube corrupt-face ' + faces2.filter((f) => f === 'bad.hdr').length, a2, b2);
  }
}

// --- UltraHDR ---
if (!only || only.includes('ultra')) {
  const { UltraHDRLoader } = await import(ex + 'jsm/loaders/UltraHDRLoader.js');
  const jpgs = findFiles(ex + 'textures', /\.jpg$/i).filter((f) => fs.readFileSync(f).includes('hdrgm'));
  const synth = (await import('./ultra_synth.mjs')).build(jpgs[0]);
  const cases = [...jpgs.map((f) => [path.relative(ex, f), f]), ...Object.entries(synth).map(([k, bytes]) => { const url = 'mem://' + k; env.routes.set(url, bytes); return [k, url]; })];
  for (const scale of [1, 3]) {
    env.installUltra({ scale });
    for (const [name, url] of cases) {
      for (const [tn, type] of [['half', HalfFloatType], ['float', FloatType]]) {
        const run = async (start) => {
          env.bitmapLog.length = 0; rejections.length = 0;
          const r = await quiet(() => new Promise((resolve) => { start(resolve); setTimeout(() => resolve('no callback'), 1500); }));
          await new Promise((r) => setTimeout(r, 20));
          return { result: r, log: env.bitmapLog.slice(), rejections: rejections.slice() };
        };
        const a = await run((resolve) => { const l = new UltraHDRLoader(); l.setDataType(type); const t = l.load(url, (t, d) => resolve(globalThis.__describe(t, d)), undefined, (e) => resolve(errJs(e))); });
        const b = await run((resolve) => M.ultra_load(url, type, resolve));
        cmp(`ultra ${name} ${tn} scale=${scale}`, a, b);
      }
    }
  }
}

// corrupt and truncated files: corrupt_run.mjs (one process per load, with a time limit)

console.log(`\n${pass} identical, ${fail} mismatches`);
for (const [k, v] of Object.entries(stats)) console.log(`  ${k}: ${v.pass} ok, ${v.fail} bad`);
process.exit(fail ? 1 : 0);
