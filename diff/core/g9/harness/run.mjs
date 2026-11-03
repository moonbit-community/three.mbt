// node run.mjs [--quiet] [--show] [name ...]: runs each scenario on both sides (fresh
// processes) and compares the mock GPU logs entry by entry, printing the first mismatch.
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import url from 'node:url';
const here = path.dirname( url.fileURLToPath( import.meta.url ) );
const args = process.argv.slice( 2 );
const quiet = args.includes( '--quiet' );
const show = args.includes( '--show' );
const { scenarios } = await import( './scenarios.mjs' );
// differences outside G9, reported but not counted (see README)
export const KNOWN = {
};
let names = args.filter( ( a ) => ! a.startsWith( '--' ) );
const all = names.length === 0;
if ( all ) names = Object.keys( scenarios );
function runOne( script, name ) {
	let out;
	try {
		out = execFileSync( 'node', [ path.join( here, script ), name ], { encoding: 'utf8', maxBuffer: 1 << 30, stdio: [ 'ignore', 'pipe', 'pipe' ] } );
	} catch ( e ) {
		return { error: ( e.stdout || '' ).slice( - 2000 ) + '\n' + ( e.stderr || '' ).slice( - 4000 ) };
	}
	const line = out.split( '\n' ).find( ( l ) => l.startsWith( '@@LOG ' ) );
	if ( ! line ) return { error: 'no @@LOG line\n' + out.slice( - 2000 ) };
	return { log: JSON.parse( line.slice( 6 ) ) };
}
const clip = ( s, n = 600 ) => ( s.length > n ? s.slice( 0, n ) + '…' : s );
let identical = 0;
const failed = [];
for ( const name of names ) {
	const up = runOne( 'upstream_one.mjs', name );
	const mb = runOne( 'mbt_one.mjs', name );
	if ( up.error || mb.error ) {
		if ( all && KNOWN[ name ] ) {
			console.log( `known ${name}: ${up.error ? 'upstream' : 'MoonBit'} side errors (${KNOWN[ name ]})` );
			continue;
		}
		failed.push( name );
		console.log( `FAIL ${name}: ${up.error ? 'upstream error\n' + up.error : ''}${mb.error ? 'mbt error\n' + mb.error : ''}` );
		continue;
	}
	const a = up.log, b = mb.log;
	let i = 0;
	while ( i < a.length && i < b.length && JSON.stringify( a[ i ] ) === JSON.stringify( b[ i ] ) ) i ++;
	if ( i === a.length && i === b.length ) {
		identical ++;
		if ( ! quiet ) console.log( `ok   ${name} (${a.length} calls)` );
		continue;
	}
	if ( all && KNOWN[ name ] ) {
		console.log( `known ${name}: differs at entry ${i} (${KNOWN[ name ]})` );
		continue;
	}
	failed.push( name );
	console.log( `DIFF ${name} at entry ${i} of ${a.length} / ${b.length}` );
	if ( i > 0 ) console.log( '  prev    : ' + clip( JSON.stringify( a[ i - 1 ] ), 300 ) );
	const sa = JSON.stringify( a[ i ] ?? null ), sb = JSON.stringify( b[ i ] ?? null );
	let k = 0;
	while ( k < sa.length && k < sb.length && sa[ k ] === sb[ k ] ) k ++;
	const from = Math.max( 0, k - 300 );
	console.log( '  upstream: ' + ( show ? sa : ( from > 0 ? '…' : '' ) + clip( sa.slice( from ), 900 ) ) );
	console.log( '  moonbit : ' + ( show ? sb : ( from > 0 ? '…' : '' ) + clip( sb.slice( from ), 900 ) ) );
}
const known = all ? names.filter( ( n ) => KNOWN[ n ] ).length : 0;
console.log( `${identical}/${names.length - known} identical${known ? ` (+${known} known differences)` : ''}${failed.length ? '; failed: ' + failed.join( ' ' ) : ''}` );
process.exit( failed.length ? 1 : 0 );
