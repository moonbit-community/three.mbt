// Group `ao` (src/addons/tsl/a4_ao_shader_diff_test.mbt): GTAONode, SSGINode, SSSNode,
// GodraysNode. Each scenario flows the node and builds its internal material.
export const modules = [ 'tsl/display/GTAONode.js', 'tsl/display/SSGINode.js', 'tsl/display/SSSNode.js', 'tsl/display/GodraysNode.js' ];

export function scenarios( { T, THREE, A, flow, tex, depthTex } ) {

	const persp = () => new THREE.PerspectiveCamera( 60, 1.5, 0.1, 50 );
	const ortho = () => new THREE.OrthographicCamera( - 2, 2, 1, - 1, 0.5, 20 );
	const aoInternals = ( n ) => [ [ 'ao', n._material ] ];

	// GTAO
	flow( 'ao_gtao', () => A.ao( T.texture( depthTex( 'depth' ) ), T.texture( tex( 'normal' ) ), persp() ), { internals: aoInternals, glsl: true } );
	flow( 'ao_gtao_no_normal', () => A.ao( T.texture( depthTex( 'depth' ) ), null, persp() ), { internals: aoInternals } );
	flow( 'ao_gtao_ortho', () => A.ao( T.texture( depthTex( 'depth' ) ), T.texture( tex( 'normal' ) ), ortho() ), { internals: aoInternals, glsl: true } );
	flow( 'ao_gtao_options', () => {

		const n = A.ao( T.texture( depthTex( 'depth' ) ), T.texture( tex( 'normal' ) ), persp() );
		n.samples.value = 32;
		n.radius.value = 0.5;
		n.distanceExponent.value = 2;
		n.thickness.value = 0.5;
		n.scale.value = 1.5;
		n.resolutionScale = 0.5;
		n.useTemporalFiltering = true;
		return n;

	}, { internals: aoInternals } );
	flow( 'ao_gtao_samples_8', () => {

		const n = A.ao( T.texture( depthTex( 'depth' ) ), null, ortho() );
		n.samples.value = 8;
		return n;

	}, { internals: aoInternals } );

	// SSGI
	const ssgiInternals = ( n ) => [ [ 'ssgi', n._material ] ];
	flow( 'ao_ssgi', () => A.ssgi( T.texture( tex( 'beauty' ) ), T.texture( depthTex( 'depth' ) ), T.texture( tex( 'normal' ) ), persp() ), { internals: ssgiInternals, glsl: true } );
	flow( 'ao_ssgi_gi_node', () => {

		const n = A.ssgi( T.texture( tex( 'beauty' ) ), T.texture( depthTex( 'depth' ) ), T.texture( tex( 'normal' ) ), persp() );
		return T.vec4( n.getGINode().rgb, n.getAONode().r );

	}, { internals: ( n ) => [] } );
	flow( 'ao_ssgi_no_normal_ortho', () => A.ssgi( T.vec4( T.uv(), 0, 1 ), T.texture( depthTex( 'depth' ) ), null, ortho() ), { internals: ( n ) => [ [ 'ssgi', n._material ], [ 'rtt', n.beautyNode._quadMesh.material ] ] } );
	flow( 'ao_ssgi_options', () => {

		const n = A.ssgi( T.texture( tex( 'beauty' ) ), T.texture( depthTex( 'depth' ) ), T.texture( tex( 'normal' ) ), persp() );
		n.sliceCount.value = 2;
		n.stepCount.value = 8;
		n.aoIntensity.value = 0.5;
		n.giIntensity.value = 4;
		n.radius.value = 6;
		n.useScreenSpaceSampling.value = false;
		n.expFactor.value = 1.5;
		n.thickness.value = 0.25;
		n.useLinearThickness.value = true;
		n.backfaceLighting.value = 0.5;
		n.useTemporalFiltering = false;
		n.resolutionScale = 0.5;
		return n;

	}, { internals: ssgiInternals } );

	// SSS
	const sssInternals = ( n ) => [ [ 'sss', n._material ] ];
	const dirLight = () => {

		const l = new THREE.DirectionalLight( 0xffffff, 2 );
		l.position.set( 1, 2, 3 );
		l.castShadow = true;
		return l;

	};

	const pointLight = () => {

		const l = new THREE.PointLight( 0xffffff, 3, 10, 2 );
		l.position.set( - 1, 2, 1 );
		l.castShadow = true;
		return l;

	};

	flow( 'ao_sss', () => A.sss( T.texture( depthTex( 'depth' ) ), persp(), dirLight() ), { internals: sssInternals, glsl: true } );
	flow( 'ao_sss_ortho_point', () => A.sss( T.texture( depthTex( 'depth' ) ), ortho(), pointLight() ), { internals: sssInternals, glsl: true } );
	flow( 'ao_sss_options', () => {

		const n = A.sss( T.texture( depthTex( 'depth' ) ), persp(), dirLight() );
		n.maxDistance.value = 0.2;
		n.thickness.value = 0.05;
		n.shadowIntensity.value = 0.75;
		n.quality.value = 1;
		n.resolutionScale = 0.5;
		n.useTemporalFiltering = true;
		return n;

	}, { internals: sssInternals } );

	// Godrays
	const godraysInternals = ( n ) => [ [ 'godrays', n._material ] ];
	const withShadowMap = ( l, depthTexture ) => {

		l.shadow.map = new THREE.RenderTarget( 4, 4, { depthTexture } );
		return l;

	};

	flow( 'ao_godrays_directional', () => A.godrays( T.texture( depthTex( 'depth' ) ), persp(), withShadowMap( dirLight(), new THREE.DepthTexture( 4, 4 ) ) ), { internals: godraysInternals, glsl: true } );
	flow( 'ao_godrays_point', () => A.godrays( T.texture( depthTex( 'depth' ) ), persp(), withShadowMap( pointLight(), new THREE.CubeDepthTexture( 4 ) ) ), { internals: godraysInternals, glsl: true } );
	flow( 'ao_godrays_options', () => {

		const n = A.godrays( T.texture( depthTex( 'depth' ) ), ortho(), withShadowMap( dirLight(), new THREE.DepthTexture( 4, 4 ) ) );
		n.raymarchSteps.value = 30;
		n.density.value = 0.5;
		n.maxDensity.value = 0.8;
		n.distanceAttenuation.value = 1;
		n.resolutionScale = 1;
		return n;

	}, { internals: godraysInternals } );

}
