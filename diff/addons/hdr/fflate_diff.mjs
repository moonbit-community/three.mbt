// Differential test of @libs.unzlib_sync against the vendored fflate.module.js.
//   node fflate_diff.mjs [--build] [count]
import zlib from 'node:zlib';
import fs from 'node:fs';
import { execSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import { EX, HARNESS_URL, HERE } from './paths.mjs';
import { ensureExr } from './fixtures.mjs';
const here = HERE + '/';
if (process.argv.includes('--build')) execSync('moon build --target js', { cwd: here + 'mod', stdio: 'inherit' });
const M = await import(HARNESS_URL);
const F = await import(pathToFileURL(EX + 'jsm/libs/fflate.module.js').href);
const count = Number(process.argv.find((a) => /^\d+$/.test(a)) || 400);

let seed = 12345;
const rnd = () => { seed = (seed * 1103515245 + 12345) >>> 0; return seed / 4294967296; };
const ri = (n) => Math.floor(rnd() * n);

function run(f, d) {
  try { const r = f(d); return { ok: true, bytes: Buffer.from(r.buffer, r.byteOffset, r.byteLength).toString('base64'), len: r.length, bl: r.buffer.byteLength, off: r.byteOffset }; }
  catch (e) { return { ok: false, msg: String(e && e.message), code: e && e.code, name: e && e.name }; }
}
let pass = 0, fail = 0; const kinds = {};
function check(label, data) {
  const a = run(F.unzlibSync, data.slice());
  const b = run(M.unzlib, data.slice());
  const ja = JSON.stringify(a), jb = JSON.stringify(b);
  const k = a.ok ? 'ok' : 'err:' + a.msg;
  kinds[k] = (kinds[k] || 0) + 1;
  if (ja === jb) pass++; else { fail++; if (fail < 10) console.log('MISMATCH', label, ja.slice(0, 300), jb.slice(0, 300)); }
}
function randomData(n) {
  const mode = ri(4); const d = new Uint8Array(n);
  for (let i = 0; i < n; i++) d[i] = mode === 0 ? ri(256) : mode === 1 ? ri(4) : mode === 2 ? (i % 251) ^ ri(2) : (i > 10 && rnd() < 0.7 ? d[i - 1 - ri(10)] : ri(256));
  return d;
}
const streams = [];
for (let t = 0; t < count; t++) {
  const n = [0, 1, 5, 100, 1000, 70000, 300000][ri(7)];
  const d = randomData(n);
  const opts = { level: ri(10), strategy: [0, 1, 2, 3, 4][ri(5)], memLevel: 1 + ri(9), windowBits: 9 + ri(7) };
  let c;
  if (rnd() < 0.2) c = F.zlibSync(d, { level: ri(10) }); else c = new Uint8Array(zlib.deflateSync(d, opts));
  streams.push(c);
  check('valid#' + t, c);
}
// real zlib streams: the chunks of ZIP/ZIPS/PXR24 scanline EXRs (every chunk whose size
// is below the raw size is a zlib stream)
const exrHeaderEnd = (b) => { let o = 8; const dv = new DataView(b.buffer, b.byteOffset); const z = () => { while (b[o] !== 0) o++; o++; }; for (;;) { if (b[o] === 0) return o + 1; z(); z(); o += 4 + dv.getUint32(o, true); } };
let real = 0;
const exrDir = ensureExr() + '/';
const realFiles = [EX + 'textures/matcaps/040full.exr', ...fs.readdirSync(exrDir).filter((f) => /\.(zip|zips|pxr24)\.|gen_zips?\./.test(f)).sort().map((f) => exrDir + f)];
for (const f of realFiles) {
  const b = new Uint8Array(fs.readFileSync(f));
  const dv = new DataView(b.buffer, b.byteOffset);
  let o = exrHeaderEnd(b);
  const first = Number(dv.getBigInt64(o, true));
  const count = (first - o) / 8;
  for (let i = 0; i < count; i++) {
    const co = Number(dv.getBigInt64(o + i * 8, true));
    const size = dv.getUint32(co + 4, true);
    const chunk = b.slice(co + 8, co + 8 + size);
    if (chunk[0] === 0x78) { check('real ' + f.split('/').pop() + '#' + i, chunk); real++; streams.push(chunk); }
  }
}
console.log('real zlib chunks:', real);
// options: out buffer (exact, short, long) and dictionary
for (let t = 0; t < 60; t++) {
  const d = randomData([10, 500, 5000][ri(3)]);
  const dict = randomData(1 + ri(300));
  const withDict = new Uint8Array(zlib.deflateSync(d, { dictionary: dict, level: ri(10) }));
  const plain = new Uint8Array(zlib.deflateSync(d));
  const runOpts = (data, out, dictionary) => {
    const a = run((x) => F.unzlibSync(x, { out: out && out.slice(), dictionary }), data);
    const b = run((x) => M.unzlib_opts(x, out ? out.slice() : undefined, dictionary), data);
    const ja = JSON.stringify(a), jb = JSON.stringify(b);
    if (ja === jb) pass++; else { fail++; console.log('MISMATCH opts', t, ja.slice(0, 200), jb.slice(0, 200)); }
    const k = 'opts:' + (a.ok ? 'ok' : a.msg); kinds[k] = (kinds[k] || 0) + 1;
  };
  runOpts(withDict, undefined, dict);
  runOpts(withDict, undefined, undefined);
  runOpts(plain, undefined, dict);
  runOpts(plain, new Uint8Array(d.length), undefined);
  runOpts(plain, new Uint8Array(d.length + 7), undefined);
  runOpts(plain, new Uint8Array(Math.max(0, d.length - 3)), undefined);
  runOpts(withDict, new Uint8Array(d.length), dict);
  const bad = withDict.slice(); bad[2 + 4 + ri(Math.max(1, bad.length - 10))] ^= 1 << ri(8);
  runOpts(bad, undefined, dict);
}
// corrupt streams
for (let t = 0; t < count * 3; t++) {
  const c = streams[ri(streams.length)].slice();
  const kind = ri(6);
  let d = c;
  if (kind === 0) d = c.slice(0, ri(c.length + 1));
  else if (kind === 1) { for (let k = 0; k < 1 + ri(4); k++) if (c.length) c[ri(c.length)] ^= 1 << ri(8); }
  else if (kind === 2) { for (let k = 2; k < c.length; k++) if (rnd() < 0.05) c[k] = ri(256); }
  else if (kind === 3) { d = new Uint8Array(ri(200)); for (let k = 0; k < d.length; k++) d[k] = ri(256); if (d.length > 1 && rnd() < 0.7) { d[0] = 0x78; d[1] = 0x9c; } }
  else if (kind === 4) { if (c.length > 1) { c[1] ^= 0x20; } }
  else { d = c.slice(0, Math.max(0, c.length - 4 - ri(8))); }
  check('corrupt#' + t + '/' + kind, d);
}
console.log(`fflate: ${pass} identical, ${fail} mismatches`);
console.log(kinds);
process.exit(fail ? 1 : 0);
