// The a6 shader records only (faster than the whole shader harness): runs
// src/addons/objects/a6_shader_diff_test.mbt with SHADER_DIFF=1 and the upstream side of
// diff/core/webgpu/shader_diff/upstream_a6.mjs, and compares them byte for byte.
//   node shader_cmp.mjs
import { spawnSync } from 'node:child_process';
import { REPO } from '../../lib/env.mjs';
import { runA6 } from '../../core/webgpu/shader_diff/upstream_a6.mjs';
const up = runA6();
const r = spawnSync('moon', ['test', '--target', 'js', 'src/addons/objects/a6_shader_diff_test.mbt'], { cwd: REPO, env: { ...process.env, SHADER_DIFF: '1' }, encoding: 'utf8', maxBuffer: 1 << 28 });
const moon = {};
for (const line of (r.stdout + r.stderr).split('\n')) { const m = /^@@SHADER (\S+) (.*)$/.exec(line.trim()); if (m) moon[m[1]] = JSON.parse(m[2]); }
let bad = 0;
for (const k of Object.keys(up)) { if (JSON.stringify(up[k]) !== JSON.stringify(moon[k])) { bad++; console.log('MISMATCH ' + k); } }
console.log(`${Object.keys(up).length - bad}/${Object.keys(up).length} identical`);
process.exit(bad ? 1 : 0);
