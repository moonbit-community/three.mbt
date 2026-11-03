// Upstream side of the A5 mock-GPU scenarios (TSL agent A5's pass-based display add-ons,
// tsl/lighting and tsl/shadows): each renders a scene through a RenderPipeline using the node
// (several frames for the temporal ones), on upstream's WebGPURenderer. The MoonBit side is
// ../mbt_a5/main/*.mbt, step for step. `node run_a5.mjs [name ...]` compares the logs.
// A scenario is { modules: [ add-on paths below examples/jsm ], run( ctx, A ) }: the modules
// are imported before the counters are aligned (the MoonBit side calls their `load_*()`).
export const scenarios = {};
export const scenario = ( name, modules, run ) => { scenarios[ name ] = { modules, run }; };

const renderer = ( { THREE, canvas } ) => new THREE.WebGPURenderer( { canvas, antialias: false } );
const camera = ( { THREE } ) => {
	const c = new THREE.PerspectiveCamera( 50, 1, 0.1, 10 );
	c.position.z = 3;
	return c;
};

// a lit standard box and a plane
const litScene = ( { THREE } ) => {
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

// One animation frame without requestAnimationFrame (the mock's never fires): the body of
// Animation's `update` (minus the inspector), so FRAME-updated nodes run again.
export const tick = ( r ) => {
	if ( r.info.autoReset === true ) r.info.reset();
	r._nodes.nodeFrame.update();
	r.info.frame = r._nodes.nodeFrame.frameId;
};

// `frames` renders (one animation frame each) of a lit scene through a RenderPipeline whose output is
// `output( scenePass, camera, scene, renderer )`; `step( i, scene )` runs before frame i > 0
const pipeline = async ( ctx, frames, output, options = {} ) => {
	const { THREE, TSL } = ctx;
	const r = renderer( ctx );
	await r.init();
	if ( options.before ) options.before( r );
	const scene = litScene( ctx );
	const cam = camera( ctx );
	const pp = new THREE.RenderPipeline( r );
	const scenePass = TSL.pass( scene, cam );
	if ( options.mrt ) scenePass.setMRT( options.mrt( TSL ) );
	pp.outputNode = output( scenePass, cam, scene, r );
	for ( let i = 0; i < frames; i ++ ) {
		if ( i > 0 ) tick( r );
		if ( i > 0 && options.step ) options.step( i, scene, cam );
		pp.render();
	}
	if ( options.after ) options.after( pp );
	return { r, pp, scene, cam };
};

const move = ( i, scene ) => {
	scene.children[ 2 ].rotation.y += 0.1;
	scene.children[ 2 ].position.x = 0.05 * i;
};

const velocityMRT = ( T ) => T.mrt( { output: T.output, velocity: T.velocity } );
const normalMRT = ( T ) => T.mrt( { output: T.output, normal: T.normalView } );
const allMRT = ( T ) => T.mrt( { output: T.output, normal: T.normalView, velocity: T.velocity } );

scenario( 'a5_bloom', [ 'tsl/display/BloomNode.js' ], ( ctx, A ) => pipeline( ctx, 2, ( p ) => p.add( A.bloom( p, 1.2, 0.3, 0.1 ) ) ) );
scenario( 'a5_bloom_nodes', [ 'tsl/display/BloomNode.js' ], ( ctx, A ) => pipeline( ctx, 2, ( p, c, s, r ) => {
	const b = A.bloom( p.getTextureNode(), ctx.TSL.uniform( 1 ), ctx.TSL.uniform( 0.5 ), ctx.TSL.uniform( 0.2 ) );
	b.setResolutionScale( 0.25 );
	return b;
}, { after: ( pp ) => pp.outputNode.dispose() } ) );
scenario( 'a5_smaa', [ 'tsl/display/SMAANode.js' ], ( ctx, A ) => pipeline( ctx, 2, ( p ) => A.smaa( p ) ) );
scenario( 'a5_ssao', [ 'tsl/display/SSAONode.js' ], ( ctx, A ) => pipeline( ctx, 2, ( p, c ) => {
	const ao = A.ssao( p.getTextureNode( 'depth' ), p.getTextureNode( 'normal' ), c );
	ao.radius.value = 0.6;
	return p.mul( ao.r );
}, { mrt: normalMRT } ) );
scenario( 'a5_outline', [ 'tsl/display/OutlineNode.js' ], ( ctx, A ) => pipeline( ctx, 2, ( p, c, s ) => {
	const o = A.outline( s, c, { selectedObjects: [ s.children[ 2 ] ], edgeThickness: ctx.TSL.uniform( 2 ), edgeGlow: ctx.TSL.uniform( 1 ) } );
	return p.add( o.visibleEdge.mul( 3 ) ).add( o.hiddenEdge );
} ) );
scenario( 'a5_film_chromatic_lut', [ 'tsl/display/FilmNode.js', 'tsl/display/ChromaticAberrationNode.js', 'tsl/display/Lut3DNode.js' ], ( ctx, A ) => pipeline( ctx, 2, ( p ) => {
	const { THREE, TSL } = ctx;
	const data = new Uint8Array( 4 * 4 * 4 * 4 );
	for ( let i = 0; i < data.length; i ++ ) data[ i ] = ( i * 37 ) % 256;
	const lut = new THREE.Data3DTexture( data, 4, 4, 4 );
	lut.needsUpdate = true;
	const ca = A.chromaticAberration( p, 1.5, TSL.vec2( 0.5, 0.5 ), 1.2 );
	return A.film( A.lut3D( ca, TSL.texture3D( lut ), 4, TSL.uniform( 0.8 ) ), TSL.uniform( 0.4 ) );
} ) );
scenario( 'a5_motion_blur_sepia', [ 'tsl/display/MotionBlur.js', 'tsl/display/Sepia.js' ], ( ctx, A ) => pipeline( ctx, 3, ( p ) => A.sepia( A.motionBlur( p.getTextureNode(), p.getTextureNode( 'velocity' ).mul( 2 ), ctx.TSL.int( 4 ) ) ), { mrt: velocityMRT, step: move } ) );
scenario( 'a5_after_image', [ 'tsl/display/AfterImageNode.js' ], ( ctx, A ) => pipeline( ctx, 3, ( p ) => A.afterImage( p, 0.9 ), { step: move } ) );
scenario( 'a5_traa', [ 'tsl/display/TRAANode.js' ], ( ctx, A ) => pipeline( ctx, 4, ( p, c ) => A.traa( p.getTextureNode(), p.getTextureNode( 'depth' ), p.getTextureNode( 'velocity' ), c ), { mrt: velocityMRT, step: move } ) );
scenario( 'a5_taau', [ 'tsl/display/TAAUNode.js' ], ( ctx, A ) => pipeline( ctx, 4, ( p, c ) => A.taau( p.getTextureNode(), p.getTextureNode( 'depth' ), p.getTextureNode( 'velocity' ), c ), { mrt: velocityMRT, step: move } ) );
scenario( 'a5_temporal_reproject', [ 'tsl/display/TemporalReprojectNode.js' ], ( ctx, A ) => pipeline( ctx, 3, ( p, c ) => A.temporalReproject( p.getTextureNode(), p.getTextureNode( 'depth' ), p.getTextureNode( 'normal' ), p.getTextureNode( 'velocity' ), c ), { mrt: allMRT, step: move } ) );
scenario( 'a5_oit', [ 'tsl/display/OITPassNode.js' ], async ( ctx, A ) => {
	const { THREE } = ctx;
	const r = renderer( ctx );
	await r.init();
	const scene = litScene( ctx );
	for ( let i = 0; i < 2; i ++ ) {
		const m = new THREE.MeshStandardNodeMaterial();
		m.transparent = true;
		m.opacity = 0.5;
		m.color.setHex( i === 0 ? 0xff4400 : 0x00ff88 );
		const s = new THREE.Mesh( new THREE.SphereGeometry( 0.4, 8, 6 ), m );
		s.position.set( i * 0.5 - 0.25, 0, 0.8 );
		scene.add( s );
	}
	const cam = camera( ctx );
	const pp = new THREE.RenderPipeline( r );
	pp.outputNode = A.oitPass( scene, cam );
	pp.render();
	tick( r );
	pp.render();
	// the transparent materials again outside the OIT pass (their own depthWrite)
	tick( r );
	r.render( scene, cam );
} );
scenario( 'a5_fsr1', [ 'tsl/display/FSR1Node.js' ], ( ctx, A ) => pipeline( ctx, 2, ( p ) => A.fsr1( p, 0.3, true ) ) );
scenario( 'a5_bilateral_lensflare', [ 'tsl/display/BilateralBlurNode.js', 'tsl/display/LensflareNode.js' ], ( ctx, A ) => pipeline( ctx, 2, ( p ) => A.bilateralBlur( p, ctx.TSL.vec2( 1, 1 ), 3, 0.2 ).add( A.lensflare( p, { threshold: ctx.TSL.float( 0.3 ) } ) ) ) );
scenario( 'a5_denoise', [ 'tsl/display/DenoiseNode.js' ], ( ctx, A ) => pipeline( ctx, 2, ( p, c ) => A.denoise( p.getTextureNode(), p.getTextureNode( 'depth' ), p.getTextureNode( 'normal' ), c ), { mrt: normalMRT } ) );
scenario( 'a5_parallax_barrier', [ 'tsl/display/ParallaxBarrierPassNode.js' ], async ( ctx, A ) => {
	const { THREE } = ctx;
	const r = renderer( ctx );
	await r.init();
	const pp = new THREE.RenderPipeline( r );
	pp.outputNode = A.parallaxBarrierPass( litScene( ctx ), camera( ctx ) );
	pp.render();
	tick( r );
	pp.render();
	pp.outputNode.dispose();
} );
scenario( 'a5_transition_blurs', [ 'tsl/display/TransitionNode.js', 'tsl/display/boxBlur.js', 'tsl/display/hashBlur.js', 'tsl/display/Shape.js' ], ( ctx, A ) => pipeline( ctx, 2, ( p ) => {
	const { TSL } = ctx;
	const a = A.boxBlur( p.getTextureNode(), { size: TSL.int( 1 ), separation: TSL.int( 2 ) } );
	const b = A.hashBlur( p.getTextureNode(), 0.05, { repeats: 4 } );
	return A.transition( a, b, A.circle( 0.5, 0.2 ), TSL.uniform( 0.4 ), TSL.uniform( 0.1 ), TSL.uniform( 1 ) );
} ) );
// renderer.lighting replaced by a Lighting whose nodes are the add-on lights nodes
// (examples/jsm/lighting/DynamicLighting.js and ClusteredLighting.js do the same)
const customLighting = ( THREE, make ) => {
	const lighting = new THREE.Lighting();
	lighting.createNode = ( lights = [] ) => make().setLights( lights );
	return lighting;
};
const pointLights = ( ctx, scene, count ) => {
	const { THREE } = ctx;
	for ( let i = 0; i < count; i ++ ) {
		const l = new THREE.PointLight( 0xffffff * ( i + 1 ) / count, 2, 5, 2 );
		l.position.set( Math.cos( i ) * 1.5, Math.sin( i ) * 1.5, 1 );
		scene.add( l );
	}
	const spot = new THREE.SpotLight( 0xffaa00, 3, 6, 0.6, 0.2 );
	spot.position.set( 0, 2, 2 );
	scene.add( spot );
	scene.add( new THREE.HemisphereLight( 0x8888ff, 0x442200, 0.5 ) );
};
scenario( 'a5_dynamic_lights', [ 'tsl/lighting/DynamicLightsNode.js' ], async ( ctx, A ) => {
	const { THREE } = ctx;
	const r = renderer( ctx );
	await r.init();
	r.lighting = customLighting( THREE, () => new A.DynamicLightsNode( { maxPointLights: 4 } ) );
	const scene = litScene( ctx );
	pointLights( ctx, scene, 3 );
	const cam = camera( ctx );
	r.render( scene, cam );
	tick( r );
	pointLights( ctx, scene, 1 );
	r.render( scene, cam );
} );
scenario( 'a5_clustered_lights', [ 'tsl/lighting/ClusteredLightsNode.js' ], async ( ctx, A ) => {
	const { THREE } = ctx;
	const r = renderer( ctx );
	await r.init();
	r.lighting = customLighting( THREE, () => new A.ClusteredLightsNode() );
	const scene = litScene( ctx );
	pointLights( ctx, scene, 4 );
	const cam = camera( ctx );
	r.render( scene, cam );
	tick( r );
	scene.children[ 2 ].rotation.y = 1;
	r.render( scene, cam );
} );
scenario( 'a5_tile_shadow', [ 'tsl/shadows/TileShadowNode.js' ], async ( ctx, A ) => {
	const { THREE } = ctx;
	const r = renderer( ctx );
	await r.init();
	r.shadowMap.enabled = true;
	const scene = litScene( ctx );
	scene.children[ 2 ].castShadow = true;
	scene.children[ 3 ].receiveShadow = true;
	const dl = scene.children[ 1 ];
	dl.castShadow = true;
	dl.shadow.mapSize.set( 64, 64 );
	// a non-square shadow frustum (tile widths and heights differ)
	dl.shadow.camera.left = - 3;
	dl.shadow.camera.right = 3;
	dl.shadow.camera.top = 2;
	dl.shadow.camera.bottom = - 1.5;
	dl.shadow.shadowNode = new A.TileShadowNode( dl, { tilesX: 2, tilesY: 2 } );
	const cam = camera( ctx );
	r.render( scene, cam );
	tick( r );
	dl.position.set( 2, 2, 2 );
	r.render( scene, cam );
} );
