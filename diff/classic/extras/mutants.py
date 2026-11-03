#!/usr/bin/env python3
# Mutation check of the extras harness. Each mutant (file, old, new) is applied, one at a
# time, to a sandbox copy of the port (moon.mod, src/math, src/core, src/extras and this
# harness's bridge package, under $THREE_DIFF_OUT/classic_extras/mutant), never to the
# repository; the sandbox is built and driver.mjs runs against it (BRIDGE=<its bridge.js>).
# Usage: python3 mutants.py [index ...]   (INJECT_DRY_RUN=1: only check the patterns)
import os, pathlib, shutil, subprocess, sys
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(next(p for p in HERE.parents if (p / 'lib/env.py').exists())))
from lib.env import REPO, out_dir  # noqa: E402

M = [
    ('earcut_lib.mbt', 'result = a_slope - b_slope', 'result = b_slope - a_slope'),
    ('earcut_lib.mbt', 'x | (y << 1)', '(x << 1) | y'),
    ('curve.mbt', '    if comparison < 0.0 {\n      low = i + 1', '    if comparison <= 0.0 {\n      low = i + 1'),
    ('ellipse_curve.mbt', 'if self.a_rotation != 0.0 {', 'if self.a_rotation > 0.0 {'),
    ('catmull_rom_curve3.mbt', '    if dt2 < 1.0e-4 {\n      dt2 = dt1', '    if dt2 < 1.0e-4 {\n      dt2 = dt0'),
    ('curve_path.mbt', 'Spline(spline) => divisions * spline.points.length()', 'Spline(spline) => divisions * (spline.points.length() - 1)'),
    ('curve_path.mbt', '''  data["autoClose"] = Json::boolean(self.auto_close)
  data["curves"] = Json::array(self.curves.map(curve => curve.to_json()))''', '''  data["curves"] = Json::array(self.curves.map(curve => curve.to_json()))
  data["autoClose"] = Json::boolean(self.auto_close)'''),
    ('shape_path.mbt', '''      entry.container = if candidate.exclude {
        candidate.container
      } else {
        Some(candidate)
      }''', '''      entry.container = Some(candidate)'''),
    ('curve.mbt', '  if tz <= min {', '  if tz < min {'),
    ('curve.mbt', '    cache.length() == divisions + 1 &&\n    !self.needs_update {', '    cache.length() == divisions + 1 {'),
]

DRY = os.environ.get('INJECT_DRY_RUN') == '1'
BOX = out_dir('classic_extras') / 'mutant'
BRIDGE_JS = BOX / '_build/js/release/build/bridge/bridge.js'


def sandbox():
    """Fresh copy of the packages the bridge needs, with the bridge as src/bridge."""
    shutil.rmtree(BOX, ignore_errors=True)
    (BOX / 'src').mkdir(parents=True)
    shutil.copy(REPO / 'moon.mod', BOX / 'moon.mod')
    skip = shutil.ignore_patterns('pkg.generated.mbti', '_build')
    for pkg in ('math', 'core', 'extras'):
        shutil.copytree(REPO / 'src' / pkg, BOX / 'src' / pkg, ignore=skip)
    shutil.copytree(HERE / 'bridge', BOX / 'src/bridge', ignore=skip)


res = []
only = [int(a) for a in sys.argv[1:]]
for i, (f, old, new) in enumerate(M):
    if only and i not in only:
        continue
    src = (REPO / 'src/extras' / f).read_text()
    assert src.count(old) == 1, (i, f, old)
    if DRY:
        print((i, f, 'pattern ok'))
        continue
    sandbox()
    target = BOX / 'src/extras' / f
    target.write_text(src.replace(old, new, 1))
    b = subprocess.run(['moon', 'build', '--target', 'js', '--release'], cwd=BOX, capture_output=True, text=True)
    if b.returncode != 0:
        res.append((i, f, 'BUILD FAILED', (b.stdout + b.stderr)[:300]))
        print(res[-1], flush=True)
        continue
    env = dict(os.environ, BRIDGE=BRIDGE_JS.as_uri())
    r = subprocess.run(['node', str(HERE / 'driver.mjs'), '1', '0.3'], capture_output=True, text=True, timeout=900, env=env)
    tot = [l for l in r.stdout.splitlines() if l.startswith('TOTAL')]
    groups = [l.split()[0] for l in r.stdout.splitlines() if len(l.split()) == 4 and l.split()[3].isdigit() and l.split()[3] != '0' and not l.startswith('TOTAL')]
    res.append((i, f, 'DETECTED' if r.returncode == 1 else 'MISSED (exit %d)' % r.returncode, tot[0] if tot else r.stderr[-300:], groups))
    print(res[-1], flush=True)
if not DRY:
    shutil.rmtree(BOX, ignore_errors=True)
    print(f"{sum(1 for r in res if r[2] == 'DETECTED')}/{len(res)} mutants detected")
