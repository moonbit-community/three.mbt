// Group `blur` (src/addons/tsl/a4_blur_shader_diff_test.mbt): GaussianBlurNode,
// DepthOfFieldNode, SharpenNode, with their internal pass materials.
export const modules = [ 'tsl/display/GaussianBlurNode.js', 'tsl/display/DepthOfFieldNode.js', 'tsl/display/SharpenNode.js' ];

export function scenarios( { T, A, flow, tex } ) {

	const gauss = ( n ) => [ [ 'horizontal', n._hMaterial ], [ 'vertical', n._vMaterial ] ];
	const color = () => T.texture( tex( 'color' ) );

	// GaussianBlurNode
	flow( 'blur_gaussian', () => A.gaussianBlur( color() ), { internals: gauss } );
	flow( 'blur_gaussian_direction_sigma', () => A.gaussianBlur( color(), T.uniform( 2 ), 2 ), { internals: gauss, glsl: true } );
	flow( 'blur_gaussian_vec2_direction', () => A.gaussianBlur( T.texture( tex( 'color' ), T.uv().mul( 0.5 ) ), T.vec2( 1, 0.5 ), 1 ), { internals: gauss } );
	flow( 'blur_gaussian_fractional_sigma', () => A.gaussianBlur( color(), null, 2.5 ), { internals: gauss } );
	flow( 'blur_gaussian_premultiplied', () => A.gaussianBlur( color(), 1.5, 3, { premultipliedAlpha: true, resolutionScale: 0.5 } ), { internals: gauss, glsl: true } );
	flow( 'blur_premultiplied_gaussian_blur', () => A.premultipliedGaussianBlur( color(), 2, 1 ), { internals: gauss } );
	flow( 'blur_gaussian_rtt', () => A.gaussianBlur( T.vec4( T.uv(), 0, 1 ) ), { internals: ( n ) => [ [ 'rtt', n.textureNode._quadMesh.material ], ...gauss( n ) ] } );

	// DepthOfFieldNode
	const dofInternals = ( n ) => [ [ 'coc', n._CoCMaterial ], [ 'coc_blurred', n._CoCBlurredMaterial ], [ 'blur64', n._blur64Material ], [ 'blur16', n._blur16Material ], [ 'composite', n._compositeMaterial ] ];
	flow( 'blur_dof', () => A.dof( color(), T.uniform( - 5 ) ), { internals: dofInternals } );
	flow( 'blur_dof_params', () => A.dof( color(), T.uniform( - 4 ), T.uniform( 2 ), 3, T.uniform( 1.5 ) ), { internals: dofInternals, glsl: true } );
	flow( 'blur_dof_coc_blur', () => A.dof( color(), - 3, 0.5, 2, 0.25 )._CoCBlurNode, { internals: gauss } );
	flow( 'blur_dof_rtt', () => A.dof( T.vec4( T.uv(), 1, 1 ), T.uniform( - 2 ) ), { internals: ( n ) => [ [ 'rtt', n.textureNode._quadMesh.material ], ...dofInternals( n ) ] } );

	// SharpenNode
	flow( 'blur_sharpen', () => A.sharpen( color() ), { internals: ( n ) => [ [ 'rcas', n._material ] ] } );
	flow( 'blur_sharpen_options', () => A.sharpen( color(), T.uniform( 0.5 ), T.uniform( true ) ), { internals: ( n ) => [ [ 'rcas', n._material ] ], glsl: true } );
	flow( 'blur_sharpen_denoise', () => A.sharpen( color(), 1, true ), { internals: ( n ) => [ [ 'rcas', n._material ] ] } );

}
