// A5's checks outside the shared shader harness (a5_* groups, core/webgpu) and the G9
// mock-GPU runner (run_a5.mjs, core/g9): WebGLNodesHandler on the classic mock GL,
// SimplexNoise bit for bit, CameraUtils.frameCorners value for value.
export default [
	{
		name: 'a5_webgl_nodes',
		area: 'addons',
		order: 50,
		title: 'A5 WebGLNodesHandler (mock GL)',
		cwd: 'webgl_nodes',
		cmd: [ 'node', 'run.mjs' ],
		summary: /identical, \d+ different or missing/,
		expect: '10 identical, 0 different or missing',
		timeout: 900,
	},
	{
		name: 'a5_simplex',
		area: 'addons',
		order: 51,
		title: 'A5 SimplexNoise',
		cmd: [ 'bash', 'simplex/compare.sh' ],
		summary: /^simplex:/,
		expect: 'simplex: 12394 lines identical',
		timeout: 900,
	},
	{
		name: 'a5_camera_utils',
		area: 'addons',
		order: 52,
		title: 'A5 CameraUtils',
		cmd: [ 'bash', 'camera_utils/compare.sh' ],
		summary: /^camera_utils:/,
		expect: 'camera_utils: 84 cases identical',
		timeout: 900,
	},
];
