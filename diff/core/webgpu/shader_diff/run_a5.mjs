// Runs only the A5 scenarios: each src/addons/tsl/a5_<group>_shader_diff_test.mbt in its
// own `moon test` against the matching upstream group (upstream_a5.mjs), byte for byte.
//
//   node run_a5.mjs [--repo <three.mbt checkout, default: this repository>] [--show] [--group g,h] [name ...]
import { REPO, UPSTREAM } from '../../../lib/env.mjs';
import { spawnSync } from 'node:child_process';
import { A5_GROUPS, runGroup } from './upstream_a5.mjs';

const args = process.argv.slice( 2 );
let repo = REPO;
let show = false;
const only = [];
let groups = A5_GROUPS;
for ( let i = 0; i < args.length; i ++ ) {

	if ( args[ i ] === '--repo' ) repo = args[ ++ i ];
	else if ( args[ i ] === '--show' ) show = true;
	else if ( args[ i ] === '--group' ) groups = args[ ++ i ].split( ',' );
	else only.push( args[ i ] );

}

let failed = 0, passed = 0;
for ( const g of groups ) {

	const file = `src/addons/tsl/a5_${g}_shader_diff_test.mbt`;
	const r = spawnSync( 'moon', [ 'test', '--target', 'js', file ], { cwd: repo, env: { ...process.env, SHADER_DIFF: '1' }, encoding: 'utf8', maxBuffer: 1 << 28 } );
	const out = ( r.stdout || '' ) + ( r.stderr || '' );
	const moon = {};
	for ( const line of out.split( '\n' ) ) {

		const m = /^@@SHADER (\S+) (.*)$/.exec( line.trim() );
		if ( m ) moon[ m[ 1 ] ] = JSON.parse( m[ 2 ] );

	}

	if ( r.status !== 0 ) console.log( `moon test ${file} exited ${r.status}:\n` + out.split( '\n' ).filter( ( l ) => ! l.startsWith( '@@' ) ).slice( - 30 ).join( '\n' ) );
	const up = runGroup( g );
	for ( const name of Object.keys( up ) ) {

		if ( only.length && ! only.includes( name ) ) continue;
		const a = moon[ name ];
		const e = up[ name ];
		if ( a === undefined ) {

			console.log( `MISSING  ${name}` + ( e.error ? ` (upstream error: ${e.error.slice( 0, 400 )})` : '' ) ); failed ++; continue;

		}

		const diffs = Object.keys( e ).filter( ( k ) => JSON.stringify( e[ k ] ) !== JSON.stringify( a[ k ] ) );
		if ( diffs.length === 0 ) {

			console.log( `ok       ${name}` ); passed ++;

		} else {

			failed ++;
			console.log( `MISMATCH ${name}` );
			for ( const k of diffs ) {

				const sa = JSON.stringify( e[ k ] ), sb = JSON.stringify( a[ k ] );
				let i = 0;
				while ( i < sa.length && sa[ i ] === sb[ i ] ) i ++;
				const from = show ? 0 : Math.max( 0, i - 200 );
				const to = show ? undefined : i + 300;
				console.log( `  ${k} (first difference at ${i})\n    up: ${sa.slice( from, to )}\n    mb: ${sb.slice( from, to )}` );

			}

		}

	}

	for ( const name of Object.keys( moon ) ) if ( ! ( name in up ) ) console.log( `EXTRA    ${name} (no upstream scenario)` );

}

console.log( `\n${passed} identical, ${failed} different or missing` );
process.exit( failed ? 1 : 0 );
