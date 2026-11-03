// The recording mock context of the WebGLNodesHandler scenarios, shared by both sides
// (upstream.mjs and src/addons/tsl/a5_webgl_nodes_handler_test.mbt): diff/core/webgl's
// mock_gl.cjs, plus active attributes / uniforms parsed from the linked shader sources (so
// every program's real uniform uploads show up in the log), and the recording canvas of
// renderer_common.cjs.
const H = require( 'node:path' ).join( __dirname, '../../../../core/webgl/harness' );
const { createMockGL } = require( H + '/mock_gl.cjs' );
const { createMockCanvas } = require( H + '/scenarios/renderer_common.cjs' );

const TYPES = {
	float: 0x1406, vec2: 0x8B50, vec3: 0x8B51, vec4: 0x8B52, int: 0x1404, ivec2: 0x8B53, ivec3: 0x8B54, ivec4: 0x8B55,
	uint: 0x1405, uvec2: 0x8DC6, uvec3: 0x8DC7, uvec4: 0x8DC8, bool: 0x8B56, bvec2: 0x8B57, bvec3: 0x8B58, bvec4: 0x8B59,
	mat2: 0x8B5A, mat3: 0x8B5B, mat4: 0x8B5C, sampler2D: 0x8B5E, sampler3D: 0x8B5F, samplerCube: 0x8B60,
	sampler2DShadow: 0x8B62, sampler2DArray: 0x8DC1, sampler2DArrayShadow: 0x8DC4, samplerCubeShadow: 0x8DC5,
	isampler2D: 0x8DCA, isampler3D: 0x8DCB, isamplerCube: 0x8DCC, isampler2DArray: 0x8DCF,
	usampler2D: 0x8DD2, usampler3D: 0x8DD3, usamplerCube: 0x8DD4, usampler2DArray: 0x8DD7,
};
const PRECISION = '(?:(?:highp|mediump|lowp)\\s+)?';

function declarations( source, keyword ) {

	const out = [];
	const seen = new Set();
	const re = new RegExp( '^\\s*(?:layout\\s*\\([^)]*\\)\\s*)?(?:' + keyword + ')\\s+' + PRECISION + '(\\w+)\\s+(\\w+)\\s*(?:\\[\\s*(\\d+)\\s*\\])?\\s*;', 'gm' );
	let m;
	while ( ( m = re.exec( source ) ) !== null ) {

		const type = TYPES[ m[ 1 ] ];
		if ( type === undefined || seen.has( m[ 2 ] ) ) continue;
		seen.add( m[ 2 ] );
		const size = m[ 3 ] !== undefined ? Number( m[ 3 ] ) : 1;
		out.push( { name: m[ 3 ] !== undefined ? m[ 2 ] + '[0]' : m[ 2 ], type, size } );

	}

	return out;

}

function createGL( options ) {

	const gl = createMockGL( options );
	const sources = new Map();
	const attached = new Map();
	const shaderSource = gl.shaderSource;
	gl.shaderSource = function ( shader, source ) {

		sources.set( shader, source );
		return shaderSource.apply( this, arguments );

	};

	const attachShader = gl.attachShader;
	gl.attachShader = function ( program, shader ) {

		if ( ! attached.has( program ) ) attached.set( program, [] );
		attached.get( program ).push( shader );
		return attachShader.apply( this, arguments );

	};

	const linkProgram = gl.linkProgram;
	gl.linkProgram = function ( program ) {

		const shaders = attached.get( program ) || [];
		const vertex = shaders.filter( ( s ) => s.__type === gl.VERTEX_SHADER ).map( ( s ) => sources.get( s ) || '' ).join( '\n' );
		const all = shaders.map( ( s ) => sources.get( s ) || '' ).join( '\n' );
		const uniforms = declarations( all, 'uniform' );
		const attributes = declarations( vertex, 'in|attribute' );
		program.__spec = { attributes, uniforms };
		return linkProgram.apply( this, arguments );

	};

	return gl;

}

module.exports = { createGL, createMockCanvas };
