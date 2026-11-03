// Group `temporal` (src/addons/tsl/a5_temporal_shader_diff_test.mbt): tsl/display TRAANode,
// TAAUNode, TemporalReprojectNode, OITPassNode.
export const modules = [
	'tsl/display/TRAANode.js', 'tsl/display/TAAUNode.js', 'tsl/display/TemporalReprojectNode.js', 'tsl/display/OITPassNode.js',
];

export function scenarios( { T, THREE, N, A, flow, custom, tex, depthTex, geometry, buildMaterial, WGSLNodeBuilder, GLSLNodeBuilder } ) {

	const beauty = () => T.texture( tex( 'beauty' ) );
	const depth = () => T.texture( depthTex( 'depth' ) );
	const vel = () => T.texture( tex( 'velocity' ) );
	const normal = () => T.texture( tex( 'normal' ) );
	const persp = () => new THREE.PerspectiveCamera( 50, 2, 0.1, 100 );
	const ortho = () => new THREE.OrthographicCamera( - 2, 2, 1, - 1, 0.1, 100 );
	const nums = ( a ) => Array.from( a ).map( String ).join( ',' );

	// a flow build of `node` in a fresh builder (as `flow` does); returns the code
	const flowCode = ( node, renderer, isGLSL ) => {

		const Builder = isGLSL ? GLSLNodeBuilder : WGSLNodeBuilder;
		const b = new Builder( new THREE.Mesh( geometry(), new THREE.MeshBasicMaterial() ), renderer );
		b.camera = new THREE.PerspectiveCamera();
		b.setShaderStage( 'fragment' );
		return b.flowStagesNode( node ).code;

	};

	// the context a RenderPipeline gives its output node
	const pipelineContext = ( node ) => {

		const ctx = { renderPipeline: {}, renderPipelineState: { viewOffsetOwner: null }, onBeforePipelineCallbacks: [], onAfterPipelineCallbacks: [] };
		return { ctx, node: T.context( T.Fn( () => node )(), ctx ) };

	};

	const traaInternals = ( n ) => [ [ 'resolve', n._resolveMaterial ] ];
	const taauInternals = ( n ) => [ [ 'resolve', n._resolveMaterial ], [ 'seed', n._seedMaterial ] ];
	const trInternals = ( n ) => [ [ 'resolve', n._resolveMaterial ], [ 'seed', n._seedMaterial ] ];

	// TRAANode
	flow( 'traa', () => A.traa( beauty(), depth(), vel(), persp() ), { glsl: true, internals: traaInternals } );
	flow( 'traa_ortho_options', () => {

		const n = A.traa( beauty(), depth(), vel(), ortho() );
		n.useSubpixelCorrection = false;
		n.depthThreshold = 0.002;
		n.edgeDepthDiff = 0.01;
		n.maxVelocityLength = 64;
		return n;

	}, { glsl: true, internals: traaInternals } );
	flow( 'traa_pass', () => {

		const p = T.pass( new THREE.Scene(), persp() );
		return A.traa( p, p.getTextureNode( 'depth' ), p.getTextureNode( 'velocity' ), persp() );

	}, { internals: traaInternals } );
	flow( 'traa_rtt', () => A.traa( T.vec4( T.uv(), 0, 1 ), depth(), vel(), persp() ), { internals: traaInternals } );
	flow( 'traa_class', () => new A.TRAANode( beauty(), depth(), vel(), persp() ), { internals: traaInternals } );
	custom( 'traa_jitter', ( renderer, isGLSL ) => {

		const camera = persp();
		const v = new N.VelocityNode();
		const n = A.traa( beauty(), depth(), vel(), camera );
		const { ctx, node } = pipelineContext( T.context( n, { velocity: v } ) );
		const code = flowCode( node, renderer, isGLSL );
		const out = [ code, 'owner ' + ( ctx.renderPipelineState.viewOffsetOwner === n ), 'callbacks ' + ctx.onBeforePipelineCallbacks.length + ' ' + ctx.onAfterPipelineCallbacks.length ];
		for ( let i = 0; i < 3; i ++ ) {

			for ( const f of ctx.onBeforePipelineCallbacks ) f();
			out.push( 'jitter ' + nums( camera.projectionMatrix.elements ) );
			out.push( 'velocity ' + nums( v.projectionMatrix.elements ) + ' ' + ( T.velocity.projectionMatrix === null || T.velocity.projectionMatrix === undefined ) );
			for ( const f of ctx.onAfterPipelineCallbacks ) f();
			out.push( 'cleared ' + nums( camera.projectionMatrix.elements ) + ' ' + v.projectionMatrix + ' ' + n._jitterIndex );

		}

		// a second TRAA in the same pipeline does not take the view offset
		const n2 = A.traa( beauty(), depth(), vel(), camera );
		flowCode( T.context( n2, ctx ), renderer, isGLSL );
		out.push( 'second ' + ( ctx.renderPipelineState.viewOffsetOwner === n ) + ' ' + ctx.onBeforePipelineCallbacks.length );
		// setSize and the halton offsets directly
		n.setSize( 64, 32 );
		out.push( 'size ' + n._historyRenderTarget.width + ' ' + n._resolveRenderTarget.height + ' ' + nums( n._invSize.value.toArray() ) + ' ' + n._previousDepthRenderTarget.depthTexture.image.width + ' ' + n._previousDepthRenderTarget.depthTexture.format );
		for ( let i = 0; i < 33; i ++ ) {

			n.setViewOffset( 64, 32 );
			if ( i === 31 || i === 32 ) out.push( 'offset ' + i + ' ' + nums( camera.projectionMatrix.elements ) );
			n.clearViewOffset();

		}

		return out.join( '\n' );

	}, { glsl: true } );

	// TAAUNode
	flow( 'taau', () => A.taau( beauty(), depth(), vel(), persp() ), { glsl: true, internals: taauInternals } );
	flow( 'taau_ortho_options', () => {

		const n = A.taau( beauty(), depth(), vel(), ortho() );
		n.currentFrameWeight = 0.1;
		n.depthThreshold = 0.002;
		n.edgeDepthDiff = 0.01;
		n.maxVelocityLength = 64;
		return n;

	}, { glsl: true, internals: taauInternals } );
	flow( 'taau_pass', () => {

		const p = T.pass( new THREE.Scene(), persp() );
		return A.taau( p, p.getTextureNode( 'depth' ), p.getTextureNode( 'velocity' ), persp() );

	}, { internals: taauInternals } );
	custom( 'taau_jitter', ( renderer, isGLSL ) => {

		const camera = persp();
		const p = T.pass( new THREE.Scene(), camera );
		const n = A.taau( p, depth(), vel(), camera );
		const { ctx, node } = pipelineContext( n );
		const code = flowCode( node, renderer, isGLSL );
		const out = [ code, 'owner ' + ( ctx.renderPipelineState.viewOffsetOwner === n ), 'callbacks ' + ctx.onBeforePipelineCallbacks.length + ' ' + ctx.onAfterPipelineCallbacks.length ];
		p.setSize( 40, 20 );
		for ( let i = 0; i < 3; i ++ ) {

			for ( const f of ctx.onBeforePipelineCallbacks ) f();
			out.push( 'jitter ' + nums( camera.projectionMatrix.elements ) + ' ' + nums( n._jitterOffset.value.toArray() ) );
			out.push( 'velocity ' + nums( T.velocity.projectionMatrix.elements ) );
			for ( const f of ctx.onAfterPipelineCallbacks ) f();
			out.push( 'cleared ' + nums( camera.projectionMatrix.elements ) + ' ' + T.velocity.projectionMatrix + ' ' + n._jitterIndex );

		}

		n.setSize( 80, 40 );
		out.push( 'size ' + n._historyRenderTarget.width + ' ' + n._historyRenderTarget.height + ' ' + n._resolveRenderTarget.width + ' ' + n._previousDepthRenderTarget.depthTexture.format );
		return out.join( '\n' );

	} );

	// TemporalReprojectNode
	flow( 'temporal_reproject', () => A.temporalReproject( beauty(), depth(), normal(), vel(), persp() ), { glsl: true, internals: trInternals } );
	flow( 'temporal_reproject_specular', () => A.temporalReproject( beauty(), depth(), normal(), vel(), persp(), { mode: 'specular' } ), { glsl: true, internals: trInternals } );
	flow( 'temporal_reproject_specular_no_hit', () => A.temporalReproject( beauty(), depth(), normal(), vel(), ortho(), { mode: 'specular', hitPointReprojection: false } ), { internals: trInternals } );
	flow( 'temporal_reproject_accumulate', () => {

		const n = A.temporalReproject( beauty(), depth(), normal(), vel(), persp(), { mode: 'diffuse', hitPointReprojection: true, accumulate: true } );
		n.maxVelocityLength = 64;
		return n;

	}, { internals: trInternals } );
	flow( 'temporal_reproject_external_history', () => {

		const n = new A.TemporalReprojectNode( beauty(), depth(), normal(), vel(), persp() );
		n.setHistoryTexture( tex( 'external' ) );
		return n;

	}, { internals: trInternals } );
	flow( 'temporal_reproject_pass', () => {

		const p = T.pass( new THREE.Scene(), persp() );
		return A.temporalReproject( p, p.getTextureNode( 'depth' ), p.getTextureNode( 'normal' ), p.getTextureNode( 'velocity' ), persp(), { mode: 'specular' } );

	}, { internals: trInternals } );
	custom( 'temporal_reproject_state', ( renderer, isGLSL ) => {

		const camera = persp();
		camera.position.set( 1, 2, 3 );
		camera.updateMatrixWorld();
		const n = A.temporalReproject( beauty(), depth(), normal(), vel(), camera, { accumulate: false } );
		const { ctx, node } = pipelineContext( n );
		const code = flowCode( node, renderer, isGLSL );
		const out = [ code, 'owner ' + ( ctx.renderPipelineState.viewOffsetOwner === n ) + ' ' + n._needsPostProcessingSync, 'callbacks ' + ctx.onBeforePipelineCallbacks.length + ' ' + ctx.onAfterPipelineCallbacks.length ];
		for ( const f of ctx.onBeforePipelineCallbacks ) f();
		out.push( 'velocity ' + nums( T.velocity.projectionMatrix.elements ) );
		for ( const f of ctx.onAfterPipelineCallbacks ) f();
		out.push( 'cleared ' + T.velocity.projectionMatrix );
		camera.position.set( 4, 5, 6 );
		camera.updateMatrixWorld();
		n._cameraUniforms.updateFromCamera( camera );
		const u = n._cameraUniforms;
		out.push( 'uniforms ' + nums( u.worldMatrix.value.elements ) + ' ' + nums( u.previousWorldMatrix.value.elements ) + ' ' + nums( u.worldPosition.value.toArray() ) + ' ' + nums( u.previousViewMatrix.value.elements ) );
		const ext = tex( 'external' );
		n.setHistoryTexture( ext );
		out.push( 'history ' + n._historyTextureNode.value.name );
		n.setHistoryTexture( { getRenderTarget: () => n._resolveRenderTarget } );
		out.push( 'history ' + n._historyTextureNode.value.name );
		n.accumulate = true;
		n.setHistoryTexture( ext );
		out.push( 'history ' + n._historyTextureNode.value.name );
		n.accumulate = false;
		n.setHistoryTexture( null );
		out.push( 'history ' + n._historyTextureNode.value.name );
		n.setSize( 48, 24 );
		out.push( 'size ' + n._historyRenderTarget.width + ' ' + n._resolveRenderTarget.height + ' ' + nums( n._resolution.value.toArray() ) );
		return out.join( '\n' );

	} );

	// OITPassNode
	flow( 'oit', () => A.oitPass( new THREE.Scene(), persp() ), { glsl: true } );
	flow( 'oit_class_options', () => new A.OITPassNode( new THREE.Scene(), persp(), { samples: 4, type: THREE.FloatType } ), { glsl: true } );
	const oitMRT = ( weight ) => ( renderer, isGLSL ) => {

		const n = A.oitPass( new THREE.Scene(), persp() );
		if ( weight ) n.weightNode = T.uniform( 2 ).mul( T.output.a );
		const m = new THREE.MeshBasicNodeMaterial();
		m.transparent = true;
		m.colorNode = T.vec3( 0.2, 0.4, 0.6 );
		m.opacityNode = T.float( 0.5 );
		renderer.setRenderTarget( n._oitRenderTarget );
		renderer.setMRT( n._getMRTNode() );
		let text;
		try {

			text = buildMaterial( m, renderer, isGLSL );

		} finally {

			renderer.setMRT( null );
			renderer.setRenderTarget( null );

		}

		const rt = n._oitRenderTarget;
		const t = rt.textures;
		return text + '\n' + [ rt.depthTexture === n.renderTarget.depthTexture, t.length, t[ 0 ].name, t[ 0 ].type, t[ 1 ].name, t[ 1 ].format, t[ 1 ].type ].join( ' ' );

	};

	custom( 'oit_mrt', oitMRT( false ), { glsl: true } );
	custom( 'oit_mrt_weight', oitMRT( true ) );
	custom( 'oit_size', ( renderer, isGLSL ) => {

		const n = A.oitPass( new THREE.Scene(), persp() );
		n.setResolutionScale( 0.5 );
		n.setSize( 64, 32 );
		const code = flowCode( n, renderer, isGLSL );
		return code + '\n' + [ n.renderTarget.width, n.renderTarget.height, n._oitRenderTarget.width, n._oitRenderTarget.height, n.renderTarget.samples, n._oitRenderTarget.samples ].join( ' ' );

	}, { glsl: true } );

}
