export default [ {
	name: 'helpers',
	area: 'classic',
	order: 30,
	title: 'helpers',
	build: [ '.' ],
	cmd: [ 'node', 'run_diff.mjs' ],
	summary: /^entries:/,
	expect: 'entries: mbt 15685, upstream 15685, typed arrays 346, mismatches 0',
} ];
