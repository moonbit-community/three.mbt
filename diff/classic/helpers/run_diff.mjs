// Runs the helpers scenarios on the MoonBit port and on upstream three.js r187 and
// compares the logs entry by entry. Usage: node run_diff.mjs [--build] [--show N]
import { execSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';
import { upstreamURL } from '../../lib/env.mjs';

const here = path.dirname( fileURLToPath( import.meta.url ) );
const args = process.argv.slice( 2 );
if ( args.includes( '--build' ) ) execSync( 'moon build --target js', { cwd: here, stdio: 'inherit' } );
const showIndex = args.indexOf( '--show' );
const show = showIndex >= 0 ? Number( args[ showIndex + 1 ] ) : 5;

let log = [];
const fmt = ( v ) => Object.is( v, - 0 ) ? '-0' : String( v );
globalThis.__noteNum = ( l, v ) => log.push( [ l, fmt( v ) ] );
globalThis.__noteStr = ( l, v ) => log.push( [ l, String( v ) ] );
globalThis.__noteTyped = ( l, a ) => log.push( [ l, a.constructor.name + '[' + a.length + '] ' +
	Buffer.from( a.buffer, a.byteOffset, a.byteLength ).toString( 'hex' ) ] );

const mbt = await import( pathToFileURL( path.join( here, '_build/js/debug/build/moonbit-community/three-diff-helpers/main/main.js' ) ) );
mbt.run_mbt();
const mine = log;
log = [];
const THREE = await import( upstreamURL( 'src/Three.js' ) );
const { runUpstream } = await import( pathToFileURL( path.join( here, 'upstream.mjs' ) ) );
runUpstream( THREE );
const theirs = log;

let mismatches = 0;
const length = Math.max( mine.length, theirs.length );
for ( let i = 0; i < length; i ++ ) {

	const a = mine[ i ], b = theirs[ i ];
	if ( a === undefined || b === undefined || a[ 0 ] !== b[ 0 ] || a[ 1 ] !== b[ 1 ] ) {

		if ( mismatches < show ) {

			console.log( `#${i}` );
			console.log( '  mbt:      ' + ( a ? a.join( ' = ' ).slice( 0, 400 ) : '<missing>' ) );
			console.log( '  upstream: ' + ( b ? b.join( ' = ' ).slice( 0, 400 ) : '<missing>' ) );

		}

		mismatches ++;
		if ( a && b && a[ 0 ] !== b[ 0 ] ) break; // logs out of step; later entries are noise

	}

}

const grepIndex = args.indexOf( '--grep' );
if ( grepIndex >= 0 ) for ( const e of mine ) if ( e[ 0 ].includes( args[ grepIndex + 1 ] ) ) console.log( e.join( ' = ' ).slice( 0, 300 ) );
const typed = theirs.filter( ( e ) => / \w+Array\[/.test( ' ' + e[ 1 ] ) ).length;
console.log( `entries: mbt ${mine.length}, upstream ${theirs.length}, typed arrays ${typed}, mismatches ${mismatches}` );
console.log( mismatches === 0 && mine.length === theirs.length ? 'MATCH' : 'DIFF' );
process.exit( mismatches === 0 ? 0 : 1 );
