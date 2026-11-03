// node dump.mjs <name> <from> <to> [width]: both logs side by side over an entry range.
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import url from 'node:url';
const here = path.dirname( url.fileURLToPath( import.meta.url ) );
const [ name, from = '0', to = '1e9', width = '220' ] = process.argv.slice( 2 );
const get = ( s ) => JSON.parse( execFileSync( 'node', [ path.join( here, s ), name ], { encoding: 'utf8', maxBuffer: 1 << 30 } ).split( '\n' ).find( ( l ) => l.startsWith( '@@LOG ' ) ).slice( 6 ) );
const a = get( 'upstream_one.mjs' ), b = get( 'mbt_one.mjs' );
for ( let i = + from; i < Math.min( + to, Math.max( a.length, b.length ) ); i ++ ) {
	const sa = JSON.stringify( a[ i ] ?? null ), sb = JSON.stringify( b[ i ] ?? null );
	console.log( ( sa === sb ? '  ' : '!!' ) + i + ' U ' + sa.slice( 0, + width ) );
	if ( sa !== sb ) console.log( '  ' + i + ' M ' + sb.slice( 0, + width ) );
}
