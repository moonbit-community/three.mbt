// node mbt_one.mjs <name>: prints the mock GPU log of one MoonBit scenario.
import url from 'node:url';
import { setup, flush, MOCK_OPTIONS } from './common.mjs';
const name = process.argv[ 2 ];
const mock = setup( MOCK_OPTIONS[ name ] );
const MAIN = new URL( '../mbt/_build/js/debug/build/moonbit-community/three-g9-diff/main/main.js', import.meta.url );
const mbt = await import( MAIN.href );
const canvas = mock.createCanvas( { width: 4, height: 4 } );
await new Promise( ( resolve ) => mbt.run_scenario( name, { canvas, note: mock.note, mock }, resolve ) );
await flush();
( await import( 'node:fs' ) ).writeSync( 1, '@@LOG ' + JSON.stringify( mock.log ) + '\n' );
process.exit( 0 );
