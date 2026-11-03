// G7: renderer data classes (bindings, buffers, render objects, cache keys) on the mock GPU.
export default [
	{ name: 'g7', area: 'core', order: 21, title: 'G7 renderer data', cwd: 'harness', cmd: [ 'node', 'run.mjs' ], summary: /passed, \d+ failed/, expect: '18 passed, 0 failed', timeout: 1800 },
];
