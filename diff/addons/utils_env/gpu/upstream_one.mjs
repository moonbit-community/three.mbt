// node --import ../register.mjs upstream_one.mjs <name> (with A6_THREE=webgpu)
import url from 'node:url';
import { setup, flush, SRC, TARGETS } from './common.mjs';
const name = process.argv[ 2 ];
const mock = setup();
const TSL = await import( url.pathToFileURL( SRC + '/Three.TSL.js' ).href );
const THREE = await import( url.pathToFileURL( SRC + '/Three.WebGPU.js' ).href );
const Node = ( await import( url.pathToFileURL( SRC + '/nodes/core/Node.js' ).href ) ).default;
// the add-on modules, in an app's import order, before the counters are aligned
const A = {
	...( await import( 'three/addons/environments/RoomEnvironment.js' ) ),
	...( await import( 'three/addons/environments/ColorEnvironment.js' ) ),
	...( await import( 'three/addons/environments/DebugEnvironment.js' ) ),
	...( await import( 'three/addons/utils/WebGPUTextureUtils.js' ) ),
};
const { scenarios } = await import( './scenarios.mjs' );
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
await scenarios[ name ]( { THREE, TSL, A, mock, canvas, note: mock.note, name } );
await flush();
{ const fs = await import( 'node:fs' ); const buf = Buffer.from( '@@LOG ' + JSON.stringify( mock.log ) + '\n' ); let off = 0; while ( off < buf.length ) { try { off += fs.writeSync( 1, buf, off ); } catch ( e ) { if ( e.code !== 'EAGAIN' ) throw e; } } }
process.exit( 0 );
