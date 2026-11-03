// BufferGeometry-free utils (SortUtils, ColorUtils, GeometryUtils, SceneUtils) and the
// environments (RoomEnvironment, DebugEnvironment): records of
// src/addons/{utils,environments}/a6_*_diff_test.mbt (A6_DIFF=1) against upstream_*.mjs,
// and WebGPUTextureUtils / PMREM'd environments on the recording mock GPU.
export default [
	{
		name: 'a6_utils_env',
		area: 'addons',
		order: 61,
		title: 'A6 utils/environments (CPU)',
		cmd: [ 'node', '--import', './register.mjs', 'run.mjs' ],
		summary: /identical, \d+ different or missing/,
		expect: '17 identical, 0 different or missing',
		timeout: 900,
	},
	{
		name: 'a6_utils_env_gpu',
		area: 'addons',
		order: 62,
		title: 'A6 utils/environments mock GPU',
		build: [ 'mbt' ],
		cwd: 'gpu',
		cmd: [ 'node', 'run.mjs' ],
		summary: /identical, \d+ different/,
		expect: '3 identical, 0 different',
		timeout: 600,
	},
];
