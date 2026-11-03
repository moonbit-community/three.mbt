// Writes the EXR fixtures of the differential run into OUT/addons_hdr/exr:
//  - base scanline files written here (NO_COMPRESSION, plus RLE/ZIPS/ZIP written here
//    too), with odd sizes, offset data windows and unusual channel layouts;
//  - every compression (none..dwab) and pixel mode via OpenEXR's `exrmetrics --convert`;
//  - tiled (one level / mipmap, round down / up) via `exrmaketiled`;
//  - multi-part via `exrmultipart -combine`;
//  - deep scanline (NO/RLE/ZIPS, single and multi part) written here;
//  - two DWA files rewritten to DEFLATE AC data (gen_dwa_deflate.mjs).
//
//   node gen_exr.mjs [--out dir]         unpack all 415 files from fixtures/exr.tar.xz
//   node gen_exr.mjs --openexr [--pack]  regenerate them: write the Node-written files and
//                                        run the OpenEXR CLI (exrmetrics, exrmaketiled,
//                                        exrmultipart; OpenEXR >= 3.3, e.g. Homebrew
//                                        `openexr`); --pack rewrites the archive
// The archive holds every file (78 Node-written, 337 OpenEXR-written). The Node-written
// ones are committed too because their ZIP/ZIPS chunks come from node:zlib, whose output
// differs between Node versions (Node 22 stores 15 fewer chunks compressed than Node 25,
// which the archive was made with), and the fflate check counts those chunks.
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { execFileSync } from 'node:child_process';
import { EXR_DIR, HERE } from './paths.mjs';

const argv = process.argv.slice(2);
const useTools = argv.includes('--openexr');
const pack = argv.includes('--pack');
const ARCHIVE = path.join(HERE, 'fixtures/exr.tar.xz');
const out = (argv.includes('--out') ? path.resolve(argv[argv.indexOf('--out') + 1]) : EXR_DIR) + '/';
fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(out, { recursive: true });
if (!useTools) {
  execFileSync('tar', ['-xJf', ARCHIVE, '-C', out], { stdio: 'inherit' });
  console.log('unpacked', fs.readdirSync(out).filter((f) => f.endsWith('.exr')).length, 'files to', out);
  process.exit(0);
}
const toolOutputs = [];

let seed = 7;
const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };

const f32 = new Float32Array(1), u32 = new Uint32Array(f32.buffer);
function toHalf(v) { // round-to-nearest-even float -> half
  f32[0] = v; const x = u32[0]; const sign = (x >>> 16) & 0x8000; const a = x & 0x7fffffff;
  if (a >= 0x47800000) return sign | (a > 0x7f800000 ? 0x7e00 : 0x7c00);
  if (a < 0x38800000) { f32[0] = Math.abs(v) + 0.5; return sign | (u32[0] - 0x3f000000); }
  return sign | (((a + 0xfff + ((a >>> 13) & 1)) - 0x38000000) >>> 13);
}

class W {
  constructor() { this.b = []; }
  u8(v) { this.b.push(v & 255); }
  bytes(a) { for (const v of a) this.b.push(v & 255); }
  i32(v) { const d = new DataView(new ArrayBuffer(4)); d.setInt32(0, v, true); this.bytes(new Uint8Array(d.buffer)); }
  u32(v) { const d = new DataView(new ArrayBuffer(4)); d.setUint32(0, v, true); this.bytes(new Uint8Array(d.buffer)); }
  f32(v) { const d = new DataView(new ArrayBuffer(4)); d.setFloat32(0, v, true); this.bytes(new Uint8Array(d.buffer)); }
  i64(v) { const d = new DataView(new ArrayBuffer(8)); d.setBigInt64(0, BigInt(v), true); this.bytes(new Uint8Array(d.buffer)); }
  str(s) { this.bytes(new TextEncoder().encode(s)); this.u8(0); }
  get length() { return this.b.length; }
  patchI64(pos, v) { const d = new DataView(new ArrayBuffer(8)); d.setBigInt64(0, BigInt(v), true); const a = new Uint8Array(d.buffer); for (let i = 0; i < 8; i++) this.b[pos + i] = a[i]; }
}

function attr(w, name, type, writeValue) {
  w.str(name); w.str(type);
  const v = new W(); writeValue(v);
  w.u32(v.length); w.bytes(v.b);
}
const compressionCode = { none: 0, rle: 1, zips: 2, zip: 3 };

function writeHeader(w, h) {
  attr(w, 'channels', 'chlist', (v) => {
    for (const c of h.channels) { v.str(c.name); v.i32(c.type); v.u8(c.pLinear || 0); v.u8(0); v.u8(0); v.u8(0); v.i32(c.xs || 1); v.i32(c.ys || 1); }
    v.u8(0);
  });
  attr(w, 'compression', 'compression', (v) => v.u8(compressionCode[h.compression]));
  attr(w, 'dataWindow', 'box2i', (v) => { v.i32(h.xMin); v.i32(h.yMin); v.i32(h.xMin + h.width - 1); v.i32(h.yMin + h.height - 1); });
  attr(w, 'displayWindow', 'box2i', (v) => { v.i32(0); v.i32(0); v.i32(63); v.i32(63); });
  attr(w, 'lineOrder', 'lineOrder', (v) => v.u8(0));
  attr(w, 'pixelAspectRatio', 'float', (v) => v.f32(1));
  attr(w, 'screenWindowCenter', 'v2f', (v) => { v.f32(0); v.f32(0); });
  attr(w, 'screenWindowWidth', 'float', (v) => v.f32(1));
  for (const [name, type, fn] of h.extra || []) attr(w, name, type, fn);
  if (h.name !== undefined) attr(w, 'name', 'string', (v) => v.bytes(new TextEncoder().encode(h.name)));
  if (h.type !== undefined) attr(w, 'type', 'string', (v) => v.bytes(new TextEncoder().encode(h.type)));
  if (h.chunkCount !== undefined) attr(w, 'chunkCount', 'int', (v) => v.i32(h.chunkCount));
  if (h.deep) { attr(w, 'version', 'int', (v) => v.i32(1)); attr(w, 'maxSamplesPerPixel', 'int', (v) => v.i32(h.maxSamples)); }
  w.u8(0);
}

function value(kind, x, y, c) {
  const r = rnd();
  switch (kind) {
    case 'smooth': return Math.sin(x * 0.21 + c) * Math.cos(y * 0.13) * 2 + 0.5;
    case 'wild': return r < 0.05 ? [Infinity, -Infinity, NaN, 1e-7, -0, 70000, -70000, 6e-5][Math.floor(rnd() * 8)] : (r - 0.3) * 40 * Math.pow(2, Math.floor(rnd() * 10) - 5);
    case 'ramp': { const k = Math.min(0x7bff, x + y * 600 + c * 3000 + (r < 0.1 ? 1 : 0)); const e = k >> 10, m = k & 1023; return e === 0 ? m * 2 ** -24 : (1 + m / 1024) * 2 ** (e - 15); }
    case 'flat': return ((x >> 2) + (y >> 2)) % 3 * 0.25;
    default: return r;
  }
}

// sample storage for one channel line: bytes
function sampleBytes(type, v) {
  const d = new DataView(new ArrayBuffer(4));
  if (type === 0) { d.setUint32(0, Math.abs(Math.floor(v * 1000)) >>> 0, true); return [...new Uint8Array(d.buffer)]; }
  if (type === 1) { d.setUint16(0, toHalf(v), true); return [...new Uint8Array(d.buffer, 0, 2)]; }
  d.setFloat32(0, v, true); return [...new Uint8Array(d.buffer)];
}

// OpenEXR zip/rle preprocessing: split into even/odd halves, then delta + 128.
function preprocess(raw) {
  const t = new Uint8Array(raw.length);
  let t1 = 0, t2 = Math.floor((raw.length + 1) / 2);
  for (let i = 0; i < raw.length; i++) { if (i % 2 === 0) t[t1++] = raw[i]; else t[t2++] = raw[i]; }
  const d = new Uint8Array(raw.length);
  let p = t[0];
  if (raw.length) d[0] = t[0];
  for (let i = 1; i < raw.length; i++) { d[i] = (t[i] - p + 128 + 256) & 255; p = t[i]; }
  return d;
}
function rleEncode(data) {
  const o = []; let i = 0;
  while (i < data.length) {
    let run = 1;
    while (i + run < data.length && data[i + run] === data[i] && run < 128) run++;
    if (run >= 3) { o.push(run - 1, data[i]); i += run; continue; }
    let j = i; const lit = [];
    while (j < data.length && lit.length < 127 && !(j + 2 < data.length && data[j] === data[j + 1] && data[j] === data[j + 2])) lit.push(data[j++]);
    o.push((-lit.length) & 255, ...lit); i = j;
  }
  return o;
}
function compressBlock(compression, raw) {
  if (compression === 'none') return raw;
  const pre = preprocess(raw);
  if (compression === 'rle') return rleEncode(pre);
  return [...zlib.deflateSync(pre)];
}
const linesPerBlock = { none: 1, rle: 1, zips: 1, zip: 16 };

// Writes a single-part scanline file (or returns the part for a multi-part writer).
function scanlinePart(h) {
  const blocks = [];
  const lpb = linesPerBlock[h.compression];
  const vals = h.channels.map((c, ci) => { const a = []; for (let y = 0; y < h.height; y++) for (let x = 0; x < h.width; x++) a.push(value(c.kind || h.kind, x, y, ci)); return a; });
  for (let y0 = 0; y0 < h.height; y0 += lpb) {
    const raw = [];
    for (let y = y0; y < Math.min(h.height, y0 + lpb); y++) {
      for (let ci = 0; ci < h.channels.length; ci++) {
        const c = h.channels[ci];
        if (((y + h.yMin) % (c.ys || 1)) !== 0) continue;
        for (let x = 0; x < h.width; x += (c.xs || 1)) raw.push(...sampleBytes(c.type, vals[ci][y * h.width + x]));
      }
    }
    let data = compressBlock(h.compression, raw);
    if (data.length >= raw.length) data = raw;
    blocks.push({ y: y0 + h.yMin, data });
  }
  return blocks;
}

function writeScanline(file, h) {
  const w = new W();
  w.u32(20000630); w.u8(2); w.u8(0); w.u8(0); w.u8(0);
  writeHeader(w, h);
  const blocks = scanlinePart(h);
  const tablePos = w.length;
  for (const b of blocks) w.i64(0);
  blocks.forEach((b, i) => { w.patchI64(tablePos + i * 8, w.length); w.i32(b.y); w.u32(b.data.length); w.bytes(b.data); });
  fs.writeFileSync(file, new Uint8Array(w.b));
}

function writeMultipart(file, parts, deep) {
  const w = new W();
  w.u32(20000630); w.u8(2); w.u8(deep ? 8 | 16 : 16); w.u8(0); w.u8(0);
  const chunks = parts.map((h) => (h.deep ? deepChunks(h) : scanlinePart(h)));
  parts.forEach((h, i) => { h.chunkCount = chunks[i].length; writeHeader(w, h); });
  w.u8(0);
  const tables = parts.map((h, i) => { const pos = w.length; for (const c of chunks[i]) w.i64(0); return pos; });
  parts.forEach((h, pi) => chunks[pi].forEach((b, i) => {
    w.patchI64(tables[pi] + i * 8, w.length);
    w.i32(pi);
    if (h.deep) writeDeepChunk(w, b); else { w.i32(b.y); w.u32(b.data.length); w.bytes(b.data); }
  }));
  fs.writeFileSync(file, new Uint8Array(w.b));
}

// Deep scanline: one line per chunk, cumulative sample counts then per-channel samples.
function deepChunks(h) {
  const chunks = [];
  for (let y = 0; y < h.height; y++) {
    const counts = []; let total = 0;
    for (let x = 0; x < h.width; x++) { total += (x + y) % 4 === 3 ? 0 : 1 + Math.floor(rnd() * h.maxSamples); counts.push(total); }
    const sct = []; for (const c of counts) sct.push(...new Uint8Array(new Uint32Array([c]).buffer));
    const data = [];
    for (let ci = 0; ci < h.channels.length; ci++) {
      const c = h.channels[ci];
      for (let s = 0; s < total; s++) data.push(...sampleBytes(c.type, c.name === 'A' ? rnd() * 0.9 : value(h.kind, s, y, ci)));
    }
    const pack = (raw) => { if (h.compression === 'none') return raw; const d = compressBlock(h.compression, raw); return d.length >= raw.length ? raw : d; };
    chunks.push({ y: y + h.yMin, sct: pack(sct), data: pack(data), rawData: data.length });
  }
  return chunks;
}
function writeDeepChunk(w, b) { w.i32(b.y); w.i64(b.sct.length); w.i64(b.data.length); w.i64(b.rawData); w.bytes(b.sct); w.bytes(b.data); }
function writeDeep(file, h) {
  const w = new W();
  w.u32(20000630); w.u8(2); w.u8(8); w.u8(0); w.u8(0);
  const chunks = deepChunks(h);
  h.chunkCount = chunks.length;
  writeHeader(w, h);
  const tablePos = w.length;
  for (const c of chunks) w.i64(0);
  chunks.forEach((b, i) => { w.patchI64(tablePos + i * 8, w.length); writeDeepChunk(w, b); });
  fs.writeFileSync(file, new Uint8Array(w.b));
}

const H = 1, F = 2, U = 0;
const ch = (names, type, extra = {}) => names.map((name) => ({ name, type, ...extra }));
const extraAttrs = [
  ['comments', 'string', (v) => v.bytes(new TextEncoder().encode('fixture ü'))],
  ['chromaticities', 'chromaticities', (v) => { for (const f of [0.64, 0.33, 0.3, 0.6, 0.15, 0.06, 0.3127, 0.329]) v.f32(f); }],
  ['envmap', 'envmap', (v) => v.u8(0)],
  ['frames', 'rational', (v) => { v.i32(-24); v.u32(1001); }],
  ['timeCode', 'timecode', (v) => { v.u32(0x12345678); v.u32(0xdeadbeef); }],
  ['worldPos', 'v3f', (v) => { v.f32(1.5); v.f32(-2); v.f32(3.25); }],
  ['bogus', 'm44f', (v) => { for (let i = 0; i < 16; i++) v.f32(i); }],
  ['preview', 'preview', (v) => { v.u32(1); v.u32(1); v.bytes([1, 2, 3, 4]); }],
  ['badEnv', 'envmap', (v) => v.u8(7)],
];
const bases = {
  rgba_half: { channels: ch(['A', 'B', 'G', 'R'], H), width: 37, height: 23, xMin: 0, yMin: 0, kind: 'smooth' },
  rgb_float: { channels: ch(['B', 'G', 'R'], F), width: 40, height: 33, xMin: 3, yMin: -5, kind: 'wild' },
  rgb_half_big: { channels: ch(['B', 'G', 'R'], H), width: 301, height: 70, xMin: 0, yMin: 0, kind: 'smooth' },
  rgba_mixed: { channels: [{ name: 'A', type: H }, { name: 'B', type: F }, { name: 'G', type: H }, { name: 'R', type: F }], width: 19, height: 17, xMin: 0, yMin: 0, kind: 'random' },
  y_half: { channels: ch(['Y'], H), width: 33, height: 40, xMin: 0, yMin: 0, kind: 'smooth' },
  y_float: { channels: ch(['Y'], F), width: 25, height: 9, xMin: -2, yMin: 4, kind: 'wild' },
  ya_half: { channels: [...ch(['A'], H), ...ch(['Y'], H)], width: 21, height: 18, xMin: 0, yMin: 0, kind: 'smooth' },
  yc_sub: { channels: [{ name: 'BY', type: H, xs: 2, ys: 2 }, { name: 'RY', type: H, xs: 2, ys: 2 }, { name: 'Y', type: H }], width: 24, height: 16, xMin: 0, yMin: 0, kind: 'smooth' },
  yc_full: { channels: ch(['BY', 'RY', 'Y'], H), width: 18, height: 21, xMin: 0, yMin: 0, kind: 'smooth' },
  rgb_uint_extra: { channels: [...ch(['B', 'G', 'R'], H), { name: 'id', type: U }], width: 17, height: 12, xMin: 0, yMin: 0, kind: 'smooth' },
  rgb_plinear: { channels: ch(['B', 'G', 'R'], H, { pLinear: 1 }), width: 20, height: 20, xMin: 0, yMin: 0, kind: 'smooth' },
  rg_only: { channels: ch(['G', 'R'], H), width: 8, height: 8, xMin: 0, yMin: 0, kind: 'smooth' },
  rgb_flat: { channels: ch(['B', 'G', 'R'], H), width: 32, height: 32, xMin: 0, yMin: 0, kind: 'flat' },
  rgb_attrs: { channels: ch(['B', 'G', 'R'], H), width: 9, height: 7, xMin: 0, yMin: 0, kind: 'smooth', extra: extraAttrs },
  rgb_ramp_big: { channels: ch(['B', 'G', 'R'], H), width: 600, height: 40, xMin: 0, yMin: 0, kind: 'ramp' },
  rgb_flat_big: { channels: ch(['B', 'G', 'R'], H), width: 256, height: 64, xMin: 0, yMin: 0, kind: 'flat' },
  layered: { channels: [...ch(['B', 'G', 'R'], H), ...ch(['diffuse.B', 'diffuse.G', 'diffuse.R'], H)], width: 16, height: 10, xMin: 0, yMin: 0, kind: 'smooth' },
};
// An OpenEXR CLI call writing `file`.
const exr = (args, file) => {
  toolOutputs.push(path.basename(file));
  execFileSync(args[0], args.slice(1), { stdio: 'pipe' });
};
const produced = [];
for (const [name, h] of Object.entries(bases)) {
  for (const c of ['none', 'rle', 'zips', 'zip']) {
    const f = `${out}${name}.gen_${c}.exr`;
    writeScanline(f, { ...h, compression: c });
    produced.push(f);
  }
  const base = `${out}${name}.gen_none.exr`;
  for (const z of ['none', 'rle', 'zips', 'zip', 'piz', 'pxr24', 'b44', 'b44a', 'dwaa', 'dwab']) {
    for (const mode of ['orig', 'half', 'float']) {
      if (mode !== 'orig' && !['rgb_half_big', 'y_half', 'rgba_half', 'yc_full'].includes(name)) continue;
      const f = `${out}${name}.${z}.${mode}.exr`;
      try { exr(['exrmetrics', '--convert', '--pixelmode', mode, '-z', z, base, '-o', f], f); produced.push(f); }
      catch (e) { console.log('exrmetrics failed', name, z, mode, String(e.stderr).slice(0, 200)); }
    }
  }
}
// tiled
for (const name of ['rgba_half', 'rgb_float', 'y_half', 'rgb_half_big']) {
  const base = `${out}${name}.gen_none.exr`;
  for (const [tag, opts] of [['one', ['-o']], ['mip_down', ['-m', '-d']], ['mip_up', ['-m', '-u']]]) {
    for (const z of ['none', 'zip', 'piz', 'b44a', 'dwaa', 'rle', 'pxr24']) {
      const f = `${out}${name}.tiled_${tag}_${z}.exr`;
      try { exr(['exrmaketiled', ...opts, '-t', '16', '8', '-z', z, base, f], f); produced.push(f); }
      catch (e) { console.log('exrmaketiled failed', name, tag, z, String(e.stderr).slice(0, 200)); }
    }
  }
}
try { exr(['exrmaketiled', '-r', '-z', 'zip', `${out}rgba_half.gen_none.exr`, `${out}rgba_half.tiled_ripmap.exr`], `${out}rgba_half.tiled_ripmap.exr`); } catch (e) { console.log('ripmap failed'); }
// multi-part
for (const [tag, files] of [['mp_two', ['rgba_half.zip.orig', 'y_half.piz.orig']], ['mp_three', ['rgb_float.gen_zips', 'rgba_half.dwaa.orig', 'yc_full.b44.orig']]]) {
  const f = `${out}${tag}.multipart.exr`;
  try { exr(['exrmultipart', '-combine', '-i', ...files.map((n, i) => `${out}${n}.exr::part${i}`), '-o', f, '-override', '1'], f); }
  catch (e) { console.log('exrmultipart failed', tag, String(e.stderr).slice(0, 300)); }
}
writeMultipart(`${out}mp_gen.multipart.exr`, [
  { ...bases.rgba_half, compression: 'zips', name: 'a', type: 'scanlineimage' },
  { ...bases.y_float, compression: 'rle', name: 'b', type: 'scanlineimage' },
]);
// deep
const deepBase = { channels: [...ch(['A', 'B', 'G', 'R'], H), { name: 'Z', type: F }], width: 13, height: 9, xMin: 0, yMin: 0, kind: 'smooth', deep: true, maxSamples: 3, type: 'deepscanline' };
for (const c of ['none', 'rle', 'zips']) writeDeep(`${out}deep_rgba.${c}.exr`, { ...deepBase, compression: c });
writeDeep(`${out}deep_rgb_float.zips.exr`, { ...deepBase, channels: ch(['B', 'G', 'R'], F), compression: 'zips' });
writeDeep(`${out}deep_y.none.exr`, { ...deepBase, channels: [...ch(['A'], F), ...ch(['Y'], H)], compression: 'none' });
writeDeep(`${out}deep_zip.zip.exr`, { ...deepBase, compression: 'zip' });
writeMultipart(`${out}deep_mp.multipart.exr`, [
  { ...deepBase, compression: 'zips', name: 'd0' },
  { ...deepBase, channels: ch(['B', 'G', 'R'], H), compression: 'rle', name: 'd1' },
], true);
// DWA with DEFLATE-compressed AC data (OpenEXR writes STATIC_HUFFMAN only)
for (const f of ['rgb_flat.dwaa.orig', 'rgb_flat.dwab.orig']) execFileSync('node', [path.join(HERE, 'gen_dwa_deflate.mjs'), `${out}${f}.exr`, `${out}${f}.acdeflate.exr`], { stdio: 'pipe' });
if (pack) {
  fs.mkdirSync(path.dirname(ARCHIVE), { recursive: true });
  const list = path.join(out, '.openexr_files');
  fs.writeFileSync(list, fs.readdirSync(out).filter((f) => f.endsWith('.exr')).sort().join('\n') + '\n');
  // plain ustar entries (no macOS xattrs / AppleDouble files, numeric owner 0)
  const bsd = /bsdtar/.test(execFileSync('tar', ['--version'], { encoding: 'utf8' }));
  const flags = bsd ? '--no-mac-metadata --no-xattrs --format ustar --uid 0 --gid 0' : '--format ustar --owner 0 --group 0 --numeric-owner';
  execFileSync('sh', ['-c', `COPYFILE_DISABLE=1 tar ${flags} -cf - -C "${out}" -T "${list}" | xz -9e > "${ARCHIVE}"`], { stdio: 'inherit' });
  fs.rmSync(list);
  console.log('packed', fs.readdirSync(out).filter((f) => f.endsWith('.exr')).length, 'files into', path.relative(process.cwd(), ARCHIVE));
}
console.log('wrote', fs.readdirSync(out).filter((f) => f.endsWith('.exr')).length, 'files to', out);
