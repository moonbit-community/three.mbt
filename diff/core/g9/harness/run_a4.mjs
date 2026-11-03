// node run_a4.mjs [--quiet] [--show] [name ...]: the A4 mock-GPU scenarios (a4_scenarios.mjs
// against ../mbt/a4), each side in a fresh process, logs compared entry by entry. Build the
// MoonBit side first: `cd ../mbt && moon build --target js`.
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import url from 'node:url';
const here = path.dirname( url.fileURLToPath( import.meta.url ) );
// the `three/*` resolve hooks of the shader harness (diff/core/webgpu/shader_diff/a4)
const HOOKS = url.pathToFileURL( path.join( here, '../../webgpu/shader_diff/a4/register_three.mjs' ) ).href;
const args = process.argv.slice( 2 );
const quiet = args.includes( '--quiet' );
const show = args.includes( '--show' );
const { scenarios } = await import( './a4_scenarios.mjs' );
let names = args.filter( ( a ) => ! a.startsWith( '--' ) );
if ( names.length === 0 ) names = Object.keys( scenarios );
function runOne( side, name ) {
	let out;
	try {
		out = execFileSync( 'node', [ '--import', HOOKS, path.join( here, 'a4_one.mjs' ), side, name ], { encoding: 'utf8', maxBuffer: 1 << 30, stdio: [ 'ignore', 'pipe', 'pipe' ] } );
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
	const up = runOne( 'up', name );
	const mb = runOne( 'mbt', name );
	if ( up.error || mb.error ) {
		failed.push( name );
		console.log( `FAIL ${name}: ${up.error ? 'upstream error\n' + up.error : ''}${mb.error ? 'mbt error\n' + mb.error : ''}` );
		continue;
	}
	const a = up.log, b = mb.log;
	let i = 0;
	while ( i < a.length && i < b.length && JSON.stringify( a[ i ] ) === JSON.stringify( b[ i ] ) ) i ++;
	if ( i === a.length && i === b.length ) {
		identical ++;
		const modules = a.filter( ( e ) => e[ 1 ] === 'createShaderModule' ).length;
		if ( ! quiet ) console.log( `ok   ${name} (${a.length} calls, ${modules} shader modules)` );
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
console.log( `${identical}/${names.length} identical${failed.length ? '; failed: ' + failed.join( ' ' ) : ''}` );
process.exit( failed.length ? 1 : 0 );
