#!/usr/bin/env python3
"""Inject deliberate bugs into a temporary COPY of the port (math, core, extras,
geometries under $THREE_DIFF_OUT/classic_geometry_gaps/mutant; the repository is never
modified) and confirm run.mjs flags each one.

    python3 mutate.py
    INJECT_DRY_RUN=1 python3 mutate.py    # only check that every pattern applies
"""
import os, shutil, subprocess, re, sys
from pathlib import Path
D = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, str(Path(D).parents[1]))  # diff/
from lib.env import REPO, out_dir  # noqa: E402
M = str(out_dir('classic_geometry_gaps', 'mutant'))
SRC = str(REPO)
DRY_RUN = os.environ.get('INJECT_DRY_RUN') == '1'
shutil.rmtree(M, ignore_errors=True)
os.makedirs(M + '/three/src')
shutil.copy(f'{SRC}/moon.mod', M + '/three/')
for pkg in ['math', 'core', 'extras', 'geometries']:
    shutil.copytree(f'{SRC}/src/{pkg}', f'{M}/three/src/{pkg}', ignore=shutil.ignore_patterns('*_test.mbt'))
os.makedirs(M + '/h')
shutil.copytree(D + '/src', M + '/h/src')
shutil.copy(f'{D}/moon.mod', M + '/h/')
open(M + '/h/moon.work', 'w').write('members = [\n  "../three",\n  ".",\n]\n')
MUTANTS = [  # file, old, new
  ('core/buffer_geometry.mbt', '  if self.to_json_hook() is Some(hook) {\n    hook(self, data)', '  if self.to_json_hook() is Some(hook) && self._transformed {\n    hook(self, data)'),
  ('core/buffer_geometry.mbt', '  if self.to_json_hook() is Some(hook) {\n    geometry.set_to_json_hook(hook)\n  }\n', ''),
  ('core/buffer_geometry.mbt', 'guard source is Some(source) else { return { values: Map([]), shapes: [], } }', 'guard source is Some(source) else { abort("plain source") }'),
  ('core/buffer_geometry.mbt', '  if self.parameters is Some(_) {\n    self.parameters = Some(GeometryParameters::copy_values(source.parameters))', '  if self.parameters is Some(_) && source.parameters is Some(_) {\n    self.parameters = Some(GeometryParameters::copy_values(source.parameters))'),
  ('core/buffer_geometry.mbt', '      JsValue::of(lazy_values.copy()),', '      JsValue::of(Map::from_array([("x", fn() { Json::null() })])),'),
  ('geometries/lathe_geometry.mbt', '  let points_json = () => Json::array(points.map(vector2_json))', '  let snapshot = Json::array(points.map(vector2_json))\n  let points_json = () => snapshot'),
  ('geometries/utils.mbt', '    Some(geometry) => { "geometry": () => geometry.to_json() }', '    Some(geometry) => {\n      let snapshot = geometry.to_json()\n      { "geometry": () => snapshot }\n    }'),
  ('geometries/tube_geometry.mbt', '    to_json_hook=tube_geometry_to_json,\n', ''),
  ('geometries/tube_geometry.mbt', '    lazy_values={ "path": () => path.to_json() },', '    lazy_values={ "path": { let p = path.to_json(); () => p } },'),
  ('geometries/extrude_geometry.mbt', '      extrude_build(extrude_default_shapes(), true, options, () => {', '      extrude_build(extrude_default_shapes(), false, options, () => {'),
  ('geometries/extrude_geometry.mbt', '  data["options"] = options\n', ''),
  ('geometries/shape_geometry.mbt', '      () => shapes[0].to_json()', '      () => Json::array([shapes[0].to_json()])'),
]
if DRY_RUN:
    bad = [(p, o[:60]) for p, o, _ in MUTANTS if o not in open(f'{SRC}/src/{p}').read()]
    print(f'{len(MUTANTS) - len(bad)}/{len(MUTANTS)} patterns apply' + (f'; not found: {bad}' if bad else ''))
    sys.exit(1 if bad else 0)
for path, old, new in MUTANTS:
    f = f'{M}/three/src/{path}'
    src = open(f).read()
    if old not in src: print(path, 'OLD TEXT NOT FOUND', old[:60]); continue
    open(f, 'w').write(src.replace(old, new, 1))
    p = subprocess.run(['node', 'run.mjs'], cwd=D, env=dict(os.environ, SHOW='1', GAPS_MODULE_DIR=M + '/h'), capture_output=True, text=True)
    open(f, 'w').write(src)
    out = p.stdout
    if 'BUILD FAILED' in out: print(path, new[:60].replace('\n', ' '), 'MUTANT DID NOT COMPILE', out[:300]); continue
    t = re.search(r'TOTAL mismatch=(\d+)', out)
    groups = ' '.join(f'{g}={n}' for g, n in re.findall(r'^(\w+): cases=\d+ match=\d+ \(bothThrow=\d+\) mismatch=(\d+)', out, re.M))
    print(f'{path}: {old.strip()[:55]!r} -> detected={t and t.group(1) != "0"} {groups}', flush=True)
