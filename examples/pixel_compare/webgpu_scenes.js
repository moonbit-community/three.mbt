// The upstream half of the WebGPU pixel comparison: the scenes of webgpu/main.mbt built
// with three.js's WebGPURenderer. Every scene mirrors the MoonBit code line by line.

import { OBJECTS_SCENE_NAMES, OBJECTS_ADDON_MODULES, buildObjectsAddon } from './webgpu_objects_scenes.js';
import { A5_SCENE_NAMES, A5_ADDON_MODULES, buildA5Addon } from './webgpu_a5_scenes.js';

export const WIDTH = 128;
export const HEIGHT = 96;

export const SCENE_NAMES = [
	'unlit_box', 'lit_spheres', 'data_texture', 'instancing', 'lines_points', 'transparent',
	'shadow_directional', 'shadow_spot', 'shadow_point', 'pmrem_env', 'cube_background', 'post_pass',
	'tone_mapping', 'tsl_material', 'compute_instances', 'msaa_target', 'skinned_morph', 'fog',
	'texture_formats', 'sprites',
	// the display add-ons (examples/jsm/tsl/display) of TSL agent A4
	'addon_fxaa', 'addon_gaussian_blur', 'addon_sobel', 'addon_rgb_shift', 'addon_dof', 'addon_gtao',
	'addon_ssr', 'addon_pixelation', 'addon_ssaa',
	// the WebGPU objects add-ons (examples/jsm/objects, webgpu_objects_scenes.js)
	...OBJECTS_SCENE_NAMES,
	// the display, lighting and shadows add-ons of TSL agent A5 (webgpu_a5_scenes.js)
	...A5_SCENE_NAMES,
];

// The add-on modules each add-on scene imports (below examples/jsm), in import order. They
// load before the scene is built, as the MoonBit side calls their `load_*()`; their bare
// `three/webgpu` / `three/tsl` imports resolve through webgpu.html's import map (or the
// harness's resolve hooks under Node).
const ADDON_MODULES = {
	addon_fxaa: [ 'tsl/display/FXAANode.js' ],
	addon_gaussian_blur: [ 'tsl/display/GaussianBlurNode.js' ],
	addon_sobel: [ 'tsl/display/SobelOperatorNode.js' ],
	addon_rgb_shift: [ 'tsl/display/RGBShiftNode.js' ],
	addon_dof: [ 'tsl/display/DepthOfFieldNode.js' ],
	addon_gtao: [ 'tsl/display/GTAONode.js' ],
	addon_ssr: [ 'tsl/display/SSRNode.js' ],
	addon_pixelation: [ 'tsl/display/PixelationPassNode.js' ],
	addon_ssaa: [ 'tsl/display/SSAAPassNode.js' ],
	...OBJECTS_ADDON_MODULES,
	...A5_ADDON_MODULES,
};

// Imports a scene's add-on modules: their named exports (and default exports by class name).
async function loadAddons( name ) {

	const A = {};
	for ( const path of ADDON_MODULES[ name ] || [] ) {

		const m = await import( new URL( '../../.repos/three.js/examples/jsm/' + path, import.meta.url ).href );
		for ( const [ k, v ] of Object.entries( m ) ) if ( k !== 'default' ) A[ k ] = v;
		if ( m.default ) A[ m.default.name ] = m.default;

	}

	return A;

}

function cameraAt( THREE, x, y, z ) {

	const camera = new THREE.PerspectiveCamera( 50, WIDTH / HEIGHT, 0.1, 100 );
	camera.position.set( x, y, z );
	camera.lookAt( 0, 0, 0 );
	return camera;

}

function colored( material, hex ) {

	material.color.setHex( hex );
	return material;

}

// What `renderUpstream` renders: the scene and camera, the render target's MSAA samples,
// a step after `init` (`before( renderer, target )`) and a render that replaces
// `renderer.render( scene, camera )`.
function view( scene, camera, options = {} ) {

	return { scene, camera, samples: options.samples ?? 0, before: options.before ?? null, render: options.render ?? null };

}

// A box on a ground plane, both casting and receiving shadows.
function shadowStage( THREE, scene, hex ) {

	const box = new THREE.Mesh( new THREE.BoxGeometry( 0.8, 0.8, 0.8 ), colored( new THREE.MeshStandardNodeMaterial(), hex ) );
	box.position.set( 0, 0.4, 0 );
	box.rotation.set( 0, 0.5, 0 );
	box.castShadow = true;
	box.receiveShadow = true;
	scene.add( box );
	const ground = new THREE.Mesh( new THREE.PlaneGeometry( 6, 6 ), colored( new THREE.MeshStandardNodeMaterial(), 0xcccccc ) );
	ground.rotation.set( - Math.PI / 2, 0, 0 );
	ground.receiveShadow = true;
	scene.add( ground );
	scene.add( new THREE.AmbientLight( new THREE.Color( 0x404040 ), 1 ) );

}

function enableShadows( THREE, renderer ) {

	renderer.shadowMap.enabled = true;
	renderer.shadowMap.type = THREE.PCFShadowMap;

}

// An equirectangular half-float sky: a vertical gradient with a bright sun texel.
function skyTexture( THREE ) {

	const w = 16, h = 8;
	const data = new Uint16Array( w * h * 4 );
	for ( let y = 0; y < h; y ++ ) {

		for ( let x = 0; x < w; x ++ ) {

			const i = ( y * w + x ) * 4;
			const t = y / ( h - 1 );
			const sun = x === 4 && y === 5 ? 6 : 0;
			data[ i ] = THREE.DataUtils.toHalfFloat( 0.9 - 0.6 * t + sun );
			data[ i + 1 ] = THREE.DataUtils.toHalfFloat( 0.6 - 0.2 * t + sun );
			data[ i + 2 ] = THREE.DataUtils.toHalfFloat( 0.3 + 0.7 * t + sun );
			data[ i + 3 ] = THREE.DataUtils.toHalfFloat( 1 );

		}

	}

	const texture = new THREE.DataTexture( data, w, h, THREE.RGBAFormat, THREE.HalfFloatType );
	texture.mapping = THREE.EquirectangularReflectionMapping;
	texture.needsUpdate = true;
	return texture;

}

// A `size`x`size` RGBA8 DataTexture of one color, for the cube faces.
function faceTexture( THREE, size, r, g, b ) {

	const data = new Uint8Array( size * size * 4 );
	for ( let i = 0; i < size * size; i ++ ) {

		data[ i * 4 ] = ( i % 2 === 0 ) ? r : Math.floor( r / 2 );
		data[ i * 4 + 1 ] = g;
		data[ i * 4 + 2 ] = b;
		data[ i * 4 + 3 ] = 255;

	}

	const texture = new THREE.DataTexture( data, size, size );
	texture.needsUpdate = true;
	return texture;

}

// A 2D canvas with a `cells`x`cells` checker of the CSS colors `a` and `b`.
function checkerCanvas( size, cells, a, b ) {

	const canvas = document.createElement( 'canvas' );
	canvas.width = size;
	canvas.height = size;
	const context = canvas.getContext( '2d' );
	const step = size / cells;
	for ( let y = 0; y < cells; y ++ ) {

		for ( let x = 0; x < cells; x ++ ) {

			context.fillStyle = ( x + y ) % 2 === 0 ? a : b;
			context.fillRect( x * step, y * step, step, step );

		}

	}

	return canvas;

}

// The add-on scenes' stage: a standard box, a metallic sphere and a glossy ground under an
// ambient and a directional light; returns the camera.
function addonStage( THREE, scene ) {

	const box = new THREE.Mesh( new THREE.BoxGeometry( 0.8, 0.8, 0.8 ), colored( new THREE.MeshStandardNodeMaterial(), 0x3366cc ) );
	box.position.set( - 0.6, 0.4, 0 );
	box.rotation.set( 0, 0.5, 0 );
	scene.add( box );
	const sphereMaterial = colored( new THREE.MeshStandardNodeMaterial(), 0xff8833 );
	sphereMaterial.metalness = 0.8;
	sphereMaterial.roughness = 0.2;
	const sphere = new THREE.Mesh( new THREE.SphereGeometry( 0.45, 32, 16 ), sphereMaterial );
	sphere.position.set( 0.6, 0.45, 0 );
	scene.add( sphere );
	const groundMaterial = colored( new THREE.MeshStandardNodeMaterial(), 0xcccccc );
	groundMaterial.metalness = 0.5;
	groundMaterial.roughness = 0.3;
	const ground = new THREE.Mesh( new THREE.PlaneGeometry( 6, 6 ), groundMaterial );
	ground.rotation.set( - Math.PI / 2, 0, 0 );
	scene.add( ground );
	scene.add( new THREE.AmbientLight( new THREE.Color( 0x404040 ), 1 ) );
	const light = new THREE.DirectionalLight( new THREE.Color( 0xffffff ), 2 );
	light.position.set( 1, 3, 2 );
	scene.add( light );
	return cameraAt( THREE, 0, 1.2, 2.6 );

}

// An add-on scene: the stage rendered through a RenderPipeline whose output is
// `output( scene, camera )`.
function addonView( THREE, name, output ) {

	const scene = new THREE.Scene();
	const camera = addonStage( THREE, scene );
	return view( scene, camera, { render: ( renderer ) => {

		const pipeline = new THREE.RenderPipeline( renderer );
		pipeline.outputNode = output( scene, camera );
		pipeline.render();

	} } );

}

// The add-on scenes (`A`: the add-on exports `loadAddons` imported).
function buildAddon( THREE, name, A ) {

	const TSL = THREE.TSL;
	switch ( name ) {

		case 'addon_fxaa':
			return addonView( THREE, name, ( scene, camera ) => A.fxaa( TSL.pass( scene, camera ) ) );
		case 'addon_gaussian_blur':
			return addonView( THREE, name, ( scene, camera ) => A.gaussianBlur( TSL.pass( scene, camera ), TSL.vec2( 1, 1 ), 2 ) );
		case 'addon_sobel':
			return addonView( THREE, name, ( scene, camera ) => A.sobel( TSL.pass( scene, camera ) ) );
		case 'addon_rgb_shift':
			return addonView( THREE, name, ( scene, camera ) => A.rgbShift( TSL.pass( scene, camera ), 0.01, 0.5 ) );
		case 'addon_dof':
			return addonView( THREE, name, ( scene, camera ) => {

				const scenePass = TSL.pass( scene, camera );
				return A.dof( scenePass, scenePass.getViewZNode(), 2.6, 1.5, 3 );

			} );
		case 'addon_gtao':
			return addonView( THREE, name, ( scene, camera ) => {

				const scenePass = TSL.pass( scene, camera );
				scenePass.setMRT( TSL.mrt( { output: TSL.output, normal: TSL.normalView } ) );
				const aoNode = A.ao( scenePass.getTextureNode( 'depth' ), scenePass.getTextureNode( 'normal' ), camera );
				const occlusion = aoNode.getTextureNode().sample( TSL.screenUV ).r;
				return TSL.vec4( scenePass.getTextureNode( 'output' ).rgb.mul( occlusion ), 1 );

			} );
		case 'addon_ssr':
			return addonView( THREE, name, ( scene, camera ) => {

				const scenePass = TSL.pass( scene, camera );
				scenePass.setMRT( TSL.mrt( { output: TSL.output, normal: TSL.normalView, metalrough: TSL.vec2( TSL.metalness, TSL.roughness ) } ) );
				const metalRough = scenePass.getTextureNode( 'metalrough' );
				const ssrNode = A.ssr( scenePass.getTextureNode( 'output' ), scenePass.getTextureNode( 'depth' ), scenePass.getTextureNode( 'normal' ), { metalnessNode: metalRough.r, roughnessNode: metalRough.g } );
				return scenePass.getTextureNode( 'output' ).add( ssrNode.rgb );

			} );
		case 'addon_pixelation':
			return addonView( THREE, name, ( scene, camera ) => A.pixelationPass( scene, camera, 4, 0.5, 0.5 ) );
		case 'addon_ssaa':
			return addonView( THREE, name, ( scene, camera ) => {

				const ssaa = A.ssaaPass( scene, camera );
				ssaa.sampleLevel = 2;
				return ssaa;

			} );

	}

	if ( name in A5_ADDON_MODULES ) return buildA5Addon( THREE, name, A );
	return buildObjectsAddon( THREE, name, A );

}

export function build( THREE, name, A = {} ) {

	if ( name in ADDON_MODULES ) return buildAddon( THREE, name, A );

	const TSL = THREE.TSL;
	const scene = new THREE.Scene();
	switch ( name ) {

		case 'unlit_box': {

			const box = new THREE.Mesh( new THREE.BoxGeometry(), colored( new THREE.MeshBasicNodeMaterial(), 0xff8800 ) );
			box.rotation.set( 0.4, 0.6, 0 );
			scene.add( box );
			return view( scene, cameraAt( THREE, 0, 0, 3 ) );

		}

		case 'lit_spheres': {

			const sphere = new THREE.SphereGeometry( 0.5, 32, 16 );
			const lambert = new THREE.Mesh( sphere, colored( new THREE.MeshLambertNodeMaterial(), 0xcc4444 ) );
			lambert.position.set( - 1.1, 0, 0 );
			scene.add( lambert );
			const phong = colored( new THREE.MeshPhongNodeMaterial(), 0x44cc44 );
			phong.shininess = 60;
			scene.add( new THREE.Mesh( sphere, phong ) );
			const standard = colored( new THREE.MeshStandardNodeMaterial(), 0x4444cc );
			standard.roughness = 0.4;
			standard.metalness = 0.1;
			const s = new THREE.Mesh( sphere, standard );
			s.position.set( 1.1, 0, 0 );
			scene.add( s );
			scene.add( new THREE.AmbientLight( new THREE.Color( 0x202020 ), 1 ) );
			const light = new THREE.DirectionalLight( new THREE.Color( 0xffffff ), 2 );
			light.position.set( 2, 3, 4 );
			scene.add( light );
			return view( scene, cameraAt( THREE, 0, 0.5, 4 ) );

		}

		case 'data_texture': {

			const w = 8, h = 8;
			const data = new Uint8Array( w * h * 4 );
			for ( let y = 0; y < h; y ++ ) {

				for ( let x = 0; x < w; x ++ ) {

					const i = ( y * w + x ) * 4;
					data[ i ] = ( x + y ) % 2 === 0 ? 255 : 30;
					data[ i + 1 ] = Math.floor( x * 255 / ( w - 1 ) );
					data[ i + 2 ] = Math.floor( y * 255 / ( h - 1 ) );
					data[ i + 3 ] = 255;

				}

			}

			const texture = new THREE.DataTexture( data, w, h );
			texture.magFilter = THREE.NearestFilter;
			texture.needsUpdate = true;
			const material = new THREE.MeshBasicNodeMaterial();
			material.map = texture;
			scene.add( new THREE.Mesh( new THREE.PlaneGeometry( 2, 2 ), material ) );
			return view( scene, cameraAt( THREE, 0, 0, 2.5 ) );

		}

		case 'instancing': {

			const instanced = new THREE.InstancedMesh( new THREE.BoxGeometry( 0.4, 0.4, 0.4 ), colored( new THREE.MeshBasicNodeMaterial(), 0x3399ff ), 5 );
			for ( let i = 0; i < 5; i ++ ) {

				instanced.setMatrixAt( i, new THREE.Matrix4().makeTranslation( ( i - 2 ) * 0.6, 0, 0 ) );
				instanced.setColorAt( i, new THREE.Color( i / 4, 1 - i / 4, 0.5 ) );

			}

			scene.add( instanced );
			return view( scene, cameraAt( THREE, 0, 0, 3 ) );

		}

		case 'lines_points': {

			const positions = [];
			for ( let i = 0; i < 16; i ++ ) {

				const t = i / 15;
				positions.push( t * 2 - 1, Math.sin( t * 6 ) * 0.5, 0 );

			}

			const geometry = new THREE.BufferGeometry();
			geometry.setAttribute( 'position', new THREE.Float32BufferAttribute( positions, 3 ) );
			scene.add( new THREE.Line( geometry, colored( new THREE.LineBasicNodeMaterial(), 0xffffff ) ) );
			scene.add( new THREE.Points( geometry, colored( new THREE.PointsNodeMaterial(), 0xff3333 ) ) );
			return view( scene, cameraAt( THREE, 0, 0, 2.5 ) );

		}

		case 'transparent': {

			const back = new THREE.Mesh( new THREE.PlaneGeometry( 1.5, 1.5 ), colored( new THREE.MeshBasicNodeMaterial(), 0x2222ff ) );
			back.position.set( - 0.3, 0, - 0.5 );
			scene.add( back );
			const frontMaterial = colored( new THREE.MeshBasicNodeMaterial(), 0xff2222 );
			frontMaterial.transparent = true;
			frontMaterial.opacity = 0.5;
			const front = new THREE.Mesh( new THREE.PlaneGeometry( 1.5, 1.5 ), frontMaterial );
			front.position.set( 0.3, 0, 0 );
			scene.add( front );
			return view( scene, cameraAt( THREE, 0, 0, 3 ) );

		}

		case 'shadow_directional': {

			shadowStage( THREE, scene, 0xff8844 );
			const light = new THREE.DirectionalLight( new THREE.Color( 0xffffff ), 3 );
			light.position.set( 2, 4, 3 );
			light.castShadow = true;
			light.shadow.mapSize.set( 256, 256 );
			scene.add( light );
			return view( scene, cameraAt( THREE, 0, 2, 4 ), { before: ( renderer ) => enableShadows( THREE, renderer ) } );

		}

		case 'shadow_spot': {

			shadowStage( THREE, scene, 0x44aaff );
			const light = new THREE.SpotLight( new THREE.Color( 0xffffff ), 40, 0, 0.6, 0.3, 2 );
			light.position.set( - 2, 4, 2 );
			light.castShadow = true;
			light.shadow.mapSize.set( 256, 256 );
			scene.add( light );
			return view( scene, cameraAt( THREE, 0, 2, 4 ), { before: ( renderer ) => enableShadows( THREE, renderer ) } );

		}

		case 'shadow_point': {

			shadowStage( THREE, scene, 0x88dd44 );
			const light = new THREE.PointLight( new THREE.Color( 0xffffff ), 20, 0, 2 );
			light.position.set( 1, 2.5, 1 );
			light.castShadow = true;
			light.shadow.mapSize.set( 128, 128 );
			scene.add( light );
			return view( scene, cameraAt( THREE, 0, 2, 4 ), { before: ( renderer ) => enableShadows( THREE, renderer ) } );

		}

		case 'pmrem_env': {

			scene.environment = skyTexture( THREE );
			const sphere = new THREE.SphereGeometry( 0.5, 32, 16 );
			const standard = colored( new THREE.MeshStandardNodeMaterial(), 0xffffff );
			standard.metalness = 1;
			standard.roughness = 0.25;
			const metal = new THREE.Mesh( sphere, standard );
			metal.position.set( - 0.6, 0, 0 );
			scene.add( metal );
			const physical = colored( new THREE.MeshPhysicalNodeMaterial(), 0xcc3333 );
			physical.roughness = 0.6;
			physical.clearcoat = 1;
			physical.clearcoatRoughness = 0.1;
			const coated = new THREE.Mesh( sphere, physical );
			coated.position.set( 0.6, 0, 0 );
			scene.add( coated );
			return view( scene, cameraAt( THREE, 0, 0, 2.5 ) );

		}

		case 'cube_background': {

			const faces = [
				faceTexture( THREE, 2, 255, 64, 64 ), faceTexture( THREE, 2, 64, 255, 64 ), faceTexture( THREE, 2, 64, 64, 255 ),
				faceTexture( THREE, 2, 255, 255, 64 ), faceTexture( THREE, 2, 64, 255, 255 ), faceTexture( THREE, 2, 255, 64, 255 ),
			];
			const cube = new THREE.CubeTexture( faces );
			cube.needsUpdate = true;
			scene.background = cube;
			const material = new THREE.MeshBasicNodeMaterial();
			material.envMap = cube;
			scene.add( new THREE.Mesh( new THREE.SphereGeometry( 0.6, 32, 16 ), material ) );
			return view( scene, cameraAt( THREE, 2, 1.5, 2 ) );

		}

		case 'post_pass': {

			const left = new THREE.Mesh( new THREE.BoxGeometry( 0.8, 0.8, 0.8 ), colored( new THREE.MeshBasicNodeMaterial(), 0xff3355 ) );
			left.position.set( - 0.6, 0, 0 );
			left.rotation.set( 0.3, 0.5, 0 );
			scene.add( left );
			const right = new THREE.Mesh( new THREE.SphereGeometry( 0.45, 32, 16 ), colored( new THREE.MeshBasicNodeMaterial(), 0x33ff88 ) );
			right.position.set( 0.6, 0, 0 );
			scene.add( right );
			const camera = cameraAt( THREE, 0, 0, 3 );
			return view( scene, camera, { render: ( renderer ) => {

				const pipeline = new THREE.RenderPipeline( renderer );
				const scenePass = TSL.pass( scene, camera );
				const gray = TSL.vec3( TSL.luminance( scenePass.rgb ) );
				pipeline.outputNode = TSL.vec4( TSL.mix( scenePass.rgb, gray, TSL.step( 0.5, TSL.uv().x ) ), 1 );
				pipeline.render();

			} } );

		}

		case 'tone_mapping': {

			const sphere = new THREE.SphereGeometry( 0.5, 32, 16 );
			for ( let i = 0; i < 3; i ++ ) {

				const material = colored( new THREE.MeshStandardNodeMaterial(), 0xffaa66 );
				material.roughness = 0.2 + i * 0.3;
				const mesh = new THREE.Mesh( sphere, material );
				mesh.position.set( ( i - 1 ) * 1.1, 0, 0 );
				scene.add( mesh );

			}

			const light = new THREE.DirectionalLight( new THREE.Color( 0xffffff ), 8 );
			light.position.set( 1, 2, 3 );
			scene.add( light );
			return view( scene, cameraAt( THREE, 0, 0, 3.5 ), { before: ( renderer, target ) => {

				renderer.toneMapping = THREE.ACESFilmicToneMapping;
				renderer.toneMappingExposure = 1.5;
				renderer.outputColorSpace = THREE.SRGBColorSpace;
				renderer.setOutputRenderTarget( target );

			} } );

		}

		case 'tsl_material': {

			const scale = TSL.uniform( 4 );
			const checker = TSL.Fn( ( [ coord ] ) => {

				const cell = coord.mul( scale ).floor().toVar();
				const color = TSL.vec3( 0.1 ).toVar();
				TSL.If( cell.x.add( cell.y ).mod( 2 ).equal( 0 ), () => {

					color.assign( TSL.vec3( 1, 0.5, 0 ) );

				} );
				return color;

			} ).setLayout( { name: 'checker', type: 'vec3', inputs: [ { name: 'coord', type: 'vec2' } ] } );
			const material = new THREE.MeshBasicNodeMaterial();
			material.colorNode = checker( TSL.uv() );
			material.positionNode = TSL.positionLocal.add( TSL.normalLocal.mul( TSL.mx_noise_float( TSL.positionLocal.mul( 3 ) ).mul( 0.15 ) ) );
			scene.add( new THREE.Mesh( new THREE.SphereGeometry( 0.8, 32, 16 ), material ) );
			return view( scene, cameraAt( THREE, 0, 0, 3 ) );

		}

		case 'compute_instances': {

			const count = 8;
			const positions = TSL.instancedArray( count, 'vec3' );
			const computePositions = TSL.Fn( () => {

				const i = TSL.float( TSL.instanceIndex );
				positions.element( TSL.instanceIndex ).assign( TSL.vec3( i.mul( 0.45 ).sub( 1.575 ), i.mul( 1.3 ).sin().mul( 0.5 ), 0 ) );

			} )().compute( count );
			const material = colored( new THREE.MeshBasicNodeMaterial(), 0x33cc99 );
			material.positionNode = TSL.positionLocal.add( positions.toAttribute() );
			scene.add( new THREE.InstancedMesh( new THREE.BoxGeometry( 0.3, 0.3, 0.3 ), material, count ) );
			return view( scene, cameraAt( THREE, 0, 0, 3 ), { before: ( renderer ) => renderer.compute( computePositions ) } );

		}

		case 'msaa_target': {

			const box = new THREE.Mesh( new THREE.BoxGeometry(), colored( new THREE.MeshBasicNodeMaterial(), 0xffdd00 ) );
			box.rotation.set( 0.5, 0.7, 0.2 );
			scene.add( box );
			const plane = new THREE.Mesh( new THREE.PlaneGeometry( 3, 0.1 ), colored( new THREE.MeshBasicNodeMaterial(), 0x00ccff ) );
			plane.rotation.set( 0, 0, 0.3 );
			plane.position.set( 0, 0, 0.8 );
			scene.add( plane );
			return view( scene, cameraAt( THREE, 0, 0, 3 ), { samples: 4 } );

		}

		case 'skinned_morph': {

			const light = new THREE.DirectionalLight( new THREE.Color( 0xffffff ), 2 );
			light.position.set( 1, 2, 3 );
			scene.add( light );
			// morph target: a box stretched along x
			const morphGeometry = new THREE.BoxGeometry( 0.6, 0.6, 0.6 );
			const positions = morphGeometry.attributes.position;
			const target = [];
			for ( let i = 0; i < positions.count; i ++ ) {

				target.push( positions.getX( i ) * 2 );
				target.push( positions.getY( i ) );
				target.push( positions.getZ( i ) );

			}

			morphGeometry.morphAttributes.position = [ new THREE.Float32BufferAttribute( target, 3 ) ];
			const morph = new THREE.Mesh( morphGeometry, colored( new THREE.MeshStandardNodeMaterial(), 0xff00ff ) );
			morph.morphTargetInfluences[ 0 ] = 0.6;
			morph.position.set( - 0.9, 0, 0 );
			scene.add( morph );
			// skinned: two bones, the upper half bent
			const skinGeometry = new THREE.BoxGeometry( 0.3, 1.2, 0.3, 1, 4, 1 );
			const skinPosition = skinGeometry.attributes.position;
			const skinIndex = [];
			const skinWeight = [];
			for ( let i = 0; i < skinPosition.count; i ++ ) {

				const y = skinPosition.getY( i );
				skinIndex.push( y > 0 ? 1 : 0 );
				skinIndex.push( 0 );
				skinIndex.push( 0 );
				skinIndex.push( 0 );
				skinWeight.push( 1 );
				skinWeight.push( 0 );
				skinWeight.push( 0 );
				skinWeight.push( 0 );

			}

			skinGeometry.setAttribute( 'skinIndex', new THREE.Uint16BufferAttribute( skinIndex, 4 ) );
			skinGeometry.setAttribute( 'skinWeight', new THREE.Float32BufferAttribute( skinWeight, 4 ) );
			const skinned = new THREE.SkinnedMesh( skinGeometry, colored( new THREE.MeshLambertNodeMaterial(), 0xffcc00 ) );
			const root = new THREE.Bone();
			const tip = new THREE.Bone();
			tip.position.y = 0;
			root.add( tip );
			skinned.add( root );
			skinned.bind( new THREE.Skeleton( [ root, tip ] ) );
			tip.rotation.z = 0.6;
			skinned.position.set( 0.9, 0, 0 );
			scene.add( skinned );
			return view( scene, cameraAt( THREE, 0, 0, 3 ) );

		}

		case 'fog': {

			const fogColor = 0x8899aa;
			scene.background = new THREE.Color( fogColor );
			scene.fog = new THREE.Fog( new THREE.Color( fogColor ), 2, 8 );
			const geometry = new THREE.BoxGeometry( 0.6, 0.6, 0.6 );
			for ( let i = 0; i < 5; i ++ ) {

				const box = new THREE.Mesh( geometry, colored( new THREE.MeshLambertNodeMaterial(), 0xff4040 ) );
				box.position.set( i * 0.5 - 1, 0, - i * 1.5 );
				scene.add( box );

			}

			const light = new THREE.DirectionalLight( new THREE.Color( 0xffffff ), 2 );
			light.position.set( 1, 1, 2 );
			scene.add( light );
			return view( scene, cameraAt( THREE, 0, 0.5, 3 ) );

		}

		case 'texture_formats': {

			const w = 4, h = 4;
			const floats = new Float32Array( w * h * 4 );
			const halves = new Uint16Array( w * h * 4 );
			for ( let i = 0; i < w * h; i ++ ) {

				const x = i % w, y = Math.floor( i / w );
				floats[ i * 4 ] = x / ( w - 1 );
				floats[ i * 4 + 1 ] = y / ( h - 1 );
				floats[ i * 4 + 2 ] = 0.5;
				floats[ i * 4 + 3 ] = 1;
				halves[ i * 4 ] = THREE.DataUtils.toHalfFloat( 1 - x / ( w - 1 ) );
				halves[ i * 4 + 1 ] = THREE.DataUtils.toHalfFloat( 0.25 );
				halves[ i * 4 + 2 ] = THREE.DataUtils.toHalfFloat( y / ( h - 1 ) );
				halves[ i * 4 + 3 ] = THREE.DataUtils.toHalfFloat( 1 );

			}

			const floatTexture = new THREE.DataTexture( floats, w, h, THREE.RGBAFormat, THREE.FloatType );
			floatTexture.magFilter = THREE.NearestFilter;
			floatTexture.minFilter = THREE.NearestFilter;
			floatTexture.needsUpdate = true;
			const halfTexture = new THREE.DataTexture( halves, w, h, THREE.RGBAFormat, THREE.HalfFloatType );
			halfTexture.magFilter = THREE.NearestFilter;
			halfTexture.minFilter = THREE.NearestFilter;
			halfTexture.needsUpdate = true;
			const canvasTexture = new THREE.CanvasTexture( checkerCanvas( 64, 8, '#ff8800', '#003366' ) );
			canvasTexture.minFilter = THREE.LinearMipmapLinearFilter;
			canvasTexture.generateMipmaps = true;
			const textures = [ floatTexture, halfTexture, canvasTexture ];
			for ( let i = 0; i < 3; i ++ ) {

				const material = new THREE.MeshBasicNodeMaterial();
				material.map = textures[ i ];
				const plane = new THREE.Mesh( new THREE.PlaneGeometry( 0.9, 0.9 ), material );
				plane.position.set( ( i - 1 ) * 1.0, 0, 0 );
				plane.rotation.set( i === 2 ? - 1.1 : 0, 0, 0 );
				scene.add( plane );

			}

			return view( scene, cameraAt( THREE, 0, 0, 2.5 ) );

		}

		case 'sprites': {

			const plain = new THREE.Sprite( colored( new THREE.SpriteNodeMaterial(), 0xff6633 ) );
			plain.position.set( - 0.9, 0, 0 );
			plain.scale.set( 0.6, 0.6, 1 );
			scene.add( plain );
			const rotatedMaterial = colored( new THREE.SpriteNodeMaterial(), 0x3366ff );
			rotatedMaterial.rotationNode = TSL.float( 0.6 );
			const rotated = new THREE.Sprite( rotatedMaterial );
			rotated.scale.set( 0.8, 0.4, 1 );
			scene.add( rotated );
			const size = 16;
			const data = new Uint8Array( size * size * 4 );
			for ( let y = 0; y < size; y ++ ) {

				for ( let x = 0; x < size; x ++ ) {

					const i = ( y * size + x ) * 4;
					const dx = x - 7.5, dy = y - 7.5;
					const inside = dx * dx + dy * dy < 56;
					data[ i ] = 255;
					data[ i + 1 ] = Math.floor( x * 255 / ( size - 1 ) );
					data[ i + 2 ] = 64;
					data[ i + 3 ] = inside ? 255 : 0;

				}

			}

			const disc = new THREE.DataTexture( data, size, size );
			disc.needsUpdate = true;
			const discMaterial = new THREE.SpriteNodeMaterial();
			discMaterial.map = disc;
			discMaterial.transparent = true;
			const discSprite = new THREE.Sprite( discMaterial );
			discSprite.position.set( 0.9, 0, 0 );
			discSprite.scale.set( 0.7, 0.7, 1 );
			scene.add( discSprite );
			return view( scene, cameraAt( THREE, 0, 0, 2.5 ) );

		}

	}

	return null;

}

// Renders `name` with upstream's WebGPURenderer into a render target; the pixels of
// `readRenderTargetPixelsAsync` (bottom row first).
export async function renderUpstream( THREE, name, canvas, forceWebGL = false ) {

	const A = await loadAddons( name );
	const built = build( THREE, name, A );
	if ( built === null ) throw new Error( 'unknown scene ' + name );
	const renderer = new THREE.WebGPURenderer( { canvas, antialias: false, forceWebGL } );
	renderer.setPixelRatio( 1 );
	renderer.setSize( WIDTH, HEIGHT, false );
	await renderer.init();
	const target = new THREE.RenderTarget( WIDTH, HEIGHT, { samples: built.samples } );
	renderer.setRenderTarget( target );
	if ( built.before !== null ) built.before( renderer, target );
	if ( built.render !== null ) built.render( renderer ); else renderer.render( built.scene, built.camera );
	const pixels = await renderer.readRenderTargetPixelsAsync( target, 0, 0, WIDTH, HEIGHT );
	await renderer.dispose();
	return pixels;

}
