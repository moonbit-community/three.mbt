// Runs only the A4 scenarios: each src/addons/tsl/a4*_shader_diff_test.mbt in its own
// `moon test` against the matching upstream group (upstream_a4.mjs), byte for byte.
//
//   node run_a4.mjs [--repo <three.mbt checkout, default: this repository>] [--show] [--group g] [name ...]
import { REPO, UPSTREAM } from '../../../lib/env.mjs';
import { spawnSync } from 'node:child_process';
import { A4_GROUPS, runGroup } from './upstream_a4.mjs';

const args = process.argv.slice( 2 );
let repo = REPO;
let show = false;
const only = [];
let groups = A4_GROUPS;
for ( let i = 0; i < args.length; i ++ ) {

	if ( args[ i ] === '--repo' ) repo = args[ ++ i ];
	else if ( args[ i ] === '--show' ) show = true;
	else if ( args[ i ] === '--group' ) groups = args[ ++ i ].split( ',' );
	else only.push( args[ i ] );

}

export const a4FileOf = ( g ) => g === 'basic' ? 'src/addons/tsl/a4_shader_diff_test.mbt' : `src/addons/tsl/a4_${g}_shader_diff_test.mbt`;

let failed = 0, passed = 0;
for ( const g of groups ) {

	const r = spawnSync( 'moon', [ 'test', '--target', 'js', a4FileOf( g ) ], { cwd: repo, env: { ...process.env, SHADER_DIFF: '1' }, encoding: 'utf8', maxBuffer: 1 << 28 } );
	const out = ( r.stdout || '' ) + ( r.stderr || '' );
	const moon = {};
	for ( const line of out.split( '\n' ) ) {

		const m = /^@@SHADER (\S+) (.*)$/.exec( line.trim() );
		if ( m ) moon[ m[ 1 ] ] = JSON.parse( m[ 2 ] );

	}

	if ( r.status !== 0 ) console.log( `moon test ${g} exited ${r.status}:\n` + out.split( '\n' ).filter( ( l ) => ! l.startsWith( '@@' ) && ! /│|╭|╰|─╯|^Warning/.test( l ) ).slice( - 30 ).join( '\n' ) );
	const up = runGroup( g );
	for ( const name of Object.keys( up ) ) {

		if ( only.length && ! only.includes( name ) ) continue;
		const a = moon[ name ], e = up[ name ];
		if ( a === undefined ) {

			console.log( `MISSING  ${name}` + ( e.error ? ' (upstream error: ' + e.error.slice( 0, 600 ) + ')' : '' ) ); failed ++; continue;

		}

		const diffs = Object.keys( e ).filter( ( k ) => JSON.stringify( e[ k ] ) !== JSON.stringify( a[ k ] ) );
		if ( diffs.length === 0 && ! e.error ) {

			console.log( `ok       ${name}` ); passed ++;
			if ( show ) console.log( JSON.stringify( e, null, 1 ) );

		} else {

			failed ++;
			console.log( `MISMATCH ${name}` );
			for ( const k of ( diffs.length ? diffs : [ 'error' ] ) ) {

				const sa = JSON.stringify( e[ k ] ) || '', sb = JSON.stringify( a[ k ] ) || '';
				let i = 0;
				while ( i < sa.length && sa[ i ] === sb[ i ] ) i ++;
				const from = Math.max( 0, i - 200 );
				console.log( `  ${k} (first difference at ${i})\n    up: …${sa.slice( from, i + 400 )}\n    mb: …${sb.slice( from, i + 400 )}` );

			}

		}

	}

	for ( const name of Object.keys( moon ) ) if ( ! ( name in up ) ) console.log( `EXTRA    ${name} (no upstream scenario)` );

}

console.log( `\n${passed} identical, ${failed} different or missing` );
process.exit( failed ? 1 : 0 );
