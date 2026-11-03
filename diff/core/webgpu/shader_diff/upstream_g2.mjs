// Upstream side of the G2 (nodes/accessors) shader scenarios. The MoonBit side is
// src/nodes/accessors_shader_diff_test.mbt; scenario names start with `g2_`.
//
// The base NodeBuilder leaves the texture methods abstract, so both sides build with
// `G2Builder`, a NodeBuilder subclass whose texture methods print their arguments
// (`null`/`undefined` as `-`), and which can report `isFlipY()`. Each builder gets a mesh
// (24 vertices with every attribute the scenarios read) and a perspective camera.

const fmt = ( v ) => v === null || v === undefined ? '-' : Array.isArray( v ) ? '[' + v.map( fmt ).join( ',' ) + ']' : String( v );

export async function runUpstream( src ) {

	const T = await import( src + '/Three.TSL.js' );
	const THREE = await import( src + '/Three.WebGPU.js' );
	const { default: NodeBuilder } = await import( src + '/nodes/core/NodeBuilder.js' );
	const { default: NodeFrame } = await import( src + '/nodes/core/NodeFrame.js' );
	const REFERENCE_BASE = await import( src + '/nodes/accessors/ReferenceBaseNode.js' );
	const { WebGPURenderer } = THREE;

	class G2Builder extends NodeBuilder {

		constructor( object, renderer ) {

			super( object, renderer );
			this.flipY = false;

		}

		isFlipY() {

			return this.flipY;

		}

		getUniformBufferLimit() {

			return this.limit;

		}

		generateTexture( texture, p, uv, depth, offset ) {

			return `tex(${ p }, ${ uv }, ${ fmt( depth ) }, ${ fmt( offset ) })`;

		}

		generateTextureLevel( texture, p, uv, level, depth, offset ) {

			return `texLevel(${ p }, ${ uv }, ${ level }, ${ fmt( depth ) }, ${ fmt( offset ) })`;

		}

		generateTextureBias( texture, p, uv, bias, depth, offset ) {

			return `texBias(${ p }, ${ uv }, ${ bias }, ${ fmt( depth ) }, ${ fmt( offset ) })`;

		}

		generateTextureGrad( texture, p, uv, grad, depth, offset ) {

			return `texGrad(${ p }, ${ uv }, ${ fmt( grad ) }, ${ fmt( depth ) }, ${ fmt( offset ) })`;

		}

		generateTextureCompare( texture, p, uv, compare, depth, offset ) {

			return `texCompare(${ p }, ${ uv }, ${ compare }, ${ fmt( depth ) }, ${ fmt( offset ) })`;

		}

		generateTextureGather( texture, p, uv, gather, depth, offset, flipY ) {

			return `texGather(${ p }, ${ uv }, ${ fmt( gather ) }, ${ fmt( depth ) }, ${ fmt( offset ) }, ${ fmt( flipY ) })`;

		}

		generateTextureGatherCompare( texture, p, uv, compare, depth, offset, flipY ) {

			return `texGatherCompare(${ p }, ${ uv }, ${ compare }, ${ fmt( depth ) }, ${ fmt( offset ) }, ${ fmt( flipY ) })`;

		}

		generateTextureLoad( texture, p, uv, level, depth, offset ) {

			return `texLoad(${ p }, ${ uv }, ${ fmt( level ) }, ${ fmt( depth ) }, ${ fmt( offset ) })`;

		}

		generateStorageTextureLoad( texture, p, uv, level, depth, offset ) {

			return `storageLoad(${ p }, ${ uv }, ${ fmt( level ) }, ${ fmt( depth ) }, ${ fmt( offset ) })`;

		}

		generateTextureStore( texture, p, uv, depth, value ) {

			return `store(${ p }, ${ uv }, ${ fmt( depth ) }, ${ value })`;

		}

		generateTextureSize( texture, p, level ) {

			return `size(${ p }, ${ level })`;

		}

		getClipDistance() {

			return 'clipDistances';

		}

		enableHardwareClipping() {}

		getDrawIndex() {

			return null;

		}

		isAvailable( name ) {

			return name === 'storageBuffer';

		}

	}

	// Node has no ImageBitmap; the flipY uniform of TextureNode tests for it.
	if ( typeof globalThis.ImageBitmap === 'undefined' ) globalThis.ImageBitmap = class ImageBitmap {};

	const canvas = { style: {}, width: 300, height: 150, addEventListener() {}, removeEventListener() {}, getContext() { return null; } };
	const renderer = new WebGPURenderer( { canvas } );
	renderer._bindings = undefined;

	const geometry = new THREE.BufferGeometry();
	for ( const [ name, itemSize ] of [ [ 'position', 3 ], [ 'normal', 3 ], [ 'uv', 2 ], [ 'uv1', 2 ], [ 'tangent', 4 ], [ 'color', 4 ] ] ) {

		geometry.setAttribute( name, new THREE.BufferAttribute( new Float32Array( 24 * itemSize ), itemSize ) );

	}

	// The callbacks a node material puts in the context (NodeMaterial.setupPositionView and
	// the others), fixed here so the accessors that read them can run.
	const materialContext = ( builder ) => {

		builder.context.setupPositionView = () => T.modelViewMatrix.mul( T.positionLocal ).xyz;
		builder.context.setupModelViewProjection = () => T.cameraProjectionMatrix.mul( T.positionView );
		builder.context.setupNormal = () => T.subBuild( T.normalViewGeometry, 'NORMAL', 'vec3' );
		builder.context.setupClearcoatNormal = () => T.subBuild( T.normalViewGeometry, 'NORMAL', 'vec3' );
		builder.context.clipSpace = T.vec4( 1, 2, 3, 1 );

	};

	const skinnedMesh = () => {

		const g = new THREE.BufferGeometry();
		for ( const [ name, itemSize ] of [ [ 'position', 3 ], [ 'normal', 3 ], [ 'tangent', 4 ], [ 'skinWeight', 4 ] ] ) {

			g.setAttribute( name, new THREE.BufferAttribute( new Float32Array( 24 * itemSize ), itemSize ) );

		}

		g.setAttribute( 'skinIndex', new THREE.BufferAttribute( new Uint16Array( 24 * 4 ), 4 ) );
		const bones = [ new THREE.Bone(), new THREE.Bone() ];
		bones[ 0 ].add( bones[ 1 ] );
		const mesh = new THREE.SkinnedMesh( g, new THREE.MeshBasicMaterial() );
		mesh.add( bones[ 0 ] );
		mesh.bind( new THREE.Skeleton( bones ) );
		return mesh;

	};

	const morphMesh = () => {

		const g = new THREE.BufferGeometry();
		g.setAttribute( 'position', new THREE.BufferAttribute( new Float32Array( 72 ), 3 ) );
		g.setAttribute( 'normal', new THREE.BufferAttribute( new Float32Array( 72 ), 3 ) );
		g.morphAttributes.position = [ new THREE.BufferAttribute( new Float32Array( 72 ), 3 ), new THREE.BufferAttribute( new Float32Array( 72 ), 3 ) ];
		g.morphAttributes.normal = [ new THREE.BufferAttribute( new Float32Array( 72 ), 3 ), new THREE.BufferAttribute( new Float32Array( 72 ), 3 ) ];
		return new THREE.Mesh( g, new THREE.MeshBasicMaterial() );

	};

	const instancedMesh = ( colors ) => {

		const mesh = new THREE.InstancedMesh( geometry, new THREE.MeshBasicMaterial(), 3 );
		if ( colors ) mesh.setColorAt( 0, new THREE.Color( 1, 0, 0 ) );
		return mesh;

	};

	const arrayCamera = ( multiView ) => {

		const cameras = [ new THREE.PerspectiveCamera(), new THREE.PerspectiveCamera() ];
		cameras[ 0 ].viewport = new THREE.Vector4( 0, 0, 1, 1 );
		cameras[ 1 ].viewport = new THREE.Vector4( 1, 0, 1, 1 );
		const camera = new THREE.ArrayCamera( cameras );
		camera.isMultiViewCamera = multiView;
		return camera;

	};

	const velocityMRT = T.mrt( { output: T.output, velocity: T.velocity } );

	const batchedMesh = () => {

		const mesh = new THREE.BatchedMesh( 2, 48, 72, new THREE.MeshBasicMaterial() );
		mesh.setColorAt( mesh.addInstance( mesh.addGeometry( geometry ) ), new THREE.Color( 1, 0, 0 ) );
		return mesh;

	};

	const { default: ClippingContext } = await import( src + '/renderers/common/ClippingContext.js' );
	const clippingContext = () => {

		const c = new ClippingContext();
		c.unionPlanes = [ new THREE.Vector4( 0, 1, 0, 0 ), new THREE.Vector4( 1, 0, 0, 2 ) ];
		c.intersectionPlanes = [ new THREE.Vector4( 0, 0, 1, 1 ) ];
		return c;

	};

	const { texture, textureLoad, textureLevel, uniformTexture, cubeTexture, texture3D, storageTexture, textureStore, textureSize, uv, vec2, vec3, vec4, ivec2, ivec3, uvec2, float, int, Fn } = T;

	const scene = new THREE.Scene();

	const tex = () => {

		const t = new THREE.Texture();
		t.name = 'tex';
		t.offset.set( 0.25, 0.5 );
		return t;

	};

	const scenarios = {
		g2_texture_sample: () => texture( tex() ),
		g2_texture_uv: () => texture( tex(), uv( 1 ) ),
		g2_texture_uv_vec: () => texture( tex(), vec2( 0.25, 0.75 ) ),
		g2_texture_level: () => texture( tex(), vec2( 0.5 ) ).level( 2 ),
		g2_texture_level_fn: () => textureLevel( tex(), vec2( 0.5 ), float( 3 ).toVar() ),
		g2_texture_bias: () => texture( tex(), vec2( 0.5 ) ).bias( 0.5 ),
		g2_texture_grad: () => texture( tex(), vec2( 0.5 ) ).grad( vec2( 0.1 ), vec2( 0.2 ) ),
		g2_texture_offset: () => texture( tex(), vec2( 0.5 ) ).offset( ivec2( 1, 2 ) ),
		g2_texture_depth: () => texture( tex(), vec2( 0.5 ) ).depth( 3 ),
		g2_texture_gather: () => texture( tex(), vec2( 0.5 ) ).gather(),
		g2_texture_gather_channel: () => texture( tex(), vec2( 0.5 ) ).gather( 2 ),
		g2_texture_load: () => textureLoad( tex(), ivec2( 1, 2 ) ),
		g2_texture_load_level: () => textureLoad( tex(), ivec2( 1, 2 ), 1 ),
		g2_texture_chain_load: () => texture( tex() ).load( ivec2( 3, 4 ) ),
		g2_texture_size: () => textureSize( texture( tex() ) ),
		g2_texture_size_level: () => texture( tex() ).size( 2 ),
		g2_texture_shared: () => {

			const t = texture( tex() );
			return vec2( t.sample( vec2( 0.1 ) ).x, t.sample( vec2( 0.2 ) ).y );

		},
		g2_texture_matrix: () => {

			const t = tex();
			t.matrixAutoUpdate = false;
			return texture( t ).rgb;

		},
		g2_texture_uniform: () => {

			const t = tex();
			return vec2( uniformTexture( t ).r, uniformTexture( t ).g );

		},
		g2_texture_mergeable: () => {

			const t = tex();
			return vec2( texture( t ).r, texture( t ).g );

		},
		g2_texture_of_node: () => texture( texture( tex() ), vec2( 0.3 ) ),
		g2_texture_array: () => {

			const t = new THREE.DataArrayTexture();
			return texture( t, vec2( 0.5 ) );

		},
		g2_texture_depth_texture: () => texture( new THREE.DepthTexture( 4, 4 ), vec2( 0.5 ) ),
		g2_texture_int: () => {

			const t = tex();
			t.type = THREE.IntType;
			return texture( t, vec2( 0.5 ) );

		},
		g2_texture_uint_red: () => {

			const t = tex();
			t.type = THREE.UnsignedIntType;
			t.format = THREE.RedIntegerFormat;
			return texture( t, vec2( 0.5 ) );

		},
		g2_texture_flip_y: { flipY: true, make: () => texture( tex(), vec2( 0.5 ) ) },
		g2_texture_flip_y_load: { flipY: true, make: () => textureLoad( tex(), ivec2( 1, 2 ) ) },
		g2_texture_property: () => texture( tex() ).convert( 'property' ),
		g2_texture_sampler: () => T.sampler( tex() ),
		g2_texture_cube: () => cubeTexture( new THREE.CubeTexture(), vec3( 0, 1, 0 ) ),
		g2_texture_cube_level: () => cubeTexture( new THREE.CubeTexture(), vec3( 0, 1, 0 ), 2 ),
		g2_texture_3d: () => texture3D( new THREE.Data3DTexture(), vec3( 0.1, 0.2, 0.3 ) ),
		g2_texture_3d_default: () => texture3D( new THREE.Data3DTexture() ),
		g2_texture_3d_load: () => T.texture3DLoad( new THREE.Data3DTexture(), ivec3( 1, 2, 3 ) ),
		g2_texture_3d_offset: () => texture3D( new THREE.Data3DTexture(), vec3( 0.5 ) ).offset( ivec3( 1, 0, 1 ) ),
		g2_storage_texture_load: () => storageTexture( new THREE.StorageTexture( 4, 4 ), uvec2( 1, 2 ) ),
		g2_storage_texture_store: () => textureStore( new THREE.StorageTexture( 4, 4 ), uvec2( 1, 2 ), T.vec4( 1, 0, 0, 1 ) ),
		// Builtins and plain attributes.
		g2_builtin: () => T.builtin( 'gl_FragCoord' ),
		g2_point_uv: () => T.pointUV,
		g2_uv0: () => uv(),
		g2_vertex_color: () => T.vertexColor(),
		g2_vertex_color_missing: () => T.vertexColor( 2 ),
		g2_position_geometry: () => T.positionGeometry,
		g2_position_local: () => T.positionLocal,
		g2_position_local_vertex: { stage: 'vertex', make: () => T.positionLocal },
		g2_normal_geometry: () => T.normalGeometry,
		g2_tangent_geometry: () => T.tangentGeometry,
		// Camera.
		g2_camera_near_far: () => vec2( T.cameraNear, T.cameraFar ),
		g2_camera_position: () => T.cameraPosition,
		g2_camera_matrices: () => T.cameraProjectionMatrix.mul( T.cameraViewMatrix ).mul( T.cameraWorldMatrix ).mul( T.cameraProjectionMatrixInverse ),
		g2_camera_normal_matrix: () => T.cameraNormalMatrix,
		g2_camera_index: () => T.cameraIndex,
		// ScreenNode's update reads the renderer's drawing buffer size (G6).
		g2_camera_viewport: () => T.cameraViewport,
		// Model and object.
		g2_model_world_matrix: () => T.modelWorldMatrix,
		g2_model_vectors: () => T.modelPosition.add( T.modelScale ).add( T.modelDirection ).add( T.modelViewPosition ).mul( T.modelRadius ),
		g2_model_normal_matrix: () => T.modelNormalMatrix,
		g2_model_world_matrix_inverse: () => T.modelWorldMatrixInverse,
		g2_model_view_matrix: () => T.modelViewMatrix,
		g2_model_view_matrix_vertex: { stage: 'vertex', make: () => T.modelViewMatrix },
		g2_highp_model_view_matrix: () => T.highpModelViewMatrix.mul( T.highpModelNormalViewMatrix ),
		g2_mediump_model_view_matrix: () => T.mediumpModelViewMatrix,
		g2_object_nodes: () => {

			const o = new THREE.Object3D();
			return T.objectPosition( o ).add( T.objectScale( o ) ).add( T.objectDirection( o ) ).add( T.objectViewPosition( o ) ).mul( T.objectRadius( o ) );

		},
		g2_object_world_matrix: () => T.objectWorldMatrix( new THREE.Object3D() ),
		// Position, normal, tangent, bitangent (the material callbacks are in the context).
		g2_position_world: () => T.positionWorld,
		g2_position_world_vertex: { stage: 'vertex', make: () => T.positionWorld },
		g2_position_world_direction: () => T.positionWorldDirection,
		g2_position_view: { ctx: true, make: () => T.positionView },
		g2_position_view_vertex: { ctx: true, stage: 'vertex', make: () => T.positionView },
		g2_position_view_direction: { ctx: true, make: () => T.positionViewDirection },
		g2_model_view_projection: { ctx: true, stage: 'vertex', make: () => T.modelViewProjection },
		g2_clip_space: { ctx: true, make: () => T.clipSpace },
		g2_clip_space_vertex: { ctx: true, stage: 'vertex', make: () => T.clipSpace },
		g2_normal_local: () => T.normalLocal,
		g2_normal_flat: { ctx: true, make: () => T.normalFlat },
		g2_normal_view_geometry: () => T.normalViewGeometry,
		g2_normal_world_geometry: () => T.normalWorldGeometry,
		g2_normal_view: { ctx: true, make: () => T.normalView },
		g2_normal_world: { ctx: true, make: () => T.normalWorld },
		g2_clearcoat_normal_view: { ctx: true, make: () => T.clearcoatNormalView },
		g2_transform_normal: () => T.transformNormal( T.normalLocal ),
		g2_transform_normal_chain: () => T.normalLocal.transformNormal( T.modelWorldMatrixInverse ),
		g2_transform_normal_to_view: () => T.transformNormalToView( T.normalLocal ),
		g2_tangent_local: () => T.tangentLocal,
		g2_tangent_view: { ctx: true, make: () => T.tangentView },
		g2_tangent_world: { ctx: true, make: () => T.tangentWorld },
		g2_bitangent_geometry: () => T.bitangentGeometry,
		g2_bitangent_local: () => T.bitangentLocal,
		g2_bitangent_view: { ctx: true, make: () => T.bitangentView },
		g2_bitangent_world: { ctx: true, make: () => T.bitangentWorld },
		g2_tbn_view_matrix: { ctx: true, make: () => T.TBNViewMatrix },
		g2_parallax_uv: { ctx: true, make: () => T.parallaxUV( uv(), 0.1 ) },
		g2_bent_normal_view: { ctx: true, make: () => T.bentNormalView },
		g2_reflect_vector: { ctx: true, make: () => T.reflectVector },
		g2_refract_vector: { ctx: true, make: () => T.refractVector },
		g2_texture_cube_default: { ctx: true, make: () => cubeTexture( new THREE.CubeTexture() ) },
		// Material, scene and light uniforms.
		g2_material_properties: () => vec3( T.materialRefractionRatio, T.materialEnvIntensity, 0 ).add( T.materialEnvRotation[ 0 ].xyz ),
		g2_scene_properties: () => vec2( T.backgroundBlurriness, T.backgroundIntensity ).add( T.backgroundRotation[ 1 ].xy ),
		g2_material_color: () => T.materialColor,
		g2_material_color_map: { material: ( m ) => {

			m.map = tex();

		}, make: () => T.materialColor },
		g2_material_opacity: () => T.materialOpacity,
		g2_material_alpha_map: { material: ( m ) => {

			m.alphaMap = tex();

		}, make: () => T.materialOpacity },
		g2_material_specular_strength: () => T.materialSpecularStrength,
		g2_material_reflectivity: () => T.materialReflectivity,
		g2_material_ao: { material: ( m ) => {

			m.aoMap = tex();

		}, make: () => T.materialAO },
		g2_material_light_map: { material: ( m ) => {

			m.lightMap = tex();

		}, make: () => T.materialLightMap },
		g2_material_line_dash_offset: () => T.materialLineDashOffset,
		g2_material_rotation: () => T.materialRotation,
		g2_material_reference: () => T.materialReference( 'opacity', 'float' ),
		g2_material_reference_color: () => T.materialReference( 'color', 'color' ),
		g2_reference_object: () => T.reference( 'position', 'vec3', new THREE.Object3D() ),
		g2_reference_material: () => {

			const m = new THREE.MeshBasicMaterial();
			return T.reference( 'opacity', 'float', m );

		},
		g2_user_data: { object: ( mesh ) => {

			mesh.userData.speed = 2;
			return mesh;

		}, make: () => T.userData( 'speed', 'float' ) },
		g2_light_position: () => {

			const light = new THREE.PointLight();
			return T.lightPosition( light ).add( T.lightViewPosition( light ) );

		},
		g2_light_target: () => {

			const light = new THREE.DirectionalLight();
			return T.lightTargetDirection( light ).add( T.lightTargetPosition( light ) );

		},
		g2_light_projection_uv: () => T.lightProjectionUV( new THREE.SpotLight() ),
		// Buffers and arrays.
		g2_uniform_array_float: () => T.uniformArray( [ 1, 2, 3 ] ).element( int( 1 ) ),
		g2_uniform_array_vec3: () => T.uniformArray( [ new THREE.Vector3(), new THREE.Vector3( 1, 2, 3 ) ] ).element( T.instanceIndex ),
		g2_uniform_array_color: () => T.uniformArray( [ new THREE.Color( 1, 0, 0 ) ] ).element( 0 ),
		g2_uniform_array_mat3: () => T.uniformArray( [ new THREE.Matrix3() ], 'mat3' ).element( 0 ),
		g2_uniform_array_int: () => T.uniformArray( [ 1, 2 ], 'int' ).element( 1 ),
		g2_buffer_mat4: () => T.buffer( new Float32Array( 32 ), 'mat4', 2 ).element( T.instanceIndex ),
		g2_buffer_attribute: () => T.bufferAttribute( new Float32Array( 72 ), 'vec3' ),
		g2_buffer_attribute_vertex: { stage: 'vertex', make: () => T.bufferAttribute( new Float32Array( 72 ), 'vec3' ) },
		g2_instanced_buffer_attribute: { stage: 'vertex', make: () => T.instancedBufferAttribute( new THREE.InstancedBufferAttribute( new Float32Array( 12 ), 4 ) ) },
		g2_buffer_attribute_mat4: { stage: 'vertex', make: () => T.instancedDynamicBufferAttribute( new THREE.InstancedBufferAttribute( new Float32Array( 48 ), 16 ) ) },
		g2_reference_buffer: () => T.referenceBuffer( 'morphTargetInfluences', 'float', 2, new THREE.Mesh() ).element( 1 ),
		g2_velocity: { stage: 'vertex', make: () => T.velocity },
		g2_texture_bicubic: () => T.textureBicubic( texture( tex(), vec2( 0.5 ) ), 0.5 ),
		// Skinning, morphing, instancing, batching (in the vertex stage, inside a Fn as a
		// material's position setup calls them).
		g2_skinning: { stage: 'vertex', object: () => skinnedMesh(), make: ( o ) => Fn( () => {

			T.skinning( o );
			return T.positionLocal;

		} )() },
		g2_skinning_normal: { stage: 'vertex', object: () => skinnedMesh(), make: ( o ) => Fn( () => {

			T.skinning( o );
			return T.normalLocal.add( T.tangentLocal );

		} )() },
		g2_skinning_texture: { stage: 'vertex', limit: 1024, object: () => skinnedMesh(), make: ( o ) => Fn( () => {

			T.skinning( o );
			return T.positionLocal;

		} )() },
		g2_morph: { stage: 'vertex', object: () => morphMesh(), make: ( o ) => Fn( () => {

			T.morphReference( o );
			return T.positionLocal.add( T.normalLocal );

		} )() },
		g2_instanced_mesh: { stage: 'vertex', object: () => instancedMesh( false ), make: ( o ) => Fn( () => {

			T.instancedMesh( o );
			return T.positionLocal.add( T.normalLocal );

		} )() },
		g2_instanced_mesh_color: { stage: 'vertex', object: () => instancedMesh( true ), make: ( o ) => Fn( () => {

			T.instancedMesh( o );
			return vec3( T.instanceColor );

		} )() },
		g2_instance: { stage: 'vertex', object: () => instancedMesh( true ), make: ( o ) => Fn( () => {

			T.instance( o.instanceMatrix, o.instanceColor );
			return T.positionLocal.add( T.instanceColor );

		} )() },
		g2_instance_large: { stage: 'vertex', limit: 64, object: () => instancedMesh( false ), make: ( o ) => Fn( () => {

			T.instance( o.instanceMatrix );
			return T.positionLocal;

		} )() },
		g2_reference_attribute: { stage: 'vertex', object: () => instancedMesh( true ), make: () => T.referenceAttribute( 'instanceColor', 'vec3' ) },
		g2_batch: { stage: 'vertex', object: () => batchedMesh(), make: ( o ) => Fn( () => {

			T.batch( o );
			return T.positionLocal.add( T.normalLocal ).add( T.batchColor.xyz );

		} )() },
		// Clipping.
		g2_clipping: { clipping: true, ctx: true, make: () => Fn( () => {

			T.clipping().toStack();
			return T.diffuseColor;

		} )() },
		g2_clipping_alpha: { clipping: true, ctx: true, make: () => Fn( () => {

			T.clippingAlpha().toStack();
			return T.diffuseColor;

		} )() },
		g2_clipping_hardware: { clipping: true, ctx: true, stage: 'vertex', make: () => Fn( () => {

			T.hardwareClipping().toStack();
			return T.positionLocal;

		} )() },
		// Storage buffers (direct use), lights, more textures.
		g2_attribute_array: () => T.attributeArray( 4, 'vec3' ),
		g2_instanced_array: () => T.instancedArray( 4, 'vec4' ).toReadOnly(),
		g2_storage_buffer: () => T.storage( new THREE.StorageBufferAttribute( 4, 4 ), 'vec4', 4 ),
		g2_light_shadow_matrix: () => T.lightShadowMatrix( new THREE.SpotLight() ),
		g2_uniform_cube_texture: { ctx: true, make: () => T.uniformCubeTexture() },
		g2_texture_cube_of_node: () => cubeTexture( cubeTexture( new THREE.CubeTexture(), vec3( 1, 0, 0 ) ), vec3( 0, 0, 1 ) ),
		g2_texture_3d_normal: () => texture3D( new THREE.Data3DTexture() ).normal( vec3( 0.5 ) ),
		g2_storage_texture_3d: () => T.storageTexture3D( new THREE.Storage3DTexture( 2, 2, 2 ), T.uvec3( 1, 1, 1 ) ),
		g2_texture_blur: () => texture( tex(), vec2( 0.5 ) ).blur( 0.5 ),
		g2_sampler_comparison: () => T.samplerComparison( tex() ),
		g2_vertex_color1: () => T.vertexColor( 1 ),
		g2_position_previous: { stage: 'vertex', make: () => T.positionPrevious },
		// Array, multiview and orthographic cameras.
		g2_array_camera: { camera: () => arrayCamera( false ), make: () => T.cameraProjectionMatrix.mul( T.cameraViewMatrix ).mul( T.cameraWorldMatrix ).mul( T.cameraProjectionMatrixInverse ).mul( T.cameraNormalMatrix[ 0 ].xyzz ) },
		g2_array_camera_position: { camera: () => arrayCamera( false ), make: () => T.cameraPosition.add( T.cameraViewport.xyz ) },
		g2_array_camera_highp: { camera: () => arrayCamera( false ), make: () => T.highpModelViewMatrix.mul( T.highpModelNormalViewMatrix[ 0 ].xyzz ) },
		g2_multiview_camera: { camera: () => arrayCamera( true ), make: () => T.cameraViewMatrix.mul( T.highpModelViewMatrix ) },
		g2_array_camera_light: { camera: () => arrayCamera( false ), make: () => T.lightViewPosition( new THREE.PointLight() ) },
		g2_ortho_view_direction: { ctx: true, camera: () => new THREE.OrthographicCamera(), make: () => T.positionViewDirection },
		// More material properties (a physical material).
		g2_material_physical: { physical: true, make: () => vec4( T.materialRoughness, T.materialMetalness, T.materialClearcoat, T.materialClearcoatRoughness ).add( vec4( T.materialSheenRoughness, T.materialIridescenceThickness, T.materialTransmission, T.materialThickness ) ) },
		g2_material_physical_colors: { physical: true, make: () => T.materialEmissive.add( T.materialSheen ).add( T.materialSpecularColor ).add( T.materialAttenuationColor ) },
		g2_material_physical_floats: { physical: true, make: () => vec4( T.materialSpecularIntensity, T.materialIOR, T.materialAttenuationDistance, T.materialDispersion ).add( vec4( T.materialIridescence, T.materialIridescenceIOR, T.materialAnisotropy.x, T.materialDiffuseRoughness ) ) },
		g2_material_physical_maps: { physical: true, material: ( m ) => {

			m.roughnessMap = tex();
			m.metalnessMap = tex();
			m.emissiveMap = tex();
			m.clearcoatMap = tex();
			m.sheenRoughnessMap = tex();
			m.anisotropyMap = tex();
			m.iridescenceThicknessMap = tex();
			m.transmissionMap = tex();
			m.thicknessMap = tex();
			m.specularIntensityMap = tex();
			m.specularColorMap = tex();
			m.sheenColorMap = tex();
			m.clearcoatRoughnessMap = tex();

		}, make: () => vec4( T.materialRoughness, T.materialMetalness, T.materialClearcoat, T.materialClearcoatRoughness ).add( vec4( T.materialSheenRoughness, T.materialIridescenceThickness, T.materialTransmission, T.materialThickness ) ).add( vec4( T.materialEmissive, T.materialSpecularIntensity ) ).add( vec4( T.materialSheen.add( T.materialSpecularColor ), 1 ) ).add( vec4( T.materialAnisotropy, 0, 0 ) ) },
		g2_material_shininess: () => vec2( T.materialShininess, T.materialPointSize ).add( vec2( T.materialLineWidth, T.materialLineScale ) ).add( vec2( T.materialLineDashSize, T.materialLineGapSize ) ).add( T.materialAlphaTest ),
		g2_material_specular: () => T.materialSpecular,
		// References.
		g2_renderer_reference: () => T.rendererReference( 'toneMappingExposure', 'float' ),
		g2_reference_shadow: () => {

			const light = new THREE.SpotLight();
			return vec4( T.reference( 'bias', 'float', light.shadow ), T.reference( 'mapSize', 'vec2', light.shadow ), T.reference( 'near', 'float', light.shadow.camera ) );

		},
		g2_reference_fog: () => T.reference( 'color', 'color', new THREE.Fog( 0xff0000, 1, 2 ) ).add( T.reference( 'density', 'float', new THREE.FogExp2( 0x00ff00 ) ) ),
		g2_reference_element: () => T.reference( 'morphTargetInfluences', 'float', new THREE.Mesh() ).element( 0 ),
		g2_reference_name: () => T.materialReference( 'opacity', 'float' ).setName( 'myOpacity' ),
		g2_reference_texture: () => {

			const m = new THREE.MeshBasicMaterial();
			m.map = tex();
			return T.materialReference( 'map', 'texture', m );

		},
		// More textures.
		g2_texture_channel: () => {

			const t = tex();
			t.channel = 1;
			return texture( t );

		},
		g2_texture_refraction: { ctx: true, make: () => cubeTexture( new THREE.CubeTexture( [], THREE.CubeRefractionMapping ) ) },
		g2_texture_array_load: () => textureLoad( new THREE.DataArrayTexture(), ivec2( 1, 1 ) ).depth( 2 ),
		g2_texture_3d_level: () => T.texture3DLevel( new THREE.Data3DTexture(), vec3( 0.5 ), 1 ),
		g2_storage_texture_rw: () => storageTexture( new THREE.StorageTexture( 4, 4 ), uvec2( 1, 2 ) ).toReadWrite(),
		g2_storage_texture_store_node: () => textureStore( storageTexture( new THREE.StorageTexture( 4, 4 ) ), uvec2( 3, 4 ), T.vec4( 0, 1, 0, 1 ) ),
		g2_storage_texture_store_3d: () => textureStore( T.storageTexture3D( new THREE.Storage3DTexture( 2, 2, 2 ) ), T.uvec3( 1, 1, 1 ), T.vec4( 0, 0, 1, 1 ) ),
		// Previous-frame data (an MRT with velocity).
		g2_skinning_previous: { stage: 'vertex', velocity: true, object: () => skinnedMesh(), make: ( o ) => Fn( () => {

			T.skinning( o );
			return T.positionLocal.add( T.positionPrevious );

		} )() },
		g2_instance_previous: { stage: 'vertex', velocity: true, object: () => instancedMesh( false ), make: ( o ) => Fn( () => {

			T.instancedMesh( o );
			return T.positionLocal.add( T.positionPrevious );

		} )() },
		g2_batch_previous: { stage: 'vertex', velocity: true, object: () => batchedMesh(), make: ( o ) => Fn( () => {

			T.batch( o );
			return T.positionLocal.add( T.positionPrevious );

		} )() },
		// Storage buffer elements.
		g2_storage_element: () => T.storage( new THREE.StorageBufferAttribute( 4, 4 ), 'vec4', 4 ).element( T.instanceIndex ),
		g2_storage_element_read_only: () => T.attributeArray( 4, 'vec3' ).toReadOnly().element( int( 2 ) ),
		g2_storage_element_atomic: () => T.instancedArray( 4, 'uint' ).toAtomic().element( 1 ),
		g2_reference_attribute_storage: { stage: 'vertex', object: () => {

			const mesh = instancedMesh( false );
			mesh.instanceMatrix = new THREE.StorageInstancedBufferAttribute( new Float32Array( 48 ), 16 );
			return mesh;

		}, make: () => T.referenceAttribute( 'instanceMatrix', 'mat4' ) },
		g2_compute_skinning: { stage: 'compute', object: () => skinnedMesh(), make: ( o ) => T.computeSkinning( o ) },
		g2_instance_storage: { stage: 'vertex', object: () => {

			const mesh = instancedMesh( false );
			mesh.instanceMatrix = new THREE.StorageInstancedBufferAttribute( new Float32Array( 48 ), 16 );
			return mesh;

		}, make: ( o ) => Fn( () => {

			T.instance( o.instanceMatrix );
			return T.positionLocal;

		} )() },
		// Normal and bump maps.
		g2_material_normal: { ctx: true, make: () => T.materialNormal },
		g2_material_normal_map: { ctx: true, material: ( m ) => {

			m.normalMap = tex();

		}, make: () => T.materialNormal },
		g2_material_normal_map_rg: { ctx: true, physical: true, material: ( m ) => {

			m.normalMap = tex();
			m.normalMap.format = THREE.RGFormat;
			m.normalMapType = THREE.ObjectSpaceNormalMap;

		}, make: () => T.materialNormal },
		g2_material_bump_map: { ctx: true, material: ( m ) => {

			m.bumpMap = tex();

		}, make: () => T.materialNormal },
		g2_material_clearcoat_normal: { ctx: true, physical: true, material: ( m ) => {

			m.clearcoatNormalMap = tex();

		}, make: () => T.materialClearcoatNormal },
		// Geometry and material variants: flat shading, no tangent, no normal, morph colors.
		g2_flat_shading: { ctx: true, material: ( m ) => {

			m.flatShading = true;

		}, make: () => T.normalView.add( T.tangentView ) },
		g2_no_tangent: { ctx: true, object: ( mesh ) => {

			const g = new THREE.BufferGeometry();
			g.setAttribute( 'position', new THREE.BufferAttribute( new Float32Array( 72 ), 3 ) );
			g.setAttribute( 'normal', new THREE.BufferAttribute( new Float32Array( 72 ), 3 ) );
			g.setAttribute( 'uv', new THREE.BufferAttribute( new Float32Array( 48 ), 2 ) );
			mesh.geometry = g;
			return mesh;

		}, make: () => T.tangentView.add( T.bitangentView ) },
		g2_no_normal: { ctx: true, object: ( mesh ) => {

			const g = new THREE.BufferGeometry();
			g.setAttribute( 'position', new THREE.BufferAttribute( new Float32Array( 72 ), 3 ) );
			mesh.geometry = g;
			return mesh;

		}, make: () => T.normalLocal.add( T.normalView ) },
		g2_morph_color: { stage: 'vertex', material: ( m ) => {

			m.vertexColors = true;

		}, object: ( mesh ) => {

			const g = new THREE.BufferGeometry();
			g.setAttribute( 'position', new THREE.BufferAttribute( new Float32Array( 72 ), 3 ) );
			g.setAttribute( 'color', new THREE.BufferAttribute( new Float32Array( 72 ), 3 ) );
			g.morphAttributes.position = [ new THREE.BufferAttribute( new Float32Array( 72 ), 3 ) ];
			g.morphAttributes.color = [ new THREE.BufferAttribute( new Float32Array( 72 ), 3 ) ];
			mesh.geometry = g;
			mesh.updateMorphTargets();
			return mesh;

		}, make: ( o ) => Fn( () => {

			T.morphReference( o );
			return T.morphColor( T.vertexColor() );

		} )() },
		g2_reference_base: () => {

			const m = new THREE.MeshBasicMaterial();
			return T.reference( 'opacity', 'float', m ).add( 0 ).add( T.rendererReference( 'toneMappingExposure', 'float', renderer ) );

		},
		g2_reference_base_node: () => {

			const { reference: referenceBase } = REFERENCE_BASE;
			return referenceBase( 'opacity', 'float', new THREE.MeshBasicMaterial() );

		},
		g2_material_reference_cube: { ctx: true, material: ( m ) => {

			m.envMap = new THREE.CubeTexture();

		}, make: () => T.materialReference( 'envMap', 'cubeTexture' ) },
		g2_dynamic_buffer_attribute: { stage: 'vertex', make: () => T.dynamicBufferAttribute( new Float32Array( 96 ), 'vec4' ) },
		g2_to_attribute: { stage: 'vertex', make: () => T.attributeArray( 24, 'vec3' ).toAttribute() },
	};

	const extraRecords = {};
	const geometryFor = () => geometry;

	const records = {};
	for ( const [ name, scenario ] of Object.entries( scenarios ) ) {

		const s = typeof scenario === 'function' ? { make: scenario } : scenario;
		const material = s.physical ? new THREE.MeshPhysicalMaterial() : new THREE.MeshBasicMaterial();
		if ( s.material ) s.material( material );
		let object = new THREE.Mesh( geometryFor(), material );
		if ( s.object ) object = s.object( object );
		object.position.set( 1, 2, 3 );
		object.scale.set( 2, 2, 2 );
		object.updateMatrixWorld( true );
		const builder = new G2Builder( object, renderer );
		builder.limit = s.limit || 65536;
		if ( s.clipping ) builder.clippingContext = clippingContext();
		builder.camera = s.camera ? s.camera() : new THREE.PerspectiveCamera();
		builder.camera.position.set( 0, 1, 5 );
		builder.camera.updateMatrixWorld( true );
		renderer._mrt = s.velocity ? velocityMRT : null;
		builder.flipY = s.flipY === true;
		if ( s.ctx ) materialContext( builder );
		builder.setShaderStage( s.stage || 'fragment' );
		let flow;
		try {

			flow = builder.flowStagesNode( s.make( object ) );

		} catch ( e ) {

			records[ name ] = { error: String( e ) };
			continue;

		}
		records[ name ] = record( builder, flow );
		// The uniform values after one update of the build's update nodes.
		if ( s.noUpdate ) {

			records[ name ].values = [ 'skipped' ];
			continue;

		}

		builder.buildUpdateNodes();
		const frame = new NodeFrame();
		frame.frameId = 1;
		frame.renderId = 1;
		frame.renderer = renderer;
		frame.camera = builder.camera;
		frame.object = object;
		frame.material = material;
		frame.scene = scene;
		try {

			for ( const node of builder.updateNodes ) frame.updateNode( node );

		} catch ( e ) {

			records[ name ].values = [ 'error: ' + e.message ];
			continue;

		}
		const values = [];
		for ( const stage of [ 'vertex', 'fragment', 'compute' ] ) {

			for ( const u of builder.uniforms[ stage ] ) values.push( `${ u.name }=${ valueString( u.node.value ) }` );

		}

		records[ name ].values = values;

	}

	// The TextureNode compare paths with `renderer.hasCompatibility( TEXTURE_COMPARE )` on
	// and off (added by G6 once the MoonBit renderer had `hasCompatibility`).
	const depthTexture = ( f ) => {

		const t = new THREE.DepthTexture( 4, 4 );
		if ( f !== undefined ) t.compareFunction = f;
		return t;

	};
	const compareScenarios = {
		g2c_compare_native: { compat: true, make: () => texture( depthTexture(), vec2( 0.5 ) ).compare( 0.25 ) },
		g2c_compare_step_null: { compat: false, make: () => texture( depthTexture(), vec2( 0.5 ) ).compare( 0.25 ) },
		g2c_compare_step_less: { compat: false, make: () => texture( depthTexture( THREE.LessCompare ), vec2( 0.5 ) ).compare( 0.25 ) },
		g2c_compare_step_greater: { compat: false, make: () => texture( depthTexture( THREE.GreaterEqualCompare ), vec2( 0.5 ) ).compare( 0.25 ) },
		g2c_compare_unsupported: { compat: false, make: () => texture( depthTexture( THREE.NeverCompare ), vec2( 0.5 ) ).compare( 0.25 ) },
		g2c_compare_gather: { compat: true, make: () => texture( depthTexture(), vec2( 0.5 ) ).gather().compare( 0.25 ) },
		g2c_compare_level: { compat: true, make: () => texture( depthTexture(), vec2( 0.5 ) ).compare( 0.25 ).level( 0 ) },
	};
	const compareRenderer = new WebGPURenderer( { canvas } );
	compareRenderer._bindings = undefined;
	compareRenderer._initialized = true; // hasCompatibility() needs it
	for ( const [ name, s ] of Object.entries( compareScenarios ) ) {

		compareRenderer.backend.hasCompatibility = () => s.compat === true;
		const object = new THREE.Mesh( geometryFor(), new THREE.MeshBasicMaterial() );
		const builder = new G2Builder( object, compareRenderer );
		builder.limit = 65536;
		builder.camera = new THREE.PerspectiveCamera();
		compareRenderer._mrt = null;
		builder.flipY = false;
		builder.setShaderStage( 'fragment' );
		records[ name ] = record( builder, builder.flowStagesNode( s.make() ) );
		records[ name ].values = [ 'skipped' ];

	}

	return records;

}

// `record` of upstream.mjs plus the varyings and attributes the build declared.
function record( builder, flow ) {

	const uniforms = [];
	for ( const stage of [ 'vertex', 'fragment', 'compute' ] ) {

		for ( const u of builder.uniforms[ stage ] ) uniforms.push( `${stage}:${u.name}:${u.type}` );

	}

	const varyings = builder.varyings.map( ( v ) => `${v.name}:${v.type}` );
	const attributes = builder.attributes.map( ( a ) => `${a.name}:${a.type}` ).concat( builder.bufferAttributes.map( ( a ) => `buffer:${a.name}:${a.type}` ) );
	return { code: flow.code, result: typeof flow.result === 'string' ? flow.result : '', vars: flow.vars ?? '', uniforms, varyings, attributes };

}

// A uniform value as the MoonBit side prints it.
function valueString( v ) {

	if ( v === undefined ) return 'undefined';
	if ( v === null ) return 'null';
	if ( typeof v === 'number' || typeof v === 'boolean' ) return String( v );
	if ( v.isTexture === true ) return 'texture:' + v.name;
	if ( v.isColor === true ) return '[' + [ v.r, v.g, v.b ].map( String ).join( ',' ) + ']';
	if ( v.isMatrix2 === true || v.isMatrix3 === true || v.isMatrix4 === true ) return '[' + v.elements.map( String ).join( ',' ) + ']';
	if ( v.isVector2 === true || v.isVector3 === true || v.isVector4 === true ) return '[' + v.toArray().map( String ).join( ',' ) + ']';
	if ( ArrayBuffer.isView( v ) ) return '[' + Array.from( v ).map( String ).join( ',' ) + ']';
	if ( v.isBufferAttribute === true ) return 'attribute:' + v.count;
	return 'object';

}
