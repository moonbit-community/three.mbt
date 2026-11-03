// Runs every differential harness under diff/ and prints one summary line per check.
//
//   node diff/run_all.mjs [--only area|name,...] [--list] [--full] [--no-build] [--keep-going]
//
// Each harness directory has a `checks.mjs` exporting its checks (see diff/README.md).
// The MoonBit side of each check (the `build` directories, each a small module whose
// moon.work points at the repository root) is rebuilt first, then the command runs and
// its summary line is compared with the expected one. The full output of every check is
// kept in diff/.out/logs/<name>.log. Exits 1 on any mismatch, failure or timeout.
//
//   --only   comma-separated areas (core, classic, addons), check names or name prefixes
//   --full   also run the long checks (EXR corrupt inputs, hang probes, ...)
//   --list   list the checks and exit
//   --no-build   skip `moon build` of the MoonBit sides
import { spawn, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { DIFF, REPO, OUT, UPSTREAM, outDir } from './lib/env.mjs';

const argv = process.argv.slice( 2 );
const flag = ( f ) => argv.includes( f );
const opt = ( f ) => {

	const i = argv.indexOf( f );
	if ( i >= 0 ) return argv[ i + 1 ];
	const eq = argv.find( ( a ) => a.startsWith( f + '=' ) );
	return eq ? eq.slice( f.length + 1 ) : undefined;

};

const full = flag( '--full' );
const only = ( opt( '--only' ) ?? '' ).split( ',' ).map( ( s ) => s.trim() ).filter( Boolean );

function findChecks( dir, acc = [] ) {

	for ( const e of fs.readdirSync( dir, { withFileTypes: true } ) ) {

		if ( e.name.startsWith( '.' ) || e.name === '_build' || e.name === 'node_modules' ) continue;
		const p = path.join( dir, e.name );
		if ( e.isDirectory() ) findChecks( p, acc );
		else if ( e.name === 'checks.mjs' ) acc.push( p );

	}

	return acc;

}

const checks = [];
for ( const file of findChecks( DIFF ).sort() ) {

	const mod = await import( pathToFileURL( file ).href );
	for ( const c of mod.default ) {

		c.dir = path.dirname( file );
		c.cwd = c.cwd ? path.resolve( c.dir, c.cwd ) : c.dir;
		c.build = ( c.build ?? [] ).map( ( b ) => path.resolve( c.dir, b ) );
		checks.push( c );

	}

}

const areaOrder = [ 'core', 'classic', 'addons' ];
// Area, then each directory by its lowest `order`, then `order` within a directory.
const dirOrder = new Map();
for ( const c of checks ) dirOrder.set( c.dir, Math.min( dirOrder.get( c.dir ) ?? Infinity, c.order ?? 0 ) );
checks.sort( ( a, b ) => ( areaOrder.indexOf( a.area ) - areaOrder.indexOf( b.area ) ) || ( dirOrder.get( a.dir ) - dirOrder.get( b.dir ) ) || a.dir.localeCompare( b.dir ) || ( ( a.order ?? 0 ) - ( b.order ?? 0 ) ) );

const names = new Set();
for ( const c of checks ) {

	if ( names.has( c.name ) ) throw new Error( `duplicate check name ${c.name}` );
	names.add( c.name );

}

// An --only item selects an area, a check by its exact name, or, if no check has that
// name, every check whose name starts with it (`--only hdr` -> hdr_fflate, hdr_loaders, ...).
const matches = ( o, c ) => o === c.area || o === c.name || ( ! names.has( o ) && c.name.startsWith( o ) );
for ( const o of only ) if ( ! checks.some( ( c ) => matches( o, c ) ) ) {

	console.error( `--only ${o}: no such area or check (see --list)` );
	process.exit( 2 );

}

const selected = checks.filter( ( c ) => only.length ? only.some( ( o ) => matches( o, c ) ) : full || ! c.full );

if ( flag( '--list' ) ) {

	for ( const c of checks ) {

		const mark = selected.includes( c ) ? '*' : ' ';
		console.log( `${mark} ${c.area.padEnd( 8 )}${c.name.padEnd( 22 )}${c.full ? '[full] ' : ''}${c.title}` );
		console.log( `  ${''.padEnd( 30 )}${path.relative( REPO, c.cwd ) || '.'}: ${c.cmd.join( ' ' )}` );

	}

	console.log( `\n${selected.length} of ${checks.length} selected (* = would run${full ? ' with --full' : ''})` );
	process.exit( 0 );

}

if ( ! fs.existsSync( path.join( UPSTREAM, 'src/Three.js' ) ) ) {

	console.error( `upstream three.js not found at ${UPSTREAM}; run tools/fetch_upstream.sh or set THREE_UPSTREAM` );
	process.exit( 2 );

}

const logs = outDir( 'logs' );
const shown = ( p ) => p.startsWith( REPO + path.sep ) ? path.relative( REPO, p ) : p;
const t0 = Date.now();
const secs = ( t ) => ( ( Date.now() - t ) / 1000 ).toFixed( 0 ) + 's';
let failures = 0;

// 1. Rebuild the MoonBit sides (a stale bundle has misled once).
if ( ! flag( '--no-build' ) ) {

	const dirs = [ ...new Set( selected.flatMap( ( c ) => c.build ) ) ];
	for ( const d of dirs ) {

		const t = Date.now();
		const r = spawnSync( 'moon', [ 'build', '--target', 'js' ], { cwd: d, encoding: 'utf8', maxBuffer: 1 << 28 } );
		const rel = path.relative( REPO, d );
		if ( r.status !== 0 ) {

			failures ++;
			fs.writeFileSync( path.join( logs, 'build_' + rel.replace( /[/\\]/g, '_' ) + '.log' ), ( r.stdout ?? '' ) + ( r.stderr ?? '' ) );
			console.log( `build FAILED: ${rel} (log in ${shown( logs )})` );
			for ( const c of selected ) if ( c.build.includes( d ) ) c.buildFailed = rel;

		} else console.log( `built ${rel} (${secs( t )})` );

	}

}

function runCheck( c ) {

	return new Promise( ( resolve ) => {

		const t = Date.now();
		const env = { ...process.env, ...( c.env ?? {} ), THREE_UPSTREAM: UPSTREAM, THREE_DIFF_OUT: OUT };
		const child = spawn( c.cmd[ 0 ], c.cmd.slice( 1 ), { cwd: c.cwd, env, stdio: [ 'ignore', 'pipe', 'pipe' ], detached: true } );
		let out = '';
		child.stdout.on( 'data', ( d ) => out += d );
		child.stderr.on( 'data', ( d ) => out += d );
		let timedOut = false;
		const timer = setTimeout( () => {

			timedOut = true;
			try { process.kill( - child.pid, 'SIGKILL' ); } catch { child.kill( 'SIGKILL' ); }

		}, ( c.timeout ?? 3000 ) * 1000 );
		child.on( 'close', ( code ) => {

			clearTimeout( timer );
			resolve( { code, out, timedOut, time: secs( t ) } );

		} );

	} );

}

// 2. Run each check, one at a time (most share the repository's _build).
const results = [];
for ( const c of selected ) {

	if ( c.buildFailed ) {

		results.push( [ c, false, `build failed (${c.buildFailed})` ] );
		console.log( `FAIL ${c.title}: build failed (${c.buildFailed})` );
		failures ++;
		continue;

	}

	const r = await runCheck( c );
	fs.writeFileSync( path.join( logs, c.name + '.log' ), r.out );
	let line;
	if ( typeof c.summary === 'function' ) line = c.summary( r.out );
	else line = r.out.split( '\n' ).filter( ( l ) => c.summary.test( l ) ).pop()?.trim();
	line ??= '(no summary line)';
	const exitOk = c.exitCode === 'any' || r.code === ( c.exitCode ?? 0 );
	const ok = ! r.timedOut && exitOk && line === c.expect;
	if ( ! ok ) failures ++;
	const why = r.timedOut ? ` [timeout ${c.timeout ?? 3000}s]` : ! exitOk ? ` [exit ${r.code}]` : line !== c.expect ? ` [expected: ${c.expect}]` : '';
	console.log( `${ok ? 'ok  ' : 'FAIL'} ${c.title}: ${line}${why} (${r.time})` );
	results.push( [ c, ok, line ] );

}

console.log( `\n${results.filter( ( r ) => r[ 1 ] ).length}/${selected.length} checks match` + ( failures ? `, ${failures} failure(s)` : '' ) + ` (${secs( t0 )}; logs in ${shown( logs )})` );
process.exit( failures ? 1 : 0 );
