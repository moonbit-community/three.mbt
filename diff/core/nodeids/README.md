# Module-load node ids: bug injection

`src/nodes/core_module_node_ids.mbt` is the table of the ids upstream's module-level nodes
get when `Three.WebGPU.js` loads; `node tools/gen_module_node_ids.mjs` generates it from
upstream and `--check` verifies it (CI runs that). This directory only holds the
bug-injection tool that showed the checks catch a wrong table or counter:

    python3 diff/core/nodeids/inject.py [shift|swap|counter ...]

- `shift`: one id moved (backgroundRotation 499 -> 496)
- `swap`: two ids swapped (backgroundBlurriness / backgroundRotation)
- `counter`: the runtime node counter starts at 0 instead of `NODE_FIRST_RUNTIME_ID`

Each bug is applied to the real file through `diff/lib/inject.py` (restored afterwards,
also on Ctrl-C; `python3 diff/lib/inject.py --restore` after a hard kill), then the
generator's `--check`, `src/nodes/core_module_node_ids_test.mbt` and the G10 mock-GL
scenario `background_cube` (diff/core/g10) run; each bug must be caught by at least one.
`INJECT_DRY_RUN=1` only checks that the patterns still apply.

The one-off measurement scripts that built the table during the port (upstream/port
allocation-site tracing, the name matcher and the source rewriter) were not kept:
tools/gen_module_node_ids.mjs supersedes them.
