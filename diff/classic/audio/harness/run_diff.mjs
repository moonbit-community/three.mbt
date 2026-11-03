// Differential test: runs each upstream scenario (harness/scenarios/<name>.mjs) on the
// recording mock and compares its log, entry by entry and byte for byte, with the MoonBit
// test of the same name, which prints `@@AUDIO_LOG <name> <json>` when AUDIO_DIFF=1.
//
// Usage: node harness/run_diff.mjs [--repo <three.mbt>] [--quiet] [name ...]
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { REPO, UPSTREAM } from '../../../lib/env.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
let repo = REPO;
let quiet = false;
const only = [];
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--repo') repo = args[++i];
  else if (args[i] === '--quiet') quiet = true;
  else only.push(args[i]);
}
const say = (s) => { if (!quiet) console.log(s); };

// The embedded copy must be the harness's mock, or the two sides run different mocks.
const { mockBody, embedded } = await import(pathToFileURL(path.join(here, '../tools/gen_mock.mjs')).href);
const body = mockBody();
const mbtMock = fs.readFileSync(path.join(repo, 'src/audio/audio_mock_test.mbt'), 'utf8');
const embeddedLines = mbtMock.split('\n').filter((l) => /^\s*#\|/.test(l)).map((l) => l.replace(/^\s*#\|/, ''));
if (embeddedLines.join('\n') !== embedded(body).join('\n')) {
  console.log('STALE    src/audio/audio_mock_test.mbt differs from harness/mock_audio_body.js; run tools/gen_mock.mjs');
  process.exit(2);
}
const { createMockAudio } = new Function(body + '\nreturn { createMockAudio };')();

// 1. MoonBit side: every *_test.mbt in src/audio that calls emit_log
const pkgDir = path.join(repo, 'src/audio');
const moonLogs = {};
let moonFailed = false;
const files = fs.readdirSync(pkgDir).filter((f) => f.endsWith('_test.mbt') && fs.readFileSync(path.join(pkgDir, f), 'utf8').includes('emit_log("'));
for (const f of files) {
  const r = spawnSync('moon', ['test', '--target', 'js', path.join('src/audio', f)], { cwd: repo, env: { ...process.env, AUDIO_DIFF: '1' }, encoding: 'utf8', maxBuffer: 1 << 28 });
  const out = (r.stdout || '') + (r.stderr || '');
  for (const line of out.split('\n')) {
    const m = /^@@AUDIO_LOG (\S+) (.*)$/.exec(line.trim());
    if (m) moonLogs[m[1]] = JSON.parse(m[2]);
  }
  if (r.status !== 0) {
    moonFailed = true;
    say(`moon test ${f} exited ${r.status}:\n` + out.split('\n').filter((l) => !l.startsWith('@@')).slice(-30).join('\n'));
  }
}

// 2. upstream side, and compare
const src = pathToFileURL(path.join(UPSTREAM, 'src')).href;
const scenarioDir = path.join(here, 'scenarios');
const names = only.length ? only : fs.readdirSync(scenarioDir).filter((f) => f.endsWith('.mjs')).map((f) => f.slice(0, -4)).sort();
let failed = 0;
let entries = 0;
for (const name of names) {
  const mod = await import(pathToFileURL(path.join(scenarioDir, name + '.mjs')).href);
  const expected = await mod.run({ src, createMockAudio });
  const actual = moonLogs[name];
  if (actual === undefined) { say(`MISSING  ${name}: no @@AUDIO_LOG from MoonBit`); failed++; continue; }
  let i = 0;
  while (i < expected.length && i < actual.length && expected[i] === actual[i]) i++;
  if (i === expected.length && i === actual.length) { entries += expected.length; say(`ok       ${name} (${expected.length} entries)`); continue; }
  failed++;
  say(`MISMATCH ${name} at entry ${i} (upstream ${expected.length}, moonbit ${actual.length})`);
  for (let j = Math.max(0, i - 2); j < Math.min(Math.max(expected.length, actual.length), i + 3); j++) {
    say(`  ${j === i ? '>' : ' '} up: ${expected[j]}\n  ${j === i ? '>' : ' '} mb: ${actual[j]}`);
  }
}
for (const name of Object.keys(moonLogs)) if (!names.includes(name) && only.length === 0) say(`NOTE     ${name}: MoonBit log without an upstream scenario`);
say(`${names.length - failed}/${names.length} scenarios match (${entries} entries)${moonFailed ? '; moon test failed' : ''}`);
process.exit(failed || moonFailed ? 1 : 0);
