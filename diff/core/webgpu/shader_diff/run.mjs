// Shader differential test: runs the MoonBit scenarios (src/nodes/shader_diff_test.mbt,
// which print `@@SHADER <name> <json>` with SHADER_DIFF=1) and the upstream ones
// (upstream.mjs), and compares each record byte for byte.
//
//   node run.mjs [--repo <three.mbt checkout, default: this repository>] [name ...]
import { REPO, UPSTREAM } from '../../../lib/env.mjs';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { runUpstream } from './upstream.mjs';

const here = path.dirname( fileURLToPath( import.meta.url ) );
const args = process.argv.slice( 2 );
let repo = REPO;
const only = [];
for ( let i = 0; i < args.length; i ++ ) {

	if ( args[ i ] === '--repo' ) repo = args[ ++ i ];
	else only.push( args[ i ] );

}

// Additive: every `src/nodes/*_shader_diff_test.mbt` also runs, and every `upstream_*.mjs`
// next to this file adds its scenarios (each exports `runUpstream( src )`).
const extraTests = fs.readdirSync( path.join( repo, 'src/nodes' ) ).filter( ( f ) => /_shader_diff_test\.mbt$/.test( f ) ).map( ( f ) => 'src/nodes/' + f );
const r = spawnSync( 'moon', [ 'test', '--target', 'js', 'src/nodes/shader_diff_test.mbt', ...extraTests ], { cwd: repo, env: { ...process.env, SHADER_DIFF: '1' }, encoding: 'utf8', maxBuffer: 1 << 28 } );
const out = ( r.stdout || '' ) + ( r.stderr || '' );
const moon = {};
for ( const line of out.split( '\n' ) ) {

	const m = /^@@SHADER (\S+) (.*)$/.exec( line.trim() );
	if ( m ) moon[ m[ 1 ] ] = JSON.parse( m[ 2 ] );

}

if ( r.status !== 0 ) console.log( `moon test exited ${r.status}:\n` + out.split( '\n' ).filter( ( l ) => ! l.startsWith( '@@' ) ).slice( - 30 ).join( '\n' ) );

// Additive: the backend packages' `*_shader_diff_test.mbt` files (G8: src/renderers/webgpu)
// run in their own `moon test`, as a package's tests build separately.
for ( const dir of [ 'src/renderers/webgpu', 'src/loaders/nodes', 'src/renderers/webgl_fallback' ] ) {

	if ( ! fs.existsSync( path.join( repo, dir ) ) ) continue;
	const files = fs.readdirSync( path.join( repo, dir ) ).filter( ( f ) => /_shader_diff_test\.mbt$/.test( f ) ).map( ( f ) => dir + '/' + f );
	if ( files.length === 0 ) continue;
	const rb = spawnSync( 'moon', [ 'test', '--target', 'js', ...files ], { cwd: repo, env: { ...process.env, SHADER_DIFF: '1' }, encoding: 'utf8', maxBuffer: 1 << 28 } );
	const outb = ( rb.stdout || '' ) + ( rb.stderr || '' );
	for ( const line of outb.split( '\n' ) ) {

		const m = /^@@SHADER (\S+) (.*)$/.exec( line.trim() );
		if ( m ) moon[ m[ 1 ] ] = JSON.parse( m[ 2 ] );

	}

	if ( rb.status !== 0 ) console.log( `moon test ${dir} exited ${rb.status}:\n` + outb.split( '\n' ).filter( ( l ) => ! l.startsWith( '@@' ) ).slice( - 30 ).join( '\n' ) );

}

// Additive (TSL add-ons, agents A4/A5): every src/addons/tsl `*_shader_diff_test.mbt` runs in
// its own `moon test`, so each group's lazily loaded add-on modules start from fresh
// counters, as its upstream child process does (upstream_a4.mjs, upstream_a5.mjs).
for ( const dir of [ 'src/addons/tsl', 'src/addons/objects' ] ) { // + objects add-ons (a6)

	if ( ! fs.existsSync( path.join( repo, dir ) ) ) continue;
	for ( const f of fs.readdirSync( path.join( repo, dir ) ).filter( ( f ) => /_shader_diff_test\.mbt$/.test( f ) ).sort() ) {

		const rb = spawnSync( 'moon', [ 'test', '--target', 'js', dir + '/' + f ], { cwd: repo, env: { ...process.env, SHADER_DIFF: '1' }, encoding: 'utf8', maxBuffer: 1 << 28 } );
		const outb = ( rb.stdout || '' ) + ( rb.stderr || '' );
		for ( const line of outb.split( '\n' ) ) {

			const m = /^@@SHADER (\S+) (.*)$/.exec( line.trim() );
			if ( m ) moon[ m[ 1 ] ] = JSON.parse( m[ 2 ] );

		}

		if ( rb.status !== 0 ) console.log( `moon test ${dir}/${f} exited ${rb.status}:\n` + outb.split( '\n' ).filter( ( l ) => ! l.startsWith( '@@' ) ).slice( - 30 ).join( '\n' ) );

	}

}

const srcURL = pathToFileURL( path.join( UPSTREAM, 'src' ) ).href;
const up = await runUpstream( srcURL );
for ( const f of fs.readdirSync( here ).filter( ( f ) => /^upstream_.*\.mjs$/.test( f ) ).sort() ) {

	const mod = await import( pathToFileURL( path.join( here, f ) ).href );
	Object.assign( up, await mod.runUpstream( srcURL ) );

}
let failed = 0, passed = 0;
for ( const name of Object.keys( up ) ) {

	if ( only.length && ! only.includes( name ) ) continue;
	const a = moon[ name ];
	const e = up[ name ];
	if ( a === undefined ) {

		console.log( `MISSING  ${name}` ); failed ++; continue;

	}

	const diffs = Object.keys( e ).filter( ( k ) => JSON.stringify( e[ k ] ) !== JSON.stringify( a[ k ] ) );
	if ( diffs.length === 0 ) {

		console.log( `ok       ${name}` ); passed ++;

	} else {

		failed ++;
		console.log( `MISMATCH ${name}` );
		for ( const k of diffs ) console.log( `  ${k}\n    up: ${JSON.stringify( e[ k ] )}\n    mb: ${JSON.stringify( a[ k ] )}` );

	}

}

for ( const name of Object.keys( moon ) ) if ( ! ( name in up ) ) console.log( `EXTRA    ${name} (no upstream scenario)` );
console.log( `\n${passed} identical, ${failed} different or missing` );
process.exit( failed ? 1 : 0 );
