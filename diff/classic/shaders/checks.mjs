export default [ {
	name: 'shaders',
	area: 'classic',
	order: 60,
	title: 'ShaderChunk/ShaderLib/UniformsLib',
	build: [ '.' ],
	cmd: [ 'node', 'compare.mjs' ],
	summary: /^shaders:/,
	expect: 'shaders: 251 strings (217162 code units), 619 uniform values, 1805 numbers, 0 differences',
}, {
	name: 'shaders_fuzz',
	area: 'classic',
	order: 61,
	title: 'gen_shaders string literals (fuzz)',
	cwd: 'fuzz',
	cmd: [ 'node', 'run.mjs' ],
	summary: /cases, \d+ differ/,
	expect: '398 cases, 0 differ',
} ];
