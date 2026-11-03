// Injects one deliberate bug at a time into src/audio, runs harness/run_diff.mjs (which also
// runs `moon test`), and reports whether the differential test caught it. Every file is
// restored afterwards, also on failure, Ctrl-C and SIGTERM (originals are also copied to
// $THREE_DIFF_OUT/classic_audio/bak while a run is active; copy them back if a run is killed).
// Usage: node tools/inject_bugs.mjs [index ...]   (INJECT_DRY_RUN=1: only check the patterns)
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { REPO, outDir } from '../../../lib/env.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const pkg = path.join(REPO, 'src/audio');
const bak = outDir('classic_audio', 'bak');
const dryRun = process.env.INJECT_DRY_RUN === '1';

const mutations = [
  ['audio.mbt', 'source.stop()\n', 'source.stop(when_=0)\n', 'pause() passes an argument to stop()'],
  ['audio.mbt', 'duration?=self.duration', 'duration?=(None : Double?)', 'start() always gets duration undefined'],
  ['audio.mbt', '    self._connected = false\n  }\n  // PositionalAudio disconnects its panner even when the source was not connected.\n  if self.panner is Some(panner) {\n    panner.as_node().disconnect(self.gain.as_node())\n  }\n', '    self._connected = false\n    if self.panner is Some(panner) {\n      panner.as_node().disconnect(self.gain.as_node())\n    }\n  }\n', 'positional disconnect skips the panner when not connected'],
  ['audio.mbt', '  ignore(self.set_detune(self.detune))\n  ignore(self.set_playback_rate(self.playback_rate))\n', '  ignore(self.set_playback_rate(self.playback_rate))\n  ignore(self.set_detune(self.detune))\n', 'play() sets playback rate before detune'],
  ['web_audio.mbt', 'value == value && value != 0.0', 'true', 'duration 0 is truthy in pause()'],
  ['audio.mbt', 'web_audio_math_max(\n        self.context.current_time() - self._started_at,\n        0,\n      )', '(self.context.current_time() - self._started_at)', 'pause() does not clamp elapsed time at 0'],
  ['web_audio.mbt', '"(a, b) => a % b"', '"(a, b) => a"', 'looped pause() skips the modulo'],
  ['audio_listener.mbt', '.set(0, 0, -1)', '.set(0, 0, 1)', 'listener forward is +z'],
  ['audio_listener.mbt', '  ignore(self._timer.update())\n  let listener = self.context.listener()\n  self.time_delta = self._timer.get_delta()\n', '  self.time_delta = self._timer.get_delta()\n  ignore(self._timer.update())\n  let listener = self.context.listener()\n', 'listener reads the delta before updating the timer'],
  ['audio_listener.mbt', '  object.update_matrix_world_kind(force)\n  ignore(self._timer.update())\n', '  ignore(self._timer.update())\n', 'listener skips super.updateMatrixWorld'],
  ['audio_listener.mbt', '  object.update_matrix_world_kind(force)\n  ignore(self._timer.update())\n  let listener = self.context.listener()\n  self.time_delta = self._timer.get_delta()\n  ignore(\n    object.matrix_world.decompose(\n      _audio_listener_position, _audio_listener_quaternion, _audio_listener_scale,\n    ),\n  )\n', '  ignore(self._timer.update())\n  let listener = self.context.listener()\n  self.time_delta = self._timer.get_delta()\n  ignore(\n    object.matrix_world.decompose(\n      _audio_listener_position, _audio_listener_quaternion, _audio_listener_scale,\n    ),\n  )\n  object.update_matrix_world_kind(force)\n', 'listener calls super after decomposing'],
  ['audio.mbt', '  object.update_matrix_world_kind(force)\n  if self.panner is Some(panner) {', '  if self.panner is Some(panner) {', 'positional audio skips super.updateMatrixWorld'],
  ['positional_audio.mbt', 'if self.has_playback_control && !self.is_playing {', 'if !self.is_playing {', 'positional early return ignores hasPlaybackControl'],
  ['positional_audio.mbt', 'self.context.current_time() + self.listener.time_delta', 'self.context.current_time()', 'panner ramps end at currentTime'],
  ['positional_audio.mbt', '.set(0, 0, 1)', '.set(0, 0, -1)', 'panner orientation is -z'],
  ['audio.mbt', 'panner.set_panning_model("HRTF")', 'panner.set_panning_model("equalpower")', 'panningModel equalpower'],
  ['audio.mbt', '    self.filters = value.copy()\n    ignore(self.connect())', '    self.filters = value\n    ignore(self.connect())', 'setFilters while connected aliases the array'],
  ['audio.mbt', '  } else {\n    self.filters = value.copy()\n  }', '  } else {\n    self.filters = value\n  }', 'setFilters while disconnected aliases the array'],
  ['audio.mbt', 'if self.is_playing && self.buffer_source().has_detune() {', 'if self.is_playing {', 'setDetune ignores a missing detune param'],
  ['audio.mbt', '      filters[i - 1].connect(filters[i])', '      filters[i].connect(filters[i - 1])', 'filter chain connected backwards'],
  ['audio_listener.mbt', '    None => self.gain.as_node().disconnect(self.context.destination())\n', '    None => ()\n', 'listener setFilter keeps the gain connected to the destination'],
  ['audio_analyser.mbt', 'value / data.length().to_double()', 'value / (data.length() + 1).to_double()', 'average frequency divides by length + 1'],
  ['audio.mbt', '  self.filters = source.filters.copy()\n}', '}', 'copy() does not copy filters'],
  ['audio.mbt', 'source.stop(when_=self.context.current_time() + delay)', 'source.stop(when_=self.context.current_time())', 'stop() ignores the delay'],
  ['audio_context.mbt', '  if audio_context_context.val.to_js().is_undefined() {\n', '  if true {\n', 'getContext creates a context on every call'],
  ['web_audio.mbt', '"(l) => l.positionX ? true : false"', '"(l) => l.positionY ? true : false"', 'listener feature test reads positionY'],
  ['audio.mbt', '  self.is_playing = false\n  self._progress = 0\n}', '  self.is_playing = false\n}', 'onEnded keeps the progress'],
  ['audio.mbt', '  if self.is_playing {\n    @core.warn("Audio: Audio is already playing.")\n    return self\n  }\n', '', 'play() while playing does not warn'],
  ['audio.mbt', 'Some(_) => PositionalAudio::new(self.listener).object', 'Some(_) => Audio::new(self.listener).object', 'clone of a PositionalAudio is a plain Audio'],
  ['audio_listener.mbt', '    listener.up_y().linear_ramp_to_value_at_time(_audio_listener_up.y, end_time)\n', '    listener.up_y().linear_ramp_to_value_at_time(_audio_listener_up.y, end_time + 0.0000001)\n', 'listener upY ramp end time off by 1e-7'],
  ['web_audio.mbt', 'value == value && value != 0.0', 'value != 0.0', 'NaN duration is truthy in pause()'],
];

const pick = process.argv.slice(2).map(Number);
const todo = pick.length ? pick : mutations.map((_, i) => i);
const originals = {};
for (const f of fs.readdirSync(pkg)) if (f.endsWith('.mbt')) { originals[f] = fs.readFileSync(path.join(pkg, f), 'utf8'); fs.writeFileSync(path.join(bak, f), originals[f]); }
const restore = () => { for (const [f, s] of Object.entries(originals)) fs.writeFileSync(path.join(pkg, f), s); };
process.on('SIGINT', () => { restore(); process.exit(130); });
process.on('SIGTERM', () => { restore(); process.exit(143); });

let caught = 0;
try {
  for (const i of todo) {
    const [file, from, to, desc] = mutations[i];
    const s = originals[file];
    const at = s.indexOf(from);
    if (at < 0 || s.indexOf(from, at + 1) >= 0) { console.log(`#${i} SKIP (pattern ${at < 0 ? 'missing' : 'not unique'}): ${desc}`); continue; }
    if (dryRun) { console.log(`#${i} pattern ok: ${desc}`); continue; }
    fs.writeFileSync(path.join(pkg, file), s.slice(0, at) + to + s.slice(at + from.length));
    const r = spawnSync('node', [path.join(here, '../harness/run_diff.mjs')], { encoding: 'utf8' });
    const detail = (r.stdout.split('\n').find((l) => l.startsWith('MISMATCH') || l.startsWith('moon test') || l.startsWith('MISSING')) ?? '').slice(0, 90);
    const hit = r.status !== 0;
    if (hit) caught++;
    console.log(`#${i} ${hit ? 'CAUGHT ' : 'MISSED '} ${desc}${hit ? '  [' + detail + ']' : ''}`);
    restore();
  }
} finally {
  restore();
}
console.log(`${caught}/${todo.length} injected bugs caught`);
