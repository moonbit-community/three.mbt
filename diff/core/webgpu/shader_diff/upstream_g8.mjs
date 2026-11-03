// Upstream side of the G8 (WGSLNodeBuilder) shader scenarios. The MoonBit side is
// src/renderers/webgpu/g8_shader_diff_test.mbt; scenario names start with `g8_`.
//
// Every scenario builds with upstream's real `WGSLNodeBuilder` on a `WebGPURenderer`
// with a stub canvas and `renderer._bindings = undefined`, marked initialized with a fake
// device (`backend.device = { features }`, `backend.compatibilityMode`), which is what
// `hasFeature` and the texture utils read. Three renderers: `a` (no features), `b`
// (`subgroups`), `c` (compatibility mode).
//
// Kinds of scenario:
// - flow: `builder.flowStagesNode( node )` in one stage, with `decl` = the declarations
//   the builder would emit (getUniforms, getAttributes, both getVaryings, getStructs,
//   getDirectives, getScopedArrays, getBuiltins( 'output' ), global getVars), joined
//   by `\n@@\n`, and `codes` (getCodes).
// - compute: `builder.compute = computeNode; builder.build()`: `shader` is computeShader.
// - material: the steps of `build()` with a stand-in for `NodeMaterial.build` (a vertex
//   and a fragment stack with the given output nodes), then `buildCode()`: `shader` is
//   vertexShader + fragmentShader.

export async function runUpstream( src ) {

	const T = await import( src + '/Three.TSL.js' );
	const THREE = await import( src + '/Three.WebGPU.js' );
	const { default: WGSLNodeBuilder } = await import( src + '/renderers/webgpu/nodes/WGSLNodeBuilder.js' );
	const { WebGPURenderer } = THREE;

	const canvas = { style: {}, width: 300, height: 150, addEventListener() {}, removeEventListener() {}, getContext() { return null; } };
	const makeRenderer = ( features, compatibilityMode ) => {

		const r = new WebGPURenderer( { canvas } );
		r._bindings = undefined;
		r._initialized = true;
		r.backend.device = { features: new Set( features ) };
		r.backend.compatibilityMode = compatibilityMode;
		r.backend.renderer = r;
		return r;

	};

	const renderers = { a: makeRenderer( [], false ), b: makeRenderer( [ 'subgroups' ], false ), c: makeRenderer( [], true ), d: makeRenderer( [], false ) };
	renderers.d.debug.diagnostics.keywords = true;
	const bindingsOf = ( builder ) => builder.getBindings().map( ( g ) => g.name + '[' + g.bindings.map( ( b ) => b.name + ':' + b.visibility ).join( ',' ) + ']' ).join( ' ' );

	const { float, int, uint, bool, vec2, vec3, vec4, ivec2, ivec3, uvec2, uvec3, bvec2, mat2, mat3, mat4, color, uniform, Fn, If, Loop, Break, Return, Discard, texture, cubeTexture, texture3D, textureLoad, storageTexture, textureStore, storage, select } = T;

	const fv = ( v ) => float( v ).toVar();
	const iv = ( v ) => int( v ).toVar();
	const uv_ = ( v ) => uint( v ).toVar();
	const v2 = () => vec2( 1, 2 ).toVar();
	const v3 = () => vec3( 1, 2, 3 ).toVar();
	const v4 = () => vec4( 1, 2, 3, 4 ).toVar();
	const m2 = () => mat2( 1, 2, 3, 4 ).toVar();
	const m3 = () => mat3( 1, 0, 0, 0, 1, 0, 0, 0, 1 ).toVar();
	const m4 = () => mat4().toVar();

	const tex = () => {

		const t = new THREE.Texture();
		t.name = 'tex';
		return t;

	};

	const floatTex = ( filter ) => {

		const t = tex();
		t.type = THREE.FloatType;
		if ( filter === 'nearest' ) {

			t.minFilter = THREE.NearestFilter;
			t.magFilter = THREE.NearestFilter;

		}

		return t;

	};

	const geometry = new THREE.BufferGeometry();
	for ( const [ name, itemSize ] of [ [ 'position', 3 ], [ 'normal', 3 ], [ 'uv', 2 ] ] ) {

		geometry.setAttribute( name, new THREE.BufferAttribute( new Float32Array( 24 * itemSize ), itemSize ) );

	}

	const floatBuffer = ( n, itemSize ) => new THREE.StorageBufferAttribute( n, itemSize );
	const uintBuffer = ( n ) => new THREE.StorageBufferAttribute( n, 1, Uint32Array );

	const scenarios = [];
	// opts: stage, renderer, mesh, pre( builder )
	const flow = ( name, make, opts = {} ) => scenarios.push( { kind: 'flow', name: 'g8_' + name, make, stage: 'fragment', renderer: 'a', mesh: false, ...opts } );
	const computeBuild = ( name, make, opts = {} ) => scenarios.push( { kind: 'compute', name: 'g8_' + name, make, renderer: 'a', ...opts } );
	const materialBuild = ( name, vertex, fragment, opts = {} ) => scenarios.push( { kind: 'material', name: 'g8_' + name, vertex, fragment, renderer: 'a', ...opts } );

	// --- Types, conversions and methods
	flow( 'vec_types', () => vec4( float( ivec2( 1, 2 ).toVar().x ), float( uvec3( 1, 2, 3 ).toVar().y ), float( bvec2( true, false ).toVar().x ), 1 ) );
	flow( 'mat_types', () => m2().mul( vec2( 1, 2 ) ).add( m3().mul( vec3( 1 ) ).xy ).add( m4().mul( vec4( 1 ) ).xy ) );
	flow( 'color_type', () => color( 0xff0000 ).toVar() );
	flow( 'convert_int_float', () => int( fv( 2.5 ) ).add( int( uv_( 3 ) ) ) );
	flow( 'convert_vec', () => vec3( ivec3( 1, 2, 3 ).toVar() ).add( vec3( uvec3( 4, 5, 6 ).toVar() ) ) );
	flow( 'bitcast', () => T.bitcast( fv( 1 ), 'uint' ) );
	flow( 'bitcast_methods', () => vec2( float( T.floatBitsToInt( fv( 1 ) ) ), T.uintBitsToFloat( uv_( 3 ) ) ) );
	flow( 'packing', () => vec3( float( T.packSnorm2x16( v2() ) ), T.unpackHalf2x16( uv_( 5 ) ).x, float( T.packUnorm4x8( v4() ) ) ) );
	flow( 'mod_float', () => fv( 5 ).mod( 2 ) );
	flow( 'mod_vec2', () => v2().mod( vec2( 2 ) ) );
	flow( 'mod_vec3', () => v3().mod( fv( 2 ) ) );
	flow( 'mod_vec4', () => v4().mod( vec4( 3 ) ) );
	flow( 'mod_int', () => iv( 5 ).mod( iv( 2 ) ) );
	flow( 'equal_bool', () => bool( true ).toVar().equal( bool( false ).toVar() ) );
	flow( 'equal_bvec2', () => bvec2( true, false ).toVar().equal( bvec2( false, false ).toVar() ) );
	flow( 'xor', () => bool( true ).toVar().xor( bool( false ).toVar() ) );
	flow( 'inverse_mat2', () => m2().inverse() );
	flow( 'inverse_mat3', () => m3().inverse() );
	flow( 'inverse_mat4', () => m4().inverse() );
	flow( 'derivatives', () => fv( 1 ).dFdx().add( fv( 2 ).dFdy() ).add( T.inverseSqrt( fv( 4 ) ) ) );
	flow( 'faceforward', () => T.faceforward( v3(), v3(), v3() ) );
	flow( 'select', () => select( fv( 1 ).greaterThan( 0 ), v3(), vec3( 0 ) ) );
	flow( 'reserved_names', () => float( 1 ).toVar( 'fn' ).add( float( 2 ).toVar( 'main' ) ).add( float( 3 ).toVar( 'let' ) ) );
	flow( 'reserved_names_checked', () => float( 1 ).toVar( 'fn' ).add( float( 2 ).toVar( 'main' ) ).add( float( 3 ).toVar( 'let' ) ).add( float( 4 ).toVar( 'color' ) ), { renderer: 'd' } );
	flow( 'declaration_names', () => uniform( 1 ).setName( 'scale' ).add( uniform( 2 ).setName( 'scale' ) ).add( storage( floatBuffer( 4, 1 ), 'float', 4 ).setName( 'buf' ).element( iv( 0 ) ) ).add( storage( floatBuffer( 4, 1 ), 'float', 4 ).setName( 'buf' ).element( iv( 1 ) ) ) );
	flow( 'array_values', () => T.array( [ float( 1 ), float( 2 ), float( 3 ) ] ).toVar().element( iv( 1 ) ) );
	flow( 'array_count', () => T.array( 'vec3', 4 ).toVar().element( iv( 2 ) ) );
	flow( 'const_let', () => vec3( 1, 2, 3 ).toConst( 'k' ).add( fv( 1 ).toConst() ) );

	// --- Functions
	flow( 'fn_layout', () => Fn( ( [ a, b ] ) => a.mul( b ).add( 1 ) ).setLayout( { name: 'myFn', type: 'float', inputs: [ { name: 'a', type: 'float' }, { name: 'b', type: 'float' } ] } )( fv( 1 ), fv( 2 ) ) );
	flow( 'fn_layout_early_return', () => Fn( ( [ p ] ) => {

		const r = vec3( 0 ).toVar();
		If( p.x.greaterThan( 1 ), () => {

			r.assign( p );
			Return();

		} );
		r.assign( p.mul( 2 ) );
		return r;

	} ).setLayout( { name: 'earlyFn', type: 'vec3', inputs: [ { name: 'p', type: 'vec3' } ] } )( v3() ) );
	flow( 'fn_layout_mod', () => Fn( ( [ x ] ) => x.mod( 2 ).add( x.dFdx() ) ).setLayout( { name: 'modFn', type: 'float', inputs: [ { name: 'x', type: 'float' } ] } )( fv( 3 ) ) );
	flow( 'wgsl_fn', () => T.wgslFn( 'fn scale( a : f32, b : vec3f ) -> vec3f { return b * a; }' )( fv( 2 ), v3() ) );
	flow( 'wgsl_fn_comment', () => T.wgslFn( '// scales\n/* by a */\nfn scale2( a : f32, b : vec2<f32> ) -> vec2<f32> { return b * a; }' )( fv( 2 ), v2() ) );
	flow( 'wgsl_fn_includes', () => {

		const inner = T.wgslFn( 'fn inner( x : f32 ) -> f32 { return x * 2.0; }' );
		return T.wgslFn( 'fn outer( x : f32 ) -> f32 { return inner( x ) + 1.0; }', [ inner ] )( fv( 3 ) );

	} );
	flow( 'wgsl_fn_object_args', () => T.wgslFn( 'fn mixer( a : vec3<f32>, b : vec3<f32>, t : f32 ) -> vec3<f32> { return mix( a, b, t ); }' )( { t: fv( 0.5 ), a: v3(), b: vec3( 1 ) } ) );
	flow( 'loop_break', () => Fn( () => {

		const r = fv( 0 );
		Loop( 4, ( { i } ) => {

			If( r.greaterThan( 2 ), () => {

				Break();

			} );
			r.addAssign( float( i ) );

		} );
		return r;

	} )() );
	flow( 'early_return_main', () => Fn( () => {

		const r = fv( 1 );
		If( r.greaterThan( 1 ), () => {

			Return();

		} );
		return r;

	} )() );
	flow( 'discard', () => Fn( () => {

		Discard( fv( 1 ).lessThan( 0 ) );
		return fv( 1 );

	} )() );

	// --- Structs
	flow( 'struct', () => {

		const S = T.struct( { a: 'float', b: 'vec3' }, 'MyStruct' );
		return S( fv( 1 ), v3() ).toVar().get( 'b' );

	} );
	flow( 'output_struct', () => T.outputStruct( vec4( 1 ), vec4( 0.5 ) ) );
	flow( 'frag_depth', () => Fn( () => {

		T.depth.assign( fv( 0.5 ) );
		return vec4( 1 );

	} )() );

	// --- Builtins
	flow( 'front_facing', () => float( T.frontFacing ).toVar(), { mesh: true } );
	flow( 'frag_coord', () => T.screenCoordinate.toVar() );
	flow( 'vertex_index', () => float( T.vertexIndex ).add( float( T.instanceIndex ) ), { stage: 'vertex' } );
	flow( 'instance_index_fragment', () => float( T.instanceIndex ) );
	flow( 'compute_builtins', () => vec3( T.globalId ).add( vec3( T.localId ) ).add( vec3( T.workgroupId ) ).add( vec3( T.numWorkgroups ) ), { stage: 'compute' } );
	flow( 'invocation_local_index', () => float( T.invocationLocalIndex ), { stage: 'compute' } );
	flow( 'subgroups', () => T.subgroupAdd( fv( 1 ) ).add( float( T.subgroupSize ) ).add( float( T.invocationSubgroupIndex ) ).add( float( T.subgroupIndex ) ), { stage: 'compute', renderer: 'b' } );
	flow( 'subgroups_unsupported', () => float( T.subgroupSize ), { stage: 'compute' } );
	flow( 'hardware_clipping', () => fv( 1 ), { stage: 'vertex', pre: ( b ) => b.enableHardwareClipping( 3 ) } );
	flow( 'directives', () => fv( 1 ), { pre: ( b ) => {

		b.enableShaderF16();
		b.enableDualSourceBlending();
		b.enableShaderF16();

	} } );
	flow( 'invariant', () => fv( 1 ), { stage: 'vertex', pre: ( b ) => {

		b.context.invariant = true;

	} } );

	// --- Uniforms
	flow( 'uniforms_object', () => uniform( 1.5 ).add( uniform( new THREE.Vector3( 1, 2, 3 ) ).x ).add( uniform( new THREE.Color( 1, 0, 0 ) ).r ).add( uniform( new THREE.Matrix4() ).mul( vec4( 1 ) ).x ) );
	flow( 'uniforms_groups', () => uniform( 1 ).setGroup( T.renderGroup ).add( uniform( 2 ).setGroup( T.frameGroup ) ).add( uniform( 3 ) ).add( uniform( 4 ).setGroup( T.uniformGroup( 'custom' ) ) ) );
	flow( 'uniforms_vertex', () => uniform( new THREE.Vector2( 1, 2 ) ).add( uniform( int( 3 ) ) ), { stage: 'vertex' } );
	flow( 'uniform_array', () => T.uniformArray( [ 1, 2, 3, 4 ] ).element( iv( 1 ) ) );
	flow( 'uniform_array_vec4', () => T.uniformArray( [ new THREE.Vector4( 1, 2, 3, 4 ), new THREE.Vector4() ] ).element( iv( 1 ) ) );

	// --- Textures
	flow( 'texture_sample', () => texture( tex() ) );
	flow( 'texture_uv', () => texture( tex(), vec2( 0.25, 0.75 ) ) );
	flow( 'texture_level', () => texture( tex(), vec2( 0.5 ) ).level( 2 ) );
	flow( 'texture_bias', () => texture( tex(), vec2( 0.5 ) ).bias( 0.5 ) );
	flow( 'texture_grad', () => texture( tex(), vec2( 0.5 ) ).grad( vec2( 0.1 ), vec2( 0.2 ) ) );
	flow( 'texture_offset', () => texture( tex(), vec2( 0.5 ) ).offset( ivec2( 1, 2 ) ) );
	flow( 'texture_depth_offset', () => texture( new THREE.DataArrayTexture(), vec2( 0.5 ) ).depth( 1 ).offset( ivec2( 1, 0 ) ) );
	flow( 'texture_gather', () => texture( tex(), vec2( 0.5 ) ).gather() );
	flow( 'texture_gather_channel', () => texture( tex(), vec2( 0.5 ) ).gather( 2 ) );
	flow( 'texture_load', () => textureLoad( tex(), ivec2( 1, 2 ) ) );
	flow( 'texture_load_level', () => textureLoad( tex(), ivec2( 1, 2 ), 1 ) );
	flow( 'texture_size', () => T.textureSize( texture( tex() ) ) );
	flow( 'texture_size_level', () => texture( tex() ).size( 2 ) );
	flow( 'texture_array', () => texture( new THREE.DataArrayTexture(), vec2( 0.5 ) ).depth( 2 ) );
	flow( 'texture_depth_texture', () => texture( new THREE.DepthTexture( 4, 4 ), vec2( 0.5 ) ) );
	// the `compare()` scenarios (restored by G6 with `Renderer::has_compatibility`)
	flow( 'texture_compare', () => texture( new THREE.DepthTexture( 4, 4 ), vec2( 0.5 ) ).compare( 0.25 ) );
	flow( 'texture_gather_compare', () => texture( new THREE.DepthTexture( 4, 4 ), vec2( 0.5 ) ).gather().compare( 0.25 ) );
	flow( 'texture_depth_load_compat', () => textureLoad( new THREE.DepthTexture( 4, 4 ), ivec2( 1, 2 ) ), { renderer: 'c' } );
	flow( 'texture_depth_compat', () => texture( new THREE.DepthTexture( 4, 4 ), vec2( 0.5 ) ), { renderer: 'c' } );
	flow( 'texture_int', () => {

		const t = tex();
		t.type = THREE.IntType;
		return texture( t, vec2( 0.5 ) );

	} );
	flow( 'texture_uint_red', () => {

		const t = tex();
		t.type = THREE.UnsignedIntType;
		t.format = THREE.RedIntegerFormat;
		return texture( t, vec2( 0.5 ) );

	} );
	flow( 'texture_cube', () => cubeTexture( new THREE.CubeTexture(), vec3( 0, 1, 0 ) ) );
	flow( 'texture_cube_level', () => cubeTexture( new THREE.CubeTexture(), vec3( 0, 1, 0 ), 2 ) );
	flow( 'texture_cube_float', () => {

		const t = new THREE.CubeTexture();
		t.type = THREE.FloatType;
		return cubeTexture( t, vec3( 0, 1, 0 ) ).offset( ivec3( 1, 0, 0 ) );

	} );
	flow( 'texture_3d', () => texture3D( new THREE.Data3DTexture(), vec3( 0.1, 0.2, 0.3 ) ) );
	flow( 'texture_3d_load', () => T.texture3DLoad( new THREE.Data3DTexture(), ivec3( 1, 2, 3 ) ) );
	flow( 'texture_3d_float_nearest', () => {

		const t = new THREE.Data3DTexture();
		t.type = THREE.FloatType;
		t.minFilter = THREE.NearestFilter;
		t.magFilter = THREE.NearestFilter;
		t.wrapR = THREE.MirroredRepeatWrapping;
		return texture3D( t, vec3( 0.5 ) ).offset( ivec3( 1, 0, 1 ) );

	} );
	flow( 'texture_float_filtered', () => texture( floatTex(), vec2( 0.5 ) ) );
	flow( 'texture_float_filtered_offset_level', () => texture( floatTex(), vec2( 0.5 ) ).offset( ivec2( 1, 1 ) ).level( 1 ) );
	flow( 'texture_float_filtered_array', () => {

		const t = new THREE.DataArrayTexture();
		t.type = THREE.FloatType;
		t.minFilter = THREE.LinearFilter;
		return texture( t, vec2( 0.5 ) ).depth( 1 );

	} );
	flow( 'texture_float_nearest', () => texture( floatTex( 'nearest' ), vec2( 0.5 ) ) );
	flow( 'texture_float_nearest_wrap', () => {

		const t = floatTex( 'nearest' );
		t.wrapS = THREE.RepeatWrapping;
		t.wrapT = THREE.MirroredRepeatWrapping;
		return texture( t, vec2( 0.5 ) ).offset( ivec2( 1, 2 ) );

	} );
	flow( 'texture_float_nearest_shared', () => {

		const t = floatTex( 'nearest' );
		return texture( t, vec2( 0.5 ) ).add( texture( t, vec2( 0.25 ) ).level( 1 ) );

	} );
	flow( 'texture_float_grad', () => texture( floatTex( 'nearest' ), vec2( 0.5 ) ).grad( vec2( 0.1 ), vec2( 0.2 ) ) );
	flow( 'texture_normalized_short', () => {

		const t = tex();
		t.type = THREE.ShortType;
		t.normalized = true;
		return texture( t, vec2( 0.5 ) );

	} );
	flow( 'texture_vertex', () => texture( tex(), vec2( 0.5 ) ), { stage: 'vertex' } );
	flow( 'texture_vertex_offset_array', () => texture( new THREE.DataArrayTexture(), vec2( 0.5 ) ).depth( 1 ).offset( ivec2( 1, 1 ) ), { stage: 'vertex' } );
	flow( 'texture_vertex_float', () => texture( floatTex( 'nearest' ), vec2( 0.5 ) ), { stage: 'vertex' } );
	flow( 'texture_vertex_bias', () => texture( tex(), vec2( 0.5 ) ).bias( 1 ), { stage: 'vertex' } );
	flow( 'texture_msaa_depth', () => {

		const rt = new THREE.RenderTarget( 4, 4, { samples: 4, depthTexture: new THREE.DepthTexture( 4, 4 ) } );
		return texture( rt.depthTexture, vec2( 0.5 ) );

	} );
	flow( 'texture_msaa_depth_gather', () => {

		const rt = new THREE.RenderTarget( 4, 4, { samples: 4, depthTexture: new THREE.DepthTexture( 4, 4 ) } );
		return texture( rt.depthTexture, vec2( 0.5 ) ).gather().offset( ivec2( 1, 0 ) );

	} );
	flow( 'texture_msaa_color', () => {

		const rt = new THREE.RenderTarget( 4, 4, { samples: 4 } );
		return texture( rt.texture, vec2( 0.5 ) ).add( texture( rt.texture ).size( 0 ) .x );

	} );
	flow( 'storage_texture_load', () => storageTexture( new THREE.StorageTexture( 4, 4 ), uvec2( 1, 2 ) ), { stage: 'compute' } );
	flow( 'storage_texture_store', () => textureStore( new THREE.StorageTexture( 4, 4 ), uvec2( 1, 2 ), vec4( 1, 0, 0, 1 ) ), { stage: 'compute' } );
	flow( 'storage_texture_rw_fragment', () => storageTexture( new THREE.StorageTexture( 4, 4 ), uvec2( 1, 2 ) ).toReadWrite() );
	flow( 'storage_texture_formats', () => {

		const a = new THREE.StorageTexture( 4, 4 );
		a.type = THREE.UnsignedByteType;
		const b = new THREE.StorageTexture( 4, 4 );
		b.format = THREE.RedFormat;
		b.type = THREE.HalfFloatType;
		const c = new THREE.StorageTexture( 4, 4 );
		c.format = THREE.RGIntegerFormat;
		c.type = THREE.UnsignedIntType;
		return storageTexture( a, uvec2( 1, 2 ) ).add( storageTexture( b, uvec2( 1, 2 ) ).x ).add( vec4( storageTexture( c, uvec2( 1, 2 ) ) ) );

	}, { stage: 'compute' } );
	flow( 'storage_texture_3d', () => T.storageTexture3D( new THREE.Storage3DTexture( 2, 2, 2 ), uvec3( 1, 1, 1 ) ), { stage: 'compute' } );
	flow( 'storage_texture_array', () => storageTexture( new THREE.StorageArrayTexture( 2, 2, 2 ), uvec2( 1, 1 ) ).depth( 1 ), { stage: 'compute' } );

	// --- Storage buffers, atomics, workgroup memory
	flow( 'storage_read', () => storage( floatBuffer( 16, 4 ), 'vec4', 16 ).element( T.instanceIndex ), { stage: 'compute' } );
	flow( 'storage_read_only', () => storage( floatBuffer( 16, 4 ), 'vec4', 16 ).toReadOnly().element( T.instanceIndex ), { stage: 'compute' } );
	flow( 'storage_vertex', () => storage( floatBuffer( 16, 3 ), 'vec3', 16 ).element( T.instanceIndex ), { stage: 'vertex' } );
	flow( 'storage_fragment', () => storage( floatBuffer( 16, 1 ), 'float', 16 ).element( iv( 2 ) ) );
	flow( 'storage_atomic', () => T.atomicAdd( storage( uintBuffer( 4 ), 'uint', 4 ).toAtomic().element( 0 ), 1 ), { stage: 'compute' } );
	flow( 'storage_atomic_fragment', () => T.atomicAdd( storage( uintBuffer( 4 ), 'uint', 4 ).toAtomic().element( 1 ), 2 ) );
	flow( 'storage_atomic_vertex', () => T.atomicLoad( storage( uintBuffer( 4 ), 'uint', 4 ).toAtomic().element( 1 ) ), { stage: 'vertex' } );
	flow( 'workgroup_array', () => T.workgroupArray( 'float', 64 ).setName( 'wgFloats' ).element( T.invocationLocalIndex ), { stage: 'compute' } );
	flow( 'workgroup_atomic', () => T.atomicAdd( T.workgroupArray( 'uint', 8 ).setName( 'wgCounters' ).toAtomic().element( uint( 0 ) ), 1 ), { stage: 'compute' } );
	flow( 'barrier', () => Fn( () => {

		const r = fv( 1 );
		T.workgroupBarrier();
		return r;

	} )(), { stage: 'compute' } );

	// --- Varyings and attributes (mesh)
	flow( 'varying', () => T.varying( T.positionLocal.mul( 2 ) ).x, { mesh: true } );
	flow( 'varying_flat', () => T.varying( T.positionLocal.mul( 3 ), 'vFlat' ).setInterpolation( 'flat', 'first' ), { mesh: true } );
	flow( 'varying_sampling', () => T.varying( T.positionLocal, 'vPos' ).setInterpolation( 'perspective', 'centroid' ).add( T.varying( T.normalLocal ).setInterpolation( 'linear' ) ), { mesh: true } );
	flow( 'varying_uint', () => float( T.varying( T.vertexIndex ) ), { mesh: true } );
	flow( 'attribute', () => T.attribute( 'uv', 'vec2' ).add( T.positionGeometry.xy ), { mesh: true, stage: 'vertex' } );
	flow( 'uv_fragment', () => T.uv(), { mesh: true } );

	// --- Representative g1/g2 graphs through WGSL
	flow( 'g1_op_add_variadic', () => T.add( fv( 1 ), 2, fv( 3 ), 4 ) );
	flow( 'g1_op_div_int_int', () => iv( 4 ).div( iv( 2 ) ) );
	flow( 'g1_op_mul_uint_negative', () => uv_( 3 ).mul( - 2 ) );
	flow( 'g1_op_not_equal_vec3', () => v3().notEqual( v3() ) );
	flow( 'g1_op_and_bvec', () => bvec2( true, false ).toVar().and( bvec2( false, true ).toVar() ) );
	flow( 'g1_op_bit_not', () => iv( 6 ).bitNot() );
	flow( 'g1_op_shift_right_uvec', () => uvec3( 8, 16, 32 ).toVar().shiftRight( 2 ) );
	flow( 'g1_op_mat3_vec3', () => m3().mul( v3() ) );
	flow( 'g1_op_assign_ops', () => Fn( () => {

		const v = fv( 1 );
		v.addAssign( 2 );
		v.mulAssign( 3 );
		v.modAssign( 5 );
		const i = iv( 3 );
		i.bitXorAssign( 7 );
		i.shiftLeftAssign( 1 );
		return v.add( float( i ) );

	} )() );
	flow( 'g1_op_increment', () => Fn( () => {

		const i = iv( 0 );
		i.increment();
		i.decrementBefore();
		return i;

	} )() );
	flow( 'g1_math_one_vec3', () => v3().normalize().add( v3().fract() ).add( v3().saturate() ).add( v3().oneMinus() ).add( v3().cbrt() ) );
	flow( 'g1_math_atan2', () => T.atan( fv( 1 ), fv( 2 ) ) );
	flow( 'g1_math_mix_vec3', () => T.mix( v3(), vec3( 0 ), fv( 0.5 ) ) );
	flow( 'g1_math_clamp_int', () => iv( 3 ).clamp( iv( 0 ), 2 ) );
	flow( 'g1_math_transpose_det', () => m3().transpose().mul( m3().determinant() ) );
	flow( 'g1_math_rand', () => T.rand( v2() ) );
	flow( 'g1_math_constants', () => vec4( T.PI, T.TWO_PI, T.HALF_PI, T.EPSILON ).add( T.INFINITY ) );
	flow( 'g1_cond_select_vec', () => T.select( fv( 1 ).greaterThan( 0 ), v3(), vec3( 1 ) ).add( fv( 1 ).greaterThan( 0 ).select( 1, 2 ) ) );
	flow( 'g1_hash', () => T.hash( uv_( 3 ) ) );
	flow( 'g1_remap', () => T.remap( fv( 0.5 ), 0, 1, 2, 4 ).add( T.remapClamp( fv( 0.5 ), 0, 1, 2, 4 ) ) );
	flow( 'g1_rotate', () => T.rotate( v2(), fv( 0.5 ) ) );
	flow( 'g1_checker', () => T.checker( v2() ) );
	flow( 'g1_tri_noise', () => T.triNoise3D( v3(), 1, fv( 0 ) ) );
	flow( 'g1_oscillators', () => T.oscSine( fv( 0.5 ) ).add( T.oscSquare( fv( 0.5 ) ) ).add( T.oscTriangle( fv( 0.5 ) ) ).add( T.oscSawtooth( fv( 0.5 ) ) ) );
	flow( 'g1_packing_normals', () => T.packNormalToRGB( v3() ).add( T.unpackRGBToNormal( v3() ) ) );
	flow( 'g2_position_view', () => T.positionView, { mesh: true, ctx: true } );
	flow( 'g2_normal_view', () => T.normalView, { mesh: true, ctx: true } );
	flow( 'g2_model_matrices', () => T.modelWorldMatrix.mul( vec4( T.positionLocal, 1 ) ).add( T.modelNormalMatrix.mul( T.normalLocal ).xyzz ), { mesh: true, stage: 'vertex' } );
	flow( 'g2_camera', () => T.cameraProjectionMatrix.mul( T.cameraViewMatrix ).mul( vec4( T.cameraPosition, 1 ) ), { mesh: true } );
	flow( 'g2_uv1', () => T.uv( 1 ), { mesh: true } );
	flow( 'g2_texture_uv_default', () => texture( tex() ).rgb, { mesh: true } );

	// --- Whole compute shaders
	computeBuild( 'compute_basic', () => {

		const buf = storage( floatBuffer( 64, 1 ), 'float', 64 );
		return T.compute( Fn( () => {

			buf.element( T.instanceIndex ).assign( float( T.instanceIndex ).mul( 2 ) );

		} )(), 64 );

	} );
	computeBuild( 'compute_workgroup_2d', () => {

		const buf = storage( floatBuffer( 64, 4 ), 'vec4', 64 );
		const scale = uniform( 2 );
		const shared = T.workgroupArray( 'float', 64 ).setName( 'shared' );
		return T.compute( Fn( () => {

			shared.element( T.invocationLocalIndex ).assign( scale );
			T.workgroupBarrier();
			buf.element( T.instanceIndex ).assign( vec4( shared.element( uint( 0 ) ) ) );

		} )(), 64, [ 8, 8 ] );

	} );
	computeBuild( 'compute_atomic', () => {

		const counter = storage( uintBuffer( 1 ), 'uint', 1 ).toAtomic();
		return T.compute( Fn( () => {

			T.atomicAdd( counter.element( 0 ), 1 );

		} )(), 16, [ 16 ] );

	} );
	computeBuild( 'compute_subgroups', () => {

		const buf = storage( floatBuffer( 32, 1 ), 'float', 32 );
		return T.compute( Fn( () => {

			buf.element( T.instanceIndex ).assign( T.subgroupAdd( float( T.invocationSubgroupIndex ) ) );

		} )(), 32, [ 32 ] );

	}, { renderer: 'b' } );
	computeBuild( 'compute_texture_store', () => {

		const t = new THREE.StorageTexture( 8, 8 );
		return T.compute( Fn( () => {

			textureStore( t, T.globalId.xy, vec4( 1, 0, 0, 1 ) ).toWriteOnly();

		} )(), 64, [ 8, 8, 1 ] );

	} );
	computeBuild( 'compute_uniforms_texture', () => {

		const buf = storage( floatBuffer( 16, 4 ), 'vec4', 16 );
		const a = uniform( 1 );
		const b = uniform( new THREE.Vector3( 1, 2, 3 ) ).setGroup( T.renderGroup );
		return T.compute( Fn( () => {

			const c = texture( tex(), vec2( 0.5 ) ).mul( a ).add( vec4( b, 1 ) );
			buf.element( T.instanceIndex ).assign( c );

		} )(), 16 );

	} );
	computeBuild( 'compute_layout_fn', () => {

		const buf = storage( floatBuffer( 16, 1 ), 'float', 16 );
		const f = Fn( ( [ x ] ) => x.mul( x ).mod( 3 ) ).setLayout( { name: 'sq', type: 'float', inputs: [ { name: 'x', type: 'float' } ] } );
		return T.compute( Fn( () => {

			buf.element( T.instanceIndex ).assign( f( float( T.instanceIndex ) ) );

		} )(), 16 );

	} );
	computeBuild( 'compute_local_vars', () => {

		const buf = storage( floatBuffer( 16, 1 ), 'float', 16 );
		return T.compute( Fn( () => {

			const v = float( 1 ).toVar();
			T.workgroupBarrier();
			v.addAssign( 1 );
			buf.element( T.instanceIndex ).assign( v );

		} )(), 16 );

	} );

	// --- Whole materials (NodeMaterial.build stand-in)
	const mvp = () => T.cameraProjectionMatrix.mul( T.modelViewMatrix ).mul( vec4( T.positionLocal, 1 ) );
	materialBuild( 'material_basic', mvp, () => vec4( T.uv(), 0, 1 ) );
	materialBuild( 'material_vec3_output', mvp, () => vec3( 1, 0, 0 ) );
	materialBuild( 'material_uniform_texture', mvp, () => texture( tex(), T.uv() ).mul( uniform( new THREE.Color( 0.5, 0.25, 1 ) ) ).add( texture( floatTex( 'nearest' ), T.uv() ) ) );
	materialBuild( 'material_sampler_comparison', mvp, () => vec4( texture( new THREE.DepthTexture( 4, 4 ), T.uv() ).compare( 0.5 ), 0, 0, 1 ) );
	materialBuild( 'material_output_struct', mvp, () => T.outputStruct( vec4( 1 ), vec4( T.uv(), 0, 1 ) ) );
	materialBuild( 'material_frag_depth', mvp, () => Fn( () => {

		T.depth.assign( 0.5 );
		return vec4( 1 );

	} )() );
	materialBuild( 'material_varyings', mvp, () => vec4( T.varying( T.positionLocal ).add( T.varying( T.normalLocal, 'vFlat' ).setInterpolation( 'flat' ) ), float( T.frontFacing ) ).add( vec4( T.screenCoordinate, 0, 0 ) ) );
	materialBuild( 'material_invariant', mvp, () => vec4( 1 ), { pre: ( b ) => {

		b.context.invariant = true;

	} } );
	materialBuild( 'material_storage_vertex', () => {

		const buf = storage( floatBuffer( 16, 3 ), 'vec3', 16 ).toReadOnly();
		return T.cameraProjectionMatrix.mul( T.modelViewMatrix ).mul( vec4( T.positionLocal.add( buf.element( T.instanceIndex ) ), 1 ) );

	}, () => vec4( float( T.varying( T.vertexIndex ) ) ) );
	materialBuild( 'material_layout_fn', mvp, () => {

		const f = Fn( ( [ c ] ) => c.mul( 2 ).mod( 1 ) ).setLayout( { name: 'tint', type: 'vec3', inputs: [ { name: 'c', type: 'vec3' } ] } );
		return vec4( f( vec3( T.uv(), 1 ) ), 1 );

	} );

	// --- run
	const records = {};
	const materialContext = ( builder ) => {

		builder.context.setupPositionView = () => T.modelViewMatrix.mul( T.positionLocal ).xyz;
		builder.context.setupModelViewProjection = () => T.cameraProjectionMatrix.mul( T.positionView );
		builder.context.setupNormal = () => T.subBuild( T.normalViewGeometry, 'NORMAL', 'vec3' );

	};

	for ( const s of scenarios ) {

		try {

			runOne( s );

		} catch ( e ) {

			records[ s.name ] = { error: String( e && e.message ) };

		}

	}

	return records;

	function runOne( s ) {

		const renderer = renderers[ s.renderer ];
		if ( s.kind === 'flow' ) {

			const object = s.mesh ? new THREE.Mesh( geometry, new THREE.MeshBasicMaterial() ) : null;
			const builder = new WGSLNodeBuilder( object, renderer );
			if ( s.mesh ) builder.camera = new THREE.PerspectiveCamera();
			if ( s.ctx ) materialContext( builder );
			if ( s.pre ) s.pre( builder );
			builder.setShaderStage( s.stage );
			const f = builder.flowStagesNode( s.make() );
			const stage = s.stage;
			if ( builder.vars.vertex === undefined ) builder.vars.vertex = [];
			const decl = [
				builder.getUniforms( stage ),
				builder.getAttributes( stage ),
				builder.getVaryings( 'vertex' ),
				builder.getVaryings( 'fragment' ),
				builder.getStructs( stage ),
				builder.getDirectives( stage ),
				String( builder.getScopedArrays( stage ) ),
				builder.getBuiltins( 'output' ),
				builder.getVars( stage, true ),
				builder.getVars( 'vertex', true )
			].join( '\n@@\n' );
			const uniforms = [];
			for ( const st of [ 'vertex', 'fragment', 'compute' ] ) {

				for ( const u of builder.uniforms[ st ] ) uniforms.push( `${st}:${u.name}:${u.type}` );

			}

			records[ s.name ] = { code: f.code, result: typeof f.result === 'string' ? f.result : '', vars: f.vars ?? '', uniforms, codes: builder.getCodes( stage ), decl, bindings: bindingsOf( builder ) };

		} else if ( s.kind === 'compute' ) {

			const builder = new WGSLNodeBuilder( null, renderer );
			builder.compute = s.make();
			builder.build();
			records[ s.name ] = { shader: builder.computeShader, bindings: bindingsOf( builder ) };

		} else {

			const mesh = new THREE.Mesh( geometry, new THREE.MeshBasicMaterial() );
			const builder = new WGSLNodeBuilder( mesh, renderer );
			builder.scene = new THREE.Scene();
			builder.camera = new THREE.PerspectiveCamera();
			if ( s.pre ) s.pre( builder );
			builder.addContext( renderer.contextNode.getFlowContextData() );
			builder.addStack();
			builder.stack.outputNode = s.vertex();
			builder.addFlow( 'vertex', builder.removeStack() );
			builder.addStack();
			builder.stack.outputNode = s.fragment();
			builder.addFlow( 'fragment', builder.removeStack() );
			for ( const buildStage of [ 'setup', 'analyze', 'generate' ] ) {

				builder.setBuildStage( buildStage );
				for ( const shaderStage of [ 'fragment', 'vertex', 'compute' ] ) {

					builder.setShaderStage( shaderStage );
					for ( const node of builder.flowNodes[ shaderStage ] ) {

						if ( buildStage === 'generate' ) builder.flowNode( node );
						else node.build( builder );

					}

				}

			}

			builder.setBuildStage( null );
			builder.setShaderStage( null );
			builder.buildCode();
			records[ s.name ] = { shader: builder.vertexShader + '\n@@@@\n' + builder.fragmentShader, bindings: bindingsOf( builder ) };

		}

	}

}
