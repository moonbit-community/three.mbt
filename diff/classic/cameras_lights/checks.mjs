export default [ {
	name: 'cameras_lights',
	area: 'classic',
	order: 20,
	title: 'cameras/lights/scenes',
	build: [ '.' ],
	cmd: [ 'node', 'run.mjs' ],
	summary: /IDENTICAL|differ/,
	expect: '49527 lines, IDENTICAL',
} ];
