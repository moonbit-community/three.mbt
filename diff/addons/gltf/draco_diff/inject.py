# python3 inject.py: applies each bug to draco_loader.mbt in turn, rebuilds the harness,
# runs run.mjs and restores the file. Prints caught/missed per bug.
import subprocess, sys, pathlib
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(next(p for p in HERE.parents if (p / 'lib/env.py').exists())))
from lib.env import REPO  # noqa: E402
from lib.inject import patched, DRY_RUN  # noqa: E402
# INJECT_DRY_RUN=1 only checks that every pattern applies; after a hard kill,
# `python3 diff/lib/inject.py --restore` restores the patched file.
SRC = 'src/addons/loaders/draco_loader.mbt'
BUGS = [
    ('sort comparator flipped (busiest worker chosen)', 'if a.task_load > b.task_load {', 'if a.task_load < b.task_load {'),
    ('useUniqueIDs always true', 'attribute_ids is Some(_),', 'true,'),
    ('color normalized inverted', 'draco_is_float32_array(array) == false', 'draco_is_float32_array(array) == true'),
    ('sRGB conversion skipped', 'if !input_color_space.strict_equal(JsValue::of(@core.SRGBColorSpace)) {', 'if true {'),
    ('never interleaved', 'let attribute = if item_size == stride {', 'let attribute = if true {'),
    ('cache ignores the task key', 'if cached_task.key == task_key {', 'if true {'),
    ('task never released', 'self.release_task(w, task_id)', 'ignore(w)'),
    ('worker body join without the empty line', '"/* draco decoder */", js_content, "", "/* worker */"', '"/* draco decoder */", js_content, "/* worker */"'),
    ('default worker limit 3', 'worker_limit: 4,', 'worker_limit: 3,'),
    ('task not cached', 'draco_task_cache.set(buffer, { key: task_key, promise: geometry_pending, })', 'ignore(task_key)'),
    ('parse uses linear color space', 'vertex_color_space=@core.SRGBColorSpace,', 'vertex_color_space=@core.LinearSRGBColorSpace,'),
    ('attribute_types argument ignored', 'Some(types) => draco_object(types)', 'Some(_) => draco_object(self.default_attribute_types)'),
    ('task id not incremented', 'self.worker_next_task_id += 1', 'self.worker_next_task_id += 0'),
    ('wasm binary not passed to the worker', 'self.decoder_config.set("wasmBinary", libraries[1])', 'ignore(libraries)'),
    ('release subtracts the wrong cost', 'worker.task_load -= worker.task_costs.get(task_id).unwrap_or(0)', 'worker.task_load -= worker.task_costs.get(task_id).unwrap_or(0) / 2'),
]
orig = (REPO / SRC).read_text()
only = [int(a) for a in sys.argv[1:]]
for i, (name, old, new) in enumerate(BUGS):
    if only and i not in only: continue
    assert orig.count(old) == 1, name
    with patched(SRC, old, new):
        if DRY_RUN:
            print(i, 'applies (dry run)', name); continue
        b = subprocess.run(['moon', 'build', '--target', 'js'], cwd=HERE, capture_output=True, text=True)
        if b.returncode != 0:
            print(i, name, 'BUILD FAILED', b.stdout[-500:], b.stderr[-500:]); continue
        r = subprocess.run(['node', 'run.mjs'], cwd=HERE, capture_output=True, text=True, timeout=300)
        if not r.stdout.strip():
            print(i, 'CAUGHT (runner crashed)', name, '|', r.stderr.strip().splitlines()[-1][:200] if r.stderr.strip() else ''); continue
        last = r.stdout.strip().splitlines()[-1]
        fails = [l for l in r.stdout.splitlines() if l.startswith('FAIL')]
        print(i, ('CAUGHT' if r.returncode else 'MISSED'), name, '|', last, '|', ' '.join(f.split()[1] for f in fails[:4]))
        sys.stdout.flush()
if not DRY_RUN:
    subprocess.run(['moon', 'build', '--target', 'js'], cwd=HERE, capture_output=True)
