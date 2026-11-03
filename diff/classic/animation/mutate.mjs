// Injects one deliberate bug at a time into src/animation, rebuilds, and checks that
// run.mjs (handcrafted scenarios + random ones) and `moon test` notice. The original file
// is restored after each mutant, also on failure.
//   node mutate.mjs [index ...]
//   INJECT_DRY_RUN=1 node mutate.mjs     only check that every pattern applies
import { execSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { REPO, outDir } from '../../lib/env.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const SRC = path.join(REPO, 'src/animation') + '/';
const DRY_RUN = process.env.INJECT_DRY_RUN === '1';

// The mutated file is restored in `finally`, on SIGINT/SIGTERM, and from the backup in
// $THREE_DIFF_OUT/classic_animation/backup (`node mutate.mjs --restore`) after a hard kill.
const backupDir = outDir('classic_animation', 'backup');
let current = null; // [path, original]
function restore() { if (current) { fs.writeFileSync(current[0], current[1]); current = null; } }
for (const sig of ['SIGINT', 'SIGTERM']) process.on(sig, () => { restore(); process.exit(130); });
if (process.argv.includes('--restore')) {
  for (const f of fs.readdirSync(backupDir)) { fs.copyFileSync(path.join(backupDir, f), SRC + f); fs.rmSync(path.join(backupDir, f)); console.log('restored ' + f); }
  process.exit(0);
}

const mutants = [
  ['property_mixer.mbt', 'let s = 1.0 - t', 'let s = 1.0 - t * 0.999', 'lerp weight'],
  ['property_mixer.mbt', 'current_weight += weight', 'current_weight = weight', 'cumulative weight'],
  ['property_mixer.mbt', '"quaternion" => (Slerp,', '"quaternion" => (Numeric,', 'quaternions lerped'],
  ['property_mixer.mbt', 'if t >= 0.5 {', 'if t > 0.5 {', 'bool select threshold'],
  ['animation_action.mbt', 'loop_count += js_math_abs(loop_delta)', 'loop_count += loop_delta', 'loop count sign'],
  ['animation_action.mbt', 'return duration - time\n', 'return time\n', 'ping-pong inversion'],
  ['animation_action.mbt', 'interpolant.settings = Some(interpolant_settings)', 'ignore(interpolant_settings)', 'shared interpolant settings'],
  ['animation_action.mbt', 'values[0] = start_time_scale / time_scale', 'values[0] = start_time_scale', 'warp start value'],
  ['animation_action.mbt', 'values[0] = weight_now', 'values[0] = weight_then', 'fade start weight'],
  ['animation_action.mbt', 'data.set("loopDelta", @core.JsValue::of(loop_delta))', 'data.set("loopDelta", @core.JsValue::of(js_math_abs(loop_delta)))', 'loop event payload'],
  ['animation_action.mbt', '      if self.zero_slope_at_start {\n        @math.ZeroSlopeEnding', '      if self.zero_slope_at_start {\n        @math.ZeroCurvatureEnding', 'start ending'],
  ['animation_mixer.mbt', 'mixer_set_cache_index(first_inactive_binding, prev_index)', 'mixer_set_cache_index(first_inactive_binding, last_active_index)', 'binding cache swap'],
  ['animation_mixer.mbt', '          float32_buffer(2),\n          float32_buffer(2),', '          Array::make(2, 0.0),\n          Array::make(2, 0.0),', 'control interpolants not Float32'],
  ['animation_js.mbt', '#|(a) => (a instanceof Float32Array ? a : new Float32Array(a))', '#|(a) => (a instanceof Float32Array ? a : new Float64Array(a))', 'track arrays not Float32'],
  ['animation_js.mbt', 'if index.to_double() == id && index >= 0', 'if index.to_double() == id && index > 0', 'string table lookup'],
  ['animation_utils.mbt', 'stable_sort(result, (i, j) => times[i] - times[j])', 'stable_sort(result, (i, j) => times[j] - times[i])', 'keyframe order'],
  ['animation_utils.mbt', 'if frame < start_frame || frame >= end_frame {', 'if frame < start_frame || frame > end_frame {', 'subclip end bound'],
  ['animation_utils.mbt', '        .conjugate()\n', '\n', 'additive quaternion conjugate'],
  ['keyframe_track.mbt', 'json["interpolation"] = Json::number(interpolation.to_double())', 'ignore(interpolation)', 'toJSON interpolation'],
  ['keyframe_track.mbt', 'while from != n_keys && times[from] < start_time {', 'while from != n_keys && times[from] <= start_time {', 'trim start bound'],
  ['keyframe_track.mbt', 'if !values.same(offset + j, offset_p + j) ||', 'if !values.same(offset + j, offset_n + j) ||', 'optimize neighbour'],
  ['property_binding.mbt', '"material", "materials", "bones", "map",', '"material", "materials", "bones",', 'parseTrackName allowlist'],
  ['property_binding.mbt', 'Material(material) => () => material.set_needs_update(true)', 'Material(_) => () => ()', 'material needsUpdate'],
  ['property_binding.mbt', 'if dictionary.get(index.to_key()) is Some(i) {', 'if dictionary.get(index.to_key() + "!") is Some(i) {', 'morph target names'],
  ['property_binding.mbt', '"y" => num(() => q.y, y => q.set_y(y))', '"y" => num(() => q.y, y => q.set_x(y))', 'quaternion component'],
  ['property_binding.mbt', 'num(() => spot.penumbra, v => spot.penumbra = v)', 'num(() => spot.penumbra, v => spot.angle = v)', 'spot light table entry'],
  ['property_binding.mbt', "if child_node.name == node_name || child_node.uuid == node_name {", "if child_node.name == node_name {", 'findNode by uuid (unit tests only)'],
  ['property_binding.mbt', 'Object3D(object) => () => object.matrix_world_needs_update = true', 'Object3D(_) => () => ()', 'Object3D matrixWorldNeedsUpdate'],
  ['property_binding.mbt', 'if skeleton.get_bone_by_name(node_name) is Some(bone) {', 'if skeleton.get_bone_by_name(node_name + "?") is Some(bone) {', 'findNode via skeleton'],
  ['property_binding.mbt', 'let first_valid_index = self._target_group.n_cached_objects_', 'let first_valid_index = 0', 'Composite getValue index'],
  ['property_mixer.mbt', 'if buffer[i] != buffer[i + stride] {', 'if buffer[i] != buffer[i + stride] && i > stride {', 'change detection'],
  ['animation_js.mbt', 'm[k] = v; }', 'void v; }', 'expando storage'],
  ['animation_object_group.mbt', 'bindings_for_path[last_cached_index] = binding', 'ignore(binding)', 'group remove bookkeeping'],
];

const only = process.argv.slice(2).map(Number);
let detected = 0, total = 0;
for (const [i, [file, from, to, label]] of mutants.entries()) {
  if (only.length && !only.includes(i)) continue;
  const p = SRC + file;
  const original = fs.readFileSync(p, 'utf8');
  const count = original.split(from).length - 1;
  if (count !== 1) { console.log(`#${i} ${label}: pattern found ${count} times, skipped`); continue; }
  total++;
  if (DRY_RUN) { console.log(`#${i} ${label}: pattern ok`); continue; }
  try {
    fs.writeFileSync(path.join(backupDir, file), original);
    current = [p, original];
    fs.writeFileSync(p, original.replace(from, to));
    let how = null;
    const build = spawnSync('moon', ['build', '--target', 'js'], { cwd: here, encoding: 'utf8' });
    if (build.status !== 0) how = 'build failed';
    else {
      const run = spawnSync('node', ['run.mjs', '--random', '300'], { cwd: here, encoding: 'utf8', env: { ...process.env, SKIP_BUILD: '1' } });
      if (run.status !== 0) {
        const first = run.stdout.split('\n').find(l => l.startsWith('FAIL')) || run.stdout.split('\n').slice(-3).join(' ');
        how = 'diff: ' + first.slice(0, 110);
      } else {
        const test = spawnSync('moon', ['test', '--target', 'js', '-p', 'bobzhang/three/animation'], { cwd: REPO, encoding: 'utf8' });
        if (test.status !== 0) how = 'moon test only';
      }
    }
    if (how) detected++;
    console.log(`#${i} ${label}: ${how ? 'DETECTED (' + how + ')' : 'NOT detected'}`);
  } finally {
    restore();
    fs.rmSync(path.join(backupDir, file), { force: true });
  }
}
if (DRY_RUN) { console.log(`${total} patterns apply`); process.exit(0); }
execSync('moon build --target js', { cwd: here, stdio: 'pipe' });
console.log(`${detected}/${total} mutants detected`);
