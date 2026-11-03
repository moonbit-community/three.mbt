// G9: WebGPURenderer / WebGPUBackend on the recording mock GPU, the examples/pixel_compare
// WebGPU scenes (mock GPU and, with forceWebGL, mock WebGL 2), and the A4/A5 TSL add-on
// scenarios. The MoonBit sides are mbt/ (main, pixel, a4) and mbt_a5/.
export default [
	{ name: 'g9', area: 'core', order: 30, title: 'G9 WebGPU', build: [ 'mbt' ], cmd: [ 'node', 'harness/run.mjs', '--quiet' ], summary: /identical/, expect: '30/30 identical', timeout: 1800 },
	{ name: 'g9_pixel', area: 'core', order: 31, title: 'G9 pixel (mock GPU)', build: [ 'mbt' ], cmd: [ 'node', 'harness/run_pixel.mjs', '--quiet' ], summary: /identical/, expect: '44/44 identical', timeout: 1800 },
	{ name: 'g9_pixel_webgl', area: 'core', order: 32, title: 'G9 pixel (mock WebGL)', build: [ 'mbt' ], cmd: [ 'node', 'harness/run_pixel.mjs', '--quiet', '--webgl' ], summary: /identical/, expect: '44/44 identical', timeout: 1800 },
	{ name: 'g9_a4', area: 'core', order: 33, title: 'A4 mock GPU', build: [ 'mbt' ], cmd: [ 'node', 'harness/run_a4.mjs', '--quiet' ], summary: /identical/, expect: '32/32 identical', timeout: 1800 },
	{ name: 'g9_a5', area: 'core', order: 34, title: 'A5 mock GPU', build: [ 'mbt_a5' ], cmd: [ 'node', 'harness/run_a5.mjs', '--quiet' ], summary: /identical/, expect: '20/20 identical', timeout: 1800 },
];
