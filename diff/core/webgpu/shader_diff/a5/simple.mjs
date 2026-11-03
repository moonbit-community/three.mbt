// Group `simple` (src/addons/tsl/a5_simple_shader_diff_test.mbt): FilmNode, Sepia,
// MotionBlur, Lut3DNode, ChromaticAberrationNode, TransitionNode, hashBlur,
// ParallaxBarrierPassNode, AfterImageNode, BilateralBlurNode, LensflareNode, DenoiseNode,
// boxBlur and Shape.
export const modules = [
	'tsl/display/FilmNode.js', 'tsl/display/Sepia.js', 'tsl/display/MotionBlur.js', 'tsl/display/Lut3DNode.js',
	'tsl/display/ChromaticAberrationNode.js', 'tsl/display/TransitionNode.js', 'tsl/display/hashBlur.js',
	'tsl/display/ParallaxBarrierPassNode.js', 'tsl/display/AfterImageNode.js', 'tsl/display/BilateralBlurNode.js',
	'tsl/display/LensflareNode.js', 'tsl/display/DenoiseNode.js', 'tsl/display/boxBlur.js', 'tsl/display/Shape.js',
];

export function scenarios( { T, THREE, A, flow, tex, depthTex } ) {

	const t = ( name ) => T.texture( tex( name ) );
	const v4 = ( name ) => T.vec4( 0.1, 0.2, 0.3, 0.4 ).toVar( name );

	// FilmNode (nodeProxy)
	flow( 'film', () => A.film( t( 'film' ) ), { glsl: true } );
	flow( 'film_intensity_uv', () => A.film( t( 'film' ), T.uniform( 0.5 ), T.uv().mul( 2 ) ), { glsl: true } );
	flow( 'film_number', () => A.film( v4( 'c' ), 0.25 ) );
	flow( 'film_uv_only', () => A.film( t( 'film' ), undefined, T.uv( 1 ) ) );

	// Sepia
	flow( 'sepia', () => A.sepia( t( 'sepia' ) ), { glsl: true } );
	flow( 'sepia_var', () => A.sepia( v4( 'c' ) ).add( A.sepia( v4( 'd' ) ) ) );

	// MotionBlur
	flow( 'motion_blur', () => A.motionBlur( t( 'beauty' ), t( 'velocity' ).xy ), { glsl: true } );
	flow( 'motion_blur_samples', () => A.motionBlur( t( 'beauty' ), t( 'velocity' ).xy.mul( 0.5 ), T.int( 8 ) ) );
	flow( 'motion_blur_number', () => A.motionBlur( t( 'beauty' ), T.uniform( new THREE.Vector2( 0.01, 0 ) ), 4 ) );

	// Lut3DNode
	flow( 'lut3d', () => A.lut3D( t( 'in' ), T.texture3D( new THREE.Data3DTexture() ), 32, T.uniform( 1 ) ), { glsl: true } );
	flow( 'lut3d_numbers', () => A.lut3D( v4( 'c' ), T.texture3D( new THREE.Data3DTexture() ), 16, 0.5 ) );

	// ChromaticAberrationNode
	flow( 'chromatic_aberration', () => A.chromaticAberration( t( 'ca' ), T.uniform( 1.5 ), T.uniform( new THREE.Vector2( 0.5, 0.5 ) ), T.uniform( 1.2 ) ), { glsl: true } );
	flow( 'chromatic_aberration_defaults', () => A.chromaticAberration( T.texture( tex( 'ca' ), T.uv().mul( 0.5 ) ), undefined, T.vec2( 0.5, 0.25 ) ) );
	flow( 'chromatic_aberration_rtt', () => A.chromaticAberration( t( 'ca' ).mul( 0.5 ), 2, T.vec2( 0.5 ), 1.5 ) );

	// TransitionNode
	flow( 'transition', () => A.transition( t( 'a' ), t( 'b' ), t( 'mix' ), T.uniform( 0.5 ), T.uniform( 0.1 ), T.uniform( 1, 'int' ) ), { glsl: true } );
	flow( 'transition_numbers', () => A.transition( t( 'a' ), T.texture( tex( 'b' ), T.uv().mul( 2 ) ), t( 'mix' ), 0.3, 0.2, 0 ) );

	// hashBlur
	flow( 'hash_blur', () => A.hashBlur( t( 'h' ) ), { glsl: true } );
	flow( 'hash_blur_options', () => A.hashBlur( t( 'h' ), T.uniform( 0.05 ), { repeats: T.uniform( 10 ), premultipliedAlpha: true } ), { glsl: true } );
	flow( 'hash_blur_numbers', () => A.hashBlur( T.texture( tex( 'h' ), T.uv().mul( 2 ) ), 0.2, { repeats: 8 } ) );
	flow( 'hash_blur_premult_false', () => A.hashBlur( t( 'h' ), 0.1, { premultipliedAlpha: false } ) );
	flow( 'hash_blur_rtt', () => A.hashBlur( t( 'h' ).mul( 0.5 ) ) );

	// ParallaxBarrierPassNode: its composite material
	let parallaxRef = null;
	const parallaxMaterial = ( n ) => [ [ 'parallax', ( parallaxRef || n )._material ] ];
	flow( 'pass_parallax_barrier', () => {

		parallaxRef = null;
		return A.parallaxBarrierPass( new THREE.Scene(), new THREE.PerspectiveCamera() );

	}, { glsl: true, internals: parallaxMaterial } );
	flow( 'pass_parallax_barrier_mul', () => {

		const p = A.parallaxBarrierPass( new THREE.Scene(), new THREE.PerspectiveCamera() );
		parallaxRef = p;
		return p.mul( 2 );

	}, { internals: parallaxMaterial } );

	// AfterImageNode: the composite material
	const afterImageMaterial = ( n ) => [ [ 'composed', n._materialComposed ] ];
	flow( 'after_image', () => A.afterImage( t( 'ai' ) ), { glsl: true, internals: afterImageMaterial } );
	flow( 'after_image_damp', () => A.afterImage( T.texture( tex( 'ai' ), T.uv().mul( 0.5 ) ), T.uniform( 0.9 ) ), { glsl: true, internals: afterImageMaterial } );
	flow( 'after_image_number', () => A.afterImage( t( 'ai' ), 0.8 ), { internals: afterImageMaterial } );
	flow( 'after_image_rtt', () => A.afterImage( t( 'ai' ).mul( 0.5 ) ), { internals: afterImageMaterial } );

	// BilateralBlurNode: the blur material
	const bilateralMaterial = ( n ) => [ [ 'blur', n._material ] ];
	flow( 'bilateral_blur', () => A.bilateralBlur( t( 'bb' ) ), { glsl: true, internals: bilateralMaterial } );
	flow( 'bilateral_blur_options', () => A.bilateralBlur( T.texture( tex( 'bb' ), T.uv().mul( 2 ) ), T.vec2( 1, 0 ), 2, 0.2 ), { glsl: true, internals: bilateralMaterial } );
	flow( 'bilateral_blur_number', () => A.bilateralBlur( t( 'bb' ), 2, 1.5 ), { internals: bilateralMaterial } );
	flow( 'bilateral_blur_vector', () => A.bilateralBlur( t( 'bb' ), new THREE.Vector2( 0.5, 2 ), 1, 0.05 ), { internals: bilateralMaterial } );

	// LensflareNode: its material
	const lensflareMaterial = ( n ) => [ [ 'lensflare', n._material ] ];
	flow( 'lensflare', () => A.lensflare( t( 'lf' ) ), { glsl: true, internals: lensflareMaterial } );
	flow( 'lensflare_params', () => A.lensflare( t( 'lf' ), {
		ghostTint: T.uniform( new THREE.Color( 1, 0.5, 0.2 ) ), threshold: T.uniform( 0.7 ), ghostSamples: 6,
		ghostSpacing: 0.3, ghostAttenuationFactor: T.uniform( 20 ), downSampleRatio: 2
	} ), { glsl: true, internals: lensflareMaterial } );
	flow( 'lensflare_some', () => A.lensflare( t( 'lf' ).mul( 0.5 ), { ghostTint: T.vec3( 1, 0.8, 0.6 ), ghostSamples: T.uniform( 3 ) } ), { internals: lensflareMaterial } );

	// DenoiseNode
	flow( 'denoise', () => A.denoise( t( 'ao' ), T.texture( depthTex( 'depth' ) ), t( 'normal' ), new THREE.PerspectiveCamera() ), { glsl: true } );
	flow( 'denoise_from_depth', () => A.denoise( t( 'ao' ), T.texture( depthTex( 'depth' ) ), null, new THREE.PerspectiveCamera() ), { glsl: true } );
	flow( 'denoise_uniforms', () => {

		const d = A.denoise( t( 'ao' ).mul( 0.5 ), T.texture( depthTex( 'depth' ) ), t( 'normal' ), new THREE.OrthographicCamera() );
		d.index.value = 2;
		return d;

	} );

	// boxBlur
	flow( 'box_blur', () => A.boxBlur( t( 'box' ) ), { glsl: true } );
	flow( 'box_blur_options', () => A.boxBlur( t( 'box' ), { size: 2, separation: 3, premultipliedAlpha: true } ), { glsl: true } );
	flow( 'box_blur_nodes', () => A.boxBlur( T.texture( tex( 'box' ), T.uv().mul( 2 ) ), { size: T.int( 1 ), separation: T.uniform( 1.5 ), premultipliedAlpha: false } ) );
	flow( 'box_blur_rtt', () => A.boxBlur( t( 'box' ).mul( 0.5 ), { size: 1 } ) );

	// Shape
	flow( 'circle', () => A.circle(), { glsl: true } );
	flow( 'circle_args', () => A.circle( T.uniform( 0.8 ), 0.2, T.uv().mul( 2 ) ), { glsl: true } );
	flow( 'circle_scale', () => A.circle( 0.5 ) );

}
