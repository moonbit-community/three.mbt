// Differential check of three geometry gaps against upstream r187.
//   node run.mjs            harness in this directory, built against the repo (moon.work)
//   GAPS_MODULE_DIR=<dir> node run.mjs   build and load the MoonBit side from <dir> (mutate.py)
// Env: SHOW=n prints the first n mismatches, ONLY=substring filters case ids.
import { execSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { upstreamURL } from '../../lib/env.mjs';
const here = process.env.GAPS_MODULE_DIR ? path.resolve(process.env.GAPS_MODULE_DIR) : path.dirname(fileURLToPath(import.meta.url));
const T = await import(upstreamURL('src/Three.js'));

if (!process.env.SKIP_BUILD) try { execSync('moon build --target js', { cwd: here, stdio: 'pipe' }); }
catch (e) { console.log('BUILD FAILED\n' + String(e.stdout).split('\n').filter(l => /rror/.test(l)).slice(0, 20).join('\n')); process.exit(2); }
const M = await import(pathToFileURL(path.join(here, '_build/js/debug/build/moonbit-community/three-diff-geometry-gaps/main/main.js')).href);
// MoonBit's abort reports its message on console.error, then throws an empty $PanicError
let panicText = '';
console.warn = () => {}; console.error = (...a) => { panicText = a.join(' '); };
const log = console.log;

const v2 = (x, y) => new T.Vector2(x, y);
const v3 = (x, y, z) => new T.Vector3(x, y, z);
function triangle() { const s = new T.Shape(); s.moveTo(0, -1); s.lineTo(1, 1); s.lineTo(-1, 1); return s; }
function squareWithHole() {
  const s = new T.Shape([v2(-2, -2), v2(2, -2), v2(2, 2), v2(-2, 2)]);
  s.holes = [new T.Path([v2(-1, -1), v2(-1, 1), v2(1, 1), v2(1, -1)])];
  return s;
}
const catmullPoints = () => [v3(0, 0, 0), v3(1, 2, 0), v3(2, 0, 1), v3(3, 1, 2)];
function plain() {
  const g = new T.BufferGeometry();
  g.setAttribute('position', new T.Float32BufferAttribute([0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0], 3));
  g.setIndex([0, 1, 2, 2, 1, 3]);
  return g;
}
const MAKE = {
  Plain: plain,
  Box: () => new T.BoxGeometry(1, 2, 3),
  Sphere: () => new T.SphereGeometry(1, 4, 3),
  Cone: () => new T.ConeGeometry(1, 2, 5),
  Tetra: () => new T.TetrahedronGeometry(1, 0),
  Shape0: () => new T.ShapeGeometry(),
  Shape1: () => new T.ShapeGeometry(triangle()),
  ShapeN: () => new T.ShapeGeometry([squareWithHole(), triangle()], 4),
  Extrude0: () => new T.ExtrudeGeometry(),
  ExtrudeN: () => new T.ExtrudeGeometry([squareWithHole(), triangle()], { steps: 2, depth: 2, bevelEnabled: false }),
  ExtrudePath: () => new T.ExtrudeGeometry([triangle()], { steps: 3, extrudePath: new T.CatmullRomCurve3(catmullPoints()) }),
  Tube0: () => new T.TubeGeometry(),
  TubeC: () => new T.TubeGeometry(new T.CatmullRomCurve3(catmullPoints(), true), 8, 0.5, 4, true),
  Edges: () => new T.EdgesGeometry(new T.BoxGeometry(), 10),
  Edges0: () => new T.EdgesGeometry(),
  Wire: () => new T.WireframeGeometry(new T.SphereGeometry(1, 4, 3)),
  Wire0: () => new T.WireframeGeometry(),
  Lathe: () => new T.LatheGeometry([v2(0, -1), v2(0.5, 0), v2(0.25, 1)], 5),
  Lathe3: () => new T.LatheGeometry([v3(0, -1, 7), v3(0.5, 0, 8), v3(0.25, 1, 9)], 3),
};
const make = (n) => MAKE[n]();
const json = (g) => JSON.stringify(g.toJSON());

const LIVE = {
  edges_src_name() { const src = new T.BoxGeometry(); const e = new T.EdgesGeometry(src); src.name = 'renamed'; return json(e); },
  edges_src_translate() { const src = new T.BoxGeometry(); const e = new T.EdgesGeometry(src); src.translate(1, 0, 0); return json(e); },
  edges_src_attribute() {
    const src = plain(); const e = new T.EdgesGeometry(src);
    src.setAttribute('color', new T.Float32BufferAttribute([1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 1], 3)); return json(e);
  },
  edges_src_copy() { const src = new T.BoxGeometry(); const e = new T.EdgesGeometry(src); src.copy(make('Sphere')); return json(e); },
  edges_copied_onto_box() { const src = new T.BoxGeometry(); const e = new T.EdgesGeometry(src); const b = new T.BoxGeometry().copy(e); src.name = 'late'; return json(b); },
  edges_clone() { const src = new T.BoxGeometry(); const e = new T.EdgesGeometry(src); const c = e.clone(); src.name = 'late'; return json(c); },
  edges_of_lathe_points() {
    const points = [v2(0, -1), v2(0.5, 0), v2(0.25, 1)];
    const e = new T.EdgesGeometry(new T.LatheGeometry(points, 3)); points[0].x = 0.3; return json(e);
  },
  wire_src_name() { const src = make('Sphere'); const w = new T.WireframeGeometry(src); src.name = 'renamed'; return json(w); },
  wire_src_translate() { const src = make('Sphere'); const w = new T.WireframeGeometry(src); src.translate(0, 1, 0); return json(w); },
  wire_copied_onto_box() { const src = make('Sphere'); const w = new T.WireframeGeometry(src); const b = new T.BoxGeometry().copy(w); src.name = 'late'; return json(b); },
  lathe_points() { const points = [v2(0, -1), v2(0.5, 0), v2(0.25, 1)]; const l = new T.LatheGeometry(points, 3); points[0].x = 0.75; points.push(v2(0.1, 1.5)); return json(l); },
  lathe_points_copy() {
    const points = [v2(0, -1), v2(0.5, 0), v2(0.25, 1)]; const l = new T.LatheGeometry(points, 3);
    const b = new T.BoxGeometry().copy(l); const c = l.clone(); points[1].y = 0.125; return json(b) + '\n' + json(c);
  },
  lathe3_points() { const points = [v3(0, -1, 7), v3(0.5, 0, 8), v3(0.25, 1, 9)]; const l = new T.LatheGeometry(points, 3); points[2].z = -4; return json(l); },
  tube_path() {
    const p1 = v3(-1, 1, 0); const t = new T.TubeGeometry(new T.QuadraticBezierCurve3(v3(-1, -1, 0), p1, v3(1, 1, 0)), 4, 1, 3);
    p1.x = 9; return json(t);
  },
  tube_path_transformed() {
    const p1 = v3(-1, 1, 0); const t = new T.TubeGeometry(new T.QuadraticBezierCurve3(v3(-1, -1, 0), p1, v3(1, 1, 0)), 4, 1, 3);
    t.translate(1, 1, 1); p1.x = 9; return json(t);
  },
  tube_catmull_push() {
    const points = catmullPoints(); const t = new T.TubeGeometry(new T.CatmullRomCurve3(points), 4, 1, 3);
    const b = new T.BoxGeometry().copy(t); points.push(v3(5, 5, 5)); return json(t) + '\n' + json(b);
  },
  extrude_path() {
    const points = catmullPoints(); const e = new T.ExtrudeGeometry([triangle()], { steps: 2, extrudePath: new T.CatmullRomCurve3(points) });
    points[1].x = 7; return json(e);
  },
  extrude_path_transformed() {
    const points = catmullPoints(); const e = new T.ExtrudeGeometry([triangle()], { steps: 2, extrudePath: new T.CatmullRomCurve3(points) });
    e.rotateX(0.5); points[1].x = 7; return json(e);
  },
  shape_hole_added() {
    const shape = triangle(); const s = new T.ShapeGeometry(shape); const b = new T.BoxGeometry().copy(s);
    shape.holes = [new T.Path([v2(0, 0), v2(0.1, 0.5), v2(-0.1, 0.5)])]; return json(s) + '\n' + json(b);
  },
};

function upstream(id) {
  const [op, a, b] = id.split('|');
  switch (op) {
    case 'json': return json(make(a));
    case 'translate': return json(make(a).translate(0.5, 0.25, -0.125));
    case 'rotate': return json(make(a).rotateX(0.5));
    case 'matrix': return json(make(a).applyMatrix4(new T.Matrix4().makeTranslation(1, 2, 3)));
    case 'clone_translated': return json(make(a).translate(0.5, 0.25, -0.125).clone());
    case 'translated_clone_copy': { const t = make(a).translate(1, 0, 0); return json(make(a).copy(t)); }
    case 'copy': return json(make(a).copy(make(b)));
    case 'copy_src_translated': return json(make(a).copy(make(b).translate(1, 0, 0)));
    case 'copy_tgt_translated': return json(make(a).translate(1, 0, 0).copy(make(b)));
    case 'copy_clone': return json(make(a).copy(make(b)).clone());
    case 'copy_then_translate': return json(make(a).copy(make(b)).translate(1, 0, 0));
    case 'copy_type': return make(a).copy(make(b)).type;
    case 'live': return LIVE[a]();
  }
  throw new Error('unknown op ' + id);
}

// MoonBit's Json::stringify may spell a number differently, so re-serialize through JS;
// uuids are numbered in order of appearance.
const UUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi;
function normalizeUuids(text) { const m = new Map(); return text.replace(UUID, u => { if (!m.has(u)) m.set(u, 'U' + m.size); return m.get(u); }); }
const reparse = (t) => t.split('\n').map(l => l.startsWith('{') ? JSON.stringify(JSON.parse(l.replace(/(?<=[:\[,])(-?Infinity|NaN)(?=[,\]}])/g, 'null'))) : l).join('\n');

const NAMES = Object.keys(MAKE);
const TRANSFORMING = ['Shape0', 'Shape1', 'ShapeN', 'Extrude0', 'ExtrudeN', 'ExtrudePath', 'Tube0', 'TubeC'];
const TARGETS = ['Plain', 'Box', 'Cone', 'Tetra', 'Shape1', 'ShapeN', 'Extrude0', 'ExtrudePath', 'Tube0', 'Edges', 'Wire', 'Lathe'];
const groups = {
  // gap 1: the classes overriding toJSON, transformed (and untransformed, as a control)
  transformed: TRANSFORMING.flatMap(a => ['json', 'translate', 'rotate', 'matrix', 'clone_translated', 'translated_clone_copy'].map(op => `${op}|${a}`)),
  // gap 2: every target class against every source, plain included
  copy: TARGETS.flatMap(a => NAMES.flatMap(b => ['copy', 'copy_src_translated', 'copy_tgt_translated', 'copy_clone', 'copy_then_translate', 'copy_type'].map(op => `${op}|${a}|${b}`))),
  // gap 3: sources mutated after construction
  live: Object.keys(LIVE).map(n => `live|${n}`),
  // controls for everything else these files touch
  other: NAMES.filter(n => !TRANSFORMING.includes(n)).flatMap(a => ['json', 'translate', 'clone_translated'].map(op => `${op}|${a}`)),
};

const only = process.env.ONLY, show = +(process.env.SHOW ?? 8);
let shown = 0; const summary = {}; const throwClasses = {};
for (const [group, ids] of Object.entries(groups)) {
  const s = summary[group] = { cases: 0, match: 0, bothThrow: 0, mismatch: 0, byKey: {} };
  for (const id of ids) {
    if (only && !id.includes(only)) continue;
    s.cases++;
    let u, ue, m, me;
    try { u = upstream(id); } catch (e) { ue = e; }
    panicText = '';
    try { m = M.run(id); } catch (e) { me = { message: panicText || String(e?.message ?? e) }; }
    let ok, detail;
    if (ue || me) { ok = !!(ue && me) && me.message.includes(ue.message); detail = `throw upstream=${ue?.message} port=${String(me?.message ?? me ?? '').split('\n')[0]}${ue ? '' : '\n  U ' + u.slice(0, 200)}`; if (ok) { s.bothThrow++; const c = `${id.split('|')[1]}: ${ue.message.slice(0, 50)} <-> ${String(me?.message ?? me).split('\n')[0].slice(0, 70)}`; throwClasses[c] = (throwClasses[c] || 0) + 1; } }
    else {
      const a = normalizeUuids(u), b = normalizeUuids(reparse(m));
      ok = a === b;
      if (!ok) { let i = 0; while (a[i] === b[i]) i++; detail = `at ${i}\n  U ${a.slice(Math.max(0, i - 100), i + 140)}\n  M ${b.slice(Math.max(0, i - 100), i + 140)}`; }
    }
    if (ok) { s.match++; continue; }
    s.mismatch++;
    const key = id.split('|').slice(0, 2).join('|');
    s.byKey[key] = (s.byKey[key] || 0) + 1;
    if (shown++ < show) log('MISMATCH', id, detail);
  }
}
for (const [g, s] of Object.entries(summary)) log(`${g}: cases=${s.cases} match=${s.match} (bothThrow=${s.bothThrow}) mismatch=${s.mismatch}`, Object.keys(s.byKey).length ? JSON.stringify(s.byKey) : '');
if (process.env.THROWS) for (const [k, v] of Object.entries(throwClasses)) log('  bothThrow', v, k);
const total = Object.values(summary).reduce((n, s) => n + s.mismatch, 0);
log(`TOTAL mismatch=${total}`);
process.exitCode = total ? 1 : 0;
