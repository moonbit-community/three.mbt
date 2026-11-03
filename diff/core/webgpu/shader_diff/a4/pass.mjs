// Group `pass` (src/addons/tsl/a4_pass_shader_diff_test.mbt): the PassNode subclasses
// (PixelationPassNode, RetroPassNode, SSAAPassNode, StereoPassNode, AnaglyphPassNode).
export const modules = [
	'tsl/display/PixelationPassNode.js',
	'tsl/display/RetroPassNode.js',
	'tsl/display/SSAAPassNode.js',
	'tsl/display/StereoPassNode.js',
	'tsl/display/AnaglyphPassNode.js',
];

export function scenarios( { T, THREE, A, flow } ) {

	const scene = () => new THREE.Scene();
	const camera = () => new THREE.PerspectiveCamera();

	// PixelationPassNode: its own setup (not PassNode's), sampling output / depth / normal
	flow( 'pass_pixelation', () => A.pixelationPass( scene(), camera() ), { glsl: true } );
	flow( 'pass_pixelation_options', () => A.pixelationPass( scene(), camera(), 4, 0.5, T.uniform( 0.2 ) ) );
	flow( 'pass_pixelation_no_edges', () => A.pixelationPass( scene(), camera(), 8, 0, 0 ) );
	flow( 'pass_pixelation_uses', () => {

		const p = A.pixelationPass( scene(), camera(), 6 );
		return p.mul( 0.5 ).add( p.getTextureNode( 'normal' ) );

	} );

	// SSAAPassNode: the accumulation material (the MRT ones need the pass's render target
	// in the builder, so only the mock-GPU scenarios build them)
	const ssaaMaterial = ( n ) => [ [ 'ssaa', n._quadMesh.material ] ];
	flow( 'pass_ssaa', () => A.ssaaPass( scene(), camera() ), { glsl: true, internals: ssaaMaterial } );
	flow( 'pass_ssaa_options', () => {

		const p = A.ssaaPass( scene(), camera() );
		p.sampleLevel = 2;
		p.unbiased = false;
		return p;

	}, { internals: ssaaMaterial } );
	flow( 'pass_ssaa_mrt', () => {

		const p = A.ssaaPass( scene(), camera() );
		p.setMRT( T.mrt( { output: T.output, normal: T.normalView } ) );
		return p.add( p.getTextureNode( 'normal' ) );

	}, { glsl: true } );
	flow( 'pass_ssaa_mrt_missing', () => {

		const p = A.ssaaPass( scene(), camera() );
		p.setMRT( T.mrt( { output: T.output, emissive: T.vec4( 1 ) } ) );
		return p;

	} );

	// StereoPassNode: PassNode's setup
	flow( 'pass_stereo', () => A.stereoPass( scene(), camera() ), { glsl: true } );
	flow( 'pass_stereo_depth', () => A.stereoPass( scene(), camera() ).getViewZNode() );

	// AnaglyphPassNode: the composite material (algorithms only change uniform values)
	let anaglyphRef = null;
	const anaglyphMaterial = ( n ) => [ [ 'anaglyph', ( anaglyphRef || n )._material ] ];
	flow( 'pass_anaglyph', () => {

		anaglyphRef = null;
		return A.anaglyphPass( scene(), camera() );

	}, { glsl: true, internals: anaglyphMaterial } );
	flow( 'pass_anaglyph_options', () => {

		const p = A.anaglyphPass( scene(), camera() );
		anaglyphRef = p;
		p.algorithm = A.AnaglyphAlgorithm.GREY;
		p.colorMode = A.AnaglyphColorMode.MAGENTA_GREEN;
		p.eyeSep = 0.1;
		return p.mul( 2 );

	}, { internals: anaglyphMaterial } );

	// RetroPassNode: PassNode's setup (its materials are made while rendering)
	flow( 'pass_retro', () => A.retroPass( scene(), camera() ), { glsl: true } );
	flow( 'pass_retro_options', () => A.retroPass( scene(), camera(), { affineDistortion: T.uniform( 0.5 ), filterTextures: true } ) );

}
