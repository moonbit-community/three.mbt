// Group `ssr` (src/addons/tsl/a4_ssr_shader_diff_test.mbt): SSRNode and RecurrentDenoiseNode.
export const modules = [ 'tsl/display/SSRNode.js', 'tsl/display/RecurrentDenoiseNode.js' ];

export function scenarios( { T, THREE, A, flow, tex, depthTex } ) {

	const persp = () => {

		const c = new THREE.PerspectiveCamera( 50, 1.5, 0.1, 20 );
		c.position.set( 0, 1, 3 );
		c.updateMatrixWorld();
		return c;

	};

	const ortho = () => {

		const c = new THREE.OrthographicCamera( - 2, 2, 1.5, - 1.5, 0.1, 10 );
		c.position.set( 0, 0, 4 );
		c.updateMatrixWorld();
		return c;

	};

	// an equirectangular half-float HDR (4x2) with CPU-side data
	const hdr = () => {

		const data = new Uint16Array( 4 * 2 * 4 );
		for ( let i = 0; i < data.length; i ++ ) data[ i ] = THREE.DataUtils.toHalfFloat( ( i % 7 ) * 0.5 + 0.25 );
		const t = new THREE.DataTexture( data, 4, 2, THREE.RGBAFormat, THREE.HalfFloatType );
		t.name = 'hdr';
		return t;

	};

	const inputs = () => ( {
		color: T.texture( tex( 'color' ) ),
		depth: T.texture( depthTex( 'depth' ) ),
		normal: T.texture( tex( 'normal' ) ),
		mr: T.texture( tex( 'metalrough' ) )
	} );

	const ssrInternals = ( n ) => {

		const list = [ [ 'ssr', n._ssrMaterial ] ];
		if ( n.stochastic === false ) list.push( [ 'blur', n._blurMaterial ] );
		list.push( [ 'copy', n._copyMaterial ] );
		return list;

	};

	flow( 'ssr_ssr_mirror_roughness', () => {

		const i = inputs();
		return A.ssr( i.color, i.depth, i.normal, { metalnessNode: i.mr.r, roughnessNode: i.mr.g, camera: persp() } );

	}, { internals: ssrInternals, glsl: true } );
	// (upstream's `float( this.roughnessNode )` throws without a roughness node, so every
	// scenario passes one; a roughness node with `stochastic` off selects the blurred mips)
	flow( 'ssr_ssr_mirror_scalar_roughness', () => {

		const i = inputs();
		return A.ssr( i.color, i.depth, i.normal, { metalnessNode: i.mr.r, roughnessNode: T.float( 0.2 ), camera: persp() } );

	}, { internals: ssrInternals } );
	flow( 'ssr_ssr_mirror_options', () => {

		const i = inputs();
		const n = A.ssr( i.color, i.depth, i.normal, { metalnessNode: i.mr.r, roughnessNode: i.mr.g, reflectNonMetals: true, binaryRefine: true, camera: persp() } );
		n.blurQuality = 3;
		n.resolutionScale = 0.5;
		n.maxDistance.value = 4;
		n.thickness.value = 0.02;
		n.quality.value = 0.8;
		n.intensity.value = 0.7;
		return n;

	}, { internals: ssrInternals } );
	flow( 'ssr_ssr_mirror_ortho', () => {

		const i = inputs();
		return A.ssr( i.color, i.depth, i.normal, { metalnessNode: i.mr.r, roughnessNode: i.mr.g, camera: ortho() } );

	}, { internals: ssrInternals, glsl: true } );
	flow( 'ssr_ssr_mirror_ortho_refine', () => {

		const i = inputs();
		const n = A.ssr( i.color, i.depth, i.normal, { metalnessNode: i.mr.r, roughnessNode: i.mr.g, camera: ortho() } );
		n.binaryRefine = true;
		return n;

	}, { internals: ssrInternals } );
	flow( 'ssr_ssr_stochastic', () => {

		const i = inputs();
		return A.ssr( i.color, i.depth, i.normal, { stochastic: true, metalnessNode: i.mr.r, roughnessNode: i.mr.g, camera: persp() } );

	}, { internals: ssrInternals, glsl: true } );
	flow( 'ssr_ssr_stochastic_specular', () => {

		const i = inputs();
		const n = A.ssr( i.color, i.depth, i.normal, { stochastic: true, metalnessNode: i.mr.r, roughnessNode: i.mr.g, specularNode: T.texture( tex( 'spec' ) ).rgb, specularF90Node: T.texture( tex( 'f90' ) ).r, diffuseNode: T.texture( tex( 'diffuse' ) ), camera: persp() } );
		n.stepExponent = 3;
		n.mirrorBias.value = 0.5;
		return n;

	}, { internals: ssrInternals } );
	flow( 'ssr_ssr_stochastic_diffuse_fade_black', () => {

		const i = inputs();
		const n = A.ssr( i.color, i.depth, i.normal, { stochastic: true, metalnessNode: i.mr.r, roughnessNode: i.mr.g, diffuseNode: T.texture( tex( 'diffuse' ) ), camera: persp() } );
		n.screenEdgeFadeBlack = true;
		return n;

	}, { internals: ssrInternals } );
	flow( 'ssr_ssr_stochastic_env_brdf', () => {

		const i = inputs();
		return A.ssr( i.color, i.depth, i.normal, { stochastic: true, metalnessNode: i.mr.r, roughnessNode: i.mr.g, environmentNode: hdr(), camera: persp() } );

	}, { internals: ssrInternals } );
	flow( 'ssr_ssr_stochastic_env_mis', () => {

		const i = inputs();
		const n = A.ssr( i.color, i.depth, i.normal, { stochastic: true, metalnessNode: i.mr.r, roughnessNode: i.mr.g, environmentNode: hdr(), envImportanceSampling: true, binaryRefine: true, camera: persp() } );
		n.screenEdgeFadeBlack = true;
		return n;

	}, { internals: ssrInternals, glsl: true } );
	flow( 'ssr_ssr_stochastic_env_ortho', () => {

		const i = inputs();
		const n = A.ssr( i.color, i.depth, i.normal, { stochastic: true, metalnessNode: i.mr.r, roughnessNode: i.mr.g, camera: ortho() } );
		n.setEnvMap( hdr() );
		return n;

	}, { internals: ssrInternals } );
	flow( 'ssr_ssr_history', () => {

		const i = inputs();
		const n = A.ssr( i.color, i.depth, i.normal, { metalnessNode: i.mr.r, roughnessNode: i.mr.g, camera: persp() } );
		n.setHistory( tex( 'history' ), T.texture( tex( 'velocity' ) ) );
		return n;

	}, { internals: ssrInternals } );
	flow( 'ssr_ssr_history_denoise', () => {

		const i = inputs();
		const cam = persp();
		const n = A.ssr( i.color, i.depth, i.normal, { stochastic: true, metalnessNode: i.mr.r, roughnessNode: i.mr.g, camera: cam } );
		const d = A.recurrentDenoise( n, cam, { depth: i.depth, normal: i.normal, raw: n, mode: 'specular', metalRoughness: i.mr } );
		n.setHistory( d, T.texture( tex( 'velocity' ) ) );
		return n;

	}, { internals: ssrInternals } );
	flow( 'ssr_ssr_env_cleared', () => {

		const i = inputs();
		const n = A.ssr( i.color, i.depth, i.normal, { stochastic: true, metalnessNode: i.mr.r, roughnessNode: i.mr.g, environmentNode: hdr(), camera: persp() } );
		n.setEnvMap( null );
		return n;

	}, { internals: ssrInternals } );
	const rdInternals = ( n ) => [ [ 'denoise', n._material ] ];

	flow( 'ssr_rd_diffuse', () => {

		const i = inputs();
		return A.recurrentDenoise( T.texture( tex( 'in' ) ), persp(), { depth: i.depth, normal: i.normal, raw: T.texture( tex( 'raw' ) ) } );

	}, { internals: rdInternals, glsl: true } );
	flow( 'ssr_rd_specular', () => {

		const i = inputs();
		const n = A.recurrentDenoise( T.texture( tex( 'in' ) ), persp(), { depth: i.depth, normal: i.normal, raw: tex( 'raw' ), metalRoughness: i.mr, diffuse: T.texture( tex( 'diffuse' ) ), mode: 'specular' } );
		n.radius.value = 3;
		return n;

	}, { internals: rdInternals, glsl: true } );
	flow( 'ssr_rd_ao', () => {

		const i = inputs();
		const n = A.recurrentDenoise( tex( 'in' ), persp(), { depth: i.depth, normal: i.normal, raw: T.texture( tex( 'raw' ) ) } );
		n.alphaSource = 'ao';
		return n;

	}, { internals: rdInternals } );
	flow( 'ssr_rd_none_spatial', () => {

		const i = inputs();
		const n = A.recurrentDenoise( T.texture( tex( 'in' ) ), persp(), { depth: i.depth, raw: T.texture( tex( 'raw' ) ), accumulate: false, mode: 'specular' } );
		n.alphaSource = 'none';
		return n;

	}, { internals: rdInternals } );
	flow( 'ssr_rd_none_ortho', () => {

		const i = inputs();
		const n = A.recurrentDenoise( T.texture( tex( 'in' ) ), ortho(), { normal: i.normal, raw: T.texture( tex( 'raw' ) ), metalRoughness: i.mr } );
		n.alphaSource = 'none';
		return n;

	}, { internals: rdInternals } );
	flow( 'ssr_rd_raw_node', () => {

		const i = inputs();
		return A.recurrentDenoise( T.vec4( T.uv(), 0, 1 ), persp(), { depth: i.depth, normal: i.normal, raw: T.texture( tex( 'raw' ) ).mul( 2 ) } );

	}, { internals: ( n ) => [ [ 'denoise', n._material ], [ 'rtt', n.textureNode._quadMesh.material ], [ 'rtt_raw', n.rawNode._quadMesh.material ] ] } );
	flow( 'ssr_rd_of_ssr', () => {

		const i = inputs();
		const cam = persp();
		const s = A.ssr( i.color, i.depth, i.normal, { stochastic: true, metalnessNode: i.mr.r, roughnessNode: i.mr.g, camera: cam } );
		return A.recurrentDenoise( s, cam, { depth: i.depth, normal: i.normal, raw: s, mode: 'specular', metalRoughness: i.mr } );

	}, { internals: ( n ) => [ [ 'denoise', n._material ] ] } );

}
