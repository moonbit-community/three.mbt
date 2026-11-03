// Group `passes` (src/addons/tsl/a5_passes_shader_diff_test.mbt): the pass-based display
// nodes BloomNode, SMAANode, SSAONode, FSR1Node and OutlineNode, with their internal
// materials.
export const modules = [
	'tsl/display/BloomNode.js',
	'tsl/display/SMAANode.js',
	'tsl/display/SSAONode.js',
	'tsl/display/FSR1Node.js',
	'tsl/display/OutlineNode.js',
];

// SMAANode creates `new Image()`s: an unloaded HTMLImageElement stub (the MoonBit test
// installs the same)
if ( typeof globalThis.Image === 'undefined' ) {

	globalThis.Image = class Image { constructor() { this.src = ''; this.onload = null; this.width = 0; this.height = 0; } };

}

export function scenarios( { T, THREE, A, flow, custom, tex, depthTex, geometry, WGSLNodeBuilder, GLSLNodeBuilder } ) {

	const sceneTex = () => T.texture( tex( 'scene' ) );
	const bloomInternals = ( n ) => [
		[ 'highPass', n._highPassFilterMaterial ],
		// as updateBefore's horizontal pass sets them
		...n._separableBlurMaterials.map( ( m, i ) => {

			m.colorTexture.value = i === 0 ? n._renderTargetBright.texture : n._renderTargetsVertical[ i - 1 ].texture;
			return [ 'blur' + i, m ];

		} ),
		[ 'composite', n._compositeMaterial ],
	];

	flow( 'bloom_default', () => A.bloom( sceneTex() ), { glsl: true, internals: bloomInternals } );
	flow( 'bloom_numbers', () => A.bloom( sceneTex(), 2.5, 0.4, 0.2 ), { internals: bloomInternals } );
	flow( 'bloom_nodes', () => A.bloom( sceneTex(), T.uniform( 1.5 ), T.float( 0.3 ), T.uniform( 0.1 ) ), { glsl: true, internals: bloomInternals } );
	flow( 'bloom_high_pass_fn', () => {

		const n = A.bloom( sceneTex(), 1, 0, 0.5 );
		n.highPassFn = T.Fn( ( { input, threshold } ) => input.mul( threshold ) );
		n.smoothWidth = T.float( 0.2 );
		return n;

	}, { internals: bloomInternals } );

	const smaaInternals = ( n ) => [ [ 'edges', n._materialEdges ], [ 'weights', n._materialWeights ], [ 'blend', n._materialBlend ] ];
	flow( 'smaa_default', () => A.smaa( sceneTex() ), { glsl: true, internals: smaaInternals } );
	flow( 'smaa_uv', () => A.smaa( T.texture( tex( 'scene' ), T.uv().mul( 0.5 ) ) ), { internals: smaaInternals } );
	flow( 'smaa_rtt', () => A.smaa( T.vec4( 0.2, 0.4, 0.6, 1.0 ) ), { internals: smaaInternals } );

	const ssaoInternals = ( n ) => [ [ 'ao', n._aoMaterial ], [ 'blur', n._blurMaterial ] ];
	const ssao = () => A.ssao( T.texture( depthTex( 'depth' ) ), T.texture( tex( 'normal' ) ), new THREE.PerspectiveCamera() );
	flow( 'ssao_default', () => ssao(), { glsl: true, internals: ssaoInternals } );
	flow( 'ssao_fields', () => {

		const n = ssao();
		n.radius = T.float( 0.25 );
		n.samples = T.uniform( 8 );
		n.blurSharpness = T.float( 4 );
		n.intensity = T.float( 1.5 );
		n.blurEnabled = false;
		return n;

	}, { glsl: true, internals: ssaoInternals } );

	const fsr1Internals = ( n ) => [ [ 'easu', n._easuMaterial ], [ 'rcas', n._rcasMaterial ] ];
	flow( 'fsr1_default', () => A.fsr1( sceneTex() ), { glsl: true, internals: fsr1Internals } );
	flow( 'fsr1_denoise', () => A.fsr1( sceneTex(), 1.0, true ), { glsl: true, internals: fsr1Internals } );
	flow( 'fsr1_uniform', () => A.fsr1( sceneTex(), T.uniform( 0.5 ) ), { internals: fsr1Internals } );

	const outlineInternals = ( n ) => [
		[ 'depth', n._depthMaterial ],
		[ 'depthSprite', n._depthSpriteMaterial ],
		[ 'prepareMask', n._prepareMaskMaterial ],
		[ 'prepareMaskSprite', n._prepareMaskSpriteMaterial ],
		[ 'copy', n._materialCopy ],
		[ 'edgeDetection', n._edgeDetectionMaterial ],
		[ 'separableBlur', n._separableBlurMaterial ],
		[ 'separableBlur2', n._separableBlurMaterial2 ],
		[ 'composite', n._compositeMaterial ],
	];
	flow( 'outline_default', () => A.outline( new THREE.Scene(), new THREE.PerspectiveCamera() ), { glsl: true, internals: outlineInternals } );
	flow( 'outline_params', () => {

		const scene = new THREE.Scene();
		const mesh = new THREE.Mesh( geometry(), new THREE.MeshBasicMaterial() );
		scene.add( mesh );
		return A.outline( scene, new THREE.OrthographicCamera(), { selectedObjects: [ mesh ], edgeThickness: T.uniform( 2 ), edgeGlow: T.uniform( 1 ), downSampleRatio: 4 } );

	}, { glsl: true, internals: outlineInternals } );
	flow( 'outline_numbers', () => A.outline( new THREE.Scene(), new THREE.PerspectiveCamera(), { edgeThickness: 3, edgeGlow: 0.5 } ), { internals: outlineInternals } );
	// `setSize( 301, 157 )` of each node (after its setup): render target sizes and the
	// size uniforms
	custom( 'set_sizes', ( renderer, isGLSL ) => {

		const mesh = new THREE.Mesh( geometry(), new THREE.MeshBasicMaterial() );
		const setup = ( node ) => {

			const Builder = isGLSL ? GLSLNodeBuilder : WGSLNodeBuilder;
			const b = new Builder( mesh, renderer );
			b.camera = new THREE.PerspectiveCamera();
			b.setShaderStage( 'fragment' );
			b.flowStagesNode( node );
			node.setSize( 301, 157 );

		};

		const rt = ( r ) => `${r.width}x${r.height}`;
		const v2 = ( n ) => String( n.value.x ) + ',' + String( n.value.y );
		const out = [];
		const b = A.bloom( sceneTex() );
		setup( b );
		out.push( 'bloom ' + rt( b._renderTargetBright ) );
		for ( let i = 0; i < 5; i ++ ) out.push( `  ${i} ` + rt( b._renderTargetsHorizontal[ i ] ) + ' ' + rt( b._renderTargetsVertical[ i ] ) + ' ' + v2( b._separableBlurMaterials[ i ].invSize ) );
		const b2 = A.bloom( sceneTex() );
		b2.setResolutionScale( 0.3 );
		out.push( 'bloom scale ' + String( b2.getResolutionScale() ) );
		const smaa = A.smaa( sceneTex() );
		setup( smaa );
		out.push( 'smaa ' + rt( smaa._renderTargetEdges ) + ' ' + rt( smaa._renderTargetWeights ) + ' ' + rt( smaa._renderTargetBlend ) + ' ' + v2( smaa._invSize ) );
		const s = ssao();
		setup( s );
		out.push( 'ssao ' + rt( s._aoRenderTarget ) + ' ' + rt( s._blurRenderTarget ) + ' ' + String( s.resolution.x ) + ',' + String( s.resolution.y ) );
		const f = A.fsr1( sceneTex() );
		setup( f );
		out.push( 'fsr1 ' + rt( f._easuRT ) + ' ' + rt( f._rcasRT ) );
		for ( const ratio of [ 2, 3 ] ) {

			const o = A.outline( new THREE.Scene(), new THREE.PerspectiveCamera(), { downSampleRatio: ratio } );
			setup( o );
			out.push( 'outline ' + [ o._renderTargetDepthBuffer, o._renderTargetMaskBuffer, o._renderTargetComposite, o._renderTargetMaskDownSampleBuffer, o._renderTargetEdgeBuffer1, o._renderTargetBlurBuffer1, o._renderTargetEdgeBuffer2, o._renderTargetBlurBuffer2 ].map( rt ).join( ' ' ) );

		}

		return out.join( '\n' );

	}, { glsl: true } );
	flow( 'outline_edges', () => {

		const o = A.outline( new THREE.Scene(), new THREE.PerspectiveCamera() );
		return o.visibleEdge.add( o.hiddenEdge );

	} );

}
