// The upstream half of the glTF pixel comparison: the scenes of gltf/main.mbt with
// three.js's GLTFLoader (+ DRACOLoader) and WebGPURenderer, line for line.

import { GLTFLoader } from '../../.repos/three.js/examples/jsm/loaders/GLTFLoader.js';
import { DRACOLoader } from '../../.repos/three.js/examples/jsm/loaders/DRACOLoader.js';

export const WIDTH = 128;
export const HEIGHT = 96;

const MODELS = '../../.repos/three.js/examples/models/gltf/';
const DRACO_PATH = '../../.repos/three.js/examples/jsm/libs/draco/gltf/';

export const SCENE_NAMES = [ 'damaged_helmet', 'draco_duck', 'skinned_robot', 'skinned_soldier', 'draco_tokyo' ];

const SETUPS = {
	damaged_helmet: { url: MODELS + 'DamagedHelmet/glTF/DamagedHelmet.gltf', camera: [ 1.2, 0.6, 2.6 ], target: [ 0, 0, 0 ], clip: null, time: 0 },
	draco_duck: { url: MODELS + 'duck.glb', camera: [ 0.25, 0.2, 0.35 ], target: [ 0, 0.09, 0.02 ], clip: null, time: 0 },
	skinned_robot: { url: MODELS + 'RobotExpressive/RobotExpressive.glb', camera: [ 2, 3, 8 ], target: [ 0, 2.2, 0 ], clip: 'Dance', time: 1.25 },
	skinned_soldier: { url: MODELS + 'Soldier.glb', camera: [ 1, 1.4, 3.2 ], target: [ 0, 0.9, 0 ], clip: 'Walk', time: 0.4 },
	draco_tokyo: { url: MODELS + 'LittlestTokyo.glb', camera: [ 300, 250, 500 ], target: [ 0, 50, 0 ], clip: 'Take 001', time: 2 },
};

function build( THREE, s, gltf ) {

	const scene = new THREE.Scene();
	scene.background = new THREE.Color( 0x334455 );
	scene.add( new THREE.HemisphereLight( 0xffffff, 0x444444, 1.5 ) );
	const sun = new THREE.DirectionalLight( 0xffffff, 2.5 );
	sun.position.set( 3, 5, 4 );
	scene.add( sun );
	const model = gltf.scene;
	scene.add( model );
	if ( s.clip !== null ) {

		const mixer = new THREE.AnimationMixer( model );
		const clip = THREE.AnimationClip.findByName( gltf.animations, s.clip );
		if ( ! clip ) throw new Error( 'no clip ' + s.clip );
		mixer.clipAction( clip ).play();
		mixer.update( s.time );

	}

	const camera = new THREE.PerspectiveCamera( 45, WIDTH / HEIGHT, 0.01, 2000 );
	camera.position.set( ...s.camera );
	camera.lookAt( ...s.target );
	return { scene, camera };

}

export async function renderUpstream( THREE, name, canvas, forceWebGL = false ) {

	const s = SETUPS[ name ];
	if ( s === undefined ) throw new Error( 'unknown scene ' + name );
	const draco = new DRACOLoader();
	draco.setDecoderPath( DRACO_PATH );
	const loader = new GLTFLoader().setDRACOLoader( draco );
	const gltf = await new Promise( ( resolve, reject ) => loader.load( s.url, resolve, undefined, reject ) );
	draco.dispose();
	const { scene, camera } = build( THREE, s, gltf );
	const renderer = new THREE.WebGPURenderer( { canvas, antialias: false, forceWebGL } );
	renderer.setPixelRatio( 1 );
	renderer.setSize( WIDTH, HEIGHT, false );
	await renderer.init();
	const target = new THREE.RenderTarget( WIDTH, HEIGHT );
	renderer.setRenderTarget( target );
	renderer.render( scene, camera );
	const pixels = await renderer.readRenderTargetPixelsAsync( target, 0, 0, WIDTH, HEIGHT );
	await renderer.dispose();
	return pixels;

}
