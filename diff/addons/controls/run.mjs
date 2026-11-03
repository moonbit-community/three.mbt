// Runs every scenario on the MoonBit port and on upstream r187 with identical DOM stubs
// and event scripts, and compares the logs entry by entry.
// Usage: node run.mjs [--build] [--show N] [scenario ...]
import { execSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import path from 'node:path';
import { makeEnv, fmt } from './env.mjs';
import { makeUpstream } from './adapter_up.mjs';
import { scenarios, FIELDS } from './scenarios.mjs';

const here = path.dirname( new URL( import.meta.url ).pathname );
const args = process.argv.slice( 2 );
if ( args.includes( '--build' ) ) execSync( 'moon build --target js', { cwd: here, stdio: 'inherit' } );
const showIndex = args.indexOf( '--show' );
const show = showIndex >= 0 ? Number( args[ showIndex + 1 ] ) : 3;
const names = args.filter( ( a, i ) => ! a.startsWith( '--' ) && ( i === 0 || args[ i - 1 ] !== '--show' ) );

globalThis.__describe = ( v ) => {

	if ( v === undefined || v === null || typeof v !== 'object' ) return v;
	if ( v.isObject3D ) return 'obj:' + v.name;
	if ( 'uuid' in v && 'matrix_world' in v ) return 'obj:' + v.name;
	if ( typeof v.w === 'number' ) return [ v.x, v.y, v.z, v.w ];
	if ( typeof v.z === 'number' ) return [ v.x, v.y, v.z ];
	return '<object>';

};

const mbt = await import( pathToFileURL( path.join( here, '_build/js/debug/build/moonbit-community/three-controls-diff/main/main.js' ) ) );
const up = await makeUpstream();

function runSide( A, scenario ) {

	const log = [];
	const push = ( e ) => log.push( e.map( ( x ) => typeof x === 'string' ? x : fmt( x ) ) );
	const env = makeEnv( push );
	env.install();
	const S = {
		env,
		log: push,
		dump( label, ctrl, kind, objects = [] ) {

			for ( const o of objects ) {

				const st = A.obj_state( o );
				for ( const k of Object.keys( st ) ) push( [ label, A.obj_name( o ) + '.' + k, st[ k ] ] );

			}

			if ( ctrl !== undefined ) for ( const f of FIELDS[ kind ] ) push( [ label, f, A.get( ctrl, kind, f ) ] );
			push( [ label, 'listeners', env.listenerSummary() ] );

		},
		listen( ctrl, kind, types ) {

			for ( const t of types ) A.listen( ctrl, kind, t, ( type, value ) => push( [ 'event', type, value ] ) );

		},
	};
	const saved = [ console.log, console.warn, console.error ];
	console.log = console.warn = console.error = ( ...a ) => push( [ 'console', a.map( String ).join( ' ' ).trim() ] );
	try {

		scenario( A, S, env );

	} catch ( e ) {

		// MoonBit's abort prints its message first; upstream throws a TypeError
		while ( log.length && log[ log.length - 1 ][ 0 ] === 'console' && log[ log.length - 1 ][ 1 ].includes( 'not a camera' ) ) log.pop();
		push( [ 'exception' ] );
		if ( process.env.SHOW_EXC ) saved[ 0 ]( '    exception:', e && e.stack ? e.stack.split( '\n' ).slice( 0, 4 ).join( ' / ' ) : e );

	}

	[ console.log, console.warn, console.error ] = saved;
	return log;

}

let total = 0, failed = 0, entries = 0;
for ( const [ name, scenario ] of Object.entries( scenarios ) ) {

	if ( names.length && ! names.some( ( n ) => name.startsWith( n ) ) ) continue;
	total ++;
	const mine = runSide( mbt, scenario );
	const theirs = runSide( up, scenario );
	entries += theirs.length;
	let mismatches = 0;
	const n = Math.max( mine.length, theirs.length );
	for ( let i = 0; i < n; i ++ ) {

		const a = mine[ i ], b = theirs[ i ];
		const sa = a ? a.join( ' | ' ) : '<missing>', sb = b ? b.join( ' | ' ) : '<missing>';
		if ( sa !== sb ) {

			if ( mismatches < show ) console.log( `  ${name} #${i}\n    mbt:      ${sa.slice( 0, 300 )}\n    upstream: ${sb.slice( 0, 300 )}` );
			mismatches ++;

		}

	}

	if ( mismatches ) failed ++;
	console.log( `${mismatches ? 'DIFF ' : 'MATCH'} ${name}: ${theirs.length} entries${mismatches ? ', ' + mismatches + ' mismatches' : ''}` );

}

console.log( `${total - failed}/${total} scenarios identical, ${entries} entries` );
process.exit( failed ? 1 : 0 );
