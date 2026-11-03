// node run.mjs [name ...]: both sides of each a6 mock-GPU scenario in fresh processes,
// logs compared entry by entry (first mismatch printed).
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import url from 'node:url';
const here = path.dirname( url.fileURLToPath( import.meta.url ) );
const { scenarios } = await import( './scenarios.mjs' );
let names = process.argv.slice( 2 );
if ( names.length === 0 ) names = Object.keys( scenarios );
const runOne = ( args, env ) => {
	try {
		const out = execFileSync( 'node', args, { cwd: here, encoding: 'utf8', maxBuffer: 1 << 30, env: { ...process.env, ...env }, stdio: [ 'ignore', 'pipe', 'pipe' ] } );
		const line = out.split( '\n' ).find( ( l ) => l.startsWith( '@@LOG ' ) );
		return line ? { log: JSON.parse( line.slice( 6 ) ) } : { error: out.slice( - 2000 ) };
	} catch ( e ) { return { error: ( e.stdout || '' ).slice( - 2000 ) + '\n' + ( e.stderr || '' ).slice( - 4000 ) }; }
};
let ok = 0, bad = 0;
for ( const name of names ) {
	const up = runOne( [ '--import', '../register.mjs', 'upstream_one.mjs', name ], {} );
	const mb = runOne( [ 'mbt_one.mjs', name ], {} );
	if ( up.error || mb.error ) { bad ++; console.log( `FAIL ${name}: ${up.error ? 'upstream\n' + up.error : ''}${mb.error ? 'mbt\n' + mb.error : ''}` ); continue; }
	const a = up.log, b = mb.log;
	let i = 0;
	while ( i < a.length && i < b.length && JSON.stringify( a[ i ] ) === JSON.stringify( b[ i ] ) ) i ++;
	if ( i === a.length && i === b.length ) { ok ++; console.log( `ok   ${name} (${a.length} calls)` ); continue; }
	bad ++;
	console.log( `DIFF ${name} at entry ${i} of ${a.length} / ${b.length}` );
	for ( let j = Math.max( 0, i - 1 ); j < i + 2; j ++ ) console.log( `  up[${j}]: ${JSON.stringify( a[ j ] ?? null ).slice( 0, 700 )}\n  mb[${j}]: ${JSON.stringify( b[ j ] ?? null ).slice( 0, 700 )}` );
}
console.log( `\n${ok} identical, ${bad} different` );
process.exit( bad ? 1 : 0 );
