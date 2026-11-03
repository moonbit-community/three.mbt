export default [ {
	name: 'json_uuid',
	area: 'classic',
	order: 70,
	title: 'JSON numbers, uuid/id order',
	build: [ '.' ],
	cmd: [ 'node', 'run.mjs', '--no-build' ],
	summary: /passed, \d+ failed/,
	expect: '126 passed, 0 failed (93 fresh, 17 nonfinite scenes)',
} ];
