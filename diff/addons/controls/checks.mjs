// Controls (src/addons/controls): the same pointer/touch/wheel/key event scripts replayed
// into upstream's controls and the port; camera, internal state, events and listeners
// compared after each event.
export default [
	{
		name: 'controls',
		area: 'addons',
		order: 10,
		title: 'controls',
		build: [ '.' ],
		cmd: [ 'node', 'run.mjs' ],
		summary: /scenarios identical/,
		expect: '27/27 scenarios identical, 111739 entries',
		timeout: 1200,
	},
];
