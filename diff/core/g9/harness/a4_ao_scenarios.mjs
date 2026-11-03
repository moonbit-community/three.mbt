// A4 mock-GPU scenarios of group `ao` (GTAONode, SSGINode, SSSNode, GodraysNode): a lit
// scene through a RenderPipeline using each node, rendered twice (temporal paths). The
// MoonBit side is ../mbt/a4/ao.mbt, step for step.
export function register( { scenario, renderer, camera, litScene } ) {

	// pass( scene, camera ) with an MRT of output + normalView
	const mrtPass = ( { TSL }, scene, cam ) => {
		const scenePass = TSL.pass( scene, cam );
		scenePass.setMRT( TSL.mrt( { output: TSL.output, normal: TSL.normalView } ) );
		return scenePass;
	};

	const shadowScene = ( ctx, light ) => {
		const scene = litScene( ctx );
		for ( const child of scene.children ) if ( child.isMesh ) {
			child.castShadow = true;
			child.receiveShadow = true;
		}
		light.castShadow = true;
		light.shadow.mapSize.set( 64, 64 );
		scene.add( light );
		return scene;
	};

	scenario( 'a4_ao_gtao', [ 'tsl/display/GTAONode.js' ], async ( ctx, A ) => {
		const { THREE } = ctx;
		const r = renderer( ctx );
		await r.init();
		const scene = litScene( ctx );
		const cam = camera( ctx );
		const pp = new THREE.RenderPipeline( r );
		const scenePass = mrtPass( ctx, scene, cam );
		const aoPass = A.ao( scenePass.getTextureNode( 'depth' ), scenePass.getTextureNode( 'normal' ), cam );
		aoPass.useTemporalFiltering = true;
		pp.outputNode = aoPass.getTextureNode().mul( scenePass.getTextureNode( 'output' ) );
		pp.render();
		r._nodes.nodeFrame.update(); // next frame (the harness's requestAnimationFrame never fires)
		pp.render();
	} );

	scenario( 'a4_ao_gtao_no_normal', [ 'tsl/display/GTAONode.js' ], async ( ctx, A ) => {
		const { THREE, TSL } = ctx;
		const r = renderer( ctx );
		await r.init();
		const scene = litScene( ctx );
		const cam = camera( ctx );
		const pp = new THREE.RenderPipeline( r );
		const scenePass = TSL.pass( scene, cam );
		const aoPass = A.ao( scenePass.getTextureNode( 'depth' ), null, cam );
		aoPass.samples.value = 8;
		aoPass.resolutionScale = 0.5;
		pp.outputNode = TSL.vec4( TSL.vec3( aoPass.getTextureNode().r ), 1 );
		pp.render();
		// a sample count change rebuilds the material
		aoPass.samples.value = 32;
		r._nodes.nodeFrame.update();
		pp.render();
	} );

	scenario( 'a4_ao_ssgi', [ 'tsl/display/SSGINode.js' ], async ( ctx, A ) => {
		const { THREE, TSL } = ctx;
		const r = renderer( ctx );
		await r.init();
		const scene = litScene( ctx );
		const cam = camera( ctx );
		const pp = new THREE.RenderPipeline( r );
		const scenePass = mrtPass( ctx, scene, cam );
		const color = scenePass.getTextureNode( 'output' );
		const giPass = A.ssgi( color, scenePass.getTextureNode( 'depth' ), scenePass.getTextureNode( 'normal' ), cam );
		giPass.sliceCount.value = 2;
		giPass.stepCount.value = 8;
		pp.outputNode = TSL.vec4( color.rgb.mul( giPass.getAONode().r ).add( giPass.getGINode().rgb ), color.a );
		pp.render();
		giPass.useTemporalFiltering = false;
		r._nodes.nodeFrame.update();
		pp.render();
	} );

	scenario( 'a4_ao_sss', [ 'tsl/display/SSSNode.js' ], async ( ctx, A ) => {
		const { THREE, TSL } = ctx;
		const r = renderer( ctx );
		await r.init();
		r.shadowMap.enabled = true;
		const light = new THREE.DirectionalLight( 0xffffff, 2 );
		light.position.set( 1, 2, 3 );
		const scene = shadowScene( ctx, light );
		const cam = camera( ctx );
		const pp = new THREE.RenderPipeline( r );
		const scenePass = TSL.pass( scene, cam );
		const sssPass = A.sss( scenePass.getTextureNode( 'depth' ), cam, light );
		sssPass.useTemporalFiltering = true;
		pp.outputNode = scenePass.getTextureNode( 'output' ).mul( sssPass.getTextureNode().r );
		pp.render();
		r._nodes.nodeFrame.update(); // next frame (the harness's requestAnimationFrame never fires)
		pp.render();
		sssPass.useTemporalFiltering = false;
		r._nodes.nodeFrame.update();
		pp.render();
	} );

	for ( const kind of [ 'directional', 'point' ] ) {
		scenario( 'a4_ao_godrays_' + kind, [ 'tsl/display/GodraysNode.js' ], async ( ctx, A ) => {
			const { THREE, TSL } = ctx;
			const r = renderer( ctx );
			await r.init();
			r.shadowMap.enabled = true;
			const light = kind === 'point' ? new THREE.PointLight( 0xffffff, 3, 10, 2 ) : new THREE.DirectionalLight( 0xffffff, 2 );
			light.position.set( - 1, 2, 2 );
			const scene = shadowScene( ctx, light );
			const cam = camera( ctx );
			// the shadow map exists once the scene has been rendered
			r.render( scene, cam );
			const pp = new THREE.RenderPipeline( r );
			const scenePass = TSL.pass( scene, cam );
			const godraysPass = A.godrays( scenePass.getTextureNode( 'depth' ), cam, light );
			godraysPass.raymarchSteps.value = 24;
			pp.outputNode = scenePass.getTextureNode( 'output' ).add( godraysPass.getTextureNode() );
			pp.render();
			r._nodes.nodeFrame.update();
			pp.render();
		} );
	}

}
