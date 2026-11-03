// The add-on scenes of TSL agent A5 in the WebGPU pixel comparison (examples/jsm/tsl/display,
// tsl/lighting, tsl/shadows): webgpu_scenes.js lists their modules in ADDON_MODULES and its
// `buildAddon` falls through to `buildA5Addon`. The MoonBit side is webgpu/a5_scenes.mbt,
// line for line. The temporal scenes render a fixed number of frames into the target.

export const A5_SCENE_NAMES = [
	'addon_bloom', 'addon_smaa', 'addon_ssao', 'addon_outline', 'addon_film', 'addon_chromatic_aberration',
	'addon_lut3d', 'addon_after_image', 'addon_traa', 'addon_tile_shadow', 'addon_dynamic_lights',
];

// The add-on modules of each scene, below examples/jsm, in import order.
export const A5_ADDON_MODULES = {
	addon_bloom: [ 'tsl/display/BloomNode.js' ],
	addon_smaa: [ 'tsl/display/SMAANode.js' ],
	addon_ssao: [ 'tsl/display/SSAONode.js' ],
	addon_outline: [ 'tsl/display/OutlineNode.js' ],
	addon_film: [ 'tsl/display/FilmNode.js' ],
	addon_chromatic_aberration: [ 'tsl/display/ChromaticAberrationNode.js' ],
	addon_lut3d: [ 'tsl/display/Lut3DNode.js' ],
	addon_after_image: [ 'tsl/display/AfterImageNode.js' ],
	addon_traa: [ 'tsl/display/TRAANode.js' ],
	addon_tile_shadow: [ 'tsl/shadows/TileShadowNode.js' ],
	addon_dynamic_lights: [ 'tsl/lighting/DynamicLightsNode.js' ],
};

const WIDTH = 128;
const HEIGHT = 96;

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

function view( scene, camera, options = {} ) {

	return { scene, camera, samples: options.samples ?? 0, before: options.before ?? null, render: options.render ?? null };

}

// The stage of webgpu_scenes.js's add-on scenes (`addonStage`): a standard box, a metallic
// sphere and a glossy ground under an ambient and a directional light; returns the camera.
function a5Stage( THREE, scene ) {

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

// The stage rendered `frames` times (one animation frame each) through a RenderPipeline whose output is
// `output( scene, camera )`; `step( i, scene )` runs before every frame after the first.
function a5View( THREE, output, frames = 1, step = null ) {

	const scene = new THREE.Scene();
	const camera = a5Stage( THREE, scene );
	return view( scene, camera, { render: ( renderer ) => {

		const pipeline = new THREE.RenderPipeline( renderer );
		pipeline.outputNode = output( scene, camera );
		for ( let i = 0; i < frames; i ++ ) {

			if ( i > 0 ) a5Tick( renderer );
			if ( i > 0 && step !== null ) step( i, scene );
			pipeline.render();

		}

	} } );

}

// One animation frame inside the synchronous render (requestAnimationFrame cannot fire
// there): the body of Animation's `update`, so FRAME-updated nodes (the passes, the
// temporal nodes' history) run again.
function a5Tick( renderer ) {

	if ( renderer.info.autoReset === true ) renderer.info.reset();
	renderer._nodes.nodeFrame.update();
	renderer.info.frame = renderer._nodes.nodeFrame.frameId;

}

// moves the box between frames
function a5Move( i, scene ) {

	const box = scene.children[ 0 ];
	box.rotation.y += 0.15;
	box.position.x = - 0.6 + 0.04 * i;

}

// The scenes (`A`: the add-on exports `loadAddons` imported); null for other names.
export function buildA5Addon( THREE, name, A ) {

	const TSL = THREE.TSL;
	switch ( name ) {

		case 'addon_bloom':
			return a5View( THREE, ( scene, camera ) => {

				const scenePass = TSL.pass( scene, camera );
				return scenePass.add( A.bloom( scenePass, 1.5, 0.4, 0.3 ) );

			} );
		case 'addon_smaa':
			// (the area and search images decode asynchronously: both sides render before
			// they have loaded)
			return a5View( THREE, ( scene, camera ) => A.smaa( TSL.pass( scene, camera ) ) );
		case 'addon_ssao':
			return a5View( THREE, ( scene, camera ) => {

				const scenePass = TSL.pass( scene, camera );
				scenePass.setMRT( TSL.mrt( { output: TSL.output, normal: TSL.normalView } ) );
				const aoNode = A.ssao( scenePass.getTextureNode( 'depth' ), scenePass.getTextureNode( 'normal' ), camera );
				return TSL.vec4( scenePass.getTextureNode( 'output' ).rgb.mul( aoNode.r ), 1 );

			} );
		case 'addon_outline':
			return a5View( THREE, ( scene, camera ) => {

				const outlineNode = A.outline( scene, camera, { selectedObjects: [ scene.children[ 1 ] ], edgeThickness: TSL.uniform( 1.5 ), edgeGlow: TSL.uniform( 0.5 ) } );
				const color = outlineNode.visibleEdge.mul( TSL.color( 0xffffff ) ).add( outlineNode.hiddenEdge.mul( TSL.color( 0x4400ff ) ) ).mul( 4 );
				return TSL.pass( scene, camera ).add( TSL.vec4( color, 0 ) );

			} );
		case 'addon_film':
			// intensity 0: the grain reads the `time` uniform, which differs between the sides
			return a5View( THREE, ( scene, camera ) => A.film( TSL.pass( scene, camera ), TSL.uniform( 0 ) ) );
		case 'addon_chromatic_aberration':
			return a5View( THREE, ( scene, camera ) => A.chromaticAberration( TSL.pass( scene, camera ), 2, TSL.vec2( 0.4, 0.6 ), 1.1 ) );
		case 'addon_lut3d':
			return a5View( THREE, ( scene, camera ) => {

				const size = 8;
				const data = new Uint8Array( size * size * size * 4 );
				for ( let z = 0; z < size; z ++ ) {

					for ( let y = 0; y < size; y ++ ) {

						for ( let x = 0; x < size; x ++ ) {

							const i = ( ( z * size + y ) * size + x ) * 4;
							data[ i ] = Math.floor( 255 * y / ( size - 1 ) );
							data[ i + 1 ] = Math.floor( 255 * z / ( size - 1 ) );
							data[ i + 2 ] = Math.floor( 255 * x / ( size - 1 ) );
							data[ i + 3 ] = 255;

						}

					}

				}

				const lut = new THREE.Data3DTexture( data, size, size, size );
				// (nearest, the default: the port's 2D textures carry wrapR = ClampToEdge where
				// upstream's have none, so a linear clamped LUT would share the 2D textures'
				// sampler in the port; see the A5 report)
				lut.needsUpdate = true;
				return A.lut3D( TSL.pass( scene, camera ), TSL.texture3D( lut ), size, TSL.uniform( 0.75 ) );

			} );
		case 'addon_after_image':
			return a5View( THREE, ( scene, camera ) => A.afterImage( TSL.pass( scene, camera ), 0.85 ), 4, a5Move );
		case 'addon_traa':
			return a5View( THREE, ( scene, camera ) => {

				const scenePass = TSL.pass( scene, camera );
				scenePass.setMRT( TSL.mrt( { output: TSL.output, velocity: TSL.velocity } ) );
				return A.traa( scenePass.getTextureNode( 'output' ), scenePass.getTextureNode( 'depth' ), scenePass.getTextureNode( 'velocity' ), camera );

			}, 5, a5Move );
		case 'addon_tile_shadow': {

			const scene = new THREE.Scene();
			const camera = a5Stage( THREE, scene );
			scene.children[ 0 ].castShadow = true;
			scene.children[ 1 ].castShadow = true;
			scene.children[ 2 ].receiveShadow = true;
			const light = scene.children[ 4 ];
			light.castShadow = true;
			light.shadow.mapSize.set( 256, 256 );
			light.shadow.camera.left = - 2;
			light.shadow.camera.right = 2;
			light.shadow.camera.top = 2;
			light.shadow.camera.bottom = - 2;
			light.shadow.shadowNode = new A.TileShadowNode( light, { tilesX: 2, tilesY: 2 } );
			return view( scene, camera, { before: ( renderer ) => {

				renderer.shadowMap.enabled = true;

			} } );

		}

		case 'addon_dynamic_lights': {

			const scene = new THREE.Scene();
			const camera = a5Stage( THREE, scene );
			for ( let i = 0; i < 3; i ++ ) {

				const l = new THREE.PointLight( new THREE.Color( [ 0xff2200, 0x22ff00, 0x0044ff ][ i ] ), 3, 4, 2 );
				l.position.set( i - 1, 0.8, 0.8 );
				scene.add( l );

			}

			const spot = new THREE.SpotLight( new THREE.Color( 0xffffaa ), 6, 8, 0.5, 0.3, 2 );
			spot.position.set( 0, 2.5, 1 );
			scene.add( spot );
			return view( scene, camera, { before: ( renderer ) => {

				// examples/jsm/lighting/DynamicLighting.js's `createNode`
				const lighting = new THREE.Lighting();
				lighting.createNode = ( lights = [] ) => new A.DynamicLightsNode( { maxPointLights: 4 } ).setLights( lights );
				renderer.lighting = lighting;

			} } );

		}

	}

	return null;

}
