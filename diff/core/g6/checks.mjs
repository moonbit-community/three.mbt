// G6: Renderer, Backend, Background, Lighting, pipelines on a stub backend (call logs).
export default [
	{ name: 'g6', area: 'core', order: 20, title: 'G6 renderer', cwd: 'harness', cmd: [ 'node', 'run.mjs' ], summary: /passed, \d+ failed/, expect: '11 passed, 0 failed', timeout: 1800 },
];
