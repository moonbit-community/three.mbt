// node --import ./register_three.mjs child.mjs <group>: the upstream side of one A4 group
// (a4/<group>.mjs), printed as `@@A4 <json>` ({ name: record }). Mirrors
// src/addons/tsl/a4_shader_diff_test.mbt: the add-on modules the group lists are imported
// first (as the MoonBit file calls their `load_*()`), then the renderers are made and each
// scenario is built by the real WGSLNodeBuilder (and GLSLNodeBuilder with `glsl: true`).
import { createRequire } from 'node:module';
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
import { DIFF, UPSTREAM as REPO } from '../../../../lib/env.mjs';
const SRC = pathToFileURL( REPO + '/src' ).href;
const group = process.argv[ 2 ];
const T = await import( SRC + '/Three.TSL.js' );
const THREE = await import( SRC + '/Three.WebGPU.js' );
const { default: WGSLNodeBuilder } = await import( SRC + '/renderers/webgpu/nodes/WGSLNodeBuilder.js' );
const { default: GLSLNodeBuilder } = await import( SRC + '/renderers/webgl-fallback/nodes/GLSLNodeBuilder.js' );
const { default: WebGLExtensions } = await import( SRC + '/renderers/webgl-fallback/utils/WebGLExtensions.js' );
const N = await import( SRC + '/nodes/Nodes.js' );
if ( typeof globalThis.ImageBitmap === 'undefined' ) globalThis.ImageBitmap = class ImageBitmap {};
const G = await import( new URL( './' + group + '.mjs', import.meta.url ).href );
const M = {};
const A = {};
for ( const path of G.modules || [] ) {

	M[ path ] = await import( pathToFileURL( REPO + '/examples/jsm/' + path ).href );
	for ( const [ k, v ] of Object.entries( M[ path ] ) ) if ( k !== 'default' ) A[ k ] = v;
	if ( M[ path ].default ) A[ M[ path ].default.name ] = M[ path ].default;

}

const require = createRequire( import.meta.url );
const { createMockGL } = require( DIFF + '/core/webgl/harness/mock_gl.cjs' );
const canvas = () => ( { style: {}, width: 300, height: 150, addEventListener() {}, removeEventListener() {}, getContext() { return null; } } );
const DEFAULT_EXTENSIONS = [ 'EXT_color_buffer_float', 'EXT_color_buffer_half_float', 'OES_texture_float_linear', 'EXT_texture_filter_anisotropic', 'WEBGL_multi_draw', 'KHR_parallel_shader_compile', 'WEBGL_lose_context', 'EXT_clip_control', 'WEBGL_compressed_texture_s3tc', 'WEBGL_compressed_texture_astc', 'WEBGL_compressed_texture_etc' ];

const bindingsOf = ( builder ) => builder.getBindings().map( ( g ) => g.name + '[' + g.bindings.map( ( b ) => b.name + ':' + b.visibility ).join( ',' ) + ']' ).join( ' ' );
const attribute = ( n, itemSize ) => new THREE.BufferAttribute( new Float32Array( n * itemSize ), itemSize );
const geometry = () => {

	const g = new THREE.BufferGeometry();
	g.setAttribute( 'position', attribute( 24, 3 ) );
	g.setAttribute( 'normal', attribute( 24, 3 ) );
	g.setAttribute( 'uv', attribute( 24, 2 ) );
	return g;

};

const tex = ( name ) => {

	const t = new THREE.Texture();
	t.name = name;
	return t;

};

const depthTex = ( name ) => {

	const t = new THREE.DepthTexture( 4, 4 );
	t.name = name;
	return t;

};

const scenarios = [];
const flow = ( name, make, opts = {} ) => scenarios.push( { name: 'a4_' + name, make, stage: 'fragment', mesh: true, glsl: false, internals: () => [], ...opts } );
G.scenarios( { T, THREE, N, A, M, flow, tex, depthTex, geometry } );

// the renderers, made after the scenarios are listed (listing creates no nodes), as
// `a4_run` makes them
const makeWGSL = () => {

	const r = new THREE.WebGPURenderer( { canvas: canvas() } );
	r._bindings = undefined;
	r._initialized = true;
	r.backend.device = { features: new Set() };
	r.backend.compatibilityMode = false;
	r.backend.renderer = r;
	return r;

};

const makeGLSL = () => {

	const r = new THREE.WebGPURenderer( { canvas: canvas(), forceWebGL: true } );
	r._bindings = undefined;
	r._initialized = true;
	r.backend.renderer = r;
	r.backend.gl = createMockGL( { extensions: DEFAULT_EXTENSIONS } );
	r.backend.extensions = new WebGLExtensions( r.backend );
	return r;

};

const wgsl = makeWGSL();
const glsl = makeGLSL();

function buildMaterial( material, renderer, isGLSL ) {

	const mesh = new THREE.Mesh( geometry(), material );
	const Builder = isGLSL ? GLSLNodeBuilder : WGSLNodeBuilder;
	const b = new Builder( mesh, renderer );
	b.scene = new THREE.Scene();
	b.camera = new THREE.PerspectiveCamera();
	b.lightsNode = new N.LightsNode().setLights( [] );
	b.build();
	return b.vertexShader + '\n@@@@\n' + b.fragmentShader + '\n@@@@\n' + bindingsOf( b );

}

function runOne( s, renderer, isGLSL ) {

	const object = s.mesh ? new THREE.Mesh( geometry(), new THREE.MeshBasicMaterial() ) : null;
	const Builder = isGLSL ? GLSLNodeBuilder : WGSLNodeBuilder;
	const b = new Builder( object, renderer );
	b.camera = new THREE.PerspectiveCamera();
	renderer.logarithmicDepthBuffer = s.logDepth === true;
	const stage = s.stage;
	b.setShaderStage( stage );
	const node = s.make();
	const f = b.flowStagesNode( node );
	if ( b.vars.vertex === undefined ) b.vars.vertex = [];
	const decl = [
		b.getUniforms( stage ),
		b.getAttributes( stage ),
		b.getVaryings( 'vertex' ),
		b.getVaryings( 'fragment' ),
		b.getStructs( stage ),
		b.getVars( stage, true ),
		b.getVars( 'vertex', true )
	].join( '\n@@\n' );
	const uniforms = [];
	for ( const st of [ 'vertex', 'fragment', 'compute' ] ) {

		for ( const u of b.uniforms[ st ] ) uniforms.push( `${st}:${u.name}:${u.type}` );

	}

	const codes = b.getCodes( stage );
	const bindings = bindingsOf( b );
	const internals = s.internals( node ).map( ( [ label, material ] ) => label + '\n' + buildMaterial( material, renderer, isGLSL ) );
	renderer.logarithmicDepthBuffer = false;
	return { code: f.code, result: typeof f.result === 'string' ? f.result : '', vars: f.vars ?? '', uniforms, codes, decl, bindings, internals };

}

const records = {};
for ( const s of scenarios ) {

	try {

		records[ s.name ] = runOne( s, wgsl, false );

	} catch ( e ) {

		records[ s.name ] = { error: String( e && e.stack ) };

	}

	if ( s.glsl ) {

		try {

			records[ s.name + '_glsl' ] = runOne( s, glsl, true );

		} catch ( e ) {

			records[ s.name + '_glsl' ] = { error: String( e && e.stack ) };

		}

	}

}

// a pipe may take a large record set in pieces (and refuse with EAGAIN while full)
const out = Buffer.from( '@@A4 ' + JSON.stringify( records ) + '\n' );
for ( let off = 0; off < out.length; ) {

	try {

		off += fs.writeSync( 1, out, off );

	} catch ( e ) {

		if ( e.code !== 'EAGAIN' ) throw e;

	}

}

process.exit( 0 );
