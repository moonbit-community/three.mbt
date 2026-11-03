// Upstream side of the A4 mock-GPU scenarios (TSL agent A4's pass-based display add-ons):
// each renders a scene through a RenderPipeline using the node, on upstream's
// WebGPURenderer. The MoonBit side is ../mbt/a4/*.mbt, step for step.
// A scenario is { modules: [ add-on paths below examples/jsm ], run( ctx, A ) }: the modules
// are imported before the counters are aligned (as the MoonBit side calls their `load_*()`),
// `A` holds their named exports (and each default export under its class name).
export const scenarios = {};
export const scenario = ( name, modules, run ) => { scenarios[ name ] = { modules, run }; };

export const renderer = ( { THREE, canvas } ) => new THREE.WebGPURenderer( { canvas, antialias: false } );
export const camera = ( { THREE } ) => {
	const c = new THREE.PerspectiveCamera( 50, 1, 0.1, 10 );
	c.position.z = 3;
	return c;
};

// a lit standard box and a sphere on a plane
export const litScene = ( { THREE } ) => {
	const scene = new THREE.Scene();
	scene.add( new THREE.AmbientLight( 0x404040, 1 ) );
	const dl = new THREE.DirectionalLight( 0xffffff, 2 );
	dl.position.set( 1, 2, 3 );
	scene.add( dl );
	const box = new THREE.Mesh( new THREE.BoxGeometry(), new THREE.MeshStandardNodeMaterial() );
	box.material.color.setHex( 0x3366cc );
	box.rotation.set( 0.4, 0.6, 0 );
	scene.add( box );
	const plane = new THREE.Mesh( new THREE.PlaneGeometry( 4, 4 ), new THREE.MeshStandardNodeMaterial() );
	plane.position.z = - 1;
	scene.add( plane );
	return scene;
};

scenario( 'a4_rgb_shift', [ 'tsl/display/RGBShiftNode.js' ], async ( ctx, A ) => {
	const { THREE, TSL } = ctx;
	const r = renderer( ctx );
	await r.init();
	const scene = litScene( ctx );
	const cam = camera( ctx );
	const pp = new THREE.RenderPipeline( r );
	const scenePass = TSL.pass( scene, cam );
	pp.outputNode = A.rgbShift( scenePass, 0.01, 0.3 );
	pp.render();
	pp.render();
} );

const pipeline = async ( ctx, output ) => {
	const { THREE, TSL } = ctx;
	const r = renderer( ctx );
	await r.init();
	const scene = litScene( ctx );
	const cam = camera( ctx );
	const pp = new THREE.RenderPipeline( r );
	const scenePass = TSL.pass( scene, cam );
	pp.outputNode = output( scenePass, cam, TSL );
	pp.render();
	pp.render();
};

scenario( 'a4_fxaa', [ 'tsl/display/FXAANode.js' ], ( ctx, A ) => pipeline( ctx, ( p ) => A.fxaa( p ) ) );
scenario( 'a4_fxaa_rtt', [ 'tsl/display/FXAANode.js' ], ( ctx, A ) => pipeline( ctx, ( p ) => A.fxaa( p.mul( 0.8 ) ) ) );
scenario( 'a4_sobel', [ 'tsl/display/SobelOperatorNode.js' ], ( ctx, A ) => pipeline( ctx, ( p ) => A.sobel( p ) ) );
scenario( 'a4_dot_screen', [ 'tsl/display/DotScreenNode.js' ], ( ctx, A ) => pipeline( ctx, ( p, c, T ) => A.dotScreen( p, T.uniform( 0.5 ), 1.5 ) ) );
scenario( 'a4_bleach_radial_blur', [ 'tsl/display/BleachBypass.js', 'tsl/display/radialBlur.js' ], ( ctx, A ) => pipeline( ctx, ( p, c, T ) => A.bleach( A.radialBlur( p, { count: 8, premultipliedAlpha: true } ), 0.7 ) ) );
scenario( 'a4_crt_lens_dirt', [ 'tsl/display/CRT.js', 'tsl/display/lensDirt.js' ], ( ctx, A ) => pipeline( ctx, ( p, c, T ) => {
	const distorted = A.barrelUV( 0.1 );
	const dirt = new ctx.THREE.DataTexture( new Uint8Array( 16 ).fill( 200 ), 2, 2 );
	dirt.needsUpdate = true;
	const bled = A.colorBleeding( p );
	// (no scanlines: their `time` uniform reads the clock)
	return A.vignette( bled, 0.4 ).add( A.lensDirt( p, T.texture( dirt ) ).rgb ).mul( A.barrelMask( distorted ) );
} ) );
scenario( 'a4_depth_aware', [ 'tsl/display/depthAwareBlur.js', 'tsl/display/depthAwareBlend.js' ], ( ctx, A ) => pipeline( ctx, ( p, c, T ) => {
	const depth = p.getTextureNode( 'depth' );
	const blurred = A.depthAwareBlur( p.getTextureNode(), depth, T.vec2( 0.01, 0 ), c );
	return A.depthAwareBlend( p.getTextureNode(), p.getTextureNode(), depth, c, { edgeRadius: 2 } ).add( blurred );
} ) );

// the groups' scenarios: a4_<group>_scenarios.mjs (blur, ao, ssr, pass), each exporting
// `register( { scenario, renderer, camera, litScene } )`
import fs from 'node:fs';
import path from 'node:path';
import url from 'node:url';
const here = path.dirname( url.fileURLToPath( import.meta.url ) );
for ( const g of [ 'blur', 'ao', 'ssr', 'pass' ] ) {
	const f = path.join( here, `a4_${g}_scenarios.mjs` );
	if ( fs.existsSync( f ) ) ( await import( url.pathToFileURL( f ).href ) ).register( { scenario, renderer, camera, litScene } );
}
