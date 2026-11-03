// Finds EXR fixtures on which upstream's parse does not terminate (both default type and
// output format), runs the port on them too, and compares the interrupted stack's
// function names. Writes OUT/addons_hdr/hangs.json and compares it with the committed
// hangs.json, which run.mjs reads to skip those files (copy it over after a deliberate
// change). Takes several minutes (8 s per hanging file and side).
//   node probe_hangs.mjs
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { HERE, OUT_HDR } from './paths.mjs';
import { ensureExr } from './fixtures.mjs';
const here = HERE;
const exrDir = ensureExr();
const files = fs.readdirSync(exrDir).filter((f) => f.endsWith('.exr')).sort().map((f) => path.join(exrDir, f));
const run = (side, file, ms) => new Promise((resolve) => {
  const p = spawn('node', ['--trace-sigint', here + '/one.mjs', side, file], { stdio: ['ignore', 'pipe', 'pipe'] });
  let out = '';
  p.stdout.on('data', (d) => (out += d)); p.stderr.on('data', (d) => (out += d));
  const t = setTimeout(() => p.kill('SIGINT'), ms);
  p.on('close', () => { clearTimeout(t); resolve(out); });
});
const fnames = (s) => [...s.matchAll(/^\s+at (\S+)/gm)].map((m) => m[1].replace(/^_M0\w*?(exr__|ExrParse\d*)/, '').replace(/__/g, '_').replace(/^\d+/, '')).filter((n) => !/one\.mjs|file:/.test(n));
const hangs = {};
const queue = files.slice();
await Promise.all(Array.from({ length: 8 }, async () => {
  while (queue.length) {
    const f = queue.shift();
    const up = await run('up', f, 8000);
    if (!/KEYBOARD_INTERRUPT/.test(up)) continue;
    const port = await run('port', f, 8000);
    hangs[path.basename(f)] = { upstream: fnames(up), port: fnames(port), portHangs: /KEYBOARD_INTERRUPT/.test(port) };
  }
}));
const sorted = Object.fromEntries(Object.keys(hangs).sort().map((k) => [k, hangs[k]]));
fs.writeFileSync(path.join(OUT_HDR, 'hangs.json'), JSON.stringify(sorted, null, 1));
console.log(JSON.stringify(sorted, null, 1));
// Compare with the committed table: same files, both sides hang, same loader frames.
const norm = (h) => ({ upstream: h.upstream.map((n) => n.toLowerCase().replace(/_/g, '')), port: h.port.filter((n) => n !== 'decode' && !/^_M0/.test(n)).map((n) => n.toLowerCase().replace(/_/g, '')), portHangs: h.portHangs });
const committed = JSON.parse(fs.readFileSync(path.join(here, 'hangs.json'), 'utf8'));
const same = (a, b) => JSON.stringify(Object.keys(a).sort().map((k) => [k, norm(a[k])])) === JSON.stringify(Object.keys(b).sort().map((k) => [k, norm(b[k])]));
const agree = Object.values(sorted).filter((h) => h.portHangs && JSON.stringify(norm(h).upstream) === JSON.stringify(norm(h).port)).length;
console.log(`hangs: ${Object.keys(sorted).length} files, port hangs in the same frames on ${agree}, ${same(sorted, committed) ? 'same as' : 'DIFFERENT from'} hangs.json`);
process.exit(same(sorted, committed) && agree === Object.keys(sorted).length ? 0 : 1);
