// node pixel_gl_up.mjs <scene>: renderUpstream( ..., forceWebGL = true ) on the mock GL.
// the add-on scenes' modules import three's bare specifiers (A4)
import '../../webgpu/shader_diff/a4/register_three.mjs';
import url from 'node:url';
import { SRC, TARGETS, flush } from './common.mjs';
import { setupGL } from './pixel_gl_common.mjs';
import { PIXEL_DIR } from './pixel_common.mjs';
const name = process.argv[ 2 ];
const { gl, canvas } = setupGL();
await import( url.pathToFileURL( SRC + '/Three.TSL.js' ).href );
const THREE = await import( url.pathToFileURL( SRC + '/Three.WebGPU.js' ).href );
const Node = ( await import( url.pathToFileURL( SRC + '/nodes/core/Node.js' ).href ) ).default;
const scenes = await import( url.pathToFileURL( PIXEL_DIR + '/webgpu_scenes.js' ).href );
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
const pixels = await scenes.renderUpstream( THREE, name, canvas, true );
gl.__note( 'pixels', pixels === null ? null : [ pixels.constructor.name, pixels.length ] );
await flush();
// a pipe may take a large log in pieces (and refuse with EAGAIN while full) (A4)
{
	const fs = await import( 'node:fs' );
	const out = Buffer.from( '@@LOG ' + JSON.stringify( gl.__log ) + '\n' );
	for ( let off = 0; off < out.length; ) {
		try {
			off += fs.writeSync( 1, out, off );
		} catch ( e ) {
			if ( e.code !== 'EAGAIN' ) throw e;
		}
	}
}
process.exit( 0 );
