// Checks that every Web Audio member upstream src/audio uses (tools/web_audio_usage.mjs) has
// an `extern "js"` binding in src/audio with the same access shape (call, get or set), and
// lists bound members upstream does not use.
// Usage: node tools/check_bindings.mjs [<web_audio_usage.json>] [<three.mbt>/src/audio]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { REPO } from '../../../lib/env.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const [usageFile = path.join(here, '../web_audio_usage.json'), dir = path.join(REPO, 'src/audio')] = process.argv.slice(2);
const usage = JSON.parse(fs.readFileSync(usageFile, 'utf8'));
const bodies = [];
for (const f of fs.readdirSync(dir).filter((f) => f.endsWith('.mbt') && !f.endsWith('_test.mbt'))) {
  const src = fs.readFileSync(path.join(dir, f), 'utf8');
  for (const m of src.matchAll(/extern "js" fn ([\w:]+)[\s\S]*?\) -> [^=]+= "([^"]*)"/g)) bodies.push({ fn: m[1], body: m[2], file: f });
}
const shapes = [];
for (const b of bodies) {
  for (const m of b.body.matchAll(/(window|\b[a-z])\.(\w+)(\s*\(|\s*=(?!=))?/g)) {
    const access = m[3] ? (m[3].trim() === '(' ? 'call' : 'set') : 'get';
    shapes.push({ member: m[2], access, window: m[1] === 'window', fn: b.fn });
  }
}
let missing = 0;
for (const u of usage) {
  const hit = shapes.find((s) => s.member === u.member && s.access === u.access && s.window === (u.iface === 'window'));
  if (!hit) { missing++; console.log(`MISSING  ${u.key}`); }
  else console.log(`ok       ${u.key.padEnd(56)} ${hit.fn}`);
}
const used = new Set(usage.map((u) => `${u.member} ${u.access}`));
for (const s of shapes) if (!used.has(`${s.member} ${s.access}`)) console.log(`EXTRA    ${s.member} ${s.access} (${s.fn})`);
console.log(`${usage.length - missing}/${usage.length} upstream members bound, ${bodies.length} extern "js" functions`);
process.exit(missing ? 1 : 0);
