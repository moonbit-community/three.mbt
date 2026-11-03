// node pixel_mbt.mjs <scene>: the same scene of examples/pixel_compare/webgpu/main.mbt
// (`render_scene`), built into ../mbt/pixel (main.mbt linked in, plus `align_counters`), on
// the mock GPU; prints @@LOG <json>.
import { setup, flush } from './common.mjs';
import { installDocument, pixelNote, WIDTH, HEIGHT } from './pixel_common.mjs';
const name = process.argv[ 2 ];
const mock = setup();
installDocument( mock );
const MAIN = new URL( '../mbt/_build/js/debug/build/moonbit-community/three-g9-diff/pixel/pixel.js', import.meta.url );
const mbt = await import( MAIN.href );
mbt.align_counters();
const canvas = mock.createCanvas( { width: WIDTH, height: HEIGHT } );
const pixels = await new Promise( ( resolve ) => mbt.render_scene( name, canvas, resolve, false ) );
pixelNote( mock, pixels );
await flush();
// a pipe may take a large log in pieces (and refuse with EAGAIN while full) (A4)
{
	const fs = await import( 'node:fs' );
	const out = Buffer.from( '@@LOG ' + JSON.stringify( mock.log ) + '\n' );
	for ( let off = 0; off < out.length; ) {
		try {
			off += fs.writeSync( 1, out, off );
		} catch ( e ) {
			if ( e.code !== 'EAGAIN' ) throw e;
		}
	}
}
process.exit( 0 );
