// Upstream side of the G6 scenarios; src/nodes/common_g6_diff_test.mbt mirrors each.
import { M, align, installFrames, createRenderer, createStubBackend, info, contextState, nodeMaterial, box } from './common.mjs';

const v4 = ( v ) => [ v.x, v.y, v.z, v.w ];

function mesh( name, material, geometry = box() ) {

	const m = new M.Mesh( geometry, material );
	m.name = name;
	return m;

}

export const scenarios = {

	async init_size( log ) {

		installFrames( log );
		align( log );
		const renderer = await createRenderer( log );
		log.push( [ 'created', renderer.initialized, renderer.samples, renderer.getPixelRatio(), renderer.coordinateSystem ] );
		await renderer.init();
		log.push( [ 'init', renderer.initialized, ...info( renderer ) ] );
		renderer.setPixelRatio( 2 );
		renderer.setSize( 200, 100 );
		const v = new M.Vector2(); renderer.getSize( v );
		const d = new M.Vector2(); renderer.getDrawingBufferSize( d );
		const canvas = renderer.domElement;
		log.push( [ 'size', v.x, v.y, d.x, d.y, canvas.width, canvas.height, canvas.style.width ] );
		renderer.setViewport( 10, 20, 50, 40 );
		renderer.setScissor( 5, 5, 30, 30 );
		renderer.setScissorTest( true );
		const vp = new M.Vector4(); renderer.getViewport( vp );
		const sc = new M.Vector4(); renderer.getScissor( sc );
		log.push( [ 'viewport', v4( vp ), v4( sc ), renderer.getScissorTest() ] );
		renderer.setClearColor( new M.Color( 0.2, 0.4, 0.6 ), 0.5 );
		const c = renderer.getClearColor( new M.Color( 0, 0, 0 ) );
		log.push( [ 'clearColor', c.r, c.g, c.b, renderer.getClearAlpha() ] );
		renderer.clear();
		renderer.setClearColor( 0xff0000 );
		renderer.setClearAlpha( 0.25 );
		renderer.setClearDepth( 0.5 );
		renderer.setClearStencil( 3 );
		renderer.clearColor();
		renderer.clearDepth();
		renderer.clearStencil();
		const rt = new M.RenderTarget( 16, 8 );
		renderer.setRenderTarget( rt );
		renderer.clear();
		renderer.setRenderTarget( null );
		renderer.outputColorSpace = M.LinearSRGBColorSpace;
		renderer.clear();
		renderer.reversedDepthBuffer = true;
		log.push( [ 'state', renderer.getClearDepth(), renderer.getClearStencil(), renderer.needsFrameBufferTarget, renderer.currentSamples, renderer.getMaxAnisotropy(), renderer.hasFeature( 'feature' ), renderer.hasCompatibility( 'compat' ), renderer.getContext() ] );
		renderer.resetState();
		renderer.setDrawingBufferSize( 50, 25, 1 );
		renderer.getDrawingBufferSize( d );
		log.push( [ 'drawingBuffer', d.x, d.y, ...info( renderer ) ] );

	},


	async render_scene( log ) {

		installFrames( log );
		align( log );
		const renderer = await createRenderer( log );
		await renderer.init();
		renderer.setSize( 64, 32, false );
		renderer.outputColorSpace = M.LinearSRGBColorSpace;
		const scene = new M.Scene(); scene.name = 'scene';
		const camera = new M.PerspectiveCamera( 50, 2, 0.1, 100 ); camera.position.set( 0, 0, 5 ); camera.name = 'camera';
		const light = new M.DirectionalLight(); scene.add( light );
		const opaque = mesh( 'opaque', nodeMaterial( 'opaqueMat' ) ); opaque.position.set( 0, 0, - 1 );
		opaque.onBeforeRender = ( r, s, c, g, m ) => log.push( [ 'onBeforeRender', opaque.name, s.id, c.id, m.name, r === renderer ] );
		opaque.onAfterRender = ( r, s, c, g, m ) => log.push( [ 'onAfterRender', opaque.name, m.name ] );
		const opaque2 = mesh( 'opaque2', nodeMaterial( 'opaqueMat2' ) ); opaque2.position.set( 0.5, 0, - 3 ); opaque2.renderOrder = 1;
		const transparent = mesh( 'transparent', nodeMaterial( 'transparentMat', ( m ) => { m.transparent = true; } ) ); transparent.position.z = 0.5;
		const doubleT = mesh( 'doubleT', nodeMaterial( 'doubleMat', ( m ) => { m.transparent = true; m.side = M.DoubleSide; } ) );
		const backdrop = mesh( 'backdrop', nodeMaterial( 'backdropMat', ( m ) => { m.backdropNode = M.TSL.vec3( 1 ); } ) );
		const geometry = box(); geometry.addGroup( 0, 3, 0 ); geometry.addGroup( 3, 3, 1 );
		const multi = mesh( 'multi', [ nodeMaterial( 'groupA' ), nodeMaterial( 'groupB' ) ], geometry );
		const group = new M.Group(); group.renderOrder = 2; group.name = 'group'; group.add( multi );
		const sprite = new M.Sprite( nodeMaterial( 'spriteMat' ) ); sprite.name = 'sprite'; sprite.position.set( - 0.5, 0, 0 );
		const lod = new M.LOD(); lod.name = 'lod';
		lod.addLevel( mesh( 'lodNear', nodeMaterial( 'lodNearMat' ) ), 0 );
		lod.addLevel( mesh( 'lodFar', nodeMaterial( 'lodFarMat' ) ), 3 );
		const culled = mesh( 'culled', nodeMaterial( 'culledMat' ) ); culled.position.set( 1000, 0, 0 );
		const hidden = mesh( 'hidden', nodeMaterial( 'hiddenMat' ) ); hidden.layers.set( 2 );
		const invisible = mesh( 'invisible', nodeMaterial( 'invisibleMat' ) ); invisible.visible = false;
		const noMat = mesh( 'noMat', nodeMaterial( 'invisibleMaterial', ( m ) => { m.visible = false; } ) );
		scene.add( opaque, opaque2, transparent, doubleT, backdrop, group, sprite, lod, culled, hidden, invisible, noMat );
		renderer.render( scene, camera );
		log.push( [ 'frame1', ...info( renderer ) ] );
		renderer.render( scene, camera );
		log.push( [ 'frame2', ...info( renderer ) ] );
		// custom sort and render object function
		renderer.setOpaqueSort( ( a, b ) => b.id - a.id );
		renderer.setRenderObjectFunction( ( object, s, c, g, m, gr, lightsNode, cc, passId ) => {

			log.push( [ 'renderObjectFunction', object.name, m.name, passId ] );
			renderer.renderObject( object, s, c, g, m, gr, lightsNode, cc, passId );

		} );
		renderer.transparent = false;
		renderer.render( scene, camera );
		renderer.setRenderObjectFunction( null );
		renderer.setOpaqueSort( null );
		renderer.transparent = true;
		renderer.opaque = false;
		renderer.sortObjects = false;
		renderer.render( scene, camera );
		renderer.opaque = true;
		renderer.sortObjects = true;
		// an array camera
		const left = new M.PerspectiveCamera( 50, 1, 0.1, 100 ); left.position.set( - 1, 0, 5 ); left.updateMatrixWorld();
		const right = new M.PerspectiveCamera( 50, 1, 0.1, 100 ); right.position.set( 1, 0, 5 ); right.updateMatrixWorld();
		const arrayCamera = new M.ArrayCamera( [ left, right ] ); arrayCamera.position.set( 0, 0, 5 );
		renderer.render( scene, arrayCamera );
		// another camera, orthographic
		const ortho = new M.OrthographicCamera( - 2, 2, 1, - 1, 0.1, 10 ); ortho.position.set( 0, 0, 3 );
		renderer.render( scene, ortho );
		log.push( [ 'end', ...info( renderer ), !! renderer.isOccluded( opaque ) ] );

	},

	async render_targets( log ) {

		installFrames( log );
		align( log );
		const renderer = await createRenderer( log );
		await renderer.init();
		renderer.setSize( 32, 32, false );
		const scene = new M.Scene();
		const camera = new M.PerspectiveCamera( 50, 1, 0.1, 100 ); camera.position.set( 0, 0, 5 );
		scene.add( mesh( 'a', nodeMaterial( 'aMat' ) ) );
		// a render target with a depth texture
		const rt = new M.RenderTarget( 16, 16, { depthTexture: new M.DepthTexture( 16, 16 ) } );
		rt.viewport.set( 2, 2, 8, 8 ); rt.scissor.set( 1, 1, 30, 4 ); rt.scissorTest = true;
		renderer.setRenderTarget( rt );
		renderer.autoClearDepth = false;
		renderer.render( scene, camera );
		renderer.autoClearDepth = true;
		// MRT
		const mrtTarget = new M.RenderTarget( 8, 8, { count: 2 } );
		renderer.setRenderTarget( mrtTarget );
		renderer.setMRT( M.TSL.mrt( { output: M.TSL.output, emissive: M.TSL.vec4( 1 ) } ) );
		renderer.render( scene, camera );
		renderer.setMRT( null );
		// a cube render target, every face, two mips
		const cube = new M.CubeRenderTarget( 8, { generateMipmaps: true, minFilter: M.LinearMipmapLinearFilter } );
		log.push( [ 'cube', cube.isCubeRenderTarget, cube.texture.isCubeTexture, cube.texture.isRenderTargetTexture, cube.texture.image.length, cube.texture.generateMipmaps, cube.texture.minFilter ] );
		for ( let face = 0; face < 6; face ++ ) {

			renderer.setRenderTarget( cube, face, face % 2 );
			log.push( [ 'face', renderer.getActiveCubeFace(), renderer.getActiveMipmapLevel() ] );
			renderer.render( scene, camera );

		}

		cube.clear( renderer, true, false, true );
		renderer.setRenderTarget( null );
		// an output render target with tone mapping
		const out = new M.RenderTarget( 20, 10 );
		renderer.setOutputRenderTarget( out );
		renderer.toneMapping = M.ACESFilmicToneMapping;
		renderer.render( scene, camera );
		log.push( [ 'output', renderer.isOutputTarget, renderer.currentToneMapping, renderer.currentColorSpace, renderer.needsFrameBufferTarget ] );
		renderer.setRenderTarget( rt );
		log.push( [ 'target', renderer.isOutputTarget, renderer.currentToneMapping, renderer.currentColorSpace, renderer.currentSamples ] );
		renderer.setRenderTarget( null );
		renderer.setOutputRenderTarget( null );
		renderer.render( scene, camera );
		renderer.initRenderTarget( new M.RenderTarget( 4, 4 ) );
		rt.dispose();
		out.dispose();
		log.push( [ 'end', ...info( renderer ) ] );

	},

	async background_fog( log ) {

		installFrames( log );
		align( log );
		const renderer = await createRenderer( log );
		await renderer.init();
		renderer.setSize( 16, 16, false );
		const scene = new M.Scene();
		const camera = new M.PerspectiveCamera( 50, 1, 0.1, 100 ); camera.position.set( 0, 0, 5 );
		scene.add( mesh( 'a', nodeMaterial( 'aMat' ) ) );
		renderer.render( scene, camera );
		scene.background = new M.Color( 0.25, 0.5, 0.75 );
		renderer.autoClear = false;
		renderer.render( scene, camera );
		renderer.autoClear = true;
		scene.fog = new M.Fog( 0xffffff, 1, 10 );
		renderer.render( scene, camera );
		const tex = new M.DataTexture( new Uint8Array( 16 ), 2, 2 );
		tex.mapping = M.EquirectangularReflectionMapping;
		scene.background = tex;
		scene.backgroundBlurriness = 0.5;
		renderer.render( scene, camera );
		const cubeTex = new M.CubeTexture( [ 1, 2, 3, 4, 5, 6 ].map( () => ( { width: 4, height: 4 } ) ) );
		scene.background = cubeTex;
		renderer.render( scene, camera );
		scene.backgroundNode = M.TSL.vec3( 0.5 );
		renderer.render( scene, camera );
		scene.backgroundNode = null;
		scene.background = null;
		renderer.toneMapping = M.ReinhardToneMapping;
		renderer.outputColorSpace = M.SRGBColorSpace;
		renderer.render( scene, camera );
		renderer.render( scene, camera );
		renderer.toneMappingExposure = 2;
		renderer.toneMapping = M.NoToneMapping;
		renderer.render( scene, camera );
		renderer.alpha = false;
		renderer.setClearColor( 0x336699, 0.5 );
		renderer.outputColorSpace = M.LinearSRGBColorSpace;
		renderer.render( scene, camera );
		log.push( [ 'end', ...info( renderer ) ] );

	},


	async compute_copy( log ) {

		installFrames( log );
		align( log );
		const renderer = await createRenderer( log );
		const early = M.TSL.Fn( () => {} )().compute( 2 );
		await renderer.computeAsync( early );
		log.push( [ 'computeAsync', ...info( renderer ) ] );
		const a = M.TSL.Fn( () => {} )().compute( 4 );
		const b = M.TSL.Fn( () => {} )().compute( 8, [ 32 ] );
		let inits = 0;
		a.onInit( () => { inits ++; } );
		renderer.compute( a );
		renderer.compute( a );
		renderer.compute( [ a, b ] );
		await renderer.compileComputeAsync( M.TSL.Fn( () => {} )().compute( 1 ) );
		log.push( [ 'compute', inits, ...info( renderer ) ] );
		renderer.setSize( 16, 8, false );
		renderer.outputColorSpace = M.LinearSRGBColorSpace;
		const fb = new M.FramebufferTexture( 16, 8 );
		renderer.copyFramebufferToTexture( fb );
		renderer.copyFramebufferToTexture( fb, new M.Vector4( 1.5, 2.5, 4, 4 ) );
		renderer.copyFramebufferToTexture( fb, new M.Vector2( 3, 1 ) );
		const rt = new M.RenderTarget( 8, 8 );
		renderer.setRenderTarget( rt );
		renderer.copyFramebufferToTexture( new M.FramebufferTexture( 8, 8 ) );
		renderer.setRenderTarget( null );
		renderer.outputColorSpace = M.SRGBColorSpace;
		renderer.copyFramebufferToTexture( fb );
		const src = new M.DataTexture( new Uint8Array( 64 ), 4, 4 );
		const dst = new M.DataTexture( new Uint8Array( 64 ), 4, 4 );
		renderer.copyTextureToTexture( src, dst );
		renderer.copyTextureToTexture( src, dst, new M.Box2( new M.Vector2( 1, 1 ), new M.Vector2( 3, 3 ) ), new M.Vector2( 0, 1 ), 0, 1 );
		const pixels = await renderer.readRenderTargetPixelsAsync( rt, 1, 2, 3, 4 );
		log.push( [ 'pixels', Array.from( pixels ) ] );
		const attribute = new M.StorageBufferAttribute( 4, 4 );
		const readback = new M.ReadbackBuffer( 64 ); readback.name = 'readback';
		const buffer = await renderer.getArrayBufferAsync( attribute, readback, 4, 8 );
		await renderer.getArrayBufferAsync( attribute, readback );
		log.push( [ 'arrayBuffer', buffer.byteLength, ...info( renderer ) ] );
		readback.dispose();
		log.push( [ 'readbackDisposed', ...info( renderer ) ] );
		a.dispose();
		renderer.compute( a );
		log.push( [ 'end', inits, ...info( renderer ) ] );

	},

	async info_dispose( log ) {

		const frames = installFrames( log );
		align( log );
		const renderer = await createRenderer( log, { antialias: true } );
		await renderer.init();
		renderer.setSize( 8, 8, false );
		const scene = new M.Scene();
		const camera = new M.PerspectiveCamera(); camera.position.z = 3;
		const geometry = box();
		const material = nodeMaterial( 'm' );
		const a = mesh( 'a', material, geometry );
		scene.add( a );
		renderer.render( scene, camera );
		log.push( [ 'render', frames.length, ...info( renderer ) ] );
		frames[ 0 ]( 16 );
		log.push( [ 'frame', frames.length, ...info( renderer ) ] );
		renderer.info.autoReset = false;
		renderer.render( scene, camera );
		frames[ 1 ]( 32 );
		log.push( [ 'noReset', ...info( renderer ) ] );
		renderer.info.autoReset = true;
		const loops = [];
		await renderer.setAnimationLoop( ( t ) => loops.push( t ) );
		frames[ frames.length - 1 ]( 48 );
		log.push( [ 'loop', loops, renderer.getAnimationLoop() !== null ] );
		await renderer.setAnimationLoop( null );
		material.dispose();
		renderer.render( scene, camera );
		geometry.dispose();
		renderer.render( scene, camera );
		const xr = renderer.xr;
		log.push( [ 'xr', xr.enabled, xr.isPresenting, xr.cameraAutoUpdate, xr.getCamera().isArrayCamera, xr.getCamera().cameras.length, xr.getEnvironmentBlendMode() ?? null, xr.getFoveation(), xr.getFramebufferScaleFactor(), xr.getReferenceSpaceType(), xr.getReferenceSpace(), xr.getSession(), xr.getFrame(), xr.useMultiview(), xr.getBaseLayer() ?? null ] );
		xr.setFoveation( 0.5 );
		xr.setFramebufferScaleFactor( 2 );
		xr.setReferenceSpaceType( 'local' );
		const controller = xr.getController( 1 );
		log.push( [ 'controller', controller.id, xr.getControllerGrip( 1 ).id, xr.getHand( 0 ).id, xr.getController( 1 ) === controller ] );
		const layerScene = new M.Scene();
		layerScene.add( mesh( 'layerMesh', nodeMaterial( 'layerMat' ) ) );
		const plane = xr.createQuadLayer( 1, 1, new M.Vector3( 0, 0, - 1 ), new M.Quaternion(), 8, 8, () => renderer.render( layerScene, camera ) );
		log.push( [ 'quadLayer', plane.id, plane.material.map.id, plane.material.map.offset.y, plane.material.map.repeat.y, plane.material.side ] );
		const cylinder = xr.createCylinderLayer( 1, Math.PI / 2, 2, new M.Vector3( 0, 0, - 1 ), new M.Quaternion(), 4, 4, () => log.push( [ 'cylinder render' ] ), { stencil: true, samples: 2 } );
		log.push( [ 'cylinderLayer', cylinder.id, cylinder.material.side, cylinder.geometry.attributes.position.count ] );
		xr.renderLayers();
		xr.updateCamera( camera );
		log.push( [ 'afterLayers', renderer.getRenderTarget(), ...info( renderer ) ] );
		await renderer.dispose();
		log.push( [ 'disposed', ...info( renderer ) ] );

	},

	async pipelines( log ) {

		installFrames( log );
		align( log );
		const renderer = await createRenderer( log );
		await renderer.init();
		renderer.setSize( 16, 16, false );
		const scene = new M.Scene();
		const camera = new M.PerspectiveCamera(); camera.position.z = 3;
		scene.add( mesh( 'a', nodeMaterial( 'aMat' ) ) );
		const scenePass = M.TSL.pass( scene, camera );
		const pipeline = new M.RenderPipeline( renderer, scenePass );
		pipeline.render();
		pipeline.render();
		renderer.toneMapping = M.AgXToneMapping;
		pipeline.render();
		const frame = renderer._nodes.nodeFrame;
		frame.renderer = renderer;
		scenePass.updateBefore( frame );
		log.push( [ 'pass', scenePass.renderTarget.width, scenePass.renderTarget.height, scenePass.renderTarget.texture.id ] );
		pipeline.outputColorTransform = false;
		pipeline.needsUpdate = true;
		pipeline.render();
		pipeline.dispose();
		const post = new M.PostProcessing( renderer );
		post.render();
		const direct = new M.DirectRenderPipeline( renderer );
		scene.background = new M.Color( 0x112233 );
		direct.render( scene, camera );
		direct.render( scene, camera );
		log.push( [ 'direct', scene.backgroundNode ?? null, renderer.contextNode === direct._contextNode, renderer.toneMapping ] );
		const quad = new M.QuadMesh( nodeMaterial( 'quadMat' ) );
		quad.render( renderer );
		quad.material = nodeMaterial( 'quadMat2' );
		quad.render( renderer );
		log.push( [ 'quad', quad.isQuadMesh, quad.camera.isOrthographicCamera, quad.geometry.attributes.uv.array.join( ',' ), quad.material.vertexNode ] );
		log.push( [ 'end', ...info( renderer ) ] );

	},

	async pmrem( log ) {

		installFrames( log );
		align( log );
		const renderer = await createRenderer( log );
		await renderer.init();
		const generator = new M.PMREMGenerator( renderer );
		const scene = new M.Scene();
		scene.add( mesh( 'a', nodeMaterial( 'aMat' ) ) );
		const fromScene = generator.fromScene( scene, 0.04, 0.1, 100, { size: 64 } );
		log.push( [ 'fromScene', fromScene.width, fromScene.texture.mipmaps.length, fromScene.texture.name, fromScene.texture.isPMREMTexture, scene.background ] );
		const equirect = new M.DataTexture( new Uint8Array( 4 * 512 * 4 ), 512, 4 );
		const fromEquirect = generator.fromEquirectangular( equirect );
		log.push( [ 'fromEquirectangular', fromEquirect.width, fromEquirect.texture.mipmaps.length ] );
		const cubemap = new M.CubeTexture( [ 1, 2, 3, 4, 5, 6 ].map( () => ( { width: 128, height: 128 } ) ) );
		const fromCube = generator.fromCubemap( cubemap, fromEquirect );
		log.push( [ 'fromCubemap', fromCube === fromEquirect, M.PMREMGenerator.lodToRoughness( 2, 5 ) ] );
		generator.dispose();
		log.push( [ 'end', ...info( renderer ) ] );

	},

	async bundles_compile( log ) {

		installFrames( log );
		align( log );
		const renderer = await createRenderer( log, {}, { bundles: true } );
		await renderer.init();
		renderer.setSize( 16, 16, false );
		renderer.outputColorSpace = M.LinearSRGBColorSpace;
		const scene = new M.Scene();
		const camera = new M.PerspectiveCamera(); camera.position.z = 3;
		const bundle = new M.BundleGroup(); bundle.name = 'bundle';
		bundle.add( mesh( 'inBundle', nodeMaterial( 'bundleMat' ) ) );
		scene.add( bundle, mesh( 'outside', nodeMaterial( 'outsideMat' ) ) );
		renderer.render( scene, camera );
		renderer.render( scene, camera );
		bundle.needsUpdate = true;
		renderer.render( scene, camera );
		const compiled = new M.Scene();
		compiled.add( mesh( 'compiled', nodeMaterial( 'compiledMat', ( m ) => { m.transparent = true; m.side = M.DoubleSide; } ) ) );
		compiled.add( new M.PointLight() );
		await renderer.compileAsync( compiled, camera );
		log.push( [ 'compiled', ...info( renderer ) ] );
		renderer.render( compiled, camera );
		const target = new M.Scene();
		target.add( new M.DirectionalLight() );
		const single = mesh( 'single', nodeMaterial( 'singleMat' ) );
		await renderer.compile( single, camera, target );
		// override material and the shadow pass material
		const override = nodeMaterial( 'override', ( m ) => { m.depthWrite = false; } );
		scene.overrideMaterial = override;
		renderer.render( scene, camera );
		scene.overrideMaterial = null;
		log.push( [ 'end', ...info( renderer ) ] );

	},


	async utils_misc( log ) {

		installFrames( log );
		align( log );
		const fallbackLog = [];
		const renderer = await createRenderer( log, { getFallback: ( error ) => { log.push( [ 'fallback', error.message ] ); const b = createStubBackend( log ); return b; } }, { failInit: true } );
		await renderer.init();
		log.push( [ 'init', renderer.initialized, renderer.backend.isWebGPUBackend, fallbackLog.length ] );
		const failing = await createRenderer( log, {}, { failInit: true } );
		let failed = null;
		try { await failing.init(); } catch ( e ) { failed = e.message; }
		try { await failing.init(); } catch ( e ) { failed += '|' + e.message; }
		log.push( [ 'failed', failed, failing.initialized ] );
		// RendererUtils
		const U = M.RendererUtils;
		renderer.setClearColor( 0x00ff00, 0.5 );
		renderer.autoClearColor = false;
		renderer.toneMapping = M.CineonToneMapping;
		const rt = new M.RenderTarget( 4, 4 );
		renderer.setRenderTarget( rt, 2, 1 );
		const scene = new M.Scene();
		scene.background = new M.Color( 1, 0, 0 );
		scene.overrideMaterial = nodeMaterial( 'ov' );
		const state = U.resetRendererAndSceneState( renderer, scene );
		const c = renderer.getClearColor( new M.Color() );
		log.push( [ 'reset', [ state.toneMapping, state.activeCubeFace, state.activeMipmapLevel, state.pixelRatio, state.clearColor.r, state.clearColor.g, state.clearAlpha, state.autoClearColor, state.scissorTest, state.renderTarget === rt, state.background.r, state.overrideMaterial.name ],
			[ c.r, c.g, renderer.getClearAlpha(), renderer.autoClearColor, scene.background, scene.overrideMaterial ] ] );
		renderer.setRenderTarget( null );
		renderer.toneMapping = M.NoToneMapping;
		U.restoreRendererAndSceneState( renderer, scene, state );
		log.push( [ 'restored', renderer.toneMapping, renderer.getRenderTarget() === rt, renderer.getActiveCubeFace(), renderer.getActiveMipmapLevel(), renderer.getClearAlpha(), renderer.autoClearColor, scene.background.r, scene.overrideMaterial.name ] );
		const saved = U.saveRendererState( renderer );
		U.restoreRendererState( renderer, saved );
		U.restoreSceneState( scene, U.resetSceneState( scene ) );
		renderer.setRenderTarget( null );
		scene.overrideMaterial = null;
		renderer.toneMapping = M.NoToneMapping;
		renderer.autoClearColor = true;
		// high precision
		log.push( [ 'highPrecision', renderer.highPrecision ] );
		renderer.highPrecision = true;
		log.push( [ 'highPrecision', renderer.highPrecision ] );
		renderer.highPrecision = false;
		log.push( [ 'highPrecision', renderer.highPrecision ] );
		// canvas targets
		const canvas2 = { style: {}, width: 40, height: 20 };
		const target = new M.CanvasTarget( canvas2 );
		renderer.setCanvasTarget( target );
		renderer.setSize( 10, 5 );
		renderer.setPixelRatio( 2 );
		log.push( [ 'canvasTarget', renderer.getCanvasTarget() === target, canvas2.width, canvas2.height, canvas2.style.width ] );
		renderer.outputColorSpace = M.LinearSRGBColorSpace;
		const camera = new M.PerspectiveCamera(); camera.position.z = 3;
		const a = mesh( 'a', nodeMaterial( 'aMat' ) );
		scene.add( a );
		renderer.render( scene, camera );
		target.dispose();
		// shader of an object
		const shaders = await renderer.debug.getShaderAsync( scene, camera, a );
		log.push( [ 'shaders', shaders.vertexShader, shaders.fragmentShader ] );
		// a shadow pass material
		const shadowScene = new M.Scene();
		const sources = [
			nodeMaterial( 'plain' ),
			nodeMaterial( 'colored', ( m ) => { m.colorNode = M.TSL.vec4( 1, 0, 0, 0.5 ); } ),
			nodeMaterial( 'mapped', ( m ) => { m.map = new M.Texture(); m.side = M.BackSide; } ),
			nodeMaterial( 'masked', ( m ) => { m.maskNode = M.TSL.bool( true ); m.shadowSide = M.DoubleSide; } ),
			nodeMaterial( 'cast', ( m ) => { m.castShadowNode = M.TSL.vec4( 0.5 ); m.positionNode = M.TSL.vec3( 1 ); m.depthNode = M.TSL.float( 0.5 ); } ),
		];
		for ( const m of sources ) shadowScene.add( mesh( 'shadow_' + m.name, m ) );
		const shadowMaterial = nodeMaterial( 'ShadowMaterial', ( m ) => { m.isShadowPassMaterial = true; } );
		shadowScene.overrideMaterial = shadowMaterial;
		renderer.render( shadowScene, camera );
		renderer.shadowMap.type = M.VSMShadowMap;
		renderer.render( shadowScene, camera );
		renderer.shadowMap.type = M.PCFSoftShadowMap;
		renderer.render( shadowScene, camera );
		log.push( [ 'shadow', renderer.shadowMap.type, shadowMaterial.side, shadowMaterial.colorNode, shadowMaterial.positionNode, ...info( renderer ) ] );
		// reversed depth
		renderer.reversedDepthBuffer = true;
		renderer.render( scene, camera );
		log.push( [ 'reversed', camera.reversedDepth, renderer.getClearDepth() ] );

	},


	async nodes_render( log ) {

		installFrames( log );
		align( log );
		const renderer = await createRenderer( log );
		await renderer.init();
		renderer.setSize( 16, 8, false );
		const scene = new M.Scene(); scene.name = 'nodesScene';
		const camera = new M.PerspectiveCamera(); camera.position.set( 0, 1, 3 ); camera.updateMatrixWorld();
		const material = nodeMaterial( 'floorMat' );
		scene.add( mesh( 'floor', material ) );
		// PassNode.compileAsync
		const scenePass = M.TSL.pass( scene, camera );
		await scenePass.compileAsync( renderer );
		log.push( [ 'passCompiled', renderer.getRenderTarget(), scenePass.renderTarget.width, ...info( renderer ) ] );
		const frame = renderer._nodes.nodeFrame;
		frame.renderer = renderer; frame.scene = scene; frame.camera = camera; frame.material = material;
		// rtt
		const r = M.TSL.rtt( M.TSL.vec4( 1, 0, 0, 1 ) );
		r.updateBefore( frame );
		r.updateBefore( frame );
		r.autoUpdate = false;
		r.updateBefore( frame );
		const fixed = M.TSL.rtt( M.TSL.vec4( 0.5 ), 4, 2, { resolutionScale: 0.5 } );
		fixed.updateBefore( frame );
		log.push( [ 'rtt', r.isRTTNode, r.autoResize, r.renderTarget.width, r.renderTarget.height, fixed.renderTarget.width, fixed.renderTarget.height, r.value === r.renderTarget.texture, r.clone().referenceNode === r ] );
		const t = M.TSL.texture( new M.Texture() );
		log.push( [ 'convert', M.TSL.convertToTexture( t ) === t, M.TSL.convertToTexture( scenePass ).isTextureNode, M.TSL.convertToTexture( M.TSL.vec4( 1 ) ).isRTTNode ] );
		// reflector
		const reflection = M.TSL.reflector( { resolutionScale: 0.5 } );
		reflection.target.rotation.x = - Math.PI / 2; reflection.target.updateMatrixWorld();
		const base = reflection.reflector;
		base.updateBefore( frame );
		log.push( [ 'reflector', base.renderTargets.size, reflection.value.id, scene.name, material.visible, base.hasOutput ] );
		camera.position.set( 0, - 1, 3 ); camera.updateMatrixWorld();
		base.updateBefore( frame );
		base.forceUpdate = true;
		base.updateBefore( frame );
		log.push( [ 'reflector2', base.hasOutput, ...info( renderer ) ] );

	},

};
