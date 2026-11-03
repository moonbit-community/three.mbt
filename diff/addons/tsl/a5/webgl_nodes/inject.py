#!/usr/bin/env python3
"""Bug injections into src/addons/tsl/webgl_nodes_handler.mbt, one at a time; each must make
run.mjs report a mismatch. The file is restored after each (diff/lib/inject.py).
    python3 inject.py [index ...]
    INJECT_DRY_RUN=1 python3 inject.py   # only check that every pattern still occurs
"""
import subprocess, sys, pathlib
sys.path.insert(0, str(next(p for p in pathlib.Path(__file__).resolve().parents if (p / 'lib/env.py').exists())))
from lib.env import DIFF, REPO  # noqa: E402
from lib.inject import patched, DRY_RUN  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent
M = 'src/addons/tsl/webgl_nodes_handler.mbt'
BUGS = [
  ('object hash ignores receiveShadow', '"" + object.receive_shadow.to_string()', '""'),
  ('#version line kept in the shaders', 'code.replace(old="#version 300 es", new="")', 'code'),
  ('group uniform type (int / uint) not set', '@webgl.set_uniform_type(uniform, node_uniform.type_)', '()'),
  ('info.render.frame not bumped before each draw', 'renderer.info.render.frame += 1', '()'),
  ('updateNodes without renderId++', 'node_frame.render_id += 1', '()'),
  ('FogExp2 built with rangeFogFactor', '@nodes.fog.call([color, @nodes.density_fog_factor.call([density])])', '@nodes.fog.call([color, @nodes.range_fog_factor.call([density, density])])'),
  ('geometry not disposed after build', 'webgl_nodes_handler_queue_microtask(() => geometry.dispose())', 'ignore(geometry)'),
]
only = [int(a) for a in sys.argv[1:]]
for i, (name, old, new) in enumerate(BUGS):
    if only and i not in only:
        continue
    with patched(M, old, new):
        if DRY_RUN:
            print(f'[{i}] pattern found: {name}')
            continue
        r = subprocess.run(['node', 'run.mjs'], cwd=HERE, capture_output=True, text=True)
    lines = [l for l in r.stdout.splitlines() if l.startswith(('ok', 'MISMATCH', 'MISSING'))]
    caught = [l.split(' (')[0] for l in lines if not l.startswith('ok')]
    print(f'[{i}] {name}: ' + ('CAUGHT by ' + '; '.join(caught) if caught else 'NOT CAUGHT'), flush=True)
