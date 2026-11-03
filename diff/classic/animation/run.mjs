// Differential test of the MoonBit src/animation port against upstream three.js r187.
// Each scenario (scenarios.mjs, plus random ones) is a JSON spec run by two
// interpreters: upstream() below on upstream src ($THREE_UPSTREAM), and run_scenario in
// src/main/main.mbt on the port. Both logs record every bound property, material,
// action and mixer state after each op, fired events and console messages; they are
// compared entry by entry with Object.is (so -0 and NaN count).
//
//   node run.mjs [--random N] [--seed S] [name ...]
//   SKIP_BUILD=1 node run.mjs      reuse the last build
import { execSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { scenarios, randomScenario, randomUtilsScenario, randomGroupScenario } from './scenarios.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
import { pathToFileURL } from 'node:url';
import { upstreamURL } from '../../lib/env.mjs';
const T = await import(upstreamURL('src/Three.js'));
const { ClippingGroup } = await import(upstreamURL('src/objects/ClippingGroup.js'));

if (!process.env.SKIP_BUILD) {
  try { execSync('moon build --target js', { cwd: here, stdio: 'pipe' }); }
  catch (e) { console.log('BUILD FAILED\n' + String(e.stdout).split('\n').filter(l => /Error|error/.test(l)).slice(0, 20).join('\n')); process.exit(2); }
}
const M = await import(pathToFileURL(path.join(here, '_build/js/debug/build/moonbit-community/three-diff-animation/main/main.js')).href);

const realLog = console.log;
let messages = null;
function capture(kind) {
  return (...args) => {
    if (messages === null) return;
    // upstream: 'THREE.' + message, then extra params; keep strings only
    const text = args.filter(a => typeof a === 'string').join(' ');
    messages.push(['console', text]);
  };
}
console.warn = capture('warn');
console.error = capture('error');

// --- upstream interpreter ----------------------------------------------------------

let upstreamLog = null;
function upstream(spec) {
  const log = [];
  upstreamLog = log;
  const L = (label, ...values) => log.push([label, ...values]);
  messages = log;
  const materials = (spec.materials || []).map(m => {
    const mat = new T[m.type]();
    if (m.name !== undefined) mat.name = m.name;
    if (m.map) mat.map = new T.Texture();
    return mat;
  });
  const objects = [];
  const skinned = [];
  function node(s) {
    let material;
    if (typeof s.material === 'number') material = materials[s.material];
    else if (Array.isArray(s.material)) material = s.material.map(i => materials[i]);
    const geometry = new T.BufferGeometry();
    if (s.morph) {
      geometry.morphAttributes.position = s.morph.map(name => {
        const a = new T.Float32BufferAttribute([0, 0, 0, 1, 1, 1], 3);
        a.name = name;
        return a;
      });
    }
    let o;
    switch (s.type) {
      case 'Object3D': o = new T.Object3D(); break;
      case 'Group': o = new T.Group(); break;
      case 'Bone': o = new T.Bone(); break;
      case 'Scene':
        o = new T.Scene();
        if (s.fog === 'Fog') o.fog = new T.Fog(new T.Color(1, 1, 1), 1, 100);
        if (s.fog === 'FogExp2') o.fog = new T.FogExp2(new T.Color(1, 1, 1), 0.5);
        break;
      case 'Mesh': o = new T.Mesh(geometry, material); break;
      case 'SkinnedMesh': o = new T.SkinnedMesh(geometry, material); break;
      case 'Points': o = new T.Points(geometry, material); break;
      case 'Line': o = new T.Line(geometry, material); break;
      case 'LOD': o = new T.LOD(); break;
      case 'ClippingGroup': o = new ClippingGroup(); break;
      case 'RectAreaLight': o = new T.RectAreaLight(); break;
      case 'LightProbe': o = new T.LightProbe(); break;
      case 'Sprite': o = new T.Sprite(material); break;
      case 'PointLight': o = new T.PointLight(new T.Color(1, 0.5, 0.25), 2); break;
      case 'SpotLight': o = new T.SpotLight(); break;
      case 'DirectionalLight': o = new T.DirectionalLight(); break;
      case 'HemisphereLight': o = new T.HemisphereLight(); break;
      case 'PerspectiveCamera': o = new T.PerspectiveCamera(50); break;
      case 'OrthographicCamera': o = new T.OrthographicCamera(); break;
      default: throw new Error('node ' + s.type);
    }
    if (s.name !== undefined) { o.name = s.name; byName[s.name] = o; }
    if (s.uuid !== undefined) o.uuid = s.uuid;
    if (s.spotMap) o.map = new T.Texture();
    if (s.position) o.position.fromArray(s.position);
    if (s.quaternion) o.quaternion.fromArray(s.quaternion);
    if (s.scale) o.scale.fromArray(s.scale);
    objects.push(o);
    for (const c of s.children || []) o.add(node(c));
    if (s.skeleton) skinned.push([o, s.skeleton]);
    return o;
  }
  const byName = {};
  const find = name => { const o = byName[name]; if (!o) throw new Error('no object ' + name); return o; };
  const roots = spec.roots.map(node);
  for (const [mesh, names] of skinned) mesh.bind(new T.Skeleton(names.map(find)));

  const TRACKS = { number: T.NumberKeyframeTrack, vector: T.VectorKeyframeTrack, color: T.ColorKeyframeTrack, quaternion: T.QuaternionKeyframeTrack, base: T.KeyframeTrack, bool: T.BooleanKeyframeTrack, string: T.StringKeyframeTrack };
  function track(t) {
    const Cls = TRACKS[t.type];
    const values = t.values.map(v => (v === 'NaN' ? NaN : v));
    const tr = (t.type === 'bool' || t.type === 'string') ? new Cls(t.name, t.times, values) : new Cls(t.name, t.times, values, t.interpolation);
    if (t.settings) tr.settings = { inTangents: new Float32Array(t.settings.inTangents), outTangents: new Float32Array(t.settings.outTangents) };
    return tr;
  }
  const clips = (spec.clips || []).map(c => new T.AnimationClip(c.name === undefined ? '' : c.name, c.duration === undefined ? -1 : c.duration, c.tracks.map(track), c.blendMode === undefined ? 2500 : c.blendMode));

  for (const op of spec.clipOps || []) {
    switch (op[0]) {
      case 'makeAdditive': T.AnimationUtils.makeClipAdditive(clips[op[1]], op[2], op[3] === null ? undefined : clips[op[3]], op[4]); break;
      case 'subclip': clips.push(T.AnimationUtils.subclip(clips[op[1]], op[2], op[3], op[4], op[5])); break;
      case 'optimize': clips[op[1]].optimize(); break;
      case 'trim': clips[op[1]].trim(); break;
      case 'resetDuration': clips[op[1]].resetDuration(); break;
      case 'validate': L('validate', clips[op[1]].validate()); break;
      case 'trackScale': clips[op[1]].tracks[op[2]].scale(op[3]); break;
      case 'trackShift': clips[op[1]].tracks[op[2]].shift(op[3]); break;
      case 'trackTrim': clips[op[1]].tracks[op[2]].trim(op[3], op[4]); break;
      case 'trackOptimize': clips[op[1]].tracks[op[2]].optimize(); break;
      case 'trackValidate': L('trackValidate', clips[op[1]].tracks[op[2]].validate()); break;
      case 'trackInterpolation': clips[op[1]].tracks[op[2]].setInterpolation(op[3]); break;
      case 'clone': clips.push(clips[op[1]].clone()); break;
      case 'roundTrip': clips[op[1]] = T.AnimationClip.parse(JSON.parse(JSON.stringify(clips[op[1]].toJSON()))); break;
      case 'fromMorph': clips.push(T.AnimationClip.CreateFromMorphTargetSequence(op[1], op[2].map(name => ({ name })), op[3], op[4])); break;
      case 'fromMorphs': clips.push(...T.AnimationClip.CreateClipsFromMorphTargetSequences(op[1].map(name => ({ name })), op[2], op[3])); break;
      case 'evaluate': {
        const interpolant = clips[op[1]].tracks[op[2]].createInterpolant();
        for (const t of op[3]) L('eval', t, interpolant.evaluate(t));
        break;
      }
      case 'keyframeOrder': {
        const order = T.AnimationUtils.getKeyframeOrder(op[1]);
        L('order', ...order);
        L('sorted', T.AnimationUtils.sortedArray(op[2], op[3], order));
        break;
      }
      default: throw new Error('clip op ' + op[0]);
    }
  }
  clips.forEach((clip, i) => {
    const uuid = clip.uuid;
    clip.uuid = 'fixed';
    L('clip ' + i, JSON.parse(JSON.stringify(clip.toJSON())));
    clip.uuid = uuid;
    clip.tracks.forEach((tr, j) => L('clip ' + i + '.track' + j, tr.name, tr.times, tr.values, tr.getValueSize(), tr.getInterpolation() === undefined ? null : tr.getInterpolation()));
  });
  if (spec.rootAnimations) roots[0].animations.push(...clips);
  if (spec.ops === undefined) return log;

  const group = spec.group ? new T.AnimationObjectGroup(...spec.group.map(find)) : null;
  const mixer = group ? new T.AnimationMixer(group) : new T.AnimationMixer(roots[0]);
  const actions = [];
  const act = i => actions[i];
  const nul = x => (x === undefined ? null : x);
  const B = x => (typeof x === 'number' ? Boolean(x) : x);
  function dump() {
    for (const o of objects) {
      const r = o.rotation;
      // known deviation: the port's Bool / String fields cannot hold the `undefined` that
      // restoring a never-saved boolean or string binding writes upstream
      // and a number written into a boolean property stays a number upstream
      const visible = o.visible === undefined ? false : B(o.visible);
      const oname = o.name === undefined ? 'undefined' : o.name;
      L('obj ' + oname, o.position.x, o.position.y, o.position.z, o.quaternion.x, o.quaternion.y, o.quaternion.z, o.quaternion.w, o.scale.x, o.scale.y, o.scale.z, r.x, r.y, r.z, r.order, visible, B(o.matrixWorldNeedsUpdate), B(o.castShadow), o.renderOrder, oname);
      if (o.morphTargetInfluences !== undefined) L('morph ' + o.name, ...o.morphTargetInfluences);
      if (o.isLight) {
        L('light ' + o.name, o.intensity, o.color.r, o.color.g, o.color.b);
        if (o.isPointLight) L('point ' + o.name, o.distance, o.decay);
        if (o.isSpotLight) L('spot ' + o.name, o.distance, o.decay, o.angle, o.penumbra);
        if (o.isHemisphereLight) L('hemi ' + o.name, o.groundColor.r, o.groundColor.g, o.groundColor.b);
        if (o.shadow) L('shadow ' + o.name, o.shadow.bias, o.shadow.radius);
      }
      if (o.isPerspectiveCamera) L('camera ' + o.name, o.fov, o.zoom, o.near, o.far);
      if (o.isOrthographicCamera) L('ortho ' + o.name, o.zoom, o.left, o.right, o.top);
      if (o.isScene) {
        L('scene ' + o.name, o.backgroundIntensity, o.backgroundBlurriness);
        if (o.fog && o.fog.isFog) L('fog', o.fog.near, o.fog.far, o.fog.color.r);
        if (o.fog && o.fog.isFogExp2) L('fog2', o.fog.density, o.fog.color.g);
      }
      if (o.isSprite) L('sprite ' + o.name, o.center.x, o.center.y);
    }
    materials.forEach((m, i) => {
      const values = [m.opacity, B(m.transparent), B(m.visible), m.version, m.alphaTest, nul(m.roughness), nul(m.metalness), nul(m.emissiveIntensity), nul(m.sheen), nul(m.shininess), nul(m.size), m.name];
      values.push(...(m.color ? [m.color.r, m.color.g, m.color.b] : [null]));
      values.push(...(m.emissive ? [m.emissive.r, m.emissive.g, m.emissive.b] : [null]));
      if (m.map) values.push(m.map.offset.x, m.map.offset.y, m.map.repeat.x, m.map.repeat.y, m.map.rotation);
      L('mat ' + i, ...values);
    });
    actions.forEach((a, i) => L('action ' + i, a.time, a.timeScale, a._effectiveTimeScale, a.weight, a._effectiveWeight, a.enabled, a.paused, a._loopCount, a.isRunning(), a.isScheduled(), a.repetitions === undefined ? NaN : a.repetitions, a.loop));
    if (group) L('group', group.stats.objects.total, group.stats.objects.inUse, group.stats.bindingsPerObject);
    const st = mixer.stats;
    L('mixer', mixer.time, mixer.timeScale, st.actions.total, st.actions.inUse, st.bindings.total, st.bindings.inUse, st.controlInterpolants.total, st.controlInterpolants.inUse);
  }
  for (const op of spec.ops) {
    switch (op[0]) {
      case 'action': {
        const a = mixer.clipAction(clips[op[1]], typeof op[2] === 'string' ? find(op[2]) : undefined, typeof op[3] === 'number' ? op[3] : undefined);
        L('actionIndex', actions.indexOf(a));
        if (actions.indexOf(a) === -1) actions.push(a);
        break;
      }
      case 'actionByName': {
        const a = mixer.clipAction(op[1]);
        if (a === null) L('actionIndex', null);
        else { L('actionIndex', actions.indexOf(a)); if (actions.indexOf(a) === -1) actions.push(a); }
        break;
      }
      case 'play': act(op[1]).play(); break;
      case 'stop': act(op[1]).stop(); break;
      case 'reset': act(op[1]).reset(); break;
      case 'fadeIn': act(op[1]).fadeIn(op[2]); break;
      case 'fadeOut': act(op[1]).fadeOut(op[2]); break;
      case 'crossFadeTo': act(op[1]).crossFadeTo(act(op[2]), op[3], op[4]); break;
      case 'crossFadeFrom': act(op[1]).crossFadeFrom(act(op[2]), op[3], op[4]); break;
      case 'setLoop': act(op[1]).setLoop(op[2], op[3] === null ? undefined : op[3] === 'Infinity' ? Infinity : op[3]); break;
      case 'set': act(op[1])[op[2]] = op[3]; break;
      case 'setEffectiveWeight': act(op[1]).setEffectiveWeight(op[2]); break;
      case 'setEffectiveTimeScale': act(op[1]).setEffectiveTimeScale(op[2]); break;
      case 'setDuration': act(op[1]).setDuration(op[2]); break;
      case 'syncWith': act(op[1]).syncWith(act(op[2])); break;
      case 'halt': act(op[1]).halt(op[2]); break;
      case 'warp': act(op[1]).warp(op[2], op[3], op[4]); break;
      case 'startAt': act(op[1]).startAt(op[2]); break;
      case 'stopFading': act(op[1]).stopFading(); break;
      case 'stopWarping': act(op[1]).stopWarping(); break;
      case 'update': mixer.update(op[1]); break;
      case 'setTime': mixer.setTime(op[1]); break;
      case 'mixerTimeScale': mixer.timeScale = op[1]; break;
      case 'stopAllAction': mixer.stopAllAction(); break;
      case 'uncacheClip': mixer.uncacheClip(clips[op[1]]); break;
      case 'uncacheRoot': mixer.uncacheRoot(typeof op[1] === 'string' ? find(op[1]) : mixer.getRoot()); break;
      case 'uncacheAction': mixer.uncacheAction(clips[op[1]]); break;
      case 'groupAdd': group.add(...op[1].map(find)); break;
      case 'groupRemove': group.remove(...op[1].map(find)); break;
      case 'groupUncache': group.uncache(...op[1].map(find)); break;
      case 'probe': {
        const binding = new T.PropertyBinding(roots[0], op[1]);
        const buffer = new Float64Array(op[2]);
        binding.getValue(buffer, 0);
        L('probe', op[1], Array.from(buffer));
        break;
      }
      case 'poke': new T.PropertyBinding(roots[0], op[1]).setValue(Float64Array.from(op[2]), 0); break;
      case 'listen': {
        const mode = op[2];
        mixer.addEventListener(op[1], event => {
          const i = actions.indexOf(event.action);
          const extra = event.type === 'loop' ? event.loopDelta : event.direction;
          L('event', event.type, i, nul(extra), mixer.time);
          if (mode === 'reverse') {
            event.action.timeScale *= -1;
            event.action.paused = false;
            event.action.startAt(mixer.time + 0.5).play();
          }
        });
        break;
      }
      default: throw new Error('op ' + op[0]);
    }
    L('op', op[0]);
    dump();
  }
  return log;
}

// --- MoonBit side ------------------------------------------------------------------

let portConsole = [];
function port(spec) {
  const log = [];
  portConsole = log;
  messages = log;
  // println from the port goes to console.log
  console.log = (...args) => log.push(['console', args.join(' ')]);
  let result;
  try {
    result = M.run_scenario(JSON.stringify(spec));
  } finally {
    console.log = realLog;
  }
  // interleave: the port's own entries carry no console lines, so merge by order of
  // occurrence is not possible; console lines are compared as a separate stream
  return { entries: Array.from(result), console: log.map(e => e[1]) };
}

// --- comparison --------------------------------------------------------------------

function flat(v) {
  if (ArrayBuffer.isView(v)) return Array.from(v);
  if (Array.isArray(v)) return v.map(flat);
  if (v !== null && typeof v === 'object') {
    const o = {};
    for (const k of Object.keys(v)) o[k] = flat(v[k]);
    return o;
  }
  return v;
}

function same(a, b) {
  a = flat(a); b = flat(b);
  if (Array.isArray(a) || Array.isArray(b)) {
    if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length) return false;
    return a.every((x, i) => same(x, b[i]));
  }
  if (a !== null && b !== null && typeof a === 'object' && typeof b === 'object') {
    const ka = Object.keys(a), kb = Object.keys(b);
    if (ka.length !== kb.length || ka.some((k, i) => k !== kb[i])) return false;
    return ka.every(k => same(a[k], b[k]));
  }
  return Object.is(a, b);
}

function show(v) {
  return JSON.stringify(flat(v), (k, x) => (typeof x === 'number' && !Number.isFinite(x)) || Object.is(x, -0) ? String(Object.is(x, -0) ? '-0' : x) : x);
}

function compare(name, spec) {
  spec = JSON.parse(JSON.stringify(spec));
  let up, upThrew = null;
  try { up = upstream(spec); }
  catch (e) { up = upstreamLog; upThrew = e.message; }
  messages = null;
  const upEntries = up.filter(e => e[0] !== 'console');
  const upConsole = up.filter(e => e[0] === 'console').map(e => e[1]);
  let mb, mbThrew = null;
  try { mb = port(spec); }
  catch (e) {
    // `abort` prints its message before throwing
    const lines = portConsole.map(e => e[1]);
    mbThrew = lines.length ? lines.pop() : 'panic: ' + String(e.stack).split('\n').slice(1, 4).join(' / ');
    mb = { entries: Array.from(M.last_log()), console: lines };
  }
  const n = Math.max(upEntries.length, mb.entries.length);
  for (let i = 0; i < n; i++) {
    if (!same(upEntries[i], mb.entries[i])) {
      return { name, fail: `entry ${i}${upThrew ? " (upstream threw: " + upThrew + ")" : ""}${mbThrew ? " (port threw: " + mbThrew + ")" : ""}\n  upstream: ${show(upEntries[i])}\n  port:     ${show(mb.entries[i])}\n  previous: ${show(upEntries[i - 1])}` };
    }
  }
  if (!same(upConsole, mb.console)) {
    return { name, fail: `console\n  upstream: ${show(upConsole)}\n  port:     ${show(mb.console)}` };
  }
  const strip = m => (m === null ? null : m.replace(/^(THREE\.)?(TypeError: |Error: )?/, '').replace(/^THREE\./, ''));
  if ((upThrew === null) !== (mbThrew === null) || (upThrew !== null && strip(upThrew) !== strip(mbThrew) && !process.env.LOOSE_THROW)) {
    return { name, fail: `upstream threw: ${upThrew}; port threw: ${mbThrew}` };
  }
  return { name, ok: upEntries.length, console: upConsole.length, threw: upThrew };
}

// --- main --------------------------------------------------------------------------

const args = process.argv.slice(2);
let random = 0, seed = 1;
const names = [];
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--random') random = Number(args[++i]);
  else if (args[i] === '--seed') seed = Number(args[++i]);
  else names.push(args[i]);
}
const list = Object.entries(scenarios).filter(([k]) => names.length === 0 || names.includes(k));
for (let i = 0; i < random; i++) {
  list.push(['random' + (seed + i), randomScenario(seed + i)]);
  if (i % 3 === 0) list.push(['utils' + (seed + i), randomUtilsScenario(seed + i)]);
  if (i % 3 === 1) list.push(['group' + (seed + i), randomGroupScenario(seed + i)]);
}
let failed = 0, entries = 0;
for (const [name, spec] of list) {
  const r = compare(name, spec);
  if (r.fail) { failed++; realLog('FAIL ' + name + ': ' + r.fail); }
  else if (r.skipped) realLog('SKIP ' + name + ': ' + r.skipped);
  else { entries += r.ok; if (names.length || list.length < 40 || process.env.VERBOSE) realLog(`ok   ${name} (${r.ok} entries, ${r.console} console lines${r.threw ? '; both threw, upstream: ' + r.threw : ''})`); }
}
realLog(`${list.length - failed}/${list.length} scenarios match, ${entries} log entries compared`);
process.exit(failed ? 1 : 0);
