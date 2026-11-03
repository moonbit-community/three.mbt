// ObjectLoader / BufferGeometryLoader / MaterialLoader round trips of upstream-built
// fixture scenes (byte-identical toJSON text, uuids included), plus mock fetch/Image
// scenarios for the file, image, texture, cube, bitmap, audio and loading-manager paths.
export default [
	{
		name: 'loaders',
		area: 'classic',
		order: 20,
		title: 'loaders',
		build: [ 'mbt' ],
		cmd: [ 'node', 'run.mjs', '--no-build' ],
		summary: / passed, \d+ failed/,
		expect: '196 passed, 0 failed, 0 known core gaps',
		timeout: 600,
	},
];
