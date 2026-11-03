#!/usr/bin/env python3
"""Inject deliberate bugs into a temporary COPY of the port (math, core, extras,
geometries under $THREE_DIFF_OUT/classic_geometries/mutant; the repository is never
modified) and confirm run.mjs flags them.

    python3 mutate.py [file-substring [show]]
    INJECT_DRY_RUN=1 python3 mutate.py    # only check that every pattern applies
"""
import os, shutil, subprocess, sys, re
from pathlib import Path
D = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, str(Path(D).parents[1]))  # diff/
from lib.env import REPO, out_dir  # noqa: E402
M = str(out_dir('classic_geometries', 'mutant'))
SRC = str(REPO)
DRY_RUN = os.environ.get('INJECT_DRY_RUN') == '1'
shutil.rmtree(M, ignore_errors=True)
os.makedirs(M + '/three'); os.makedirs(M + '/h/src')
for f in ['moon.mod', 'README.md', 'LICENSE']:
    if os.path.exists(f'{SRC}/{f}'): shutil.copy(f'{SRC}/{f}', M + '/three/')
for pkg in ['math', 'core', 'geometries', 'extras']:
    if os.path.exists(f'{SRC}/src/{pkg}'): shutil.copytree(f'{SRC}/src/{pkg}', f'{M}/three/src/{pkg}')
shutil.copytree(D + '/src/main', M + '/h/src/main')
shutil.copy(D + '/moon.mod', M + '/h/')
open(M + '/h/moon.work', 'w').write('members = [\n  "../three",\n  ".",\n]\n')

MUTANTS = [
  # file, old, new, ONLY filter
  ('plane_geometry.mbt', 'push3(vertices, x, -y, 0.0)', 'push3(vertices, x, 0.0 - y, 0.0)', '"name":"Plane"'),   # -0 vs +0
  ('box_geometry.mbt', 'if depth > 0.0 { 1.0 } else { -1.0 }', 'if depth >= 0.0 { 1.0 } else { -1.0 }', '"name":"Box"'),
  ('sphere_geometry.mbt', 'u_offset = -0.5 / width_segments', 'u_offset = 0.5 / width_segments', '"name":"Sphere"'),
  ('cylinder_geometry.mbt', 'material_index=if top { 1 } else { 2 }', 'material_index=if top { 2 } else { 1 }', '"name":"Cylinder"'),
  ('ring_geometry.mbt', 'let phi_segments = js_math_max(1.0, phi_segments)', 'let phi_segments = js_math_max(1.0, phi_segments.floor())', '"name":"Ring"'),
  ('circle_geometry.mbt', '"thetaStart": @math.json_number(theta_start),\n    "thetaLength": @math.json_number(theta_length),', '"thetaLength": @math.json_number(theta_length),\n    "thetaStart": @math.json_number(theta_start),', '"name":"Circle"'),  # parameter key order
  ('capsule_geometry.mbt', 'js_math_min(1.0, current_arc_length / total_arc_length)', '1.0.min(current_arc_length / total_arc_length)', '"name":"Capsule"'),  # NaN handling
  ('torus_knot_geometry.mbt', 'calculate_position_on_curve(u + 0.01, p, q, radius, p2)', 'calculate_position_on_curve(u + 0.0100001, p, q, radius, p2)', '"name":"TorusKnot"'),
  ('polyhedron_geometry.mbt', '@core.Float32BufferAttribute::new(uv_buffer, 2)', '@core.Float16BufferAttribute::new(uv_buffer, 2)', '"name":"Tetrahedron"'),  # array type
  ('lathe_geometry.mbt', 'push3(indices, c, d, b)', 'push3(indices, b, c, d)', '"name":"Lathe"'),
  ('edges_geometry.mbt', 'js_number_string(js_math_round(v.x * precision))', 'js_number_string(1.0 / js_math_round(v.x * precision))', '"name":"Edges"'),  # hash tells -0 from 0
  ('wireframe_geometry.mbt', '"\\{js_number_string(v.x)},', '"\\{js_number_string(1.0 / v.x)},', '"name":"Wireframe"'),  # hash tells -0 from 0
  ('wireframe_geometry.mbt', 'if edges.contains(hash1) || edges.contains(hash2) {', 'if false {', '"name":"Wireframe"'),  # no dedupe at all
  ('cone_geometry.mbt', 'geometry.type_ = "ConeGeometry"', 'geometry.type_ = "CylinderGeometry"', '"name":"Cone"'),
  ('dodecahedron_geometry.mbt', '19.0, 5.0, 14.0,', '19.0, 14.0, 5.0,', '"name":"Dodecahedron"'),
  ('torus_geometry.mbt', '"tube": @math.json_number(tube)', '"tube": @math.json_number(tube + 1.0e-12)', '"name":"Torus"'),   # parameters only
  ('utils.mbt', 'geometry.set_attribute("uv"', 'geometry.set_attribute("uvs"', '"name":"Plane"'),
]
if os.path.exists(D + '/mutants_extra.py'):
    MUTANTS += [tuple(x) for x in eval(open(D + '/mutants_extra.py').read())]
if len(sys.argv) > 1: MUTANTS = [m for m in MUTANTS if sys.argv[1] in m[0]]
results = []
def run(only):
    env = dict(os.environ, ONLY=only, SHOW='1', GEOMETRIES_MODULE_DIR=M + '/h')
    p = subprocess.run(['node', 'run.mjs'], cwd=D, env=env, capture_output=True, text=True)
    # 0 = all pass, 1 = failures found with a summary; anything else is a crash, not a verdict
    crashed = p.returncode not in (0, 1) or 'cases=' not in p.stdout
    return p.stdout + (f'\nHARNESS CRASHED (exit {p.returncode})\n' + p.stderr[-600:] if crashed else '')
if DRY_RUN:
    bad = [(p, o) for p, o, _, _ in MUTANTS if o not in open(f'{SRC}/src/geometries/{p}').read()]
    print(f'{len(MUTANTS) - len(bad)}/{len(MUTANTS)} patterns apply' + (f'; not found: {bad}' if bad else ''))
    sys.exit(1 if bad else 0)
for path, old, new, only in MUTANTS:
    f = f'{M}/three/src/geometries/{path}'
    src = open(f).read()
    if old not in src: results.append((path, old, 'OLD TEXT NOT FOUND')); continue
    open(f, 'w').write(src.replace(old, new, 1))
    out = run(only)
    open(f, 'w').write(src)
    if 'BUILD FAILED' in out: results.append((path, new[:50], 'MUTANT DID NOT COMPILE', out[:200])); print(results[-1], flush=True); continue
    if 'HARNESS CRASHED' in out: results.append((path, new[:50], 'HARNESS CRASHED', out[-300:])); print(results[-1], flush=True); continue
    m = re.search(r'cases=(\d+) pass=(\d+) bothThrow=(\d+) fail=(\d+)', out)
    first = next((l.strip() for l in out.split('\n')[1:] if l.strip() and not l.startswith('THREE')), '')[:110]
    results.append((path, new[:50].replace('\n', ' '), m.group(0) if m else 'NO SUMMARY: ' + out[-300:], first))
    print(results[-1], flush=True)
detected = sum(1 for r in results if re.search(r'fail=[1-9]', r[2]))
print(f'mutants={len(results)} detected={detected}')
if len(sys.argv) > 2: print(out[-1500:])
