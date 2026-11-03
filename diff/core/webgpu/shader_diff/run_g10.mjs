// Runs only the G10 (GLSLNodeBuilder) scenarios: src/renderers/webgl_fallback/g10_shader_diff_test.mbt against upstream_g10.mjs,
// byte for byte, as run.mjs does (which also runs the other groups' scenarios).
//
//   node run_g10.mjs [--repo <three.mbt checkout, default: this repository>] [--show] [name ...]
import { REPO, UPSTREAM } from '../../../lib/env.mjs';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { runUpstream } from './upstream_g10.mjs';

const args = process.argv.slice( 2 );
let repo = REPO;
let show = false;
const only = [];
for ( let i = 0; i < args.length; i ++ ) {

	if ( args[ i ] === '--repo' ) repo = args[ ++ i ];
	else if ( args[ i ] === '--show' ) show = true;
	else only.push( args[ i ] );

}

const r = spawnSync( 'moon', [ 'test', '--target', 'js', 'src/renderers/webgl_fallback/g10_shader_diff_test.mbt' ], { cwd: repo, env: { ...process.env, SHADER_DIFF: '1' }, encoding: 'utf8', maxBuffer: 1 << 28 } );
const out = ( r.stdout || '' ) + ( r.stderr || '' );
const moon = {};
for ( const line of out.split( '\n' ) ) {

	const m = /^@@SHADER (\S+) (.*)$/.exec( line.trim() );
	if ( m ) moon[ m[ 1 ] ] = JSON.parse( m[ 2 ] );

}

if ( r.status !== 0 ) console.log( `moon test exited ${r.status}:\n` + out.split( '\n' ).filter( ( l ) => ! l.startsWith( '@@' ) && ! /│|╭|╰|─╯|^Warning/.test( l ) ).slice( - 30 ).join( '\n' ) );
const up = await runUpstream( pathToFileURL( path.join( UPSTREAM, 'src' ) ).href );
let failed = 0, passed = 0;
for ( const name of Object.keys( up ) ) {

	if ( only.length && ! only.includes( name ) ) continue;
	const a = moon[ name ], e = up[ name ];
	if ( a === undefined ) {

		console.log( `MISSING  ${name}` ); failed ++; continue;

	}

	const diffs = Object.keys( e ).filter( ( k ) => JSON.stringify( e[ k ] ) !== JSON.stringify( a[ k ] ) );
	if ( diffs.length === 0 ) {

		console.log( `ok       ${name}` ); passed ++;
		if ( show ) console.log( JSON.stringify( e, null, 1 ) );

	} else {

		failed ++;
		console.log( `MISMATCH ${name}` );
		for ( const k of diffs ) console.log( `  ${k}\n    up: ${JSON.stringify( e[ k ] )}\n    mb: ${JSON.stringify( a[ k ] )}` );

	}

}

for ( const name of Object.keys( moon ) ) if ( ! ( name in up ) ) console.log( `EXTRA    ${name} (no upstream scenario)` );
console.log( `\n${passed} identical, ${failed} different or missing` );
process.exit( failed ? 1 : 0 );
