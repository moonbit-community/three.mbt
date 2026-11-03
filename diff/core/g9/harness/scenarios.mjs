// Upstream side of the G9 scenarios (the MoonBit side is mbt/main/*.mbt, step for step).
export const scenarios = {};
const scenario = ( name, f ) => { scenarios[ name ] = f; };

const renderer = ( { THREE, canvas }, antialias = false ) => new THREE.WebGPURenderer( { canvas, antialias } );
const camera = ( { THREE } ) => {
	const c = new THREE.PerspectiveCamera( 50, 1, 0.1, 10 );
	c.position.z = 3;
	return c;
};

scenario( 'init', async ( ctx ) => {
	const r = renderer( ctx );
	await r.init();
} );

scenario( 'smoke', async ( ctx ) => {
	const { THREE } = ctx;
	const r = renderer( ctx );
	await r.init();
	const scene = new THREE.Scene();
	const material = new THREE.MeshBasicNodeMaterial();
	material.color.set( 0xff0000 );
	scene.add( new THREE.Mesh( new THREE.BoxGeometry(), material ) );
	r.render( scene, camera( ctx ) );
} );

const lights = ( { THREE }, scene ) => {
	scene.add( new THREE.AmbientLight( 0x404040, 1 ) );
	const dl = new THREE.DirectionalLight( 0xffffff, 2 );
	dl.position.set( 1, 2, 3 );
	scene.add( dl );
	const pl = new THREE.PointLight( 0xff8800, 3, 10, 2 );
	pl.position.set( - 1, 1, 2 );
	scene.add( pl );
	scene.add( new THREE.HemisphereLight( 0x8888ff, 0x442200, 0.5 ) );
};

scenario( 'materials_lit', async ( ctx ) => {
	const { THREE } = ctx;
	const r = renderer( ctx );
	await r.init();
	const scene = new THREE.Scene();
	lights( ctx, scene );
	const geo = new THREE.SphereGeometry( 0.5, 8, 6 );
	const mats = [ new THREE.MeshStandardNodeMaterial(), new THREE.MeshPhysicalNodeMaterial(), new THREE.MeshPhongNodeMaterial(), new THREE.MeshLambertNodeMaterial(), new THREE.MeshToonNodeMaterial() ];
	mats.forEach( ( m, i ) => {
		m.color.setHex( 0x3366cc );
		const mesh = new THREE.Mesh( geo, m );
		mesh.position.x = i - 2;
		scene.add( mesh );
	} );
	r.render( scene, camera( ctx ) );
} );

scenario( 'materials_unlit', async ( ctx ) => {
	const { THREE } = ctx;
	const r = renderer( ctx );
	await r.init();
	const scene = new THREE.Scene();
	const geo = new THREE.BoxGeometry();
	const normal = new THREE.Mesh( geo, new THREE.MeshNormalNodeMaterial() );
	normal.position.x = - 1;
	scene.add( normal );
	scene.add( new THREE.Mesh( geo, new THREE.MeshMatcapNodeMaterial() ) );
	const lineGeo = new THREE.BufferGeometry().setAttribute( 'position', new THREE.Float32BufferAttribute( [ 0, 0, 0, 1, 1, 0, 1, 0, 0 ], 3 ) );
	scene.add( new THREE.Line( lineGeo, new THREE.LineBasicNodeMaterial() ) );
	scene.add( new THREE.LineSegments( lineGeo, new THREE.LineBasicNodeMaterial() ) );
	const points = new THREE.PointsNodeMaterial();
	points.size = 2;
	scene.add( new THREE.Points( lineGeo, points ) );
	const sprite = new THREE.Sprite( new THREE.SpriteNodeMaterial() );
	sprite.position.y = 1;
	scene.add( sprite );
	const transparent = new THREE.MeshBasicNodeMaterial();
	transparent.transparent = true;
	transparent.opacity = 0.5;
	scene.add( new THREE.Mesh( geo, transparent ) );
	const additive = new THREE.MeshBasicNodeMaterial();
	additive.blending = THREE.AdditiveBlending;
	additive.side = THREE.DoubleSide;
	scene.add( new THREE.Mesh( geo, additive ) );
	const custom = new THREE.MeshBasicNodeMaterial();
	custom.blending = THREE.CustomBlending;
	custom.blendSrc = THREE.ConstantColorFactor;
	custom.blendDst = THREE.OneMinusSrcColorFactor;
	custom.blendEquation = THREE.ReverseSubtractEquation;
	custom.blendColor.setRGB( 0.25, 0.5, 0.75 );
	custom.blendAlpha = 0.5;
	custom.side = THREE.BackSide;
	scene.add( new THREE.Mesh( geo, custom ) );
	const premultiplied = new THREE.MeshBasicNodeMaterial();
	premultiplied.blending = THREE.MultiplyBlending;
	premultiplied.premultipliedAlpha = true;
	scene.add( new THREE.Mesh( geo, premultiplied ) );
	r.render( scene, camera( ctx ) );
} );

const dataTex = ( THREE, Array, n, format, type ) => {
	const data = new Array( 4 * 4 * n );
	for ( let i = 0; i < data.length; i ++ ) data[ i ] = i % 7;
	const t = new THREE.DataTexture( data, 4, 4, format, type );
	t.needsUpdate = true;
	return t;
};

scenario( 'textures_formats', async ( ctx ) => {
	const { THREE } = ctx;
	const r = renderer( ctx );
	await r.init();
	const list = [
		dataTex( THREE, Uint8Array, 4, THREE.RGBAFormat, THREE.UnsignedByteType ),
		dataTex( THREE, Float32Array, 4, THREE.RGBAFormat, THREE.FloatType ),
		dataTex( THREE, Uint16Array, 4, THREE.RGBAFormat, THREE.HalfFloatType ),
		dataTex( THREE, Float32Array, 1, THREE.RedFormat, THREE.FloatType ),
		dataTex( THREE, Uint8Array, 2, THREE.RGFormat, THREE.UnsignedByteType ),
		dataTex( THREE, Int32Array, 1, THREE.RedIntegerFormat, THREE.IntType ),
		dataTex( THREE, Uint32Array, 4, THREE.RGBAIntegerFormat, THREE.UnsignedIntType ),
		dataTex( THREE, Int8Array, 4, THREE.RGBAFormat, THREE.ByteType ),
		dataTex( THREE, Uint32Array, 1, THREE.RGBFormat, THREE.UnsignedInt5999Type ),
		dataTex( THREE, Uint16Array, 1, THREE.RedFormat, THREE.HalfFloatType ),
		dataTex( THREE, Float32Array, 2, THREE.RGFormat, THREE.FloatType ),
	];
	list[ 0 ].colorSpace = THREE.SRGBColorSpace;
	const flipped = dataTex( THREE, Uint8Array, 4, THREE.RGBAFormat, THREE.UnsignedByteType );
	flipped.flipY = true;
	list.push( flipped );
	const mipmapped = dataTex( THREE, Uint8Array, 4, THREE.RGBAFormat, THREE.UnsignedByteType );
	mipmapped.generateMipmaps = true;
	mipmapped.minFilter = THREE.LinearMipmapLinearFilter;
	list.push( mipmapped );
	const withMips = dataTex( THREE, Uint8Array, 4, THREE.RGBAFormat, THREE.UnsignedByteType );
	withMips.mipmaps = [ { data: new Uint8Array( 64 ), width: 4, height: 4 }, { data: new Uint8Array( 16 ), width: 2, height: 2 }, { data: new Uint8Array( 4 ), width: 1, height: 1 } ];
	list.push( withMips );
	for ( const t of list ) r.initTexture( t );
	// sample one with a sampler: anisotropy and mipmaps
	const scene = new THREE.Scene();
	const m = new THREE.MeshBasicNodeMaterial();
	mipmapped.anisotropy = 4;
	mipmapped.wrapS = THREE.RepeatWrapping;
	mipmapped.wrapT = THREE.MirroredRepeatWrapping;
	m.map = mipmapped;
	scene.add( new THREE.Mesh( new THREE.PlaneGeometry(), m ) );
	const m2 = new THREE.MeshBasicNodeMaterial();
	list[ 1 ].magFilter = THREE.NearestFilter;
	list[ 1 ].wrapS = THREE.RepeatWrapping;
	list[ 1 ].wrapT = THREE.MirroredRepeatWrapping;
	m2.map = list[ 1 ];
	scene.add( new THREE.Mesh( new THREE.PlaneGeometry(), m2 ) );
	r.render( scene, camera( ctx ) );
	// switching textures back and forth reuses the cached bind groups
	m.map = list[ 0 ];
	r.render( scene, camera( ctx ) );
	m.map = mipmapped;
	r.render( scene, camera( ctx ) );
	m.map = list[ 0 ];
	r.render( scene, camera( ctx ) );
} );

scenario( 'textures_kinds', async ( ctx ) => {
	const { THREE } = ctx;
	const r = renderer( ctx );
	await r.init();
	const img = ( w, h ) => ( { width: w, height: h } );
	const cube = new THREE.CubeTexture( [ img( 2, 2 ), img( 2, 2 ), img( 2, 2 ), img( 2, 2 ), img( 2, 2 ), img( 2, 2 ) ] );
	cube.needsUpdate = true;
	const d3 = new THREE.Data3DTexture( new Uint8Array( 4 * 2 * 2 * 2 ), 2, 2, 2 );
	d3.needsUpdate = true;
	const arr = new THREE.DataArrayTexture( new Uint8Array( 4 * 2 * 2 * 3 ), 2, 2, 3 );
	arr.needsUpdate = true;
	const arr2 = new THREE.DataArrayTexture( new Uint8Array( 4 * 2 * 2 * 3 ), 2, 2, 3 );
	arr2.needsUpdate = true;
	arr2.addLayerUpdate( 1 );
	const dxt = new THREE.CompressedTexture( [ { data: new Uint8Array( 8 ), width: 4, height: 4 }, { data: new Uint8Array( 8 ), width: 2, height: 2 } ], 4, 4, THREE.RGBA_S3TC_DXT1_Format );
	dxt.needsUpdate = true;
	const astc = new THREE.CompressedTexture( [ { data: new Uint8Array( 16 ), width: 5, height: 4 } ], 5, 4, THREE.RGBA_ASTC_5x4_Format );
	astc.colorSpace = THREE.SRGBColorSpace;
	astc.needsUpdate = true;
	const carr = new THREE.CompressedArrayTexture( [ { data: new Uint8Array( 32 ), width: 4, height: 4 } ], 4, 4, 2, THREE.RGBA_ETC2_EAC_Format );
	carr.needsUpdate = true;
	const canvasTex = new THREE.CanvasTexture( img( 4, 4 ) );
	const imageTex = new THREE.Texture( img( 4, 2 ) );
	imageTex.flipY = false;
	imageTex.premultiplyAlpha = true;
	imageTex.needsUpdate = true;
	const video = img( 4, 4 );
	video.readyState = 4;
	const videoTex = new THREE.VideoTexture( video );
	for ( const t of [ cube, d3, arr, arr2, dxt, astc, carr, canvasTex, imageTex, videoTex ] ) r.initTexture( t );
	const scene = new THREE.Scene();
	const m = new THREE.MeshBasicNodeMaterial();
	m.map = imageTex;
	m.envMap = cube;
	scene.add( new THREE.Mesh( new THREE.BoxGeometry(), m ) );
	r.render( scene, camera( ctx ) );
} );

const boxScene = ( { THREE } ) => {
	const scene = new THREE.Scene();
	scene.add( new THREE.Mesh( new THREE.BoxGeometry(), new THREE.MeshBasicNodeMaterial() ) );
	return scene;
};

scenario( 'render_targets', async ( ctx ) => {
	const { THREE, TSL } = ctx;
	const r = renderer( ctx );
	await r.init();
	const scene = boxScene( ctx );
	const cam = camera( ctx );
	const rt = new THREE.RenderTarget( 4, 4 );
	r.setRenderTarget( rt );
	r.render( scene, cam );
	const mrtRT = new THREE.RenderTarget( 4, 4, { count: 2 } );
	mrtRT.textures[ 0 ].name = 'output';
	mrtRT.textures[ 1 ].name = 'normal';
	r.setMRT( TSL.mrt( { output: TSL.output, normal: TSL.vec4( TSL.normalView, 1 ) } ) );
	r.setRenderTarget( mrtRT );
	r.render( scene, cam );
	r.setMRT( null );
	const msaa = new THREE.RenderTarget( 4, 4, { samples: 4 } );
	r.setRenderTarget( msaa );
	r.render( scene, cam );
	const noResolve = new THREE.RenderTarget( 4, 4, { samples: 4, resolveDepthBuffer: false } );
	noResolve.resolveColorBuffer = false;
	r.setRenderTarget( noResolve );
	r.render( scene, cam );
	const discard = new THREE.RenderTarget( 4, 4, { samples: 4 } );
	discard.storeMultisampledColorBuffer = false;
	discard.storeMultisampledDepthBuffer = false;
	r.autoClear = false;
	r.setRenderTarget( discard );
	r.render( scene, cam );
	r.autoClear = true;
	const depthTexture = new THREE.DepthTexture( 4, 4 );
	depthTexture.format = THREE.DepthStencilFormat;
	depthTexture.type = THREE.UnsignedInt248Type;
	const ds = new THREE.RenderTarget( 4, 4, { depthTexture, stencilBuffer: true } );
	const scene2 = new THREE.Scene();
	const sm = new THREE.MeshBasicNodeMaterial();
	sm.stencilWrite = true;
	sm.stencilRef = 1;
	sm.stencilZPass = THREE.ReplaceStencilOp;
	sm.stencilFunc = THREE.AlwaysStencilFunc;
	scene2.add( new THREE.Mesh( new THREE.BoxGeometry(), sm ) );
	r.setRenderTarget( ds );
	r.render( scene2, cam );
	r.setRenderTarget( null );
	r.render( scene, cam );
} );

scenario( 'reversed_depth_nostencil', async ( ctx ) => {
	const { THREE } = ctx;
	const r = new THREE.WebGPURenderer( { canvas: ctx.canvas, reversedDepthBuffer: true } );
	await r.init();
	r.render( boxScene( ctx ), camera( ctx ) );
} );

scenario( 'msaa_canvas', async ( ctx ) => {
	const r = renderer( ctx, true );
	await r.init();
	r.render( boxScene( ctx ), camera( ctx ) );
	r.render( boxScene( ctx ), camera( ctx ) );
} );

scenario( 'reversed_depth', async ( ctx ) => {
	const { THREE } = ctx;
	const r = new THREE.WebGPURenderer( { canvas: ctx.canvas, reversedDepthBuffer: true, stencil: true } );
	await r.init();
	const scene = boxScene( ctx );
	const m = new THREE.MeshBasicNodeMaterial();
	m.polygonOffset = true;
	m.polygonOffsetFactor = 2;
	m.polygonOffsetUnits = 3;
	m.depthFunc = THREE.LessDepth;
	scene.add( new THREE.Mesh( new THREE.BoxGeometry(), m ) );
	r.render( scene, camera( ctx ) );
} );

scenario( 'geometry_draws', async ( ctx ) => {
	const { THREE } = ctx;
	const r = renderer( ctx );
	await r.init();
	const scene = new THREE.Scene();
	const cam = camera( ctx );
	const basic = () => new THREE.MeshBasicNodeMaterial();
	// non-indexed
	const tri = new THREE.BufferGeometry();
	const triPos = new THREE.Float32BufferAttribute( [ 0, 0, 0, 1, 0, 0, 0, 1, 0 ], 3 );
	tri.setAttribute( 'position', triPos );
	scene.add( new THREE.Mesh( tri, basic() ) );
	// indexed (uint32) with a normalized, padded color attribute
	const q = new THREE.BufferGeometry();
	q.setAttribute( 'position', new THREE.Float32BufferAttribute( [ 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0 ], 3 ) );
	q.setAttribute( 'color', new THREE.Uint8BufferAttribute( [ 255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 255 ], 3, true ) );
	q.setIndex( new THREE.Uint32BufferAttribute( [ 0, 1, 2, 0, 2, 3 ], 1 ) );
	const mq = basic();
	mq.vertexColors = true;
	scene.add( new THREE.Mesh( q, mq ) );
	// interleaved position + uv
	const ib = new THREE.InterleavedBuffer( new Float32Array( [ 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1 ] ), 5 );
	const ig = new THREE.BufferGeometry();
	ig.setAttribute( 'position', new THREE.InterleavedBufferAttribute( ib, 3, 0 ) );
	ig.setAttribute( 'uv', new THREE.InterleavedBufferAttribute( ib, 2, 3 ) );
	scene.add( new THREE.Mesh( ig, basic() ) );
	// instancing
	const im = new THREE.InstancedMesh( new THREE.BoxGeometry(), basic(), 3 );
	for ( let i = 0; i < 3; i ++ ) {
		im.setMatrixAt( i, new THREE.Matrix4().makeTranslation( i, 0, 0 ) );
		im.setColorAt( i, new THREE.Color( i / 3, 0.5, 1 ) );
	}
	scene.add( im );
	// indirect (indexed and not)
	const ind = new THREE.BoxGeometry();
	ind.setIndirect( new THREE.IndirectStorageBufferAttribute( new Uint32Array( [ 36, 1, 0, 0, 0 ] ), 5 ) );
	scene.add( new THREE.Mesh( ind, basic() ) );
	const ind2 = new THREE.BufferGeometry();
	ind2.setAttribute( 'position', new THREE.Float32BufferAttribute( [ 0, 0, 0, 1, 0, 0, 0, 1, 0 ], 3 ) );
	ind2.setIndirect( new THREE.IndirectStorageBufferAttribute( new Uint32Array( [ 3, 1, 0, 0 ] ), 4 ) );
	scene.add( new THREE.Mesh( ind2, basic() ) );
	// batched mesh
	const bm = new THREE.BatchedMesh( 4, 100, 200, basic() );
	const g1 = bm.addGeometry( new THREE.BoxGeometry() );
	const g2 = bm.addGeometry( new THREE.PlaneGeometry() );
	const i1 = bm.addInstance( g1 );
	const i2 = bm.addInstance( g2 );
	const i3 = bm.addInstance( g1 );
	bm.setMatrixAt( i2, new THREE.Matrix4().makeTranslation( 1, 0, 0 ) );
	bm.setMatrixAt( i3, new THREE.Matrix4().makeTranslation( - 1, 0, 0 ) );
	scene.add( bm );
	ctx.note( 'batched', [ i1, i2, i3 ] );
	r.render( scene, cam );
	// update ranges
	triPos.array[ 0 ] = 0.5;
	triPos.addUpdateRange( 0, 3 );
	triPos.needsUpdate = true;
	r.render( scene, cam );
	triPos.needsUpdate = true;
	r.render( scene, cam );
} );

scenario( 'compute_storage', async ( ctx ) => {
	const { THREE, TSL } = ctx;
	const r = renderer( ctx );
	await r.init();
	const count = 16;
	const positions = TSL.instancedArray( count, 'vec4' );
	const counter = TSL.instancedArray( 1, 'uint' ).toAtomic();
	const fn = TSL.Fn( () => {
		positions.element( TSL.instanceIndex ).assign( TSL.vec4( TSL.float( TSL.instanceIndex ), 1, 2, 3 ) );
		TSL.atomicAdd( counter.element( 0 ), 1 );
	} );
	const compute = fn().compute( count );
	r.compute( compute );
	r.compute( compute );
	const kernel = fn().computeKernel( [ 4 ] );
	r.compute( kernel, [ 2, 1, 1 ] );
	r.compute( kernel, new THREE.IndirectStorageBufferAttribute( new Uint32Array( [ 1, 1, 1 ] ), 1 ) );
	// storage texture
	const st = new THREE.StorageTexture( 4, 4 );
	const storeFn = TSL.Fn( () => {
		const x = TSL.instanceIndex.mod( 4 );
		const y = TSL.instanceIndex.div( 4 );
		TSL.textureStore( st, TSL.uvec2( x, y ), TSL.vec4( 1, 0, 0, 1 ) );
	} );
	r.compute( storeFn().compute( 16, [ 8 ] ) );
	// several compute nodes in one call
	r.compute( [ compute, storeFn().compute( 4 ) ] );
	// readback
	const buffer = await r.getArrayBufferAsync( positions.value );
	ctx.note( 'readback', buffer.byteLength );
	const rt = new THREE.RenderTarget( 4, 4 );
	r.setRenderTarget( rt );
	r.render( boxScene( ctx ), camera( ctx ) );
	r.setRenderTarget( null );
	const pixels = await r.readRenderTargetPixelsAsync( rt, 0, 0, 2, 2 );
	ctx.note( 'pixels', [ pixels.constructor.name, pixels.length ] );
	const frt = new THREE.RenderTarget( 4, 4, { type: THREE.FloatType } );
	r.setRenderTarget( frt );
	r.render( boxScene( ctx ), camera( ctx ) );
	r.setRenderTarget( null );
	const fpixels = await r.readRenderTargetPixelsAsync( frt, 1, 1, 3, 2 );
	ctx.note( 'fpixels', [ fpixels.constructor.name, fpixels.length ] );
} );

scenario( 'copies', async ( ctx ) => {
	const { THREE, TSL } = ctx;
	const r = renderer( ctx );
	await r.init();
	const src = dataTex( THREE, Uint8Array, 4, THREE.RGBAFormat, THREE.UnsignedByteType );
	const dst = dataTex( THREE, Uint8Array, 4, THREE.RGBAFormat, THREE.UnsignedByteType );
	r.initTexture( src );
	r.initTexture( dst );
	r.copyTextureToTexture( src, dst );
	r.copyTextureToTexture( src, dst, new THREE.Box2( new THREE.Vector2( 1, 1 ), new THREE.Vector2( 3, 3 ) ), new THREE.Vector2( 0, 1 ) );
	const mipDst = dataTex( THREE, Uint8Array, 4, THREE.RGBAFormat, THREE.UnsignedByteType );
	mipDst.generateMipmaps = true;
	mipDst.minFilter = THREE.LinearMipmapLinearFilter;
	r.initTexture( mipDst );
	r.copyTextureToTexture( src, mipDst );
	const a = new THREE.Data3DTexture( new Uint8Array( 4 * 8 ), 2, 2, 2 );
	a.needsUpdate = true;
	const b = new THREE.Data3DTexture( new Uint8Array( 4 * 8 ), 2, 2, 2 );
	b.needsUpdate = true;
	r.initTexture( a );
	r.initTexture( b );
	r.copyTextureToTexture( a, b, new THREE.Box3( new THREE.Vector3( 0, 0, 0 ), new THREE.Vector3( 1, 1, 2 ) ), new THREE.Vector3( 1, 1, 0 ), 0, 0 );
	// framebuffer copies: of a render target, of the canvas output, and in a render
	const scene = boxScene( ctx );
	const cam = camera( ctx );
	const rt = new THREE.RenderTarget( 4, 4 );
	r.setRenderTarget( rt );
	r.render( scene, cam );
	const fb = new THREE.FramebufferTexture( 4, 4 );
	r.copyFramebufferToTexture( fb );
	r.setRenderTarget( null );
	r.render( scene, cam );
	const fb2 = new THREE.FramebufferTexture( 2, 2 );
	r.copyFramebufferToTexture( fb2, new THREE.Vector4( 1, 1, 2, 2 ) );
	const m = new THREE.MeshBasicNodeMaterial();
	m.colorNode = TSL.viewportSharedTexture();
	const scene2 = boxScene( ctx );
	scene2.add( new THREE.Mesh( new THREE.PlaneGeometry(), m ) );
	r.render( scene2, cam );
	r.setRenderTarget( rt );
	r.render( scene2, cam );
} );

const tick = () => new Promise( ( r ) => setTimeout( r, 0 ) );

scenario( 'bundles', async ( ctx ) => {
	const { THREE } = ctx;
	const r = renderer( ctx );
	await r.init();
	const scene = new THREE.Scene();
	const group = new THREE.BundleGroup();
	group.add( new THREE.Mesh( new THREE.BoxGeometry(), new THREE.MeshBasicNodeMaterial() ) );
	const m2 = new THREE.Mesh( new THREE.SphereGeometry( 0.5, 6, 4 ), new THREE.MeshBasicNodeMaterial() );
	m2.position.x = 1;
	group.add( m2 );
	scene.add( group );
	scene.add( new THREE.Mesh( new THREE.PlaneGeometry(), new THREE.MeshBasicNodeMaterial() ) );
	const cam = camera( ctx );
	r.render( scene, cam );
	r.render( scene, cam );
	group.needsUpdate = true;
	r.render( scene, cam );
} );

scenario( 'timestamps', async ( ctx ) => {
	const { THREE, TSL } = ctx;
	const r = new THREE.WebGPURenderer( { canvas: ctx.canvas, trackTimestamp: true } );
	await r.init();
	const cam = camera( ctx );
	r.render( boxScene( ctx ), cam );
	const values = TSL.instancedArray( 4, 'float' );
	const c = TSL.Fn( () => {
		values.element( TSL.instanceIndex ).assign( 1 );
	} )().compute( 4 );
	r.compute( c );
	ctx.note( 'render', await r.resolveTimestampsAsync( 'render' ) );
	ctx.note( 'compute', await r.resolveTimestampsAsync( 'compute' ) );
	r.render( boxScene( ctx ), cam );
	r.render( boxScene( ctx ), cam );
	ctx.note( 'render2', await r.resolveTimestampsAsync() );
	ctx.note( 'frames', r.backend.getTimestampFrames( 'render' ) );
} );

scenario( 'occlusion', async ( ctx ) => {
	const { THREE } = ctx;
	const r = renderer( ctx );
	await r.init();
	const scene = new THREE.Scene();
	const a = new THREE.Mesh( new THREE.BoxGeometry(), new THREE.MeshBasicNodeMaterial() );
	a.occlusionTest = true;
	scene.add( a );
	const b = new THREE.Mesh( new THREE.PlaneGeometry(), new THREE.MeshBasicNodeMaterial() );
	scene.add( b );
	const c = new THREE.Mesh( new THREE.PlaneGeometry(), new THREE.MeshBasicNodeMaterial() );
	c.occlusionTest = true;
	c.position.z = - 1;
	scene.add( c );
	const cam = camera( ctx );
	r.render( scene, cam );
	r.render( scene, cam );
	await tick();
	ctx.note( 'occluded', [ r.isOccluded( a ) === true, r.isOccluded( b ) === true, r.isOccluded( c ) === true ] );
	a.occlusionTest = false;
	c.occlusionTest = false;
	r.render( scene, cam );
	r.render( scene, cam );
} );

scenario( 'shadows', async ( ctx ) => {
	const { THREE } = ctx;
	const r = renderer( ctx );
	r.shadowMap.enabled = true;
	await r.init();
	const scene = new THREE.Scene();
	const dl = new THREE.DirectionalLight( 0xffffff, 1 );
	dl.position.set( 2, 3, 1 );
	dl.castShadow = true;
	dl.shadow.mapSize.set( 16, 16 );
	scene.add( dl );
	const spot = new THREE.SpotLight( 0xffffff, 2 );
	spot.position.set( - 2, 3, 1 );
	spot.castShadow = true;
	spot.shadow.mapSize.set( 8, 8 );
	scene.add( spot );
	const point = new THREE.PointLight( 0xffffff, 2 );
	point.position.set( 0, 2, 2 );
	point.castShadow = true;
	point.shadow.mapSize.set( 8, 8 );
	scene.add( point );
	const box = new THREE.Mesh( new THREE.BoxGeometry(), new THREE.MeshStandardNodeMaterial() );
	box.castShadow = true;
	box.receiveShadow = true;
	scene.add( box );
	const plane = new THREE.Mesh( new THREE.PlaneGeometry( 4, 4 ), new THREE.MeshStandardNodeMaterial() );
	plane.position.y = - 1;
	plane.receiveShadow = true;
	scene.add( plane );
	const cam = camera( ctx );
	r.render( scene, cam );
	r.render( scene, cam );
} );

scenario( 'background_env', async ( ctx ) => {
	const { THREE } = ctx;
	const r = renderer( ctx );
	await r.init();
	const scene = boxScene( ctx );
	scene.background = new THREE.Color( 0x112233 );
	const cam = camera( ctx );
	r.render( scene, cam );
	const data = new Uint8Array( 8 * 4 * 4 );
	for ( let i = 0; i < data.length; i ++ ) data[ i ] = ( i * 13 ) % 255;
	const env = new THREE.DataTexture( data, 8, 4 );
	env.mapping = THREE.EquirectangularReflectionMapping;
	env.needsUpdate = true;
	const scene2 = new THREE.Scene();
	scene2.environment = env;
	if ( ctx.name === 'background_texture' ) scene2.background = env;
	const m = new THREE.MeshStandardNodeMaterial();
	m.roughness = 0.5;
	scene2.add( new THREE.Mesh( new THREE.SphereGeometry( 0.5, 8, 6 ), m ) );
	r.render( scene2, cam );
} );

scenarios.background_texture = scenarios.background_env;

scenario( 'postprocessing', async ( ctx ) => {
	const { THREE, TSL } = ctx;
	const r = renderer( ctx );
	await r.init();
	const scene = boxScene( ctx );
	const cam = camera( ctx );
	const pp = new THREE.RenderPipeline( r );
	const scenePass = TSL.pass( scene, cam );
	pp.outputNode = scenePass.mul( 0.5 );
	pp.render();
	pp.render();
} );

scenario( 'clearing', async ( ctx ) => {
	const { THREE } = ctx;
	const r = new THREE.WebGPURenderer( { canvas: ctx.canvas, stencil: true } );
	await r.init();
	r.autoClear = false;
	r.setClearColor( 0x336699, 0.5 );
	r.clear();
	r.clearColor();
	r.clearDepth();
	r.clearStencil();
	r.clear( true, false, true );
	r.render( boxScene( ctx ), camera( ctx ) );
	const depthTexture = new THREE.DepthTexture( 4, 4 );
	const rt = new THREE.RenderTarget( 4, 4, { stencilBuffer: true, depthTexture } );
	depthTexture.format = THREE.DepthStencilFormat;
	depthTexture.type = THREE.UnsignedInt248Type;
	r.setRenderTarget( rt );
	r.clear();
	r.setClearColor( 0xff0000, 1 );
	r.clear( true, true, false );
	r.render( boxScene( ctx ), camera( ctx ) );
	r.setRenderTarget( null );
	r.autoClear = true;
	r.setClearAlpha( 0.25 );
	r.render( boxScene( ctx ), camera( ctx ) );
} );

scenario( 'resize', async ( ctx ) => {
	const r = renderer( ctx );
	await r.init();
	const scene = boxScene( ctx );
	const cam = camera( ctx );
	r.render( scene, cam );
	r.setSize( 8, 6, false );
	r.render( scene, cam );
	r.setPixelRatio( 2 );
	r.render( scene, cam );
	r.setViewport( 1, 1, 2, 2 );
	r.setScissor( 0, 0, 3, 3 );
	r.setScissorTest( true );
	r.render( scene, cam );
} );

scenario( 'dispose', async ( ctx ) => {
	const { THREE } = ctx;
	const r = renderer( ctx );
	await r.init();
	const scene = new THREE.Scene();
	const geo = new THREE.BoxGeometry();
	const mat = new THREE.MeshBasicNodeMaterial();
	const tex = dataTex( THREE, Uint8Array, 4, THREE.RGBAFormat, THREE.UnsignedByteType );
	mat.map = tex;
	const mesh = new THREE.Mesh( geo, mat );
	scene.add( mesh );
	const cam = camera( ctx );
	const rt = new THREE.RenderTarget( 4, 4, { samples: 4 } );
	r.setRenderTarget( rt );
	r.render( scene, cam );
	r.setRenderTarget( null );
	r.render( scene, cam );
	tex.dispose();
	geo.dispose();
	mat.dispose();
	rt.dispose();
	r.render( scene, cam );
	scene.remove( mesh );
	r.render( scene, cam );
	await r.dispose();
} );

scenario( 'compile_async', async ( ctx ) => {
	const { THREE } = ctx;
	const r = renderer( ctx );
	await r.init();
	const scene = boxScene( ctx );
	scene.add( new THREE.Mesh( new THREE.SphereGeometry( 0.5, 6, 4 ), new THREE.MeshPhongNodeMaterial() ) );
	const cam = camera( ctx );
	await r.compileAsync( scene, cam );
	r.render( scene, cam );
} );

scenario( 'pipeline_errors', async ( ctx ) => {
	const r = renderer( ctx );
	await r.init();
	const cam = camera( ctx );
	r.render( boxScene( ctx ), cam );
	await tick();
	const scene = boxScene( ctx );
	await r.compileAsync( scene, cam );
	r.render( scene, cam );
} );

scenario( 'compatibility', async ( ctx ) => {
	const { THREE } = ctx;
	const r = renderer( ctx, true );
	await r.init();
	ctx.note( 'compatibilityMode', r.backend.compatibilityMode );
	const scene = boxScene( ctx );
	const depthTexture = new THREE.DepthTexture( 4, 4 );
	const rt = new THREE.RenderTarget( 4, 4, { depthTexture, count: 2 } );
	r.setRenderTarget( rt );
	r.render( scene, camera( ctx ) );
	r.setRenderTarget( null );
	const m = new THREE.MeshBasicNodeMaterial();
	m.map = depthTexture;
	scene.add( new THREE.Mesh( new THREE.PlaneGeometry(), m ) );
	r.render( scene, camera( ctx ) );
} );

scenario( 'features', async ( ctx ) => {
	const { THREE } = ctx;
	const r = renderer( ctx );
	await r.init();
	ctx.note( 'features', [ r.hasFeature( 'float32-filterable' ), r.hasFeature( 'texture-compression-s3tc' ), r.hasFeature( 'timestamp-query' ) ] );
	const f = dataTex( THREE, Float32Array, 4, THREE.RGBAFormat, THREE.FloatType );
	const n = dataTex( THREE, Int16Array, 4, THREE.RGBAFormat, THREE.ShortType );
	n.normalized = true;
	const ds = new THREE.DepthTexture( 4, 4 );
	ds.format = THREE.DepthStencilFormat;
	ds.type = THREE.FloatType;
	const scene = new THREE.Scene();
	for ( const t of [ f, n ] ) {
		const m = new THREE.MeshBasicNodeMaterial();
		m.map = t;
		scene.add( new THREE.Mesh( new THREE.PlaneGeometry(), m ) );
	}
	const rt = new THREE.RenderTarget( 4, 4, { depthTexture: ds, stencilBuffer: true } );
	r.setRenderTarget( rt );
	r.render( scene, camera( ctx ) );
} );

scenario( 'instancing_dispose', async ( ctx ) => {
	const { THREE } = ctx;
	const r = renderer( ctx );
	await r.init();
	const scene = new THREE.Scene();
	const m = new THREE.MeshBasicNodeMaterial();
	m.color.setHex( 0x3399ff );
	const instanced = new THREE.InstancedMesh( new THREE.BoxGeometry( 0.4, 0.4, 0.4 ), m, 5 );
	for ( let i = 0; i < 5; i ++ ) {
		instanced.setMatrixAt( i, new THREE.Matrix4().makeTranslation( ( i - 2 ) * 0.6, 0, 0 ) );
		instanced.setColorAt( i, new THREE.Color( i / 4, 1 - i / 4, 0.5 ) );
	}
	scene.add( instanced );
	const target = new THREE.RenderTarget( 4, 4 );
	r.setRenderTarget( target );
	r.render( scene, camera( ctx ) );
	instanced.setMatrixAt( 0, new THREE.Matrix4().makeTranslation( 0, 1, 0 ) );
	instanced.instanceMatrix.needsUpdate = true;
	r.render( scene, camera( ctx ) );
	const pixels = await r.readRenderTargetPixelsAsync( target, 0, 0, 4, 4 );
	ctx.note( 'pixels', pixels.length );
	await r.dispose();
} );

scenario( 'device_lost', async ( ctx ) => {
	const r = renderer( ctx );
	await r.init();
	r.render( boxScene( ctx ), camera( ctx ) );
	ctx.mock.uncapturedError( r.backend.device, 'mock uncaptured' );
	ctx.mock.loseDevice( r.backend.device, 'unknown', 'mock loss' );
	await tick();
	ctx.note( 'lost', r._isDeviceLost === true );
} );

scenario( 'no_adapter', async ( ctx ) => {
	const r = renderer( ctx );
	let error = null;
	try {
		await r.init();
	} catch ( e ) {
		error = 'rejected';
	}
	ctx.note( 'init', [ error, r.backend.isWebGLBackend === true ] );
} );
