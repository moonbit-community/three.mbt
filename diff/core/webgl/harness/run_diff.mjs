// Differential test: runs each upstream scenario (harness/scenarios/<name>.mjs) on the
// recording mock and compares its log with the MoonBit test of the same name, which
// prints `@@WEBGL_LOG <name> <json>` when run with WEBGL_DIFF=1.
//
// Usage: node harness/run_diff.mjs [--repo <three.mbt checkout, default: this repository>] [--file <test file>] [name ...]
//   (run from diff/core/webgl; upstream comes from THREE_UPSTREAM, default .repos/three.js)
//   --file defaults to every *_test.mbt in src/renderers/webgl that calls emit_log.
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { REPO, UPSTREAM } from '../../../lib/env.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
let repo = REPO;
const files = [];
const only = [];
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--repo') repo = args[++i];
  else if (args[i] === '--file') files.push(args[++i]);
  else only.push(args[i]);
}
const pkgDir = path.join(repo, 'src/renderers/webgl');
if (files.length === 0) {
  for (const f of fs.readdirSync(pkgDir)) {
    if (f.endsWith('_test.mbt') && f !== 'webgl_test_helpers_test.mbt' && fs.readFileSync(path.join(pkgDir, f), 'utf8').includes('emit_log(')) files.push(path.join('src/renderers/webgl', f));
  }
  // Additive (a6, objects add-ons): white-box scenario files of add-on packages, one
  // `moon test` per package (their helpers are package-local), scenarios named a6_*.
  for (const dir of ['src/addons/objects']) {
    const abs = path.join(repo, dir);
    if (!fs.existsSync(abs)) continue;
    const pkgFiles = fs.readdirSync(abs).filter((f) => /_diff_wbtest\.mbt$/.test(f) && fs.readFileSync(path.join(abs, f), 'utf8').includes('emit_log(')).map((f) => path.join(dir, f));
    if (pkgFiles.length) files.push(pkgFiles);
  }
}
const src = pathToFileURL(path.join(UPSTREAM, 'src')).href;
const { createMockGL, createMockAnimationContext } = createRequire(import.meta.url)('./mock_gl.cjs');

// 1. MoonBit side
const moonLogs = {};
for (const file of files) {
  const r = spawnSync('moon', ['test', '--target', 'js', ...[].concat(file)], { cwd: repo, env: { ...process.env, WEBGL_DIFF: '1' }, encoding: 'utf8', maxBuffer: 1 << 28 });
  const out = (r.stdout || '') + (r.stderr || '');
  for (const line of out.split('\n')) {
    const m = /^@@WEBGL_LOG (\S+) (.*)$/.exec(line.trim());
    if (m) moonLogs[m[1]] = JSON.parse(m[2]);
  }
  if (r.status !== 0) console.log(`moon test ${file} exited ${r.status}:\n` + out.split('\n').filter((l) => !l.startsWith('@@')).slice(-30).join('\n'));
}

// 2. upstream side, and compare
let failed = 0, passed = 0;
const scenarioDir = path.join(here, 'scenarios');
const names = only.length ? only : fs.readdirSync(scenarioDir).filter((f) => f.endsWith('.mjs')).map((f) => f.slice(0, -4)).sort();
for (const name of names) {
  const mod = await import(pathToFileURL(path.join(scenarioDir, name + '.mjs')).href);
  const expected = await mod.run({ src, createMockGL, createMockAnimationContext });
  const actual = moonLogs[name];
  if (actual === undefined) { console.log(`MISSING  ${name}: no @@WEBGL_LOG from MoonBit`); failed++; continue; }
  let i = 0;
  while (i < expected.length && i < actual.length && expected[i] === actual[i]) i++;
  if (i === expected.length && i === actual.length) { console.log(`ok       ${name} (${expected.length} entries)`); passed++; continue; }
  failed++;
  console.log(`MISMATCH ${name} at entry ${i} (upstream ${expected.length}, moonbit ${actual.length})`);
  for (let j = Math.max(0, i - 2); j < Math.min(Math.max(expected.length, actual.length), i + 4); j++) {
    console.log(`  ${j === i ? '>' : ' '} up: ${expected[j]}\n  ${j === i ? '>' : ' '} mb: ${actual[j]}`);
  }
}
for (const name of Object.keys(moonLogs)) if (!names.includes(name) && only.length === 0) console.log(`NOTE     ${name}: MoonBit log without an upstream scenario`);
console.log(`\n${passed} ok, ${failed} failed`);
process.exit(failed ? 1 : 0);
