// The objects add-on scenes of the classic pixel comparison (examples/jsm/objects on
// WebGLRenderer): `build` in scenes.js falls through to `buildObjectsAddon` for them. The
// MoonBit side is main/objects_scenes.mbt, line for line. The add-ons import 'three',
// which index.html's import map points at the same src/Three.js the page loads.
import { Reflector } from '../../.repos/three.js/examples/jsm/objects/Reflector.js';
import { Refractor } from '../../.repos/three.js/examples/jsm/objects/Refractor.js';
import { Sky } from '../../.repos/three.js/examples/jsm/objects/Sky.js';
import { Water } from '../../.repos/three.js/examples/jsm/objects/Water.js';
import { Lensflare, LensflareElement } from '../../.repos/three.js/examples/jsm/objects/Lensflare.js';
import { MarchingCubes } from '../../.repos/three.js/examples/jsm/objects/MarchingCubes.js';

export const OBJECTS_SCENE_NAMES = [ 'addon_reflector', 'addon_refractor', 'addon_sky_water', 'addon_lensflare_cubes' ];

const WIDTH = 128;
const HEIGHT = 96;

function color( material, hex ) {

	material.color.setHex( hex );
	return material;

}

function cameraAt( THREE, x, y, z ) {

	const camera = new THREE.PerspectiveCamera( 50, WIDTH / HEIGHT, 0.1, 100 );
	camera.position.set( x, y, z );
	camera.lookAt( 0, 0, 0 );
	return camera;

}

// A `size`x`size` RGBA texture of integer patterns (`seed` varies them).
function patternTexture( THREE, size, seed ) {

	const data = new Uint8Array( size * size * 4 );
	for ( let y = 0; y < size; y ++ ) {

		for ( let x = 0; x < size; x ++ ) {

			const i = ( y * size + x ) * 4;
			data[ i ] = ( x * 37 + y * 11 + seed ) % 256;
			data[ i + 1 ] = ( x * 13 + y * 29 + seed * 3 ) % 256;
			data[ i + 2 ] = 160 + ( ( x + y + seed ) % 4 ) * 24;
			data[ i + 3 ] = 255;

		}

	}

	const texture = new THREE.DataTexture( data, size, size );
	texture.needsUpdate = true;
	return texture;

}

function addLights( THREE, scene ) {

	scene.add( new THREE.AmbientLight( new THREE.Color( 0x404040 ), 1 ) );
	const light = new THREE.DirectionalLight( new THREE.Color( 0xffffff ), 2 );
	light.position.set( 1, 3, 2 );
	scene.add( light );

}

export function buildObjectsAddon( THREE, name, renderer, scene ) {

	switch ( name ) {

		case 'addon_reflector': {

			addLights( THREE, scene );
			const box = new THREE.Mesh( new THREE.BoxGeometry( 0.8, 0.8, 0.8 ), color( new THREE.MeshStandardMaterial(), 0x3366cc ) );
			box.position.set( - 0.5, 0.5, 0 );
			box.rotation.set( 0, 0.6, 0 );
			scene.add( box );
			const ball = new THREE.Mesh( new THREE.SphereGeometry( 0.35, 32, 16 ), color( new THREE.MeshPhongMaterial(), 0xff8833 ) );
			ball.position.set( 0.6, 0.4, 0.3 );
			scene.add( ball );
			const mirror = new Reflector( new THREE.PlaneGeometry( 4, 4 ), { clipBias: 0.003, textureWidth: WIDTH, textureHeight: HEIGHT, color: 0xb0b0b0 } );
			mirror.rotation.set( - Math.PI / 2, 0, 0 );
			scene.add( mirror );
			return { scene, camera: cameraAt( THREE, 0, 1.5, 3.5 ) };

		}

		case 'addon_refractor': {

			const colors = [ 0xcc3333, 0x33cc33, 0x3333cc ];
			for ( let i = 0; i < 3; i ++ ) {

				const box = new THREE.Mesh( new THREE.BoxGeometry( 0.6, 0.6, 0.6 ), color( new THREE.MeshBasicMaterial(), colors[ i ] ) );
				box.position.set( i - 1, ( i - 1 ) * 0.3, - 1.5 );
				scene.add( box );

			}

			const pane = new Refractor( new THREE.PlaneGeometry( 2.4, 1.6 ), { color: 0xcccccc, textureWidth: WIDTH, textureHeight: HEIGHT, multisample: 0 } );
			pane.rotation.set( 0, 0.15, 0 );
			scene.add( pane );
			return { scene, camera: cameraAt( THREE, 0.3, 0.2, 3 ) };

		}

		case 'addon_sky_water': {

			renderer.toneMapping = THREE.ACESFilmicToneMapping;
			renderer.toneMappingExposure = 0.5;
			const sky = new Sky();
			sky.scale.setScalar( 1000 );
			const u = sky.material.uniforms;
			u.turbidity.value = 10;
			u.rayleigh.value = 2;
			u.sunPosition.value.set( 0.3, 0.05, - 0.95 );
			scene.add( sky );
			const normals = patternTexture( THREE, 16, 5 );
			normals.wrapS = THREE.RepeatWrapping;
			normals.wrapT = THREE.RepeatWrapping;
			const water = new Water( new THREE.PlaneGeometry( 100, 100 ), { textureWidth: WIDTH, textureHeight: HEIGHT, waterNormals: normals, sunDirection: new THREE.Vector3( 0.3, 0.05, - 0.95 ).normalize(), sunColor: 0xffffff, waterColor: 0x001e0f, distortionScale: 3.7 } );
			water.rotation.set( - Math.PI / 2, 0, 0 );
			scene.add( water );
			const camera = new THREE.PerspectiveCamera( 55, WIDTH / HEIGHT, 1, 2000 );
			camera.position.set( 0, 5, 20 );
			camera.lookAt( 0, 2, 0 );
			return { scene, camera };

		}

		case 'addon_lensflare_cubes': {

			addLights( THREE, scene );
			const cubes = new MarchingCubes( 24, color( new THREE.MeshPhongMaterial(), 0x88aa44 ), false, false, 20000 );
			cubes.isolation = 50;
			cubes.addBall( 0.45, 0.5, 0.5, 0.6, 12 );
			cubes.addBall( 0.6, 0.55, 0.45, 0.4, 12 );
			cubes.addPlaneY( 2, 12 );
			cubes.update();
			cubes.position.set( - 0.4, 0, 0 );
			cubes.scale.setScalar( 0.8 );
			scene.add( cubes );
			const flareLight = new THREE.Object3D();
			flareLight.position.set( 0.8, 0.6, - 2 );
			scene.add( flareLight );
			const flare = new Lensflare();
			flare.addElement( new LensflareElement( patternTexture( THREE, 8, 1 ), 40, 0, new THREE.Color( 0xffeecc ) ) );
			flare.addElement( new LensflareElement( patternTexture( THREE, 4, 2 ), 16, 0.5 ) );
			flare.addElement( new LensflareElement( patternTexture( THREE, 8, 3 ), 24, 0.9, new THREE.Color( 0x6688ff ) ) );
			flareLight.add( flare );
			return { scene, camera: cameraAt( THREE, 0, 0.5, 3 ) };

		}

	}

	return null;

}
