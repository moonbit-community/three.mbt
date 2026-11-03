// Shader text byte-diff of every group (base / WGSL / GLSL builders, TSL add-ons); see README.
export default [
	{
		name: 'shader',
		area: 'core',
		order: 20,
		title: 'shader harness',
		cmd: [ 'node', 'shader_diff/run.mjs' ],
		summary: /\d+ identical, \d+ different or missing/,
		expect: '1849 identical, 0 different or missing',
		timeout: 3600,
	},
];
