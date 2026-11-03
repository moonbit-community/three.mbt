"""Bug injection for the module-load node ids (src/nodes/core_module_node_ids.mbt, the
table tools/gen_module_node_ids.mjs generates, and the runtime counter in core_node.mbt).

Each bug is applied to the real file, then three checks run: the generator's --check, the
table's unit tests, and the G10 mock-GL scenario background_cube (whose uniforms carry
node ids). Every bug must be caught by at least one; the file is restored after each.

    python3 diff/core/nodeids/inject.py            # all bugs
    python3 diff/core/nodeids/inject.py shift swap # some
    INJECT_DRY_RUN=1 python3 diff/core/nodeids/inject.py   # only check the patterns apply
"""
import re
import sys
import pathlib

sys.path.insert(0, str(next(p for p in pathlib.Path(__file__).resolve().parents if (p / 'lib/env.py').exists())))
from lib.env import REPO, DIFF  # noqa: E402
from lib.inject import patched, run, DRY_RUN  # noqa: E402

TABLE = 'src/nodes/core_module_node_ids.mbt'
NODE = 'src/nodes/core_node.mbt'
BUGS = {
    'shift': [(TABLE, '"nodes/accessors/SceneProperties.js:backgroundRotation" => Some((499, 1))',
               '"nodes/accessors/SceneProperties.js:backgroundRotation" => Some((496, 1))')],
    'swap': [(TABLE, 'backgroundBlurriness" => Some((497, 1))\n    "nodes/accessors/SceneProperties.js:backgroundIntensity" => Some((498, 1))\n    "nodes/accessors/SceneProperties.js:backgroundRotation" => Some((499, 1))',
              'backgroundBlurriness" => Some((499, 1))\n    "nodes/accessors/SceneProperties.js:backgroundIntensity" => Some((498, 1))\n    "nodes/accessors/SceneProperties.js:backgroundRotation" => Some((497, 1))')],
    'counter': [(NODE, 'let _node_id : Ref[Int32] = Ref(NODE_FIRST_RUNTIME_ID)', 'let _node_id : Ref[Int32] = Ref(0)')],
}


def checks():
    tool = run(['node', 'tools/gen_module_node_ids.mjs', '--check'], cwd=REPO).strip().split('\n')[-1:]
    unit = [l for l in run(['moon', 'test', '--target', 'js', 'src/nodes/core_module_node_ids_test.mbt'], cwd=REPO).split('\n')
            if re.match(r'^Total|.*failed:', l)][:3]
    g10 = [l for l in run(['node', 'run.mjs', 'background_cube'], cwd=DIFF / 'core/g10/harness').split('\n')
           if re.search(r'MISMATCH|ok |MOON ERROR|identical', l)][:3]
    return tool, unit, g10


def apply(edits):
    # One patch per file (nested patches of one file would share a backup).
    if not edits:
        return checks() if not DRY_RUN else None
    f, old, new = edits[0]
    with patched(f, old, new):
        return apply(edits[1:])


names = sys.argv[1:] or list(BUGS)
for name in names:
    result = apply(BUGS[name])
    if DRY_RUN:
        print(f'{name}: pattern ok')
        continue
    tool, unit, g10 = result
    caught = ('stale' in ' '.join(tool) or 'up to date' not in ' '.join(tool)) or any('failed: 0' not in l for l in unit if 'failed:' in l) or any('MISMATCH' in l or 'ERROR' in l for l in g10)
    print(f'== {name}: {"CAUGHT" if caught else "MISSED"}')
    print('  tool:', *tool)
    print('  unit:', *unit)
    print('  g10: ', *g10)
