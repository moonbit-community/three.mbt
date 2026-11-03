// Group `basic` (src/addons/tsl/a4_shader_diff_test.mbt): the add-ons without internal passes.
export const modules = [
	'tsl/display/RGBShiftNode.js', 'tsl/display/DotScreenNode.js', 'tsl/display/SobelOperatorNode.js', 'tsl/display/FXAANode.js',
	'tsl/display/BleachBypass.js', 'tsl/display/CRT.js', 'tsl/display/lensDirt.js', 'tsl/display/radialBlur.js',
	'tsl/display/depthAwareBlur.js', 'tsl/display/depthAwareBlend.js'
];

export function scenarios( { T, THREE, A, flow, tex, depthTex } ) {

	const color = () => T.texture( tex( 'color' ) );
	// RGBShiftNode
	flow( 'rgb_shift', () => A.rgbShift( color() ) );
	flow( 'rgb_shift_options', () => A.rgbShift( T.texture( tex( 'color' ), T.uv().mul( 2 ) ), 0.01, T.uniform( 0.5 ) ), { glsl: true } );
	flow( 'rgb_shift_rtt', () => A.rgbShift( T.vec4( T.uv(), 0, 1 ) ), { internals: ( n ) => [ [ 'rtt', n.textureNode._quadMesh.material ] ] } );
	// DotScreenNode
	flow( 'dot_screen', () => A.dotScreen( color() ) );
	flow( 'dot_screen_options', () => A.dotScreen( color().mul( 0.5 ), T.uniform( 0.3 ), 2 ), { glsl: true } );
	// SobelOperatorNode
	flow( 'sobel', () => A.sobel( color() ), { glsl: true } );
	flow( 'sobel_rtt', () => A.sobel( color().mul( T.uniform( 2 ) ) ), { internals: ( n ) => [ [ 'rtt', n.textureNode._quadMesh.material ] ] } );
	// FXAANode
	flow( 'fxaa', () => A.fxaa( color() ), { glsl: true } );
	flow( 'fxaa_uv', () => A.fxaa( T.texture( tex( 'color' ), T.screenUV ) ) );
	// BleachBypass
	flow( 'bleach', () => A.bleach( color() ) );
	flow( 'bleach_opacity', () => A.bleach( color(), T.uniform( 0.5 ) ), { glsl: true } );
	// CRT
	flow( 'crt_barrel_uv', () => A.barrelUV() );
	flow( 'crt_barrel_uv_args', () => A.barrelUV( T.uniform( 0.2 ), T.uv().mul( 2 ) ) );
	flow( 'crt_barrel_mask', () => A.barrelMask( A.barrelUV() ) );
	flow( 'crt_color_bleeding', () => A.colorBleeding( color() ) );
	flow( 'crt_color_bleeding_rtt', () => A.colorBleeding( T.vec4( T.uv(), 0, 1 ), 0.01 ) );
	flow( 'crt_scanlines', () => A.scanlines( color().rgb ) );
	flow( 'crt_scanlines_args', () => A.scanlines( color().rgb, 0.5, T.uniform( 120 ), 2, T.screenUV ), { glsl: true } );
	flow( 'crt_vignette', () => A.vignette( color().rgb ) );
	flow( 'crt_vignette_args', () => A.vignette( color().rgb, T.uniform( 0.6 ), 0.25, T.screenUV ), { glsl: true } );
	flow( 'crt_chain', () => {

		const distorted = A.barrelUV( 0.15 );
		const c = T.texture( tex( 'color' ), distorted );
		const bled = A.colorBleeding( c );
		const lines = A.scanlines( bled, 0.3, 240, 0, distorted );
		return A.vignette( lines, 0.4, 0.5, distorted ).mul( A.barrelMask( distorted ) );

	} );
	// lensDirt
	flow( 'lens_dirt', () => A.lensDirt( color(), T.texture( tex( 'dirt' ) ) ) );
	flow( 'lens_dirt_intensity', () => A.lensDirt( T.texture( tex( 'color' ), T.screenUV ), T.texture( tex( 'dirt' ) ), T.uniform( 2 ) ), { glsl: true } );
	// radialBlur
	flow( 'radial_blur', () => A.radialBlur( color() ) );
	flow( 'radial_blur_options', () => A.radialBlur( color(), { center: T.uniform( new THREE.Vector2( 0.25, 0.75 ) ), weight: 0.8, decay: T.uniform( 0.9 ), count: 16, exposure: 3, premultipliedAlpha: true } ), { glsl: true } );
	// depthAwareBlur
	const camera = () => new THREE.PerspectiveCamera( 50, 1, 0.5, 50 );
	flow( 'depth_aware_blur', () => A.depthAwareBlur( color(), T.texture( depthTex( 'depth' ) ), T.vec2( 0.01, 0 ), camera() ) );
	flow( 'depth_aware_blur_args', () => A.depthAwareBlur( color(), T.texture( depthTex( 'depth' ) ), T.uniform( new THREE.Vector2( 0, 0.02 ) ), camera(), 4, T.uniform( 2 ) ), { glsl: true } );
	flow( 'depth_aware_blur_log_depth', () => A.depthAwareBlur( color(), T.texture( depthTex( 'depth' ) ), T.vec2( 0.01, 0 ), camera() ), { logDepth: true } );
	// depthAwareBlend
	flow( 'depth_aware_blend', () => A.depthAwareBlend( color(), T.texture( tex( 'blend' ) ), T.texture( depthTex( 'depth' ) ), camera() ) );
	flow( 'depth_aware_blend_options', () => A.depthAwareBlend( T.texture( tex( 'color' ), T.screenUV ), T.texture( tex( 'blend' ) ), T.texture( depthTex( 'depth' ) ), camera(), { blendColor: T.uniform( new THREE.Color( 1, 0, 0 ) ), edgeRadius: 3, edgeStrength: T.uniform( 1.5 ) } ), { glsl: true } );

}
