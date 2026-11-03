// G10 differential test: runs each scenario in a fresh process on both sides (the MoonBit
// test "g10diff <name>" in src/renderers/webgl_fallback/g10_diff_test.mbt with
// G10_DIFF=1, and upstream_one.mjs <name>) and compares the two mock-gl logs entry by
// entry, byte for byte.
//
//   node run.mjs [--repo <three.mbt checkout, default: this repository>] [--quiet] [--context N] [name ...]
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { REPO } from '../../../lib/env.mjs';

import { scenarios, known } from './scenarios.mjs';

const here = path.dirname( fileURLToPath( import.meta.url ) );
const args = process.argv.slice( 2 );
let repo = REPO;
let quiet = false;
let context = 3;
const only = [];
for ( let i = 0; i < args.length; i ++ ) {

	if ( args[ i ] === '--repo' ) repo = args[ ++ i ];
	else if ( args[ i ] === '--quiet' ) quiet = true;
	else if ( args[ i ] === '--context' ) context = Number( args[ ++ i ] );
	else only.push( args[ i ] );

}

function runMoon( name ) {

	const r = spawnSync( 'moon', [ 'test', '--target', 'js', 'src/renderers/webgl_fallback/g10_diff_test.mbt', '-f', `g10diff ${name}` ], {
		cwd: repo, env: { ...process.env, G10_DIFF: '1' }, encoding: 'utf8', maxBuffer: 1 << 28,
	} );
	const out = ( r.stdout || '' ) + ( r.stderr || '' );
	for ( const line of out.split( '\n' ) ) {

		const m = /^@@G10_LOG (\S+) (.*)$/.exec( line.trim() );
		if ( m && m[ 1 ] === name ) return { log: JSON.parse( m[ 2 ] ) };

	}

	return { error: out.split( '\n' ).filter( ( l ) => ! l.startsWith( '@@' ) && ! /│|╭|╰|─╯|^Warning/.test( l ) ).slice( - 25 ).join( '\n' ) };

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

const short = ( s ) => s === undefined ? '<end>' : ( s.length > 400 ? s.slice( 0, 400 ) + '…' : s );
let failed = 0;
let passed = 0;
let knownCount = 0;
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

		if ( a[ i ] !== e[ i ] ) {

			bad = i; break;

		}

	}

	if ( bad === - 1 ) {

		passed ++;
		if ( ! quiet ) console.log( `ok       ${name} (${e.length} entries)` );

	} else if ( known.includes( name ) ) {

		knownCount ++;
		console.log( `KNOWN    ${name} differs at entry ${bad} (a difference outside webgl_fallback; see scenarios.mjs)` );
		continue;

	} else {

		failed ++;
		console.log( `MISMATCH ${name} at entry ${bad} (upstream ${e.length}, moonbit ${a.length})` );
		for ( let j = Math.max( 0, bad - context ); j < Math.min( Math.max( a.length, e.length ), bad + context ); j ++ ) {

			const mark = j === bad ? '>' : ' ';
			if ( a[ j ] === e[ j ] ) console.log( `  ${mark}    ${short( e[ j ] )}` );
			else console.log( `  ${mark} up: ${short( e[ j ] )}\n  ${mark} mb: ${short( a[ j ] )}` );

		}

	}

}

console.log( `\n${passed}/${passed + failed} scenarios identical` + ( knownCount ? `, ${knownCount} known differences outside webgl_fallback` : '' ) );
process.exit( failed ? 1 : 0 );
