// The upstream half of the pixel comparison: the scenes of main/main.mbt built with
// three.js itself. Every function mirrors the MoonBit code line by line; keep them in step.

import { OBJECTS_SCENE_NAMES, buildObjectsAddon } from './objects_scenes.js';

export const WIDTH = 128;
export const HEIGHT = 96;

export const SCENE_NAMES = [
	'unlit_box', 'lights_directional', 'lights_point', 'lights_spot', 'lights_hemisphere',
	'shadow', 'data_texture', 'fog', 'skinned_morph', 'instancing', 'lines_points', 'transparent',
	'render_to_texture', 'helpers_grid_axes', 'helpers_lights', 'helpers_boxes_camera', 'helpers_skeleton',
	// the objects add-ons (examples/jsm/objects, objects_scenes.js)
	...OBJECTS_SCENE_NAMES,
];

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

function addSpheres( THREE, scene ) {

	const sphere = new THREE.SphereGeometry( 0.5, 32, 16 );
	const lambert = new THREE.Mesh( sphere, color( new THREE.MeshLambertMaterial(), 0xcc4444 ) );
	lambert.position.set( - 1.1, 0, 0 );
	scene.add( lambert );
	const phongMaterial = color( new THREE.MeshPhongMaterial(), 0x44cc44 );
	phongMaterial.shininess = 60;
	scene.add( new THREE.Mesh( sphere, phongMaterial ) );
	const standardMaterial = color( new THREE.MeshStandardMaterial(), 0x4444cc );
	standardMaterial.roughness = 0.4;
	standardMaterial.metalness = 0.1;
	const standard = new THREE.Mesh( sphere, standardMaterial );
	standard.position.set( 1.1, 0, 0 );
	scene.add( standard );
	scene.add( new THREE.AmbientLight( new THREE.Color( 0x202020 ), 1 ) );

}

function dataTexture( THREE, width, height ) {

	const data = new Uint8Array( width * height * 4 );
	for ( let y = 0; y < height; y ++ ) {

		for ( let x = 0; x < width; x ++ ) {

			const i = ( y * width + x ) * 4;
			const on = ( x + y ) % 2 === 0;
			data[ i ] = on ? 255 : 30;
			data[ i + 1 ] = Math.floor( x * 255 / ( width - 1 ) );
			data[ i + 2 ] = Math.floor( y * 255 / ( height - 1 ) );
			data[ i + 3 ] = 255;

		}

	}

	const texture = new THREE.DataTexture( data, width, height );
	texture.needsUpdate = true;
	return texture;

}

// Builds scene `name`; `renderer` is there for scenes that need a setup pass.
export function build( THREE, name, renderer ) {

	const scene = new THREE.Scene();
	switch ( name ) {

		case 'unlit_box': {

			const box = new THREE.Mesh( new THREE.BoxGeometry( 1, 1, 1 ), color( new THREE.MeshBasicMaterial(), 0xff8800 ) );
			box.rotation.set( 0.5, 0.7, 0 );
			scene.add( box );
			return { scene, camera: cameraAt( THREE, 0, 0, 3 ) };

		}

		case 'lights_directional': {

			addSpheres( THREE, scene );
			const light = new THREE.DirectionalLight( new THREE.Color( 0xffffff ), 2 );
			light.position.set( 1, 2, 3 );
			scene.add( light );
			return { scene, camera: cameraAt( THREE, 0, 0, 4 ) };

		}

		case 'lights_point': {

			addSpheres( THREE, scene );
			const light = new THREE.PointLight( new THREE.Color( 0xffffff ), 8, 0, 2 );
			light.position.set( 0, 1.5, 1.5 );
			scene.add( light );
			return { scene, camera: cameraAt( THREE, 0, 0, 4 ) };

		}

		case 'lights_spot': {

			addSpheres( THREE, scene );
			const light = new THREE.SpotLight( new THREE.Color( 0xffffff ), 10, 0, Math.PI / 5, 0.3, 2 );
			light.position.set( 0, 3, 2 );
			scene.add( light );
			return { scene, camera: cameraAt( THREE, 0, 0, 4 ) };

		}

		case 'lights_hemisphere': {

			addSpheres( THREE, scene );
			scene.add( new THREE.HemisphereLight( new THREE.Color( 0x88aaff ), new THREE.Color( 0x553311 ), 1.5 ) );
			return { scene, camera: cameraAt( THREE, 0, 0, 4 ) };

		}

		case 'shadow': {

			renderer.shadowMap.enabled = true;
			const sphere = new THREE.Mesh( new THREE.SphereGeometry( 0.5, 24, 12 ), color( new THREE.MeshStandardMaterial(), 0xdddddd ) );
			sphere.position.set( 0, 0.6, 0 );
			sphere.castShadow = true;
			scene.add( sphere );
			const ground = new THREE.Mesh( new THREE.PlaneGeometry( 6, 6 ), color( new THREE.MeshStandardMaterial(), 0x888888 ) );
			ground.rotation.x = - Math.PI / 2;
			ground.receiveShadow = true;
			scene.add( ground );
			const light = new THREE.DirectionalLight( new THREE.Color( 0xffffff ), 2.5 );
			light.position.set( 2, 4, 2 );
			light.castShadow = true;
			light.shadow.mapSize.set( 256, 256 );
			scene.add( light );
			scene.add( new THREE.AmbientLight( new THREE.Color( 0x404040 ), 1 ) );
			return { scene, camera: cameraAt( THREE, 0, 2, 4 ) };

		}

		case 'data_texture': {

			const material = new THREE.MeshBasicMaterial();
			material.map = dataTexture( THREE, 4, 4 );
			const plane = new THREE.Mesh( new THREE.PlaneGeometry( 2, 2 ), material );
			plane.rotation.set( - 0.3, 0.2, 0 );
			scene.add( plane );
			return { scene, camera: cameraAt( THREE, 0, 0, 3 ) };

		}

		case 'fog': {

			const fogColor = 0x8899aa;
			scene.background = new THREE.Color( fogColor );
			scene.fog = new THREE.Fog( new THREE.Color( fogColor ), 2, 8 );
			const geometry = new THREE.BoxGeometry( 0.6, 0.6, 0.6 );
			for ( let i = 0; i < 5; i ++ ) {

				const box = new THREE.Mesh( geometry, color( new THREE.MeshLambertMaterial(), 0xff4040 ) );
				box.position.set( i * 0.5 - 1, 0, - i * 1.5 );
				scene.add( box );

			}

			const light = new THREE.DirectionalLight( new THREE.Color( 0xffffff ), 2 );
			light.position.set( 1, 1, 2 );
			scene.add( light );
			return { scene, camera: cameraAt( THREE, 0, 0.5, 3 ) };

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
			const morph = new THREE.Mesh( morphGeometry, color( new THREE.MeshStandardMaterial(), 0xff00ff ) );
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
			const skinned = new THREE.SkinnedMesh( skinGeometry, color( new THREE.MeshLambertMaterial(), 0xffcc00 ) );
			const root = new THREE.Bone();
			const tip = new THREE.Bone();
			tip.position.y = 0;
			root.add( tip );
			skinned.add( root );
			skinned.bind( new THREE.Skeleton( [ root, tip ] ) );
			tip.rotation.z = 0.6;
			skinned.position.set( 0.9, 0, 0 );
			scene.add( skinned );
			return { scene, camera: cameraAt( THREE, 0, 0, 3 ) };

		}

		case 'instancing': {

			const instanced = new THREE.InstancedMesh( new THREE.BoxGeometry( 0.4, 0.4, 0.4 ), new THREE.MeshLambertMaterial(), 9 );
			const matrix = new THREE.Matrix4();
			for ( let i = 0; i < 9; i ++ ) {

				const x = ( i % 3 ) - 1;
				const y = Math.floor( i / 3 ) - 1;
				instanced.setMatrixAt( i, matrix.makeRotationY( i * 0.3 ).setPosition( x * 0.7, y * 0.6, 0 ) );
				instanced.setColorAt( i, new THREE.Color( i / 8, 0.5, 1 - i / 8 ) );

			}

			scene.add( instanced );
			const light = new THREE.DirectionalLight( new THREE.Color( 0xffffff ), 2 );
			light.position.set( 1, 2, 3 );
			scene.add( light );
			return { scene, camera: cameraAt( THREE, 0, 0, 3 ) };

		}

		case 'lines_points': {

			const spiral = [];
			for ( let i = 0; i < 64; i ++ ) {

				const t = i / 63;
				const angle = t * Math.PI * 6;
				spiral.push( new THREE.Vector3( Math.cos( angle ) * t * 1.4, Math.sin( angle ) * t * 1, 0 ) );

			}

			const lineMaterial = color( new THREE.LineBasicMaterial(), 0x00ffaa );
			scene.add( new THREE.Line( new THREE.BufferGeometry().setFromPoints( spiral ), lineMaterial ) );
			const segments = new THREE.LineSegments(
				new THREE.BufferGeometry().setFromPoints( [
					new THREE.Vector3( - 1.6, - 1, 0 ), new THREE.Vector3( 1.6, - 1, 0 ),
					new THREE.Vector3( - 1.6, 1, 0 ), new THREE.Vector3( 1.6, 1, 0 ),
				] ),
				color( new THREE.LineBasicMaterial(), 0xffff00 ),
			);
			scene.add( segments );
			const pointsMaterial = color( new THREE.PointsMaterial(), 0xff3366 );
			pointsMaterial.size = 4;
			pointsMaterial.sizeAttenuation = false;
			scene.add( new THREE.Points( new THREE.BufferGeometry().setFromPoints( spiral ), pointsMaterial ) );
			return { scene, camera: cameraAt( THREE, 0, 0, 3 ) };

		}

		case 'transparent': {

			const back = new THREE.Mesh( new THREE.BoxGeometry( 1, 1, 1 ), color( new THREE.MeshBasicMaterial(), 0x2244ff ) );
			back.position.set( 0.3, 0, - 1 );
			back.rotation.set( 0.4, 0.6, 0 );
			scene.add( back );
			const glassMaterial = color( new THREE.MeshBasicMaterial(), 0xff2222 );
			glassMaterial.transparent = true;
			glassMaterial.opacity = 0.5;
			glassMaterial.side = THREE.DoubleSide;
			const glass = new THREE.Mesh( new THREE.SphereGeometry( 0.6, 24, 12 ), glassMaterial );
			scene.add( glass );
			const veilMaterial = color( new THREE.MeshBasicMaterial(), 0x22ff22 );
			veilMaterial.transparent = true;
			veilMaterial.opacity = 0.3;
			const veil = new THREE.Mesh( new THREE.PlaneGeometry( 1.2, 0.8 ), veilMaterial );
			veil.position.set( - 0.4, - 0.2, 0.8 );
			scene.add( veil );
			return { scene, camera: cameraAt( THREE, 0, 0, 3 ) };

		}

		case 'render_to_texture': {

			// pass 1: a lit box into a 64x64 target
			const inner = new THREE.Scene();
			inner.background = new THREE.Color( 0x203040 );
			const box = new THREE.Mesh( new THREE.BoxGeometry( 1, 1, 1 ), color( new THREE.MeshLambertMaterial(), 0xffaa00 ) );
			box.rotation.set( 0.6, 0.8, 0 );
			inner.add( box );
			const light = new THREE.DirectionalLight( new THREE.Color( 0xffffff ), 2 );
			light.position.set( 1, 2, 3 );
			inner.add( light );
			const innerCamera = new THREE.PerspectiveCamera( 50, 1, 0.1, 10 );
			innerCamera.position.set( 0, 0, 2.5 );
			const target = new THREE.WebGLRenderTarget( 64, 64 );
			renderer.setRenderTarget( target );
			renderer.render( inner, innerCamera );
			renderer.setRenderTarget( null );
			// pass 2: the target on a tilted plane
			const material = new THREE.MeshBasicMaterial();
			material.map = target.texture;
			const plane = new THREE.Mesh( new THREE.PlaneGeometry( 1.6, 1.6 ), material );
			plane.rotation.set( 0, 0.5, 0.1 );
			scene.add( plane );
			return { scene, camera: cameraAt( THREE, 0, 0, 2.5 ) };

		}

		case 'helpers_grid_axes': {

			scene.add( new THREE.GridHelper( 4, 8, new THREE.Color( 0xff4444 ), new THREE.Color( 0x666666 ) ) );
			const polar = new THREE.PolarGridHelper( 1.5, 8, 4, 32, new THREE.Color( 0x44ff44 ), new THREE.Color( 0x4444ff ) );
			polar.position.set( 0, 0.5, 0 );
			scene.add( polar );
			const axes = new THREE.AxesHelper( 1.5 );
			axes.setColors( new THREE.Color( 0xff00ff ), new THREE.Color( 0xffff00 ), new THREE.Color( 0x00ffff ) );
			scene.add( axes );
			return { scene, camera: cameraAt( THREE, 2.5, 2, 3 ) };

		}

		case 'helpers_lights': {

			addSpheres( THREE, scene );
			const directional = new THREE.DirectionalLight( new THREE.Color( 0xffffff ), 1.5 );
			directional.position.set( 1.5, 1.5, 1 );
			scene.add( directional );
			scene.add( new THREE.DirectionalLightHelper( directional, 0.3 ) );
			const point = new THREE.PointLight( new THREE.Color( 0xffaa44 ), 4, 0, 2 );
			point.position.set( - 1.2, 1, 0.8 );
			scene.add( point );
			scene.add( new THREE.PointLightHelper( point, 0.15 ) );
			const spot = new THREE.SpotLight( new THREE.Color( 0x44aaff ), 6, 4, Math.PI / 8, 0.2, 2 );
			spot.position.set( 1, - 1.2, 1.5 );
			scene.add( spot );
			scene.add( new THREE.SpotLightHelper( spot ) );
			const hemisphere = new THREE.HemisphereLight( new THREE.Color( 0x8888ff ), new THREE.Color( 0x884422 ), 0.5 );
			hemisphere.position.set( 0, 1.2, - 0.5 );
			scene.add( hemisphere );
			scene.add( new THREE.HemisphereLightHelper( hemisphere, 0.2 ) );
			return { scene, camera: cameraAt( THREE, 0, 0.5, 4.5 ) };

		}

		case 'helpers_boxes_camera': {

			const box = new THREE.Mesh( new THREE.BoxGeometry( 0.8, 0.6, 0.5 ), color( new THREE.MeshBasicMaterial(), 0x336699 ) );
			box.position.set( - 0.8, 0.2, 0 );
			box.rotation.set( 0.4, 0.6, 0.2 );
			scene.add( box );
			scene.add( new THREE.BoxHelper( box, new THREE.Color( 0xffff00 ) ) );
			const bounds = new THREE.Box3( new THREE.Vector3( 0.3, - 0.8, - 0.5 ), new THREE.Vector3( 1.3, - 0.2, 0.3 ) );
			scene.add( new THREE.Box3Helper( bounds, new THREE.Color( 0x00ffff ) ) );
			const watched = new THREE.PerspectiveCamera( 40, 1.5, 0.3, 1.5 );
			watched.position.set( 0.8, 0.6, 0.5 );
			watched.lookAt( - 0.5, 0, - 1 );
			scene.add( watched );
			scene.add( new THREE.CameraHelper( watched ) );
			const normal = new THREE.Vector3( 0, 1, 0.3 ).normalize();
			scene.add( new THREE.PlaneHelper( new THREE.Plane( normal, 0.9 ), 1.6, new THREE.Color( 0xff66cc ) ) );
			const direction = new THREE.Vector3( 1, 1, 0 ).normalize();
			scene.add( new THREE.ArrowHelper( direction, new THREE.Vector3( - 1.5, - 1, 0 ), 1.2, new THREE.Color( 0xff8800 ) ) );
			return { scene, camera: cameraAt( THREE, 0, 1, 4 ) };

		}

		case 'helpers_skeleton': {

			const light = new THREE.DirectionalLight( new THREE.Color( 0xffffff ), 2 );
			light.position.set( 1, 2, 3 );
			scene.add( light );
			scene.add( new THREE.AmbientLight( new THREE.Color( 0x404040 ), 1 ) );
			const skinGeometry = new THREE.BoxGeometry( 0.3, 1.6, 0.3, 1, 8, 1 );
			const skinPosition = skinGeometry.attributes.position;
			const skinIndex = [];
			const skinWeight = [];
			for ( let i = 0; i < skinPosition.count; i ++ ) {

				const y = skinPosition.getY( i );
				skinIndex.push( y > 0.3 ? 2 : ( y > - 0.3 ? 1 : 0 ) );
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
			const skinned = new THREE.SkinnedMesh( skinGeometry, color( new THREE.MeshLambertMaterial(), 0x88cc44 ) );
			const root = new THREE.Bone();
			root.position.y = - 0.8;
			const middle = new THREE.Bone();
			middle.position.y = 0.5;
			const tip = new THREE.Bone();
			tip.position.y = 0.6;
			root.add( middle );
			middle.add( tip );
			skinned.add( root );
			skinned.bind( new THREE.Skeleton( [ root, middle, tip ] ) );
			middle.rotation.z = 0.5;
			tip.rotation.z = 0.6;
			skinned.position.set( - 0.3, 0, 0 );
			scene.add( skinned );
			scene.add( new THREE.SkeletonHelper( skinned ) );
			return { scene, camera: cameraAt( THREE, 0, 0, 3 ) };

		}

	}

	return buildObjectsAddon( THREE, name, renderer, scene );

}
