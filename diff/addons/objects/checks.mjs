// The objects add-ons' (SkyMesh, WaterMesh, Water2Mesh, LensflareMesh) WebGPU call logs on
// the recording mock GPU. Their WebGL variants are classic mock-GL scenarios of
// diff/core/webgl (a6_*), and their shader records are in the shared shader harness.
export default [
	{
		name: 'a6_objects_gpu',
		area: 'addons',
		order: 60,
		title: 'A6 objects mock GPU',
		build: [ 'mbt' ],
		cwd: 'gpu',
		cmd: [ 'node', 'run.mjs' ],
		summary: /identical, \d+ different/,
		expect: '4 identical, 0 different',
		timeout: 600,
	},
];
