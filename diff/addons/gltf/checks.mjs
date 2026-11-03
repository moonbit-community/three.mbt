// glTF and the loaders/utils it uses (src/addons/loaders, src/addons/utils, src/addons/libs).
// Each harness loads or computes the same inputs with upstream (examples/jsm, under
// register.mjs) and with the port, both in the env.mjs browser stand-in, and compares.
const imp = [ 'node', '--import', '../register.mjs' ];
export default [
	{
		// GLTFLoader: 50 example models + 13 generated fixtures + plugin / no-decoder runs.
		name: 'gltf', area: 'addons', order: 20, title: 'glTF',
		build: [ 'gltf_diff' ], cwd: 'gltf_diff', cmd: [ ...imp, 'run.mjs', '--no-build' ],
		summary: /passed/, expect: '67 passed, 0 failed', timeout: 1800,
	},
	{
		// BufferGeometryUtils / SkeletonUtils outputs on generated inputs.
		name: 'gltf_utils', area: 'addons', order: 21, title: 'BufferGeometry/SkeletonUtils',
		build: [ 'utils_diff' ], cwd: 'utils_diff', cmd: [ ...imp, 'run.mjs' ],
		summary: /cases/, expect: 'cases: 1384, pass: 1384, fail: 0 (both threw: 0)', timeout: 1200,
	},
	{
		// DRACOLoader: every Draco primitive of 15 GLBs, real wasm decoder in an in-process worker.
		name: 'gltf_draco', area: 'addons', order: 22, title: 'Draco',
		build: [ 'draco_diff' ], cwd: 'draco_diff', cmd: [ 'node', 'run.mjs' ],
		summary: /mismatches/, expect: '4190 log entries compared (671 geometry summaries), 0 mismatches', timeout: 1800,
	},
	{
		// KTX2Loader + ktx-parse + zstddec + WorkerPool + ColorSpaces, real Basis transcoder.
		name: 'gltf_ktx2', area: 'addons', order: 23, title: 'KTX2',
		build: [ 'ktx2_diff' ], cwd: 'ktx2_diff', cmd: [ ...imp, 'run.mjs' ],
		summary: /checks/, expect: '59/59 checks identical', timeout: 1800,
	},
];
