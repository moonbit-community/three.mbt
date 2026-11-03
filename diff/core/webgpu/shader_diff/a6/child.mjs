// node --import ./register_three.mjs child.mjs: the upstream side of the a6 shader
// scenarios (the WebGPU objects add-ons: SkyMesh, WaterMesh, Water2Mesh, LensflareMesh),
// printed as `@@A6 <json>` ({ name: record }). Mirrors
// src/addons/objects/a6_shader_diff_test.mbt step for step: the add-on modules are
// imported first (the MoonBit side calls `load_lensflare_mesh()` at the same point), then
// both renderers are made, then each object is built by the real WGSLNodeBuilder and
// GLSLNodeBuilder (`<name>_glsl`), each from a fresh object.
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import { DIFF, UPSTREAM as REPO } from '../../../../lib/env.mjs';
const SRC = pathToFileURL( REPO + '/src' ).href;
await import( SRC + '/Three.TSL.js' );
const THREE = await import( SRC + '/Three.WebGPU.js' );
const { default: WGSLNodeBuilder } = await import( SRC + '/renderers/webgpu/nodes/WGSLNodeBuilder.js' );
const { default: GLSLNodeBuilder } = await import( SRC + '/renderers/webgl-fallback/nodes/GLSLNodeBuilder.js' );
const { default: WebGLExtensions } = await import( SRC + '/renderers/webgl-fallback/utils/WebGLExtensions.js' );
const N = await import( SRC + '/nodes/Nodes.js' );
if ( typeof globalThis.ImageBitmap === 'undefined' ) globalThis.ImageBitmap = class ImageBitmap {};
const { SkyMesh } = await import( 'three/addons/objects/SkyMesh.js' );
const { WaterMesh } = await import( 'three/addons/objects/WaterMesh.js' );
const { WaterMesh: Water2Mesh } = await import( 'three/addons/objects/Water2Mesh.js' );
const { LensflareMesh } = await import( 'three/addons/objects/LensflareMesh.js' );

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

const wgslRenderer = () => {

	const r = new THREE.WebGPURenderer( { canvas: canvas() } );
	r._bindings = undefined;
	r._initialized = true;
	r.backend.device = { features: new Set() };
	r.backend.compatibilityMode = false;
	r.backend.renderer = r;
	return r;

};

const glslRenderer = () => {

	const r = new THREE.WebGPURenderer( { canvas: canvas(), forceWebGL: true } );
	r._bindings = undefined;
	r._initialized = true;
	r.backend.renderer = r;
	r.backend.gl = createMockGL( { extensions: DEFAULT_EXTENSIONS } );
	r.backend.extensions = new WebGLExtensions( r.backend );
	return r;

};

const scenarios = [];
const add = ( name, make ) => scenarios.push( { name: 'a6_' + name, make } );
add( 'sky_mesh', () => new SkyMesh() );
add( 'sky_mesh_scaled', () => {

	const sky = new SkyMesh();
	sky.scale.setScalar( 450000 );
	sky.turbidity.value = 10;
	sky.sunPosition.value.set( 0.3, 0.1, - 1 );
	sky.showSunDisc.value = 0;
	return sky;

} );
add( 'water_mesh', () => new WaterMesh( geometry(), { waterNormals: tex( 'waterNormals' ), sunDirection: new THREE.Vector3( 0.2, 0.9, 0.1 ), sunColor: 0xffeedd, waterColor: 0x001e0f, distortionScale: 3.7, alpha: 0.8, size: 2, resolutionScale: 0.25 } ) );
add( 'water_mesh_defaults', () => new WaterMesh( geometry(), {} ) );
add( 'water2_mesh', () => new Water2Mesh( geometry(), { normalMap0: tex( 'n0' ), normalMap1: tex( 'n1' ), color: 0xaaccff, scale: 4, flowDirection: new THREE.Vector2( 1, 1 ) } ) );
add( 'water2_mesh_flow', () => new Water2Mesh( geometry(), { normalMap0: tex( 'n0' ), normalMap1: tex( 'n1' ), flowMap: tex( 'flow' ), reflectivity: 0.35, flowSpeed: 0.5 } ) );
add( 'lensflare_mesh', () => new LensflareMesh() );

const build = ( object, renderer, glsl ) => {

	const b = glsl ? new GLSLNodeBuilder( object, renderer ) : new WGSLNodeBuilder( object, renderer );
	b.scene = new THREE.Scene();
	b.camera = new THREE.PerspectiveCamera();
	b.lightsNode = new N.LightsNode().setLights( [] );
	try {

		b.build();

	} catch ( e ) {

		return { error: String( e && e.message ) };

	}

	return { shader: b.vertexShader + '\n@@@@\n' + b.fragmentShader, bindings: bindingsOf( b ), children: object.children.map( ( c ) => c.type + ':' + c.name ).join( ',' ) };

};

const wgsl = wgslRenderer();
const glsl = glslRenderer();
const records = {};
for ( const s of scenarios ) {

	records[ s.name ] = build( s.make(), wgsl, false );
	records[ s.name + '_glsl' ] = build( s.make(), glsl, true );

}

process.stdout.write( '@@A6 ' + JSON.stringify( records ) + '\n' );
