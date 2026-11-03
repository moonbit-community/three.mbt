// Upstream side of the G4 (nodes/display, nodes/gpgpu, nodes/parsers) shader scenarios.
// The MoonBit side is src/nodes/g4_shader_diff_test.mbt; scenario names start with `g4_`.
//
// Both sides build with `G4Builder`: a NodeBuilder with a GLSLNodeParser whose
// `buildFunctionCode` is GLSLNodeBuilder's (so layout functions, and their `fn<id>`
// names, show up in the output), plus fixed snippets for the few backend methods the
// nodes call (`getScopedArray`, `getInstanceIndex`, `getFrontFacing`, `getFragCoord`).
// One renderer serves every scenario, as layout functions are cached per backend.
//
// Records add `codes` (every NodeCode of the builder: `stage:name:code`) and `extra`
// (scenario-specific values) to the shared record.

import { record } from './upstream.mjs';

export async function runUpstream( src ) {

	const T = await import( src + '/Three.TSL.js' );
	const THREE = await import( src + '/Three.WebGPU.js' );
	const { default: NodeBuilder } = await import( src + '/nodes/core/NodeBuilder.js' );
	const { default: GLSLNodeParser } = await import( src + '/nodes/parsers/GLSLNodeParser.js' );
	const { default: FunctionNode } = await import( src + '/nodes/code/FunctionNode.js' );
	const { WebGPURenderer, ColorManagement, Matrix3, SRGBTransfer, LinearTransfer, SRGBColorSpace, LinearSRGBColorSpace,
		NoToneMapping, LinearToneMapping, ReinhardToneMapping, CineonToneMapping, ACESFilmicToneMapping, AgXToneMapping, NeutralToneMapping, CustomToneMapping } = THREE;

	const canvas = { style: {}, width: 300, height: 150, addEventListener() {}, removeEventListener() {}, getContext() { return null; } };
	const renderer = new WebGPURenderer( { canvas } );
	renderer._bindings = undefined;

	class G4Builder extends NodeBuilder {

		buildFunctionCode( shaderNode ) {

			const layout = shaderNode.layout;
			const flowData = this.flowShaderNode( shaderNode );
			const parameters = [];
			for ( const input of layout.inputs ) parameters.push( this.getType( input.type ) + ' ' + input.name );
			return `${ this.getType( layout.type ) } ${ layout.name }( ${ parameters.join( ', ' ) } ) {

	${ flowData.vars }

${ flowData.code }
	return ${ flowData.result };

}`;

		}

		getScopedArray( name, scope, bufferType, bufferCount, isAtomic ) {

			return `${ name }/*${ scope } ${ bufferType } ${ bufferCount } ${ isAtomic }*/`;

		}

		hasBuiltin() {

			return false;

		}

		enableSubGroups() {}

		getInstanceIndex() {

			return 'instanceIndex';

		}

		getFrontFacing() {

			return 'gl_FrontFacing';

		}

		getFragCoord() {

			return 'gl_FragCoord';

		}

		getFragDepth() {

			return 'gl_FragDepth';

		}

		isFlipY() {

			return this.flipY === true;

		}

		generateTexture( texture, p, uv, depth, offset ) {

			return `tex(${ p }, ${ uv }, ${ fmt( depth ) }, ${ fmt( offset ) })`;

		}

		generateTextureLevel( texture, p, uv, level, depth, offset ) {

			return `texLevel(${ p }, ${ uv }, ${ level }, ${ fmt( depth ) }, ${ fmt( offset ) })`;

		}

		generateTextureSize( texture, p, level ) {

			return `size(${ p }, ${ level })`;

		}

	}

	const fmt = ( v ) => v === null || v === undefined ? '-' : String( v );

	const geometry = new THREE.BufferGeometry();
	for ( const [ name, itemSize ] of [ [ 'position', 3 ], [ 'normal', 3 ], [ 'uv', 2 ], [ 'tangent', 4 ] ] ) {

		geometry.setAttribute( name, new THREE.BufferAttribute( new Float32Array( 24 * itemSize ), itemSize ) );

	}

	// The callbacks a node material puts in the context (as upstream_g2.mjs).
	const materialContext = ( builder ) => {

		builder.context.setupPositionView = () => T.modelViewMatrix.mul( T.positionLocal ).xyz;
		builder.context.setupNormal = () => T.subBuild( T.normalViewGeometry, 'NORMAL', 'vec3' );

	};

	const tex = () => {

		const t = new THREE.Texture();
		t.name = 'tex';
		return t;

	};

	// Display P3, as examples/jsm/math/ColorSpaces.js defines it.
	const P3_PRIMARIES = [ 0.680, 0.320, 0.265, 0.690, 0.150, 0.060 ];
	const P3_TO_XYZ = new Matrix3().set( 0.4865709, 0.2656677, 0.1982173, 0.2289746, 0.6917385, 0.0792869, 0.0000000, 0.0451134, 1.0439444 );
	const XYZ_TO_P3 = new Matrix3().set( 2.4934969, - 0.9313836, - 0.4027108, - 0.8294890, 1.7626641, 0.0236247, 0.0358458, - 0.0761724, 0.9568845 );
	ColorManagement.define( {
		'display-p3': { primaries: P3_PRIMARIES, whitePoint: [ 0.3127, 0.3290 ], transfer: SRGBTransfer, toXYZ: P3_TO_XYZ, fromXYZ: XYZ_TO_P3, luminanceCoefficients: [ 0.2289, 0.6917, 0.0793 ], outputColorSpaceConfig: { drawingBufferColorSpace: 'display-p3' } },
		'display-p3-linear': { primaries: P3_PRIMARIES, whitePoint: [ 0.3127, 0.3290 ], transfer: LinearTransfer, toXYZ: P3_TO_XYZ, fromXYZ: XYZ_TO_P3, luminanceCoefficients: [ 0.2289, 0.6917, 0.0793 ], workingColorSpaceConfig: { unpackColorSpace: 'display-p3' }, outputColorSpaceConfig: { drawingBufferColorSpace: 'display-p3' } },
	} );

	const {
		float, int, uint, bool, vec2, vec3, vec4, uvec4, Fn,
		sRGBTransferEOTF, sRGBTransferOETF, premultiplyAlpha, unpremultiplyAlpha,
		blendBurn, blendDodge, blendScreen, blendOverlay, blendColor,
		grayscale, saturation, vibrance, hue, luminance, cdl, posterize,
		linearToneMapping, reinhardToneMapping, cineonToneMapping, acesFilmicToneMapping, agxToneMapping, neutralToneMapping,
		colorSpaceToWorking, workingToColorSpace, convertColorSpace,
		numWorkgroups, workgroupId, globalId, localId, subgroupSize,
		atomicAdd, atomicSub, atomicMax, atomicMin, atomicAnd, atomicOr, atomicXor, atomicLoad, atomicStore,
		workgroupArray, workgroupBarrier, storageBarrier, textureBarrier,
		subgroupElect, subgroupBallot, subgroupAdd, subgroupInclusiveMul, subgroupAll, subgroupBroadcast, subgroupShuffleXor, subgroupShuffleUp, quadSwapX, quadBroadcast,
		compute, computeKernel, glslFn, toneMapping, renderOutput,
		frontFacing, faceDirection, negateOnBackSide,
		screenUV, screenSize, screenCoordinate, screenDPR, viewport, viewportSize, viewportCoordinate, viewportUV,
		normalMap, bumpMap, texture,
		depth, linearDepth, viewportLinearDepth, viewZToOrthographicDepth, viewZToReversedOrthographicDepth, orthographicDepthToViewZ,
		viewZToPerspectiveDepth, viewZToReversedPerspectiveDepth, perspectiveDepthToViewZ, viewZToLogarithmicDepth, logarithmicDepthToViewZ,
		viewportTexture, viewportMipTexture, viewportSharedTexture, viewportDepthTexture, viewportOpaqueMipTexture,
	} = T;
	const { BackSide, DoubleSide, ObjectSpaceNormalMap, NormalRGPacking, NormalGAPacking, RenderTarget } = THREE;
	const f1 = ( v, n ) => float( v ).toVar( n );

	const c3 = () => vec3( 0.5, 0.25, 1 ).toVar( 'c' );
	const c4 = () => vec4( 0.5, 0.25, 1, 0.5 ).toVar( 'c' );
	const glsl = ( code ) => new FunctionNode( code );
	const parsed = ( node ) => ( builder ) => {

		const f = node.getNodeFunction( builder );
		return [ `${ f.type }|${ f.name }|${ f.precision }`, ...f.inputs.map( ( i ) => `${ i.type } ${ i.name } ${ i.count } ${ i.qualifier } ${ i.isConst }` ) ].join( '\n' );

	};

	// [ name, stage, make, { extra, setup, teardown, ids, user } ]: `extra( builder, node )` adds a
	// value; `ids( node )` lists node ids to write as `#` (ids differ between the ports);
	// `user` writes the `fn<id>` names of user functions relative to the first one.
	const scenarios = [

		// color space functions and node
		[ 'g4_srgb_eotf', 'fragment', () => sRGBTransferEOTF( c3() ) ],
		[ 'g4_srgb_oetf', 'fragment', () => sRGBTransferOETF( c3() ) ],
		[ 'g4_premultiply_alpha', 'fragment', () => premultiplyAlpha( c4() ) ],
		[ 'g4_unpremultiply_alpha', 'fragment', () => unpremultiplyAlpha( c4() ) ],
		[ 'g4_color_space_srgb_to_working', 'fragment', () => colorSpaceToWorking( c4(), SRGBColorSpace ) ],
		[ 'g4_color_space_working_to_srgb', 'fragment', () => c4().workingToColorSpace( SRGBColorSpace ) ],
		[ 'g4_color_space_same', 'fragment', () => convertColorSpace( c4(), LinearSRGBColorSpace, LinearSRGBColorSpace ) ],
		[ 'g4_color_space_output', 'fragment', () => workingToColorSpace( c4(), 'OutputColorSpace' ) ],
		[ 'g4_color_space_srgb_to_p3', 'fragment', () => convertColorSpace( c4(), SRGBColorSpace, 'display-p3' ) ],
		[ 'g4_color_space_p3_linear_to_working', 'fragment', () => c4().colorSpaceToWorking( 'display-p3-linear' ) ],
		[ 'g4_color_space_disabled', 'fragment', () => {

			ColorManagement.enabled = false;
			return colorSpaceToWorking( c4(), SRGBColorSpace );

		}, { teardown: () => { ColorManagement.enabled = true; } } ],

		// tone mapping and render output nodes
		[ 'g4_tone_mapping_linear', 'fragment', () => toneMapping( LinearToneMapping, float( 1.2 ), c4() ) ],
		[ 'g4_tone_mapping_reinhard', 'fragment', () => toneMapping( ReinhardToneMapping, float( 1.2 ), c4() ) ],
		[ 'g4_tone_mapping_cineon', 'fragment', () => toneMapping( CineonToneMapping, float( 1.2 ), c4() ) ],
		[ 'g4_tone_mapping_aces_default_exposure', 'fragment', () => c4().toneMapping( ACESFilmicToneMapping ) ],
		[ 'g4_tone_mapping_agx', 'fragment', () => toneMapping( AgXToneMapping, float( 1.2 ), c4() ) ],
		[ 'g4_tone_mapping_neutral_context_color', 'fragment', () => toneMapping( NeutralToneMapping, float( 0.8 ) ), { setup: ( builder ) => { builder.context.color = vec4( 0.1, 0.2, 0.3, 0.4 ).toVar( 'ctx' ); } } ],
		[ 'g4_tone_mapping_none', 'fragment', () => toneMapping( NoToneMapping, float( 1 ), c4() ) ],
		[ 'g4_tone_mapping_unsupported', 'fragment', () => toneMapping( CustomToneMapping, float( 1 ), c4() ) ],
		[ 'g4_render_output_plain', 'fragment', () => renderOutput( c4() ) ],
		[ 'g4_render_output_explicit', 'fragment', () => renderOutput( c4(), ACESFilmicToneMapping, SRGBColorSpace ) ],
		[ 'g4_render_output_context', 'fragment', () => c4().renderOutput(), { setup: ( builder ) => { builder.context.toneMapping = AgXToneMapping; builder.context.outputColorSpace = SRGBColorSpace; } } ],
		[ 'g4_render_output_context_color', 'fragment', () => {

			const n = renderOutput( null, NeutralToneMapping, LinearSRGBColorSpace );
			n.premultipliedAlpha = false;
			return n;

		}, { setup: ( builder ) => { builder.context.color = vec4( 0.1, 0.2, 0.3, 0.4 ).toVar( 'ctx' ); } } ],

		// front facing
		[ 'g4_front_facing', 'fragment', () => vec2( float( frontFacing ), faceDirection ), { mesh: () => {} } ],
		[ 'g4_front_facing_back_side', 'fragment', () => float( frontFacing ), { mesh: ( m ) => { m.side = BackSide; } } ],
		[ 'g4_front_facing_vertex', 'vertex', () => float( frontFacing ), { mesh: () => {} } ],
		[ 'g4_negate_on_back_side_front', 'fragment', () => negateOnBackSide( c3() ), { mesh: () => {} } ],
		[ 'g4_negate_on_back_side_back', 'fragment', () => negateOnBackSide( c3() ), { mesh: ( m ) => { m.side = BackSide; } } ],
		[ 'g4_negate_on_back_side_double', 'fragment', () => negateOnBackSide( c3() ), { mesh: ( m ) => { m.side = DoubleSide; } } ],

		// screen and viewport
		[ 'g4_screen_uv', 'fragment', () => screenUV ],
		[ 'g4_screen_size_coordinate', 'fragment', () => vec4( screenSize, screenCoordinate ) ],
		[ 'g4_screen_coordinate_flip_y', 'fragment', () => screenCoordinate, { flipY: true } ],
		[ 'g4_screen_uv_flip_y', 'fragment', () => screenUV, { flipY: true } ],
		[ 'g4_viewport', 'fragment', () => vec4( viewport.xy, viewportSize ) ],
		[ 'g4_viewport_uv', 'fragment', () => vec4( viewportCoordinate, viewportUV ) ],
		[ 'g4_screen_dpr', 'fragment', () => screenDPR.mul( 2 ) ],

		// normal and bump maps
		[ 'g4_normal_map', 'fragment', () => normalMap( texture( tex() ) ), { mesh: () => {} } ],
		[ 'g4_normal_map_scale', 'fragment', () => normalMap( texture( tex() ), vec2( 0.5, 2 ) ), { mesh: () => {} } ],
		[ 'g4_normal_map_scale_flat', 'fragment', () => normalMap( texture( tex() ), vec2( 0.5, 2 ) ), { mesh: ( m ) => { m.flatShading = true; m.side = DoubleSide; } } ],
		[ 'g4_normal_map_object_space', 'fragment', () => {

			const n = normalMap( texture( tex() ) );
			n.normalMapType = ObjectSpaceNormalMap;
			return n;

		}, { mesh: () => {} } ],
		[ 'g4_normal_map_rg', 'fragment', () => {

			const n = normalMap( texture( tex() ), float( 1.5 ) );
			n.unpackNormalMode = NormalRGPacking;
			return n;

		}, { mesh: () => {} } ],
		[ 'g4_normal_map_ga', 'fragment', () => {

			const n = normalMap( texture( tex() ) );
			n.unpackNormalMode = NormalGAPacking;
			return n;

		}, { mesh: () => {} } ],
		[ 'g4_bump_map', 'fragment', () => bumpMap( texture( tex() ) ), { mesh: () => {} } ],
		[ 'g4_bump_map_scale', 'fragment', () => bumpMap( texture( tex() ).r, float( 0.5 ), vec3( 0, 0, 1 ).toVar( 'n' ) ), { mesh: () => {} } ],
		[ 'g4_bump_map_wireframe', 'fragment', () => bumpMap( texture( tex() ), float( 0.5 ) ), { mesh: ( m ) => { m.wireframe = true; } } ],

		// depth
		[ 'g4_depth', 'fragment', () => depth, { mesh: () => {} } ],
		[ 'g4_depth_orthographic', 'fragment', () => depth, { mesh: () => {}, orthographic: true } ],
		[ 'g4_linear_depth', 'fragment', () => linearDepth(), { mesh: () => {} } ],
		[ 'g4_linear_depth_value', 'fragment', () => linearDepth( f1( 0.5, 'd' ) ), { mesh: () => {} } ],
		[ 'g4_linear_depth_value_orthographic', 'fragment', () => linearDepth( f1( 0.5, 'd' ) ), { mesh: () => {}, orthographic: true } ],
		[ 'g4_depth_assign', 'fragment', () => Fn( () => {

			depth.assign( float( 0.25 ) ).toStack();

		} )(), { mesh: () => {} } ],
		[ 'g4_depth_functions', 'fragment', () => {

			const z = f1( - 3, 'z' ), n = f1( 0.1, 'n' ), f = f1( 100, 'f' ), d = f1( 0.5, 'd' );
			return vec4( viewZToOrthographicDepth( z, n, f ), viewZToReversedOrthographicDepth( z, n, f ), viewZToPerspectiveDepth( z, n, f ), viewZToReversedPerspectiveDepth( z, n, f ) )
				.add( vec4( orthographicDepthToViewZ( d, n, f ), perspectiveDepthToViewZ( d, n, f ), viewZToLogarithmicDepth( z, n, f ), logarithmicDepthToViewZ( d, n, f ) ) );

		} ],

		// viewport textures (a render target is bound, so the reference is the target)
		[ 'g4_viewport_texture', 'fragment', () => viewportTexture(), { renderTarget: true } ],
		[ 'g4_viewport_texture_uv_level', 'fragment', () => viewportTexture( vec2( 0.25, 0.5 ), float( 2 ) ), { renderTarget: true } ],
		[ 'g4_viewport_mip_texture', 'fragment', () => viewportMipTexture(), { renderTarget: true } ],
		[ 'g4_viewport_shared_texture', 'fragment', () => viewportSharedTexture( screenUV.mul( 0.5 ) ), { renderTarget: true } ],
		[ 'g4_viewport_depth_texture', 'fragment', () => viewportDepthTexture(), { renderTarget: true } ],
		[ 'g4_viewport_opaque_mip_texture', 'fragment', () => viewportOpaqueMipTexture( vec2( 0.5 ) ), { renderTarget: true } ],
		[ 'g4_viewport_linear_depth', 'fragment', () => viewportLinearDepth, { mesh: () => {}, renderTarget: true } ],

		// pass nodes (state only: building one needs renderer members not ported yet)
		[ 'g4_pass_node_state', 'fragment', () => float( 1 ), { extra: () => {

			const p = T.pass( new THREE.Scene(), new THREE.PerspectiveCamera(), { samples: 2 } );
			const output = p.getTexture( 'output' );
			p.getTexture( 'normal' );
			p.getTextureNode( 'normal' );
			p.getPreviousTextureNode( 'output' );
			p.setResolutionScale( 0.5 );
			p.setScissor( new THREE.Vector4( 1, 2, 3, 5 ) );
			p.setViewport( new THREE.Vector4( 2, 4, 7, 9 ) );
			p.setSize( 101, 51 );
			p.toggleTexture( 'output' );
			const rt = p.renderTarget;
			return [ rt.width, rt.height, rt.scissor.toArray().join( ',' ), rt.scissorTest, rt.viewport.toArray().join( ',' ), rt.textures.map( ( t ) => t.name ).join( ',' ),
				rt.textures[ 0 ] === output, p.getTexture( 'output' ) === output, p.getPreviousTexture( 'output' ) === output, rt.depthTexture.name, rt.depthTexture.format, rt.depthTexture.type,
				rt.texture.type, rt.samples, p.getResolutionScale(), p.getTextureNode( 'normal' ) === p.getTextureNode( 'normal' ), p.getTextureNode().value === p.getTexture( 'output' ),
				p.getPreviousTextureNode().value === output, p.updateBeforeType, p.global ].join( ' ' );

		} } ],
		[ 'g4_depth_pass_state', 'fragment', () => float( 1 ), { extra: () => {

			const p = T.depthPass( new THREE.Scene(), new THREE.PerspectiveCamera(), { stencilBuffer: true, depthBuffer: false, type: THREE.FloatType } );
			const q = T.pass( new THREE.Scene(), new THREE.PerspectiveCamera(), { depthBuffer: false } );
			const rt = p.renderTarget;
			return [ p.scope, rt.depthTexture.format, rt.depthTexture.type, rt.depthTexture.isRenderTargetTexture, rt.texture.type, rt.texture.name, q.renderTarget.depthTexture, Object.keys( q._textures ).join( ',' ), p.autoClear, p.autoClearDepth ].join( ' ' );

		} } ],
		[ 'g4_toon_outline_vertex', 'vertex', () => T.toonOutlinePass( new THREE.Scene(), new THREE.PerspectiveCamera() )._outlineMaterial.vertexNode, { mesh: () => {} } ],
		[ 'g4_toon_outline_color', 'fragment', () => T.toonOutlinePass( new THREE.Scene(), new THREE.PerspectiveCamera(), new THREE.Color( 1, 0.5, 0 ), 0.01, 0.5 )._outlineMaterial.colorNode, { extra: () => {

			const p = T.toonOutlinePass( new THREE.Scene(), new THREE.PerspectiveCamera() );
			const m = p._outlineMaterial;
			return [ p.name, m.name, m.side, m.positionNode, p.scope ].join( ' ' );

		} } ],

		// blend modes
		[ 'g4_blend_burn', 'fragment', () => blendBurn( c3(), vec3( 0.2, 0.4, 0.6 ) ) ],
		[ 'g4_blend_dodge', 'fragment', () => blendDodge( c3(), vec3( 0.2, 0.4, 0.6 ) ) ],
		[ 'g4_blend_screen', 'fragment', () => blendScreen( c3(), vec3( 0.2, 0.4, 0.6 ) ) ],
		[ 'g4_blend_overlay', 'fragment', () => blendOverlay( c3(), vec3( 0.2, 0.4, 0.6 ) ) ],
		[ 'g4_blend_color', 'fragment', () => blendColor( c4(), vec4( 0.2, 0.4, 0.6, 0.8 ) ) ],

		// color adjustment
		[ 'g4_grayscale_default', 'fragment', () => grayscale( c3() ) ],
		[ 'g4_grayscale_coefficients', 'fragment', () => grayscale( c3(), vec3( 0.3, 0.59, 0.11 ) ) ],
		[ 'g4_saturation', 'fragment', () => saturation( c3(), float( 0.5 ) ) ],
		[ 'g4_saturation_default', 'fragment', () => saturation( c3() ) ],
		[ 'g4_vibrance', 'fragment', () => vibrance( c3(), float( 0.3 ) ) ],
		[ 'g4_hue', 'fragment', () => hue( c3(), float( 0.7 ) ) ],
		[ 'g4_luminance', 'fragment', () => luminance( c3() ) ],
		[ 'g4_cdl_default', 'fragment', () => cdl( c4() ) ],
		[ 'g4_cdl_full', 'fragment', () => cdl( c4(), vec3( 1.1 ), vec3( 0.01 ), vec3( 0.9 ), float( 1.2 ) ) ],
		[ 'g4_posterize', 'fragment', () => posterize( c3(), float( 4 ) ) ],

		// tone mapping functions
		[ 'g4_tone_linear', 'fragment', () => linearToneMapping( c3(), float( 1.5 ) ) ],
		[ 'g4_tone_reinhard', 'fragment', () => reinhardToneMapping( c3(), float( 1.5 ) ) ],
		[ 'g4_tone_cineon', 'fragment', () => cineonToneMapping( c3(), float( 1.5 ) ) ],
		[ 'g4_tone_aces_filmic', 'fragment', () => acesFilmicToneMapping( c3(), float( 1.5 ) ) ],
		[ 'g4_tone_agx', 'fragment', () => agxToneMapping( c3(), float( 1.5 ) ) ],
		[ 'g4_tone_neutral', 'fragment', () => neutralToneMapping( c3(), float( 1.5 ) ) ],

		// compute built-ins
		[ 'g4_compute_builtins', 'compute', () => uvec4( numWorkgroups.x, workgroupId.y, localId.z, globalId.x.add( subgroupSize ) ) ],
		[ 'g4_compute_builtins_fragment', 'fragment', () => uvec4( numWorkgroups.x, workgroupId.y, localId.z, subgroupSize ) ],

		// atomics
		[ 'g4_atomic_value', 'compute', () => atomicAdd( workgroupArray( 'uint', 4 ).setName( 'counts' ).toAtomic().element( uint( 1 ) ), uint( 2 ) ) ],
		[ 'g4_atomic_statements', 'compute', () => Fn( () => {

			const counts = workgroupArray( 'int', 8 ).setName( 'counts' ).toAtomic();
			const e = counts.element( uint( 3 ) );
			atomicAdd( e, int( 1 ) );
			atomicSub( e, int( 2 ) );
			atomicMax( e, int( 3 ) );
			atomicMin( e, int( 4 ) );
			atomicAnd( e, int( 5 ) );
			atomicOr( e, int( 6 ) );
			atomicXor( e, int( 7 ) );
			atomicStore( e, int( 8 ) );
			const v = atomicLoad( e ).toVar( 'v' );
			return v;

		} )() ],

		// barriers and workgroup arrays
		[ 'g4_barriers', 'compute', () => Fn( () => {

			workgroupBarrier();
			storageBarrier();
			textureBarrier();

		} )() ],
		[ 'g4_workgroup_array_named', 'compute', () => workgroupArray( 'vec4', 16 ).setName( 'tile' ).element( uint( 2 ) ).xy ],
		[ 'g4_workgroup_array_assign', 'compute', () => Fn( () => {

			const tile = workgroupArray( 'float', 4 ).setName( 'tile' );
			tile.element( uint( 1 ) ).assign( float( 3 ) );
			return tile.element( uint( 1 ) ).add( 1 );

		} )() ],
		[ 'g4_workgroup_array_unnamed', 'compute', () => workgroupArray( 'float' ).element( uint( 0 ) ), { ids: ( node ) => [ node.node.id ] } ],

		// subgroups
		[ 'g4_subgroup_ops', 'compute', () => {

			const x = float( 1.5 ).toVar( 'x' );
			const v = vec3( 1, 2, 3 ).toVar( 'v' );
			return vec4( subgroupAdd( x ), subgroupInclusiveMul( v ).y, subgroupBroadcast( v, float( 2 ) ).z, subgroupShuffleXor( x, uint( 1 ) ) );

		} ],
		[ 'g4_subgroup_misc', 'compute', () => {

			const x = float( 1.5 ).toVar( 'x' );
			return vec4( float( subgroupElect() ), float( subgroupBallot( bool( true ) ).x ), float( subgroupAll( bool( false ) ) ), quadSwapX( x ).add( quadBroadcast( x, uint( 1 ) ) ).add( subgroupShuffleUp( x, uint( 2 ) ) ) );

		} ],

		// compute nodes
		[ 'g4_compute_count', 'compute', () => Fn( () => {

			const counts = workgroupArray( 'float', 4 ).setName( 'counts' );
			counts.element( uint( 0 ) ).assign( float( 1 ) );

		} )().compute( 64 ), { setup: ( builder ) => { builder.allowEarlyReturns = true; } } ],
		[ 'g4_compute_count_no_early_return', 'compute', () => compute( Fn( () => {

			const counts = workgroupArray( 'float', 4 ).setName( 'counts' );
			counts.element( uint( 0 ) ).assign( float( 1 ) );

		} )(), 32, [ 8, 8 ] ) ],
		[ 'g4_compute_kernel_output', 'fragment', () => computeKernel( Fn( () => vec3( 1, 2, 3 ).toVar( 'r' ) )(), [ 4, 2 ] ) ],
		[ 'g4_compute_barrier_flags', 'compute', () => Fn( () => {

			workgroupBarrier();

		} )().compute( 16 ), { extra: ( builder ) => `${ builder.allowEarlyReturns } ${ builder.allowGlobalVariables }`, setup: ( builder ) => { builder.allowEarlyReturns = true; builder.allowGlobalVariables = true; } } ],

		// GLSL parser
		...( () => {

			const basic = glsl( 'float myFn( vec3 a, float b ) { return a.x + b; }' );
			const qualifiers = glsl( '#define FOO 1\n// header\n#pragma main\n/* lead */\n// line\nhighp vec4 shade( const in vec3 a, out float b[ 4 ], inout int c, sampler2D t ) {\n\tb[ 0 ] = 1.0;\n\treturn vec4( a, 1.0 );\n}' );
			const iface = glsl( '  vec3 noBody( vec2 uv )  ' );
			const semicolon = glsl( 'vec3 decl( vec2 uv );' );
			const unnamed = glsl( 'mediump float ( float a ) { return a; }' );
			const inout = glsl( 'void update( inout vec3 a, in float b, out int c, const float d, mat3 m, float e ) { c = 1; }' );
			const called = glslFn( 'float called( vec3 a, int b, float c ) { return a.x * float( b ) + c; }' );
			return [
				[ 'g4_glsl_basic', 'fragment', () => basic, { extra: parsed( basic ) } ],
				[ 'g4_glsl_qualifiers', 'fragment', () => qualifiers, { extra: parsed( qualifiers ) } ],
				[ 'g4_glsl_interface', 'fragment', () => iface, { extra: parsed( iface ) } ],
				[ 'g4_glsl_semicolon', 'fragment', () => semicolon, { extra: parsed( semicolon ) } ],
				[ 'g4_glsl_unnamed', 'fragment', () => unnamed, { extra: parsed( unnamed ) } ],
				[ 'g4_glsl_inout', 'fragment', () => inout, { extra: parsed( inout ) } ],
				[ 'g4_glsl_call', 'fragment', () => called( vec3( 1, 2, 3 ).toVar( 'a' ), 2.5, int( 4 ) ) ],
				[ 'g4_glsl_call_named', 'fragment', () => called( { c: float( 1 ), a: vec3( 4 ), b: int( 2 ) } ) ],
			];

		} )(),

		// fn<id> names of library functions from each group
		[ 'g4_fn_names_g1', 'fragment', () => vec4( T.rand( vec2( 0.25, 0.5 ).toVar( 'p' ) ), T.hash( uint( 7 ).toVar( 's' ) ), T.triNoise3D( vec3( 1, 2, 3 ).toVar( 'q' ), float( 0.5 ), float( 0.25 ) ), float( 1 ) ) ],
		[ 'g4_fn_names_g4', 'fragment', () => vec4( sRGBTransferOETF( blendScreen( c3(), vec3( 0.1 ) ) ), grayscale( neutralToneMapping( c3(), float( 1 ) ) ) ) ],
		[ 'g4_fn_names_user', 'fragment', () => {

			// short layouts created at run time count on from the library functions
			const a = Fn( ( [ x ] ) => x.mul( 2 ), { x: 'float', return: 'float' } );
			const b = Fn( ( [ x ] ) => x.add( 1 ), { x: 'float', return: 'float' } );
			return a( b( float( 3 ).toVar( 'u' ) ) );

		}, { user: true } ],
	];

	const viewportTarget = new RenderTarget( 1, 1 );
	const records = {};
	for ( const [ name, stage, make, opts = {} ] of scenarios ) {

		let object = null;
		if ( opts.mesh ) {

			const material = new THREE.MeshBasicMaterial();
			opts.mesh( material );
			object = new THREE.Mesh( geometry, material );

		}

		const builder = new G4Builder( object, renderer, new GLSLNodeParser() );
		builder.flipY = opts.flipY === true;
		if ( opts.mesh ) {

			builder.camera = opts.orthographic ? new THREE.OrthographicCamera() : new THREE.PerspectiveCamera();
			materialContext( builder );

		}

		renderer._renderTarget = opts.renderTarget ? viewportTarget : null;
		builder.setShaderStage( stage );
		if ( opts.setup ) opts.setup( builder );
		const node = make();
		const flow = builder.flowStagesNode( node );
		const r = record( builder, flow );
		r.codes = [];
		for ( const s of [ 'vertex', 'fragment', 'compute' ] ) for ( const c of builder.codes[ s ] || [] ) r.codes.push( `${ s }:${ c.name }:${ c.code }` );
		r.extra = opts.extra ? opts.extra( builder, node ) : '';
		if ( opts.teardown ) opts.teardown();
		renderer._renderTarget = null;
		let json = JSON.stringify( r );
		for ( const id of opts.ids ? opts.ids( node ) : [] ) json = json.replaceAll( `_${ id }`, '_#' );
		if ( opts.user ) json = relativeUserNames( json );
		records[ name ] = JSON.parse( json );

	}

	return records;

}

// `fn<id>` names from 130 on (user functions) as `fnUser<k>`, `k` counted from the
// smallest one in the record.
export function relativeUserNames( json ) {

	const ids = [ ...json.matchAll( /\bfn(\d+)\b/g ) ].map( ( m ) => + m[ 1 ] ).filter( ( n ) => n >= 130 );
	if ( ids.length === 0 ) return json;
	const base = Math.min( ...ids );
	return json.replace( /\bfn(\d+)\b/g, ( m, n ) => + n >= 130 ? `fnUser${ + n - base }` : m );

}
