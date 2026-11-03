// node mbt_one.mjs <name>: the MoonBit side (build ../mbt first: moon build --target js).
import { setup, flush } from './common.mjs';
const name = process.argv[ 2 ];
const mock = setup();
const MAIN = new URL( '../mbt/_build/js/debug/build/bobzhang/three-diff-a6-objects/main/main.js', import.meta.url );
const mbt = await import( MAIN.href );
const canvas = mock.createCanvas( { width: 64, height: 32 } );
await new Promise( ( resolve ) => mbt.run_scenario( name, { canvas, note: mock.note, mock }, resolve ) );
await flush();
{ const fs = await import( 'node:fs' ); const buf = Buffer.from( '@@LOG ' + JSON.stringify( mock.log ) + '\n' ); let off = 0; while ( off < buf.length ) { try { off += fs.writeSync( 1, buf, off ); } catch ( e ) { if ( e.code !== 'EAGAIN' ) throw e; } } }
process.exit( 0 );
