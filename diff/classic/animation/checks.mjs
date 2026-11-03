// src/animation vs upstream: JSON scenario specs (mixer, actions, fades/warps, loops,
// bindings, object groups, AnimationUtils) run by both interpreters, logs compared entry
// by entry with Object.is; plus 300 seeded random scenarios.
export default [
	{
		name: 'animation',
		area: 'classic',
		order: 30,
		title: 'animation',
		build: [ '.' ],
		cmd: [ 'node', 'run.mjs' ],
		env: { SKIP_BUILD: '1' },
		summary: /scenarios match/,
		expect: '16/16 scenarios match, 141486 log entries compared',
		timeout: 600,
	},
	{
		name: 'animation_random',
		area: 'classic',
		order: 31,
		title: 'animation (300 random seeds)',
		build: [ '.' ],
		cmd: [ 'node', 'run.mjs', '--random', '300' ],
		env: { SKIP_BUILD: '1' },
		summary: /scenarios match/,
		expect: '516/516 scenarios match, 356452 log entries compared',
		timeout: 600,
	},
];
