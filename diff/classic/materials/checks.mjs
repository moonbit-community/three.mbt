// Material port vs upstream: constructors, setters, copy/clone, toJSON/fromJSON and
// uniforms of all 18 material classes (diff.mjs drives both sides).
export default [
	{
		name: 'materials',
		area: 'classic',
		order: 10,
		title: 'materials',
		build: [ 'mbt' ],
		cmd: [ 'bash', 'run.sh' ],
		summary: / checks, \d+ failures/,
		expect: '8077 checks, 0 failures (fromJSON: 1 upstream null held as NaN by the port)',
		timeout: 600,
	},
];
