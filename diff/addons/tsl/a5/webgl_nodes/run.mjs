// node run.mjs [--repo <three.mbt checkout>] [--show N] [name ...]: runs the MoonBit
// scenarios (moon test of src/addons/tsl/a5_webgl_nodes_handler_test.mbt with WEBGL_DIFF=1)
// and the upstream ones (upstream.mjs, with the 'three' resolve hooks), and compares the
// logs entry by entry, printing the first mismatch with context. Both logs are written to
// OUT/addons_a5_webgl_nodes/last_{mb,up}.json (dd.py diffs one scenario of them).
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { REPO, outDir } from '../../../../lib/env.mjs';
const OUT = outDir( 'addons_a5_webgl_nodes' );
const args = process.argv.slice( 2 );
let repo = REPO;
let show = 4;
const only = [];
for ( let i = 0; i < args.length; i ++ ) {

	if ( args[ i ] === '--repo' ) repo = args[ ++ i ];
	else if ( args[ i ] === '--show' ) show = Number( args[ ++ i ] );
	else only.push( args[ i ] );

}

const parse = ( out ) => {

	const logs = {};
	for ( const line of out.split( '\n' ) ) {

		const m = /^@@WEBGL_LOG (\S+) (.*)$/.exec( line.trim() );
		if ( m ) logs[ m[ 1 ] ] = JSON.parse( m[ 2 ] );

	}

	return logs;

};

const mb = spawnSync( 'moon', [ 'test', '--target', 'js', 'src/addons/tsl/a5_webgl_nodes_handler_test.mbt' ], { cwd: repo, env: { ...process.env, WEBGL_DIFF: '1' }, encoding: 'utf8', maxBuffer: 1 << 30 } );
const mbOut = ( mb.stdout || '' ) + ( mb.stderr || '' );
if ( mb.status !== 0 ) console.log( 'moon test exited ' + mb.status + ':\n' + mbOut.split( '\n' ).filter( ( l ) => ! l.startsWith( '@@' ) ).slice( - 40 ).join( '\n' ) );
const up = spawnSync( 'node', [ '--import', './register.mjs', 'upstream.mjs' ], { cwd: new URL( '.', import.meta.url ).pathname, encoding: 'utf8', maxBuffer: 1 << 30 } );
if ( up.status !== 0 ) console.log( 'upstream exited ' + up.status + ':\n' + ( up.stderr || '' ).split( '\n' ).slice( - 30 ).join( '\n' ) );
const moonLogs = parse( mbOut );
const upLogs = parse( up.stdout || '' );
fs.writeFileSync( path.join( OUT, 'last_mb.json' ), JSON.stringify( moonLogs ) );
fs.writeFileSync( path.join( OUT, 'last_up.json' ), JSON.stringify( upLogs ) );
let failed = 0, passed = 0;
const cut = ( s ) => s.length > 400 ? s.slice( 0, 400 ) + '...(' + s.length + ')' : s;
for ( const name of Object.keys( upLogs ) ) {

	if ( only.length && ! only.includes( name ) ) continue;
	const expected = upLogs[ name ];
	const actual = moonLogs[ name ];
	if ( actual === undefined ) {

		console.log( `MISSING  ${name}` ); failed ++; continue;

	}

	let i = 0;
	while ( i < expected.length && i < actual.length && expected[ i ] === actual[ i ] ) i ++;
	if ( i === expected.length && i === actual.length ) {

		console.log( `ok       ${name} (${expected.length} entries)` ); passed ++; continue;

	}

	failed ++;
	console.log( `MISMATCH ${name} at entry ${i} (upstream ${expected.length}, moonbit ${actual.length})` );
	for ( let j = Math.max( 0, i - 2 ); j < Math.min( Math.max( expected.length, actual.length ), i + show ); j ++ ) {

		console.log( `  ${j === i ? '>' : ' '} up: ${cut( String( expected[ j ] ) )}\n  ${j === i ? '>' : ' '} mb: ${cut( String( actual[ j ] ) )}` );

	}

}

for ( const name of Object.keys( moonLogs ) ) if ( ! ( name in upLogs ) ) console.log( `NOTE     ${name}: no upstream scenario` );
if ( Object.keys( upLogs ).length === 0 ) failed ++;
console.log( `\n${passed} identical, ${failed} different or missing` );
process.exit( failed ? 1 : 0 );
