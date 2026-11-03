// The objects add-on scenes of the WebGPU pixel comparison (the WebGPU variants of
// examples/jsm/objects): webgpu_scenes.js lists their modules in ADDON_MODULES and its
// `buildAddon` falls through to `buildObjectsAddon`. The MoonBit side is
// webgpu/objects_scenes.mbt, line for line.

export const OBJECTS_SCENE_NAMES = [ 'addon_sky_mesh', 'addon_water_mesh', 'addon_water2_mesh', 'addon_lensflare_mesh' ];

// The add-on modules of each scene, below examples/jsm, in import order.
export const OBJECTS_ADDON_MODULES = {
	addon_sky_mesh: [ 'objects/SkyMesh.js' ],
	addon_water_mesh: [ 'objects/WaterMesh.js' ],
	addon_water2_mesh: [ 'objects/Water2Mesh.js' ],
	addon_lensflare_mesh: [ 'objects/LensflareMesh.js' ],
};

const WIDTH = 128;
const HEIGHT = 96;

function camera( THREE, x, y, z, tx, ty, tz ) {

	const c = new THREE.PerspectiveCamera( 50, WIDTH / HEIGHT, 0.1, 100 );
	c.position.set( x, y, z );
	c.lookAt( tx, ty, tz );
	return c;

}

function view( scene, camera ) {

	return { scene, camera, samples: 0, before: null, render: null };

}

function colored( material, hex ) {

	material.color.setHex( hex );
	return material;

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

// A lit box above the origin.
function addBox( THREE, scene, hex ) {

	scene.add( new THREE.AmbientLight( new THREE.Color( 0x404040 ), 1 ) );
	const light = new THREE.DirectionalLight( new THREE.Color( 0xffffff ), 2 );
	light.position.set( 1, 3, 2 );
	scene.add( light );
	const box = new THREE.Mesh( new THREE.BoxGeometry( 0.8, 0.8, 0.8 ), colored( new THREE.MeshStandardNodeMaterial(), hex ) );
	box.position.set( - 0.3, 0.6, 0 );
	box.rotation.set( 0, 0.6, 0 );
	scene.add( box );

}

export function buildObjectsAddon( THREE, name, A ) {

	const scene = new THREE.Scene();
	switch ( name ) {

		case 'addon_sky_mesh': {

			const sky = new A.SkyMesh();
			sky.scale.setScalar( 50 );
			sky.turbidity.value = 10;
			sky.rayleigh.value = 2.5;
			sky.sunPosition.value.set( 0.2, 0.15, - 1 );
			sky.cloudCoverage.value = 0.5;
			scene.add( sky );
			return view( scene, camera( THREE, 0, 0.5, 0, 0, 0.9, - 3 ) );

		}

		case 'addon_water_mesh': {

			scene.background = new THREE.Color( 0x6688aa );
			addBox( THREE, scene, 0xcc6633 );
			const normals = patternTexture( THREE, 16, 5 );
			normals.wrapS = THREE.RepeatWrapping;
			normals.wrapT = THREE.RepeatWrapping;
			const water = new A.WaterMesh( new THREE.PlaneGeometry( 20, 20 ), { waterNormals: normals, sunDirection: new THREE.Vector3( 0.3, 0.9, 0.2 ).normalize(), sunColor: 0xffffff, waterColor: 0x001e0f, distortionScale: 3.7 } );
			water.rotation.set( - Math.PI / 2, 0, 0 );
			scene.add( water );
			return view( scene, camera( THREE, 0, 1.5, 4, 0, 0, 0 ) );

		}

		case 'addon_water2_mesh': {

			scene.background = new THREE.Color( 0x335577 );
			addBox( THREE, scene, 0x44aa66 );
			const ground = new THREE.Mesh( new THREE.PlaneGeometry( 20, 20 ), colored( new THREE.MeshStandardNodeMaterial(), 0x997755 ) );
			ground.rotation.set( - Math.PI / 2, 0, 0 );
			ground.position.set( 0, - 0.5, 0 );
			scene.add( ground );
			const water = new A.WaterMesh( new THREE.PlaneGeometry( 6, 6 ), { color: 0xaaccff, scale: 2, flowDirection: new THREE.Vector2( 1, 0.5 ), normalMap0: patternTexture( THREE, 16, 7 ), normalMap1: patternTexture( THREE, 16, 11 ) } );
			water.rotation.set( - Math.PI / 2, 0, 0 );
			scene.add( water );
			return view( scene, camera( THREE, 0, 2, 4, 0, 0, 0 ) );

		}

		case 'addon_lensflare_mesh': {

			addBox( THREE, scene, 0x3366cc );
			const flareLight = new THREE.Object3D();
			flareLight.position.set( 0.8, 0.6, - 2 );
			scene.add( flareLight );
			const flare = new A.LensflareMesh();
			flare.addElement( new A.LensflareElement( patternTexture( THREE, 8, 1 ), 40, 0, new THREE.Color( 0xffeecc ) ) );
			flare.addElement( new A.LensflareElement( patternTexture( THREE, 4, 2 ), 16, 0.5 ) );
			flare.addElement( new A.LensflareElement( patternTexture( THREE, 8, 3 ), 24, 0.9, new THREE.Color( 0x6688ff ) ) );
			flareLight.add( flare );
			return view( scene, camera( THREE, 0, 0.5, 3, 0, 0, 0 ) );

		}

	}

	return null;

}
