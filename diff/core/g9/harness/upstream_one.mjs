// node upstream_one.mjs <name>: prints the mock GPU log of one upstream scenario.
import url from 'node:url';
import { setup, flush, SRC, TARGETS, MOCK_OPTIONS } from './common.mjs';
const name = process.argv[ 2 ];
const mock = setup( MOCK_OPTIONS[ name ] );
// the published bundles' module order: three.webgpu.js imports three.tsl.js first (fn<id> names)
const TSL = await import( url.pathToFileURL( SRC + '/Three.TSL.js' ).href );
const THREE = await import( url.pathToFileURL( SRC + '/Three.WebGPU.js' ).href );
const Node = ( await import( url.pathToFileURL( SRC + '/nodes/core/Node.js' ).href ) ).default;
const { scenarios } = await import( './scenarios.mjs' );
// align the global id counters
const probe = {
	node: () => new Node().id,
	object3d: () => new THREE.Object3D().id,
	material: () => new THREE.Material().id,
	texture: () => new THREE.Texture().id,
	attribute: () => new THREE.BufferAttribute( new Float32Array( 1 ), 1 ).id,
	geometry: () => new THREE.BufferGeometry().id,
};
for ( const [ k, f ] of Object.entries( probe ) ) {
	let id = f();
	if ( id >= TARGETS[ k ] ) throw new Error( `counter ${k} already at ${id}` );
	while ( id < TARGETS[ k ] - 1 ) id = f();
}
const canvas = mock.createCanvas( { width: 4, height: 4 } );
const ctx = { THREE, TSL, mock, canvas, note: mock.note, name };
await scenarios[ name ]( ctx );
await flush();
( await import( 'node:fs' ) ).writeSync( 1, '@@LOG ' + JSON.stringify( mock.log ) + '\n' );
process.exit( 0 );
