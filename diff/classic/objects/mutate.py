#!/usr/bin/env python3
"""Bug injection for the objects harness on a temporary COPY of src/math and src/core
(under $THREE_DIFF_OUT/classic_objects/mutant; the repository is never modified): each
mutation is applied to the copy, the MoonBit runner is rebuilt against it and run.sh
must report differing scenarios.

    python3 mutate.py                    # the built-in list
    python3 mutate.py <file> <old> <new> # one ad-hoc mutation of src/core/<file>
    INJECT_DRY_RUN=1 python3 mutate.py   # only check that every pattern applies
"""
import os, re, shutil, subprocess, sys
from pathlib import Path
D = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, str(Path(D).parents[1]))  # diff/
from lib.env import REPO, out_dir  # noqa: E402
DRY_RUN = os.environ.get('INJECT_DRY_RUN') == '1'

MUTANTS = [  # file in src/core, old, new
    ('points.mbt', '  if ray_point_distance_sq < local_threshold_sq {', '  if ray_point_distance_sq <= local_threshold_sq * 0.99 {'),
    ('mesh.mbt', '    ray.intersect_triangle(p_c, p_b, p_a, true, point)', '    ray.intersect_triangle(p_a, p_b, p_c, true, point)'),
    ('points.mbt', '  _points_sphere.radius = _points_sphere.radius + threshold', '  _points_sphere.radius = _points_sphere.radius'),
    ('lod.mbt', '        level_distance = level_distance - level_distance * levels[i].hysteresis', '        level_distance = level_distance + level_distance * levels[i].hysteresis'),
]
if len(sys.argv) == 4:
    MUTANTS = [tuple(sys.argv[1:4])]

if DRY_RUN:
    bad = [(f, o[:60]) for f, o, _ in MUTANTS if o not in (REPO / 'src/core' / f).read_text()]
    print(f'{len(MUTANTS) - len(bad)}/{len(MUTANTS)} patterns apply' + (f'; not found: {bad}' if bad else ''))
    sys.exit(1 if bad else 0)

M = out_dir('classic_objects', 'mutant')
shutil.rmtree(M)
(M / 'three/src').mkdir(parents=True)
shutil.copy(REPO / 'moon.mod', M / 'three')
for pkg in ['math', 'core']:
    shutil.copytree(REPO / 'src' / pkg, M / 'three/src' / pkg, ignore=shutil.ignore_patterns('*_test.mbt', '*_wbtest.mbt'))
shutil.copytree(Path(D) / 'mbt/diff', M / 'h/diff')
shutil.copy(Path(D) / 'mbt/moon.mod', M / 'h')
(M / 'h/moon.work').write_text('members = [\n  ".",\n  "../three",\n]\n')
runner = M / 'h/_build/js/debug/build/moonbit-community/three-diff-objects/diff/diff.js'

def run():
    b = subprocess.run(['moon', 'build', '--target', 'js'], cwd=M / 'h', capture_output=True, text=True)
    if b.returncode != 0:
        return 'BUILD FAILED ' + (b.stdout + b.stderr)[-300:]
    p = subprocess.run(['bash', 'run.sh'], cwd=D, env=dict(os.environ, OBJECTS_RUNNER=str(runner)), capture_output=True, text=True)
    out = p.stdout + p.stderr
    s = re.findall(r'^\d+/\d+ scenarios identical.*$', out, re.M)
    first = next((l for l in out.split('\n') if l.startswith('[')), '')
    return (s[-1] if s else 'NO SUMMARY ' + out[-300:]) + (' | ' + first[:120] if first else '')

caught = 0
for f, old, new in MUTANTS:
    path = M / 'three/src/core' / f
    src = path.read_text()
    path.write_text(src.replace(old, new, 1))
    res = run()
    path.write_text(src)
    hit = 'BUILD FAILED' in res or not re.match(r'(\d+)/\1 ', res)
    caught += hit
    print(f'{"CAUGHT" if hit else "MISSED"} {f}: {old.strip()[:60]!r}\n    {res}', flush=True)
print(f'{caught}/{len(MUTANTS)} caught')
