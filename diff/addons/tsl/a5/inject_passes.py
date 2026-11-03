#!/usr/bin/env python3
"""A5 bug injection in the post-processing passes (bloom, SMAA, SSAO, FSR1, outline): each
bug is applied to the real src/addons/tsl file, the shader group `passes`
(diff/core/webgpu/shader_diff/run_a5.mjs --group passes) runs, and the file is restored.
    python3 inject_passes.py [key ...]      # keys 1..5, default all
    INJECT_DRY_RUN=1 python3 inject_passes.py
"""
import subprocess, sys, pathlib
sys.path.insert(0, str(next(p for p in pathlib.Path(__file__).resolve().parents if (p / 'lib/env.py').exists())))
from lib.env import DIFF, REPO  # noqa: E402
from lib.inject import patched, DRY_RUN  # noqa: E402

M = 'src/addons/tsl/'
H = DIFF / 'core/webgpu/shader_diff'
bugs={
 '1':('display_bloom_node.mbt','[6, 10, 14, 18, 22]','[6, 10, 13, 18, 22]'),
 '2':('display_smaa_node.mbt','smaa_search_length.call([search_tex, e, 0.5, 0.5])','smaa_search_length.call([search_tex, e, 0, 0.5])'),
 '3':('display_ssao_node.mbt','ssao_node_math_round(self.resolution_scale * width)','(self.resolution_scale * width).floor()'),
 '4':('display_fsr1_node.mbt','1.0 / 4.0 - 0.04 - 0.5','1.0 / 4.0 - 0.05 - 0.5'),
 '5':('display_outline_node.mbt','.less_than_equal(view_z_node)','.less_than(view_z_node)'),
}
for k in (sys.argv[1:] or sorted(bugs)):
    f, a, b = bugs[k]
    with patched(M + f, a, b):
        if DRY_RUN:
            print(f'[{k}] pattern found: {f}')
            continue
        r = subprocess.run(['node', 'run_a5.mjs', '--group', 'passes'], cwd=H, capture_output=True, text=True)
    last = r.stdout.strip().split('\n')[-1] if r.stdout.strip() else ''
    print(f'[{k}] {"CAUGHT" if r.returncode != 0 else "MISSED"} {f}: {a!r} -> {b!r} ({last})', flush=True)
