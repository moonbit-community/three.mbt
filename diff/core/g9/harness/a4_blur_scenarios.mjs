// A4 mock-GPU scenarios, group `blur` (MoonBit side: ../mbt/a4/blur.mbt): GaussianBlurNode,
// DepthOfFieldNode and SharpenNode in a RenderPipeline over a scene pass.
export function register( { scenario, renderer, camera, litScene } ) {

	const run = ( output ) => async ( ctx, A ) => {
		const { THREE, TSL } = ctx;
		const r = renderer( ctx );
		await r.init();
		const scene = litScene( ctx );
		const cam = camera( ctx );
		const pp = new THREE.RenderPipeline( r );
		const scenePass = TSL.pass( scene, cam );
		pp.outputNode = output( ctx, A, scenePass );
		pp.render();
		pp.render();
	};

	scenario( 'a4_blur_gaussian', [ 'tsl/display/GaussianBlurNode.js' ], run( ( { TSL }, A, scenePass ) => A.gaussianBlur( scenePass, null, 2 ) ) );
	scenario( 'a4_blur_gaussian_premultiplied', [ 'tsl/display/GaussianBlurNode.js' ], run( ( { TSL }, A, scenePass ) => A.gaussianBlur( scenePass, TSL.vec2( 1, 0.5 ), 3, { premultipliedAlpha: true, resolutionScale: 0.5 } ) ) );
	scenario( 'a4_blur_dof', [ 'tsl/display/GaussianBlurNode.js', 'tsl/display/DepthOfFieldNode.js' ], run( ( { TSL }, A, scenePass ) => A.dof( scenePass, scenePass.getViewZNode(), TSL.uniform( 2 ), TSL.uniform( 1 ), TSL.uniform( 1 ) ) ) );
	scenario( 'a4_blur_sharpen', [ 'tsl/display/SharpenNode.js' ], run( ( { TSL }, A, scenePass ) => A.sharpen( scenePass, 0.5, true ) ) );

}
