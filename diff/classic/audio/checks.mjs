export default [ {
	name: 'audio',
	area: 'classic',
	order: 40,
	title: 'audio (mock Web Audio)',
	cmd: [ 'node', 'harness/run_diff.mjs' ],
	summary: /scenarios match/,
	expect: '11/11 scenarios match (864 entries)',
}, {
	name: 'audio_bindings',
	area: 'classic',
	order: 41,
	title: 'audio Web Audio bindings',
	cmd: [ 'node', 'tools/check_bindings.mjs' ],
	summary: /upstream members bound/,
	expect: '63/63 upstream members bound, 68 extern "js" functions',
} ];
