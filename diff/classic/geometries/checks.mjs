// src/geometries vs upstream: a parameter grid over every geometry class (77k cases:
// attributes, index, groups, bounds, parameters, toJSON/fromJSON), compared exactly;
// cases where both sides throw are counted separately.
export default [
	{
		name: 'geometries',
		area: 'classic',
		order: 40,
		title: 'geometries',
		build: [ '.' ],
		cmd: [ 'node', 'run.mjs' ],
		env: { SKIP_BUILD: '1' },
		summary: /^cases=/,
		expect: 'cases=77461 pass=76397 bothThrow=1064 fail=0',
		timeout: 1200,
	},
];
