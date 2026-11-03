// A4 mock-GPU scenarios of group `ssr` (SSRNode, RecurrentDenoiseNode); the MoonBit side is
// ../mbt/a4/ssr.mbt, step for step.
const MODULES = [ 'tsl/display/SSRNode.js', 'tsl/display/RecurrentDenoiseNode.js' ];

export function register( { scenario, renderer, camera, litScene } ) {

	// the lit scene with a metallic box and the g-buffer pass: output, view normal, metal/rough
	const gbuffer = ( ctx ) => {
		const { THREE, TSL } = ctx;
		const scene = litScene( ctx );
		const box = scene.children[ 2 ];
		box.material.metalness = 1;
		box.material.roughness = 0.3;
		const cam = camera( ctx );
		const scenePass = TSL.pass( scene, cam );
		scenePass.setMRT( TSL.mrt( { output: TSL.output, normal: TSL.normalView, metalrough: TSL.vec2( TSL.metalness, TSL.roughness ) } ) );
		return {
			cam,
			color: scenePass.getTextureNode( 'output' ),
			normal: scenePass.getTextureNode( 'normal' ),
			depth: scenePass.getTextureNode( 'depth' ),
			mr: scenePass.getTextureNode( 'metalrough' ),
			THREE
		};
	};

	const hdr = ( { THREE } ) => {
		const data = new Uint16Array( 4 * 2 * 4 );
		for ( let i = 0; i < data.length; i ++ ) data[ i ] = THREE.DataUtils.toHalfFloat( ( i % 7 ) * 0.5 + 0.25 );
		const t = new THREE.DataTexture( data, 4, 2, THREE.RGBAFormat, THREE.HalfFloatType );
		t.needsUpdate = true;
		return t;
	};

	scenario( 'a4_ssr_mirror', MODULES, async ( ctx, A ) => {
		const { THREE, TSL } = ctx;
		const r = renderer( ctx );
		await r.init();
		const g = gbuffer( ctx );
		const pp = new THREE.RenderPipeline( r );
		const s = A.ssr( g.color, g.depth, g.normal, { metalnessNode: g.mr.r, roughnessNode: g.mr.g, camera: g.cam } );
		s.blurQuality = 1;
		pp.outputNode = TSL.vec4( g.color.rgb.add( s.rgb ), g.color.a );
		pp.render();
		pp.render();
	} );

	scenario( 'a4_ssr_stochastic_denoise', MODULES, async ( ctx, A ) => {
		const { THREE, TSL } = ctx;
		const r = renderer( ctx );
		await r.init();
		const g = gbuffer( ctx );
		const pp = new THREE.RenderPipeline( r );
		const s = A.ssr( g.color, g.depth, g.normal, { stochastic: true, metalnessNode: g.mr.r, roughnessNode: g.mr.g, camera: g.cam } );
		const d = A.recurrentDenoise( s, g.cam, { depth: g.depth, normal: g.normal, raw: s, mode: 'specular', metalRoughness: g.mr } );
		pp.outputNode = TSL.vec4( g.color.rgb.add( d.rgb ), g.color.a );
		pp.render();
		pp.render();
		pp.render();
	} );

	scenario( 'a4_ssr_env_refine', MODULES, async ( ctx, A ) => {
		const { THREE, TSL } = ctx;
		const r = renderer( ctx );
		await r.init();
		const g = gbuffer( ctx );
		const pp = new THREE.RenderPipeline( r );
		const s = A.ssr( g.color, g.depth, g.normal, { stochastic: true, metalnessNode: g.mr.r, roughnessNode: g.mr.g, environmentNode: hdr( ctx ), envImportanceSampling: true, binaryRefine: true, camera: g.cam } );
		s.screenEdgeFadeBlack = true;
		s.resolutionScale = 0.5;
		pp.outputNode = TSL.vec4( g.color.rgb.add( s.rgb ), g.color.a );
		pp.render();
		pp.render();
	} );

	scenario( 'a4_ssr_denoise_diffuse_ao', MODULES, async ( ctx, A ) => {
		const { THREE, TSL } = ctx;
		const r = renderer( ctx );
		await r.init();
		const g = gbuffer( ctx );
		const pp = new THREE.RenderPipeline( r );
		const d = A.recurrentDenoise( g.color, g.cam, { depth: g.depth, normal: g.normal, raw: g.color, accumulate: true } );
		d.alphaSource = 'ao';
		pp.outputNode = d;
		pp.render();
		pp.render();
	} );

}
