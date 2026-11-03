// Round-trip differential test of the loaders.
//
//   node run.mjs [--no-build] [--only name] [--keep]
//
// 1. Builds every fixture scene with upstream three.js (fixtures.mjs, nonfinite_fixtures.mjs)
//    and writes its toJSON() text to $THREE_DIFF_OUT/classic_loaders/fixtures/<name>.json.
// 2. With Math.random reseeded identically on both sides, compares
//      upstream: new ObjectLoader().parse( JSON.parse( text ) ).toJSON()
//      port:     ObjectLoader::new().parse( @json.parse( text ) ).to_json()
//    as JSON.stringify text, byte for byte (uuids included). The same is done for
//    parseAsync, and for BufferGeometryLoader / MaterialLoader on the geometries and
//    materials of each fixture.
// 3. Runs the mock fetch/Image scenarios (scenarios_upstream.mjs and the MoonBit
//    `run_scenario`) and compares their logs entry by entry.
import { execSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import * as mock from './mock_env.mjs';
import { outDir, upstreamURL } from '../../lib/env.mjs';
import { builders } from './fixtures.mjs';
import { scenarios } from './scenarios_upstream.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const only = args.includes('--only') ? args[args.indexOf('--only') + 1].split(',') : null;
// The MoonBit side is the module in mbt/ (built against the repo through its moon.work).
// mutate.py points LOADERS_MODULE_DIR / LOADERS_HARNESS at a mutated temporary copy.
const devDir = process.env.LOADERS_MODULE_DIR ? path.resolve(process.env.LOADERS_MODULE_DIR) : path.join(here, 'mbt');

mock.install();
const quiet = (f) => { const w = console.warn, e = console.error, l = console.log; console.warn = console.error = () => {}; try { return f(); } finally { console.warn = w; console.error = e; } };

// Deterministic Math.random shared by both sides.
let seed = 0;
const realRandom = Math.random;
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

if (!args.includes('--no-build')) {
  try { execSync('moon build --target js', { cwd: devDir, stdio: 'pipe' }); }
  catch (e) { console.log('BUILD FAILED\n' + String(e.stdout).split('\n').filter((l) => /Error|error/.test(l)).slice(0, 20).join('\n')); process.exit(2); }
}
const M = await import(pathToFileURL(path.join(devDir, '_build/js/debug/build/' + (process.env.LOADERS_HARNESS || 'bobzhang/three-diff-loaders/harness/harness.js'))).href);
const T = await import(upstreamURL('src/Three.js'));

let failed = 0, passed = 0, known = 0;
// Differences caused by core, not by the loaders; shown but not counted. The two listed
// here before (attenuationDistance null dropped by Material::from_json, geometryInfo.active
// written before the bounds) are fixed in core.
const knownGaps = {};
function compare(name, expected, actual) {
  const gap = Object.keys(knownGaps).find((k) => name.endsWith(' ' + k) || name.includes(' ' + k + '/'));
  if (expected === actual) { passed++; if (gap && name.startsWith('parse')) console.log(`FIXED?   ${name}: listed as a known gap`); return true; }
  if (gap) known++; else failed++;
  if (gap) console.log(`KNOWN    ${name}: ${knownGaps[gap]}`);
  let i = 0;
  while (i < expected.length && expected[i] === actual[i]) i++;
  console.log(`MISMATCH ${name} at char ${i} (upstream ${expected.length}, port ${actual.length})`);
  console.log('  up: ' + expected.slice(Math.max(0, i - 120), i + 120));
  console.log('  mb: ' + actual.slice(Math.max(0, i - 120), i + 120));
  return false;
}
// The port's text is compared as it is: it must already be what JSON.stringify writes
// (null for NaN and the infinities), so `canon` only checks that it is valid JSON.
const canon = (s) => { JSON.parse(s); return s; };
function guarded(name, f) {
  try { return f(); } catch (e) { failed++; console.log(`ERROR ${name}: ${e && e.stack ? e.stack.split('\n').slice(0, 4).join(' | ') : e}`); return undefined; }
}

// 1. fixtures
const fixtureDir = outDir('classic_loaders', 'fixtures');
const B = builders(T);
const fixtures = {};
quiet(() => {
  for (const name of Object.keys(B)) {
    if (only && !only.includes(name)) continue;
    reseed(1000 + Object.keys(fixtures).length);
    const object = B[name]();
    let text;
    if (object.__json) text = JSON.stringify(object.__json);
    else { object.updateMatrixWorld(true); text = JSON.stringify(object.toJSON()); }
    fixtures[name] = text;
    fs.writeFileSync(path.join(fixtureDir, name + '.json'), text);
  }
});
M.warmup();

// 2. round trips
for (const [name, text] of Object.entries(fixtures)) {
  reseed(42);
  const expected = quiet(() => JSON.stringify(new T.ObjectLoader().parse(JSON.parse(text)).toJSON()));
  reseed(42);
  const actual = guarded(name, () => quiet(() => canon(M.object_roundtrip(text))));
  if (actual !== undefined && compare('parse ' + name, expected, actual)) console.log(`ok       parse ${name} (${expected.length} chars)`);

  reseed(43);
  const expectedAsync = JSON.stringify((await new T.ObjectLoader().parseAsync(JSON.parse(text))).toJSON());
  reseed(43);
  let actualAsync;
  try { actualAsync = canon(await M.object_roundtrip_async(text)); } catch (e) { failed++; console.log(`ERROR parseAsync ${name}: ${e}`); }
  if (actualAsync !== undefined && compare('parseAsync ' + name, expectedAsync, actualAsync)) console.log(`ok       parseAsync ${name}`);

  const json = JSON.parse(text);
  for (const g of json.geometries || []) {
    if (g.type !== 'BufferGeometry' && g.type !== 'InstancedBufferGeometry') continue;
    reseed(44);
    const e = JSON.stringify(new T.BufferGeometryLoader().parse(g).toJSON());
    reseed(44);
    const a = guarded('geometry ' + name, () => canon(M.geometry_roundtrip(JSON.stringify(g))));
    if (a !== undefined && compare(`geometry ${name}/${g.uuid}`, e, a)) passed += 0;
  }
  for (const m of json.materials || []) {
    reseed(45);
    const e = quiet(() => JSON.stringify(new T.MaterialLoader().parse(m).toJSON()));
    reseed(45);
    const a = guarded('material ' + name, () => quiet(() => canon(M.material_roundtrip(JSON.stringify(m)))));
    if (a !== undefined) compare(`material ${name}/${m.type}`, e, a);
  }
}

// 3. mock scenarios
for (const [name, scenario] of Object.entries(scenarios)) {
  if (only && !only.includes(name)) continue;
  mock.reset(scenario.routes);
  quiet(() => scenario.run(T, mock.note));
  await mock.settle();
  const expected = mock.log.slice();
  mock.reset(scenario.routes);
  try { quiet(() => M.run_scenario(name)); } catch (e) { mock.log.push('THROW ' + e); }
  await mock.settle();
  let actual = mock.log.slice();
  // A `load_async` result resumes MoonBit's coroutine a few microtasks after upstream's
  // promise handler runs, so the notes of awaited results (labels in `scenario.awaited`)
  // are compared after everything else, in their own order.
  const awaited = scenario.awaited || [];
  const isAwaited = (e) => awaited.some((p) => e.startsWith(p + ' '));
  const sink = (l) => [...l.filter((e) => !isAwaited(e)), ...l.filter(isAwaited)];
  const expectedAll = expected.slice();
  expected.length = 0; expected.push(...sink(expectedAll));
  actual = sink(actual);
  let i = 0;
  while (i < expected.length && i < actual.length && expected[i] === actual[i]) i++;
  if (i === expected.length && i === actual.length) { passed++; console.log(`ok       scenario ${name} (${expected.length} entries)`); continue; }
  failed++;
  console.log(`MISMATCH scenario ${name} at entry ${i} (upstream ${expected.length}, port ${actual.length})`);
  for (let j = Math.max(0, i - 3); j < Math.min(Math.max(expected.length, actual.length), i + 4); j++) {
    console.log(`  ${j === i ? '>' : ' '} up: ${expected[j]}\n  ${j === i ? '>' : ' '} mb: ${actual[j]}`);
  }
}
Math.random = realRandom;
console.log(`\n${passed} passed, ${failed} failed, ${known} known core gaps`);
process.exit(failed ? 1 : 0);
