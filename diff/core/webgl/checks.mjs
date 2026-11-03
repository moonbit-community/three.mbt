// Classic WebGLRenderer on the recording mock WebGL 2 context (see README.md).
export default [
	{
		name: 'webgl',
		area: 'core',
		order: 10,
		title: 'classic WebGL',
		cmd: [ 'node', 'harness/run_diff.mjs' ],
		// verify_all.out counted the `ok` lines ("52 ok"); run_diff.mjs now prints this total.
		summary: /^\d+ ok, \d+ failed$/,
		expect: '52 ok, 0 failed',
		timeout: 1800,
	},
];
