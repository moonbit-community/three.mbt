// G10: the WebGL fallback (WebGLBackend, GLSLNodeBuilder) on the recording mock WebGL 2
// context (the embedded mock copy is checked by `node tools/gen_g10_mock.mjs --check` in CI).
export default [
	{ name: 'g10', area: 'core', order: 40, title: 'G10 WebGL fallback', cwd: 'harness', cmd: [ 'node', 'run.mjs' ], summary: /scenarios identical/, expect: '28/28 scenarios identical', timeout: 1800 },
];
