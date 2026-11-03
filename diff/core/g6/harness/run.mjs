// G6 differential test: runs each scenario in a fresh process on both sides (the MoonBit
// test `g6diff <name>` in src/nodes/common_g6_diff_test.mbt with G6_DIFF=1, and
// upstream_one.mjs <name>) and compares the two logs entry by entry, byte for byte
// (JSON.stringify of each entry).
//
//   node run.mjs [--repo <three.mbt checkout, default: this repository>] [--quiet] [name ...]
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { REPO } from '../../../lib/env.mjs';

import { scenarios } from './scenarios.mjs';

const here = path.dirname( fileURLToPath( import.meta.url ) );
const args = process.argv.slice( 2 );
let repo = REPO;
let quiet = false;
const only = [];
for ( let i = 0; i < args.length; i ++ ) {

	if ( args[ i ] === '--repo' ) repo = args[ ++ i ];
	else if ( args[ i ] === '--quiet' ) quiet = true;
	else only.push( args[ i ] );

}

function runMoon( name ) {

	const r = spawnSync( 'moon', [ 'test', '--target', 'js', 'src/nodes/common_g6_diff_test.mbt', '-f', `g6diff ${name}` ], {
		cwd: repo, env: { ...process.env, G6_DIFF: '1' }, encoding: 'utf8', maxBuffer: 1 << 28,
	} );
	const out = ( r.stdout || '' ) + ( r.stderr || '' );
	for ( const line of out.split( '\n' ) ) {

		const m = /^@@G6 (\S+) (.*)$/.exec( line.trim() );
		if ( m && m[ 1 ] === name ) return { log: JSON.parse( m[ 2 ] ) };

	}

	return { error: out.split( '\n' ).filter( ( l ) => ! l.startsWith( '@@' ) ).slice( - 25 ).join( '\n' ) };

}

function runUpstream( name ) {

	const r = spawnSync( process.execPath, [ path.join( here, 'upstream_one.mjs' ), name ], { encoding: 'utf8', maxBuffer: 1 << 28 } );
	const lines = ( r.stdout || '' ).trim().split( '\n' );
	try {

		return { log: JSON.parse( lines[ lines.length - 1 ] ) };

	} catch ( e ) {

		return { error: ( r.stdout || '' ) + ( r.stderr || '' ) };

	}

}

let failed = 0;
let passed = 0;
for ( const name of Object.keys( scenarios ) ) {

	if ( only.length && ! only.includes( name ) ) continue;
	const up = runUpstream( name );
	const moon = runMoon( name );
	if ( up.error ) {

		console.log( `UPSTREAM ERROR ${name}\n${up.error}` ); failed ++; continue;

	}

	if ( moon.error ) {

		console.log( `MOON ERROR ${name}\n${moon.error}` ); failed ++; continue;

	}

	const a = moon.log, e = up.log;
	let bad = - 1;
	for ( let i = 0; i < Math.max( a.length, e.length ); i ++ ) {

		if ( JSON.stringify( a[ i ] ) !== JSON.stringify( e[ i ] ) ) {

			bad = i;
			break;

		}

	}

	const exceptions = e.filter( ( x ) => x[ 0 ] === 'exception' ).length;
	if ( bad < 0 && exceptions === 0 ) {

		const gpu = e.filter( ( x ) => x[ 0 ] === 'gpu' ).map( ( x ) => x[ 1 ].length ).reduce( ( s, n ) => s + n, 0 );
		const backend = e.filter( ( x ) => x[ 0 ] === 'backend' ).length;
		console.log( `OK       ${name} (${e.length} entries, ${backend} backend calls, ${gpu} mock GPU calls)` );
		passed ++;

	} else {

		failed ++;
		console.log( `MISMATCH ${name} at entry ${bad} of ${e.length} (moon ${a.length})` );
		if ( ! quiet ) {

			const cut = ( x ) => { const s = JSON.stringify( x ); return s === undefined ? 'undefined' : ( s.length > 1500 ? s.slice( 0, 1500 ) + '...' : s ); };
			if ( bad > 0 ) console.log( '  previous: ' + cut( e[ bad - 1 ] ) );
			console.log( '  upstream: ' + cut( e[ bad ] ) );
			console.log( '  moonbit:  ' + cut( a[ bad ] ) );

		}

	}

}

console.log( `${passed} passed, ${failed} failed` );
process.exit( failed ? 1 : 0 );
