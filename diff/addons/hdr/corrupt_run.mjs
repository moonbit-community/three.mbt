// Truncated and corrupted HDR/EXR files, each load in its own process on both sides
// (a corrupt size can make upstream loop for minutes; such cases are compared by the
// interrupted stack instead).
//   node corrupt_run.mjs [--limit-ms 20000] [--jobs 8] [--every N] [--filter re]
// The inputs are derived from upstream's examples and the generated EXRs and written to
// OUT/addons_hdr/corrupt. --every N runs every N-th case only (the fast default check).
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { CORRUPT_DIR, EX, HERE } from './paths.mjs';
import { ensureExr } from './fixtures.mjs';
const here = HERE;
const args = process.argv.slice(2);
const limit = Number(args.includes('--limit-ms') ? args[args.indexOf('--limit-ms') + 1] : 20000);
const jobs = Number(args.includes('--jobs') ? args[args.indexOf('--jobs') + 1] : Math.min(8, os.availableParallelism()));
const every = Number(args.includes('--every') ? args[args.indexOf('--every') + 1] : 1);
const filter = args.includes('--filter') ? new RegExp(args[args.indexOf('--filter') + 1]) : null;
const ex = EX;
const exrDir = ensureExr();
const dir = CORRUPT_DIR;
fs.rmSync(dir, { recursive: true, force: true }); fs.mkdirSync(dir, { recursive: true });
let seed = 99;
const rnd = () => { seed = (seed * 1103515245 + 12345) >>> 0; return seed / 4294967296; };
const variants = (bytes, headerEnd, n) => {
  const out = [];
  for (const f of [0, 0.25, 0.5, 0.9, 0.999]) { const len = Math.max(headerEnd, Math.floor(bytes.length * f)); out.push(['trunc' + len, bytes.slice(0, len)]); }
  out.push(['trunc-header+1', bytes.slice(0, headerEnd + 1)], ['trunc-1', bytes.slice(0, bytes.length - 1)]);
  for (let k = 0; k < n; k++) {
    const c = bytes.slice();
    const flips = 1 + Math.floor(rnd() * 6);
    for (let j = 0; j < flips; j++) { const i = headerEnd + Math.floor(rnd() * (c.length - headerEnd)); c[i] = rnd() < 0.5 ? c[i] ^ (1 << Math.floor(rnd() * 8)) : Math.floor(rnd() * 256); }
    out.push(['flip' + k, c]);
  }
  return out;
};
const cases = [];
const picked = (i, name) => i % every === 0 && (!filter || filter.test(name));
const add = (kind, name, data, type, format = 1023) => { const f = `${dir}/${name}`; if (picked(cases.length, name)) fs.writeFileSync(f, data); cases.push({ kind, file: f, type, format }); };
// HDR
for (const file of ['textures/equirectangular/spot1Lux.hdr', 'textures/memorial.hdr', 'textures/cube/pisaHDR/px.hdr', 'textures/equirectangular/lobe.hdr'].map((f) => ex + f)) {
  const bytes = new Uint8Array(fs.readFileSync(file));
  const headerEnd = bytes.indexOf(10, bytes.indexOf(0x2b)) + 1;
  const vs = variants(bytes, headerEnd, 12);
  const text = new TextDecoder('latin1').decode(bytes.slice(0, headerEnd));
  const hv = (t) => new Uint8Array([...new TextEncoder().encode(t), ...bytes.slice(headerEnd)]);
  vs.push(['no-magic', hv(text.replace('#?', '#!'))], ['no-format', hv(text.replace(/FORMAT=\S+\n/, ''))], ['no-size', hv(text.replace(/-Y \d+ \+X \d+\n/, 'junk\n'))],
    ['empty', new Uint8Array(0)], ['newline-first', hv('\n' + text)], ['gamma', hv(text.replace('FORMAT', 'GAMMA=2.2\nEXPOSURE=0.5\nFORMAT'))], ['narrow', hv(text.replace(/\+X (\d+)/, '+X 7'))],
    ['wide', hv(text.replace(/\+X (\d+)/, (m, w) => '+X ' + (Number(w) + 1)))], ['tall', hv(text.replace(/-Y (\d+)/, (m, h) => '-Y ' + (Number(h) + 3)))], ['long-line', hv('#?RADIANCE\n' + 'x'.repeat(3000) + '\n' + text.slice(11))], ['header-only', bytes.slice(0, headerEnd)]);
  for (const [vn, data] of vs) for (const type of [1016, 1015]) add('hdr', `${path.basename(file)}.${vn}.${type}`, data, type);
}
// EXR: corrupt only after the attribute list (a corrupt header can make upstream's
// parseNullTerminatedString loop forever)
const exrHeaderEnd = (b) => { let o = 8; const dv = new DataView(b.buffer); const z = () => { while (b[o] !== 0) o++; o++; }; for (;;) { if (b[o] === 0) return o + 1; z(); z(); const sz = dv.getUint32(o, true); o += 4 + sz; } };
const exrs = fs.readdirSync(exrDir).sort().filter((f) => /^(rgb_half_big|rgba_half|y_half|yc_sub|yc_full|rgb_plinear|rgb_float|rgba_mixed|deep_rgba|deep_y|deep_mp|mp_gen)\.(none|rle|zips|zip|piz|pxr24|b44|b44a|dwaa|dwab|gen_\w+|tiled_one_\w+|tiled_mip_down_\w+|multipart)\.?(orig|half)?\.?exr$/.test(f) && !/yc_sub\.dwa/.test(f));
const exrPaths = [...exrs.map((f) => path.join(exrDir, f)), ex + 'textures/memorial.exr'];
for (const name of exrPaths) {
  const bytes = new Uint8Array(fs.readFileSync(name));
  const he = exrHeaderEnd(bytes);
  for (const [vn, data] of variants(bytes, he, /big|memorial/.test(name) ? 4 : 2)) add('exr', `${path.basename(name)}.${vn}`, data, vn.length % 2 ? 1016 : 1015);
}
// EXR header-level cases
const base = new Uint8Array(fs.readFileSync(exrDir + '/rgba_half.gen_none.exr'));
const patch = (pat, f) => { const c = base.slice(); const i = new TextDecoder('latin1').decode(c).indexOf(pat); f(c, i); return c; };
const hcases = {
  empty: new Uint8Array(0), short: base.slice(0, 3), magic: patch('', (c) => { c[0] ^= 1; }), headerOnly: base.slice(0, exrHeaderEnd(base)),
  badCompression: patch('compression\0compression\0', (c, i) => { c[i + 24 + 4] = 42; }),
  noChannels: patch('chlist\0', (c, i) => { c[i + 11] = 0x51; c[i + 11 + 18] = 0x52; }),
  pixelType7: patch('chlist\0', (c, i) => { c[i + 13] = 7; c[i + 31] = 7; c[i + 49] = 7; c[i + 67] = 7; }),
  multipartFlag: patch('', (c) => { c[5] |= 16; }),
  tiledFlagNoTiles: patch('', (c) => { c[5] |= 2; }),
  deepFlag: patch('', (c) => { c[5] |= 8; }),
};
for (const [vn, data] of Object.entries(hcases)) add('exr', `header.${vn}`, data, 1016);
for (const [tag, type, format] of [['ubyte', 1009, 1023], ['rgbformat', 1016, 1022], ['alpha', 1015, 1021]]) add('exr', `opts.${tag}`, fs.readFileSync(exrDir + '/rgba_half.gen_zip.exr'), type, format);
add('exr', 'opts.ripmap', fs.readFileSync(exrDir + '/rgba_half.tiled_ripmap.exr'), 1016);
add('exr', 'opts.deepzip', fs.readFileSync(exrDir + '/deep_zip.zip.exr'), 1016);
add('exr', 'opts.rgonly', fs.readFileSync(exrDir + '/rg_only.gen_zip.exr'), 1016);

const runOne = (side, c) => new Promise((resolve) => {
  const p = spawn('node', ['--trace-sigint', here + '/case.mjs', side, c.kind, c.file, String(c.type), String(c.format)], { stdio: ['ignore', 'pipe', 'pipe'] });
  let out = '', err = '', timedOut = false;
  p.stdout.on('data', (d) => (out += d)); p.stderr.on('data', (d) => (err += d));
  const t = setTimeout(() => { timedOut = true; p.kill('SIGINT'); }, limit);
  p.on('close', () => {
    clearTimeout(t);
    if (timedOut) {
      // the loader's own frames only (an interrupt can land inside a typed-array accessor)
      const names = [...err.matchAll(/^\s+at (\S+) \((\S+)\)/gm)]
        .filter((m) => /(EXRLoader|HDRLoader)\.js/.test(m[2]) || /addons\d+loaders\d+(exr|hdr)__|addons\d+loaders\d+ExrParse/.test(m[1]))
        .map((m) => m[1].replace(/^_M0\w*?(?:addons\d+loaders\d+(?:exr__|hdr__)|ExrParse\d+)/, '').replace(/^\d+/, '').toLowerCase().replace(/_/g, ''))
        .filter((n) => !/^decode$|^parse$/.test(n));
      resolve({ timeout: names.slice(0, 8) });
    } else resolve(out.trim().split('\n').pop() || ('no output: ' + err.split('\n').slice(0, 3).join(' ')));
  });
});
// Where the SIGINT lands is timing-dependent: one side can be interrupted inside a small
// helper the other side was not in at that moment (port `get_code` under `huf_decode`).
// Drop the innermost frames of each side that the other side's stack does not contain,
// then compare the three innermost frames left.
function align(a, b) {
  if (!a || !b || !a.timeout || !b.timeout) return [a, b];
  let x = a.timeout, y = b.timeout;
  while (x.length > 1 && !y.includes(x[0])) x = x.slice(1);
  while (y.length > 1 && !x.includes(y[0])) y = y.slice(1);
  return [{ timeout: x.slice(0, 3) }, { timeout: y.slice(0, 3) }];
}
let pass = 0, fail = 0; const kinds = {};
const run = cases.filter((c, i) => picked(i, path.basename(c.file)));
const queue = run.slice();
await Promise.all(Array.from({ length: jobs }, async () => {
  while (queue.length) {
    const c = queue.shift();
    const [a, b] = align(...(await Promise.all([runOne('up', c), runOne('port', c)])));
    const ja = JSON.stringify(a), jb = JSON.stringify(b);
    const k = c.kind + ':' + (a.timeout ? 'timeout ' + a.timeout.join('<') : (/"error"/.test(a) ? JSON.parse(a).error.replace(/\d+/g, 'N') : 'ok'));
    kinds[k] = (kinds[k] || 0) + 1;
    if (ja === jb) pass++; else { fail++; console.log('MISMATCH', path.basename(c.file), '\n  upstream:', ja.slice(0, 400), '\n  port:    ', jb.slice(0, 400)); }
  }
}));
console.log(`\ncorrupt: ${pass} identical, ${fail} mismatches (${run.length} cases${every > 1 ? `, every ${every}th of ${cases.length}` : ''})`);
for (const [k, v] of Object.entries(kinds).sort()) console.log(`  ${v}\t${k}`);
process.exit(fail ? 1 : 0);
