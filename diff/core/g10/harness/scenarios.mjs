// Upstream side of each G10 scenario: returns the mock's log. The MoonBit side of a
// scenario is the test "g10diff <name>" in src/renderers/webgl_fallback/g10_diff_test.mbt.
import { M, makeRenderer, createMockGL, makeCanvas, installFrames } from './common.mjs';

const T = () => M.TSL;

function box( material ) {

	return new M.Mesh( new M.BoxGeometry( 1, 1, 1 ), material );

}

function camera() {

	const c = new M.PerspectiveCamera( 50, 2, 0.1, 100 );
	c.position.set( 0, 0, 3 );
	return c;

}

// Scenarios whose difference is outside renderers/webgl_fallback (see their comments);
// run.mjs reports them as KNOWN instead of failing.
export const known = [];

export const scenarios = {

	async compute_pbo_render() {

		const { renderer, gl } = await makeRenderer();
		const { Fn, storage, instanceIndex, float, vec4, int } = T();
		const data = new M.StorageBufferAttribute( new Float32Array( 6 ), 1 );
		const writeNode = storage( data, 'float', 6 );
		const readNode = storage( data, 'float', 6 ).setPBO( true );
		const scene = new M.Scene();
		const material = new M.MeshBasicNodeMaterial();
		material.colorNode = vec4( readNode.element( int( 2 ) ) );
		scene.add( box( material ) );
		renderer.render( scene, camera() );
		const kernel = Fn( () => {

			writeNode.element( instanceIndex ).assign( float( instanceIndex ).add( 1 ) );

		} )().compute( 6 );
		renderer.compute( kernel );
		renderer.render( scene, camera() );
		return gl.__log;

	},

	async compile_async_parallel() {

		const { renderer, gl } = await makeRenderer();
		const scene = new M.Scene();
		scene.add( box( new M.MeshPhongNodeMaterial() ) );
		scene.add( new M.PointLight( 0xffffff, 1 ) );
		await renderer.compileAsync( scene, camera() );
		gl.__note( 'compiled', true );
		renderer.render( scene, camera() );
		return gl.__log;

	},

	async user_context() {

		const gl = createMockGL( {} );
		installFrames( gl );
		const canvas = makeCanvas( gl );
		const renderer = new M.WebGPURenderer( { canvas, context: gl, forceWebGL: true } );
		await renderer.init();
		const scene = new M.Scene();
		scene.add( box( new M.MeshBasicNodeMaterial() ) );
		renderer.render( scene, camera() );
		await renderer.dispose();
		return gl.__log;

	},


	async compute_transform_feedback() {

		const { renderer, gl } = await makeRenderer();
		const { Fn, storage, instanceIndex, float, uniform, vec4 } = T();
		const a = new M.StorageBufferAttribute( new Float32Array( 8 ), 1 );
		const b = new M.StorageBufferAttribute( new Float32Array( 8 * 4 ), 4 );
		const k = uniform( 2 );
		const aNode = storage( a, 'float', 8 );
		const bNode = storage( b, 'vec4', 8 );
		const kernel = Fn( () => {

			aNode.element( instanceIndex ).assign( float( instanceIndex ).mul( k ) );
			bNode.element( instanceIndex ).assign( vec4( aNode.element( instanceIndex ) ) );

		} )().compute( 8 );
		renderer.compute( kernel );
		k.value = 3;
		renderer.compute( kernel );
		const buffer = await renderer.getArrayBufferAsync( a );
		gl.__note( 'readback', Array.from( new Float32Array( buffer ) ) );
		return gl.__log;

	},

	async compute_then_render() {

		const { renderer, gl } = await makeRenderer();
		const { Fn, storage, instanceIndex, float, vec3, positionLocal } = T();
		const offsets = new M.StorageInstancedBufferAttribute( new Float32Array( 3 * 3 ), 3 );
		const offsetNode = storage( offsets, 'vec3', 3 );
		const kernel = Fn( () => {

			offsetNode.element( instanceIndex ).assign( vec3( float( instanceIndex ), 0, 0 ) );

		} )().compute( 3 );
		renderer.compute( kernel );
		const scene = new M.Scene();
		const material = new M.MeshBasicNodeMaterial();
		material.positionNode = positionLocal.add( offsetNode.toAttribute() );
		const mesh = new M.InstancedMesh( new M.BoxGeometry(), material, 3 );
		scene.add( mesh );
		renderer.render( scene, camera() );
		return gl.__log;

	},

	async queries() {

		const { renderer, gl } = await makeRenderer( { parameters: { trackTimestamp: true } }, { extensions: [ 'EXT_color_buffer_float', 'WEBGL_multi_draw', 'EXT_disjoint_timer_query_webgl2', 'KHR_parallel_shader_compile' ], queries: { available: true, result: 0 } } );
		const scene = new M.Scene();
		const a = box( new M.MeshBasicNodeMaterial() ); a.occlusionTest = true; scene.add( a );
		const b = box( new M.MeshBasicNodeMaterial() ); b.occlusionTest = true; b.position.x = 1; scene.add( b );
		renderer.render( scene, camera() );
		gl.__note( 'occluded', renderer.isOccluded( a ) );
		renderer.render( scene, camera() );
		gl.__note( 'occluded', renderer.isOccluded( a ) );
		gl.__note( 'hasTimestamp', renderer.backend.hasTimestamp );
		const t = await renderer.resolveTimestampsAsync( 'render' );
		gl.__note( 'timestamp', t );
		return gl.__log;

	},

	async background_environment() {

		const { renderer, gl } = await makeRenderer();
		const scene = new M.Scene();
		scene.background = new M.Color( 0x112233 );
		scene.add( box( new M.MeshStandardNodeMaterial() ) );
		renderer.render( scene, camera() );
		const env = new M.DataTexture( new Uint8Array( 4 * 4 ), 2, 2 );
		env.mapping = M.EquirectangularReflectionMapping;
		env.needsUpdate = true;
		scene.environment = env;
		renderer.render( scene, camera() );
		return gl.__log;

	},

	// Known difference outside this package: with a cube texture as `scene.environment`,
	// upstream uploads the cube before PMREMGenerator renders from it, MoonBit renders
	// first (common PMREM / Textures order, groups G3/G6/G7).
	async environment_cube() {

		const { renderer, gl } = await makeRenderer();
		const scene = new M.Scene();
		const face = () => ( { data: new Uint8Array( 4 * 4 ), width: 2, height: 2 } );
		const cube = new M.CubeTexture( [ face(), face(), face(), face(), face(), face() ] );
		cube.needsUpdate = true;
		scene.environment = cube;
		scene.add( box( new M.MeshStandardNodeMaterial() ) );
		renderer.render( scene, camera() );
		return gl.__log;

	},

	async background_cube() {

		const { renderer, gl } = await makeRenderer();
		const scene = new M.Scene();
		const face = () => ( { data: new Uint8Array( 4 * 4 ), width: 2, height: 2 } );
		const cube = new M.CubeTexture( [ face(), face(), face(), face(), face(), face() ] );
		cube.needsUpdate = true;
		scene.background = cube;
		scene.add( box( new M.MeshBasicNodeMaterial() ) );
		renderer.render( scene, camera() );
		return gl.__log;

	},

	async fog_tone_mapping() {

		const { renderer, gl } = await makeRenderer();
		renderer.toneMapping = M.ACESFilmicToneMapping;
		renderer.toneMappingExposure = 1.5;
		const scene = new M.Scene();
		scene.fog = new M.Fog( 0x888888, 1, 10 );
		scene.add( box( new M.MeshStandardNodeMaterial() ) );
		scene.add( new M.DirectionalLight( 0xffffff, 1 ) );
		renderer.render( scene, camera() );
		scene.fog = new M.FogExp2( 0x888888, 0.1 );
		renderer.toneMapping = M.AgXToneMapping;
		renderer.outputColorSpace = M.LinearSRGBColorSpace;
		renderer.render( scene, camera() );
		return gl.__log;

	},

	async post_processing() {

		const { renderer, gl } = await makeRenderer();
		const scene = new M.Scene();
		scene.add( box( new M.MeshBasicNodeMaterial( { color: 0x00ff00 } ) ) );
		const cam = camera();
		const pipeline = new M.RenderPipeline( renderer );
		const scenePass = T().pass( scene, cam );
		pipeline.outputNode = scenePass.getTextureNode().mul( 0.5 );
		pipeline.render();
		pipeline.render();
		return gl.__log;

	},

	async clear_resize_dispose() {

		const { renderer, gl } = await makeRenderer( { parameters: { stencil: true } } );
		renderer.setClearColor( 0x334455, 0.5 );
		renderer.clear();
		renderer.clear( true, false, true );
		renderer.setClearDepth( 0.5 );
		renderer.setClearStencil( 3 );
		renderer.clearDepth();
		renderer.clearStencil();
		const rt = new M.RenderTarget( 4, 4, { stencilBuffer: true } );
		renderer.setRenderTarget( rt );
		renderer.clear();
		renderer.setRenderTarget( null );
		renderer.setPixelRatio( 2 );
		renderer.setSize( 100, 50, false );
		renderer.setViewport( 10, 10, 50, 20 );
		renderer.setScissor( 5, 5, 20, 10 );
		renderer.setScissorTest( true );
		const scene = new M.Scene();
		scene.add( box( new M.MeshBasicNodeMaterial() ) );
		renderer.render( scene, camera() );
		renderer.setScissorTest( false );
		rt.dispose();
		await renderer.dispose();
		gl.__note( 'disposed', true );
		return gl.__log;

	},

	async cube_render_target() {

		const { renderer, gl } = await makeRenderer();
		const scene = new M.Scene();
		scene.add( box( new M.MeshBasicNodeMaterial() ) );
		const crt = new M.CubeRenderTarget( 8 );
		const cubeCamera = new M.CubeCamera( 0.1, 10, crt );
		cubeCamera.update( renderer, scene );
		const array = new M.RenderTarget( 4, 4, { depth: 2 } );
		array.texture.isArrayTexture = true;
		renderer.setRenderTarget( array, 1 );
		renderer.render( scene, camera() );
		renderer.setRenderTarget( null );
		return gl.__log;

	},


	async textures_formats() {

		const { renderer, gl } = await makeRenderer();
		const scene = new M.Scene();
		const make = ( data, format, type, opts = {} ) => {

			const t = new M.DataTexture( data, 2, 2, format, type );
			Object.assign( t, opts );
			t.needsUpdate = true;
			return t;

		};

		const textures = [
			make( new Uint8Array( 16 ), M.RGBAFormat, M.UnsignedByteType, { colorSpace: M.SRGBColorSpace, flipY: true, anisotropy: 4, wrapS: M.RepeatWrapping, wrapT: M.MirroredRepeatWrapping, minFilter: M.LinearMipmapLinearFilter, magFilter: M.LinearFilter, generateMipmaps: true } ),
			make( new Float32Array( 16 ), M.RGBAFormat, M.FloatType, { magFilter: M.NearestFilter } ),
			make( new Uint16Array( 8 ), M.RGFormat, M.HalfFloatType ),
			make( new Uint8Array( 4 ), M.RedFormat, M.UnsignedByteType, { generateMipmaps: true, minFilter: M.LinearMipmapLinearFilter, magFilter: M.LinearFilter } ),
			make( new Uint32Array( 4 ), M.RedIntegerFormat, M.UnsignedIntType ),
			make( new Uint8Array( 16 ), M.RGBAFormat, M.UnsignedByteType, { premultiplyAlpha: true, unpackAlignment: 1 } ),
		];
		textures.forEach( ( t, i ) => {

			const m = new M.MeshBasicNodeMaterial();
			if ( i === 4 ) m.colorNode = T().vec4( T().textureLoad( t, T().ivec2( 0, 0 ) ) );
			else m.map = t;
			const o = box( m ); o.position.x = i; scene.add( o );

		} );
		renderer.render( scene, camera() );
		textures[ 0 ].needsUpdate = true;
		renderer.render( scene, camera() );
		return gl.__log;

	},

	async textures_kinds() {

		const { renderer, gl } = await makeRenderer();
		const scene = new M.Scene();
		const face = () => ( { data: new Uint8Array( 4 * 4 ), width: 2, height: 2 } );
		const cube = new M.CubeTexture( [ face(), face(), face(), face(), face(), face() ] );
		cube.needsUpdate = true;
		const tex3d = new M.Data3DTexture( new Uint8Array( 2 * 2 * 2 * 4 ), 2, 2, 2 );
		tex3d.needsUpdate = true;
		const array = new M.DataArrayTexture( new Uint8Array( 2 * 2 * 3 * 4 ), 2, 2, 3 );
		array.needsUpdate = true;
		const compressed = new M.CompressedTexture( [ { data: new Uint8Array( 8 ), width: 4, height: 4 }, { data: new Uint8Array( 8 ), width: 2, height: 2 } ], 4, 4, M.RGBA_S3TC_DXT1_Format );
		compressed.needsUpdate = true;
		const mats = [
			Object.assign( new M.MeshBasicNodeMaterial(), { colorNode: T().cubeTexture( cube, T().normalView ) } ),
			Object.assign( new M.MeshBasicNodeMaterial(), { colorNode: T().texture3D( tex3d, T().vec3( 0.5 ) ) } ),
			Object.assign( new M.MeshBasicNodeMaterial(), { colorNode: T().texture( array, T().uv() ).depth( 1 ) } ),
			Object.assign( new M.MeshBasicNodeMaterial(), { map: compressed } ),
		];
		mats.forEach( ( m, i ) => { const o = box( m ); o.position.x = i; scene.add( o ); } );
		renderer.render( scene, camera() );
		return gl.__log;

	},

	async render_targets() {

		const { renderer, gl } = await makeRenderer();
		const scene = new M.Scene();
		scene.add( box( new M.MeshBasicNodeMaterial( { color: 0x336699 } ) ) );
		const rt = new M.RenderTarget( 8, 8, { depthBuffer: true } );
		rt.depthTexture = new M.DepthTexture( 8, 8 );
		renderer.setRenderTarget( rt );
		renderer.render( scene, camera() );
		renderer.setRenderTarget( null );
		const quad = new M.Scene();
		const show = new M.MeshBasicNodeMaterial(); show.map = rt.texture;
		quad.add( box( show ) );
		renderer.render( quad, camera() );
		const msaa = new M.RenderTarget( 8, 8, { samples: 4 } );
		renderer.setRenderTarget( msaa );
		renderer.render( scene, camera() );
		renderer.setRenderTarget( null );
		const pixels = await renderer.readRenderTargetPixelsAsync( rt, 0, 0, 2, 2 );
		gl.__note( 'pixels', Array.from( pixels ) );
		return gl.__log;

	},

	async render_targets_mrt() {

		const { renderer, gl } = await makeRenderer();
		const scene = new M.Scene();
		scene.add( box( new M.MeshStandardNodeMaterial() ) );
		scene.add( new M.DirectionalLight( 0xffffff, 1 ) );
		const rt = new M.RenderTarget( 8, 8, { count: 2 } );
		rt.textures[ 0 ].name = 'output';
		rt.textures[ 1 ].name = 'normal';
		renderer.setMRT( T().mrt( { output: T().output, normal: T().vec4( T().normalView, 1 ) } ) );
		renderer.setRenderTarget( rt );
		renderer.render( scene, camera() );
		const msaa = new M.RenderTarget( 8, 8, { count: 2, samples: 4 } );
		msaa.textures[ 0 ].name = 'output';
		msaa.textures[ 1 ].name = 'normal';
		renderer.setRenderTarget( msaa );
		renderer.render( scene, camera() );
		renderer.setRenderTarget( null );
		renderer.setMRT( null );
		return gl.__log;

	},

	async copies() {

		const { renderer, gl } = await makeRenderer();
		const scene = new M.Scene();
		scene.add( box( new M.MeshBasicNodeMaterial() ) );
		renderer.render( scene, camera() );
		const fbTexture = new M.FramebufferTexture( 16, 16 );
		renderer.copyFramebufferToTexture( fbTexture, new M.Vector2( 4, 4 ) );
		const src = new M.DataTexture( new Uint8Array( 4 * 4 * 4 ), 4, 4 );
		src.needsUpdate = true;
		const dst = new M.DataTexture( new Uint8Array( 8 * 8 * 4 ), 8, 8 );
		dst.needsUpdate = true;
		renderer.initTexture( src );
		renderer.initTexture( dst );
		renderer.copyTextureToTexture( src, dst, null, new M.Vector2( 2, 2 ) );
		renderer.copyTextureToTexture( src, dst, new M.Box2( new M.Vector2( 1, 1 ), new M.Vector2( 3, 3 ) ), new M.Vector2( 0, 0 ) );
		return gl.__log;

	},

	async geometry_kinds() {

		const { renderer, gl } = await makeRenderer();
		const scene = new M.Scene();
		const inst = new M.InstancedMesh( new M.BoxGeometry(), new M.MeshBasicNodeMaterial(), 3 );
		for ( let i = 0; i < 3; i ++ ) inst.setMatrixAt( i, new M.Matrix4().makeTranslation( i, 0, 0 ) );
		scene.add( inst );
		const nonIndexed = new M.BoxGeometry().toNonIndexed();
		nonIndexed.setDrawRange( 3, 12 );
		scene.add( new M.Mesh( nonIndexed, new M.MeshBasicNodeMaterial() ) );
		const interleavedGeometry = new M.BufferGeometry();
		const ib = new M.InterleavedBuffer( new Float32Array( [ 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 1 ] ), 6 );
		interleavedGeometry.setAttribute( 'position', new M.InterleavedBufferAttribute( ib, 3, 0 ) );
		interleavedGeometry.setAttribute( 'normal', new M.InterleavedBufferAttribute( ib, 3, 3 ) );
		scene.add( new M.Mesh( interleavedGeometry, new M.MeshNormalNodeMaterial() ) );
		const grouped = new M.BoxGeometry();
		scene.add( new M.Mesh( grouped, [ new M.MeshBasicNodeMaterial( { color: 0xff0000 } ), new M.MeshBasicNodeMaterial( { color: 0x00ff00 } ) ] ) );
		renderer.render( scene, camera() );
		return gl.__log;

	},

	async batched_mesh() {

		const out = [];
		for ( const extensions of [ undefined, [ 'EXT_color_buffer_float' ] ] ) {

			const { renderer, gl } = await makeRenderer( {}, extensions ? { extensions } : {} );
			const scene = new M.Scene();
			const batched = new M.BatchedMesh( 4, 200, 400, new M.MeshBasicNodeMaterial() );
			const g0 = batched.addGeometry( new M.BoxGeometry() );
			const g1 = batched.addGeometry( new M.PlaneGeometry() );
			const i0 = batched.addInstance( g0 );
			const i1 = batched.addInstance( g1 );
			batched.addInstance( g0 );
			batched.setMatrixAt( i1, new M.Matrix4().makeTranslation( 2, 0, 0 ) );
			batched.setColorAt( i0, new M.Color( 1, 0, 0 ) );
			scene.add( batched );
			renderer.render( scene, camera() );
			out.push( ...gl.__log );

		}

		return out;

	},


	async init_options() {

		const { renderer, gl } = await makeRenderer( { parameters: { antialias: true, stencil: true, reversedDepthBuffer: true } } );
		gl.__note( 'samples', renderer.samples );
		gl.__note( 'reversedDepthBuffer', renderer.reversedDepthBuffer );
		gl.__note( 'maxAnisotropy', renderer.getMaxAnisotropy() );
		gl.__note( 'hasTimestamp', renderer.backend.hasTimestamp );
		const scene = new M.Scene();
		scene.add( box( new M.MeshBasicNodeMaterial() ) );
		renderer.render( scene, camera() );
		return gl.__log;

	},

	async init_no_extensions() {

		const { renderer, gl } = await makeRenderer( { parameters: { reversedDepthBuffer: true, samples: 2 } }, { extensions: [] } );
		gl.__note( 'reversedDepthBuffer', renderer.reversedDepthBuffer );
		gl.__note( 'maxAnisotropy', renderer.getMaxAnisotropy() );
		gl.__note( 'float32Filterable', renderer.hasFeature( 'float32-filterable' ) );
		const scene = new M.Scene();
		scene.add( box( new M.MeshBasicNodeMaterial() ) );
		renderer.render( scene, camera() );
		return gl.__log;

	},

	async materials_unlit() {

		const { renderer, gl } = await makeRenderer();
		const scene = new M.Scene();
		const mats = [ new M.MeshBasicNodeMaterial( { color: 0x00ff00, transparent: true, opacity: 0.5 } ), new M.MeshNormalNodeMaterial(), new M.MeshMatcapNodeMaterial(), new M.LineBasicNodeMaterial(), new M.PointsNodeMaterial( { size: 3 } ), new M.SpriteNodeMaterial() ];
		const m0 = box( mats[ 0 ] ); m0.position.x = - 1; scene.add( m0 );
		const m1 = box( mats[ 1 ] ); m1.material.side = M.DoubleSide; scene.add( m1 );
		const m2 = box( mats[ 2 ] ); m2.scale.x = - 1; scene.add( m2 );
		const lineGeometry = new M.BufferGeometry().setFromPoints( [ new M.Vector3( 0, 0, 0 ), new M.Vector3( 1, 1, 0 ), new M.Vector3( 1, 0, 0 ) ] );
		scene.add( new M.Line( lineGeometry, mats[ 3 ] ) );
		scene.add( new M.LineSegments( lineGeometry, new M.LineBasicNodeMaterial() ) );
		scene.add( new M.LineLoop( lineGeometry, new M.LineBasicNodeMaterial() ) );
		scene.add( new M.Points( lineGeometry, mats[ 4 ] ) );
		scene.add( new M.Sprite( mats[ 5 ] ) );
		const wire = box( new M.MeshBasicNodeMaterial( { wireframe: true } ) ); scene.add( wire );
		renderer.render( scene, camera() );
		return gl.__log;

	},

	async materials_lit() {

		const { renderer, gl } = await makeRenderer();
		const scene = new M.Scene();
		scene.add( new M.AmbientLight( 0x404040, 1 ) );
		const dir = new M.DirectionalLight( 0xffffff, 2 ); dir.position.set( 1, 2, 3 ); scene.add( dir );
		const point = new M.PointLight( 0xff8800, 3, 10, 2 ); point.position.set( - 1, 1, 1 ); scene.add( point );
		const spot = new M.SpotLight( 0x88ff00, 2, 20, Math.PI / 6, 0.2, 2 ); spot.position.set( 0, 3, 0 ); scene.add( spot );
		scene.add( new M.HemisphereLight( 0x8888ff, 0x442200, 0.5 ) );
		const mats = [ new M.MeshLambertNodeMaterial(), new M.MeshPhongNodeMaterial( { shininess: 50 } ), new M.MeshStandardNodeMaterial( { roughness: 0.3, metalness: 0.7 } ), new M.MeshPhysicalNodeMaterial( { clearcoat: 1 } ), new M.MeshToonNodeMaterial() ];
		mats.forEach( ( m, i ) => { const o = box( m ); o.position.x = i - 2; scene.add( o ); } );
		renderer.render( scene, camera() );
		return gl.__log;

	},

	async shadows() {

		const { renderer, gl } = await makeRenderer();
		renderer.shadowMap.enabled = true;
		const scene = new M.Scene();
		const dir = new M.DirectionalLight( 0xffffff, 2 ); dir.position.set( 1, 2, 3 ); dir.castShadow = true; dir.shadow.mapSize.set( 64, 64 ); scene.add( dir );
		const spot = new M.SpotLight( 0xffffff, 2 ); spot.position.set( 0, 3, 0 ); spot.castShadow = true; spot.shadow.mapSize.set( 32, 32 ); scene.add( spot );
		const caster = box( new M.MeshStandardNodeMaterial() ); caster.castShadow = true; scene.add( caster );
		const ground = box( new M.MeshStandardNodeMaterial() ); ground.receiveShadow = true; ground.position.y = - 1; scene.add( ground );
		renderer.render( scene, camera() );
		return gl.__log;

	},

	async shadows_point() {

		const { renderer, gl } = await makeRenderer();
		renderer.shadowMap.enabled = true;
		const scene = new M.Scene();
		const point = new M.PointLight( 0xffffff, 2, 10 ); point.position.set( 0, 2, 0 ); point.castShadow = true; point.shadow.mapSize.set( 16, 16 ); scene.add( point );
		const caster = box( new M.MeshPhongNodeMaterial() ); caster.castShadow = true; caster.receiveShadow = true; scene.add( caster );
		renderer.render( scene, camera() );
		return gl.__log;

	},


	async init_basic() {

		const { renderer, gl } = await makeRenderer();
		gl.__note( 'coordinateSystem', renderer.coordinateSystem );
		gl.__note( 'hasFeature multi_draw', renderer.hasFeature( 'WEBGL_multi_draw' ) );
		gl.__note( 'hasFeature timestamp', renderer.hasFeature( 'timestamp-query' ) );
		return gl.__log;

	},

	async render_basic() {

		const { renderer, gl } = await makeRenderer();
		const scene = new M.Scene();
		scene.add( box( new M.MeshBasicNodeMaterial( { color: 0xff0000 } ) ) );
		renderer.render( scene, camera() );
		gl.__note( 'frame', 2 );
		renderer.render( scene, camera() );
		return gl.__log;

	},

};
