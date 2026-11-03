// node --import ../a4/register_three.mjs child.mjs <group>: the upstream side of one A5
// group (a5/<group>.mjs), printed as `@@A5 <json>` ({ name: record }). Mirrors
// src/addons/tsl/a5_harness_test.mbt (`a5_run`): make the renderers, align the counters,
// import the group's add-on modules in order (the MoonBit side calls their `load_*()`), then
// build each scenario with the real WGSLNodeBuilder (and GLSLNodeBuilder with `glsl: true`).
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
const { default: Node } = await import( SRC + '/nodes/core/Node.js' );
const N = await import( SRC + '/nodes/Nodes.js' );
if ( typeof globalThis.ImageBitmap === 'undefined' ) globalThis.ImageBitmap = class ImageBitmap {};
const G = await import( new URL( './' + group + '.mjs', import.meta.url ).href );

const require = createRequire( import.meta.url );
const { createMockGL } = require( DIFF + '/core/webgl/harness/mock_gl.cjs' );
const canvas = () => ( { style: {}, width: 300, height: 150, addEventListener() {}, removeEventListener() {}, getContext() { return null; } } );
const DEFAULT_EXTENSIONS = [ 'EXT_color_buffer_float', 'EXT_color_buffer_half_float', 'OES_texture_float_linear', 'EXT_texture_filter_anisotropic', 'WEBGL_multi_draw', 'KHR_parallel_shader_compile', 'WEBGL_lose_context', 'EXT_clip_control', 'WEBGL_compressed_texture_s3tc', 'WEBGL_compressed_texture_astc', 'WEBGL_compressed_texture_etc' ];

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

// counters (a5_align_counters)
const advance = ( name, target, f ) => {

	let id = f();
	if ( id >= target ) throw new Error( `counter ${name} already at ${id}` );
	while ( id < target - 1 ) id = f();

};

advance( 'fn', 2000, () => Number( T.Fn( () => {}, { return: 'float' } ).shaderNode.layout.name.slice( 2 ) ) );
advance( 'node', 200000, () => new Node().id );
advance( 'object3d', 5000, () => new THREE.Object3D().id );
advance( 'material', 5000, () => new THREE.Material().id );
advance( 'texture', 5000, () => new THREE.Texture().id );
advance( 'attribute', 5000, () => new THREE.BufferAttribute( new Float32Array( 1 ), 1 ).id );
advance( 'geometry', 5000, () => new THREE.BufferGeometry().id );

// the group's add-on modules, in order
const M = {};
const A = {};
for ( const path of G.modules || [] ) {

	M[ path ] = await import( pathToFileURL( REPO + '/examples/jsm/' + path ).href );
	for ( const [ k, v ] of Object.entries( M[ path ] ) ) if ( k !== 'default' ) A[ k ] = v;
	if ( M[ path ].default ) A[ M[ path ].default.name ] = M[ path ].default;

}

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
const flow = ( name, make, opts = {} ) => scenarios.push( { kind: 'flow', name: 'a5_' + name, make, stage: 'fragment', mesh: true, glsl: false, internals: () => [], ...opts } );
const whole = ( name, material, opts = {} ) => scenarios.push( { kind: 'whole', name: 'a5_' + name, material, glsl: false, ...opts } );
// `run( renderer, isGLSL )` returns the record's text
const custom = ( name, run, opts = {} ) => scenarios.push( { kind: 'custom', name: 'a5_' + name, run, glsl: false, ...opts } );

// opts: lightsNode (default: an empty LightsNode), object (default: a mesh), camera
function buildMaterial( material, renderer, isGLSL, opts = {} ) {

	const mesh = opts.object ?? new THREE.Mesh( geometry(), material );
	const Builder = isGLSL ? GLSLNodeBuilder : WGSLNodeBuilder;
	const b = new Builder( mesh, renderer );
	b.scene = new THREE.Scene();
	b.camera = opts.camera ?? new THREE.PerspectiveCamera();
	b.lightsNode = opts.lightsNode ?? new N.LightsNode().setLights( [] );
	b.build();
	return b.vertexShader + '\n@@@@\n' + b.fragmentShader + '\n@@@@\n' + bindingsOf( b );

}

function runOne( s, renderer, isGLSL ) {

	if ( s.kind === 'whole' ) return { shader: buildMaterial( s.material(), renderer, isGLSL ) };
	if ( s.kind === 'custom' ) return { text: s.run( renderer, isGLSL ) };
	const object = s.mesh ? new THREE.Mesh( geometry(), new THREE.MeshBasicMaterial() ) : null;
	const Builder = isGLSL ? GLSLNodeBuilder : WGSLNodeBuilder;
	const b = new Builder( object, renderer );
	b.camera = new THREE.PerspectiveCamera();
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
	return { code: f.code, result: typeof f.result === 'string' ? f.result : '', vars: f.vars ?? '', uniforms, codes, decl, bindings, internals };

}

G.scenarios( { T, THREE, N, A, M, flow, whole, custom, tex, depthTex, geometry, buildMaterial, bindingsOf, WGSLNodeBuilder, GLSLNodeBuilder } );

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

// the records go through a file: a large write to a pipe can be cut short
fs.writeFileSync( process.env.A5_OUT, JSON.stringify( records ) );
process.exit( 0 );
