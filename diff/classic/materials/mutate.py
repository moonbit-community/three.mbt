#!/usr/bin/env python3
"""Bug injection for the materials harness: applies each mutation to the real file in
src/core, rebuilds, runs the comparison (first failure only), restores the file.

    python3 mutate.py [index ...]     # all mutations, or only the given ones
    INJECT_DRY_RUN=1 python3 mutate.py   # only check that every pattern still applies

Every mutation must make the harness report failures. Restore after a hard kill with
`python3 diff/lib/inject.py --restore`.
"""
import pathlib, sys
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]))  # diff/
from lib.inject import patched, run, DRY_RUN  # noqa: E402

MUTANTS = [
    ('shadow_material.mbt', 'material.transparent = true', ''),
    ('mesh_phong_material.mbt', 'from_hex(0x111111)', 'from_hex(0x111112)'),
    ('line_dashed_material.mbt', '  self.gap_size = source.gap_size', ''),
    ('mesh_physical_material.mbt', 'self.set_sheen(source._sheen.unwrap())', 'self._sheen = source._sheen'),
    ('material.mbt', '"map", "gradientMap", "lightMap"', '"gradientMap", "lightMap"'),
    ('shader_material.mbt', 'material.force_single_pass = true', ''),
    ('uniforms_utils.mbt', '  | Quaternion(_))', '  | Quaternion(_) | Plane(_))'),
    ('material.mbt', '  material_put_number(data, "metalness", self.metalness)', ''),
]

only = [int(a) for a in sys.argv[1:]]
caught = 0
for i, (f, old, new) in enumerate(MUTANTS):
    if only and i not in only:
        continue
    with patched('src/core/' + f, old, new):
        if DRY_RUN:
            print(f'[{i}] pattern ok: {f}')
            continue
        out = run(['bash', 'run.sh', '1'], cwd=HERE)
    if DRY_RUN:
        continue
    lines = out.strip().split('\n')
    first = next((l for l in lines if ' checks, ' in l), '(no summary)')
    if any(l.startswith('Error') for l in lines):
        first = 'BUILD ERROR (bundle stale): ' + first
    hit = ' checks, ' in first and ' 0 failures' not in first
    caught += hit
    print(f'[{i}] {"CAUGHT" if hit else "MISSED"} {f}: {old!r} -> {new!r}\n    {first[:200]}')
if not DRY_RUN:
    print(f'{caught} caught')
