// node pixel_gl_mbt.mjs <scene>: render_scene( ..., force_webgl = true ) on the mock GL.
import { flush } from './common.mjs';
import { setupGL } from './pixel_gl_common.mjs';
const name = process.argv[ 2 ];
const { gl, canvas } = setupGL();
const MAIN = new URL( '../mbt/_build/js/debug/build/moonbit-community/three-g9-diff/pixel/pixel.js', import.meta.url );
const mbt = await import( MAIN.href );
mbt.align_counters();
const pixels = await new Promise( ( resolve ) => mbt.render_scene( name, canvas, resolve, true ) );
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
