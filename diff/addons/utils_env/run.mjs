// Compares the MoonBit utils/environments scenarios (@@A6U <name> <json>) with upstream.
//   node --import ./register.mjs run.mjs [name ...]
import { spawnSync } from 'node:child_process';
import { runUtils } from './upstream_utils.mjs';
import { runEnvironments } from './upstream_env.mjs';
import { REPO } from '../../lib/env.mjs';
const repo = REPO;
const only = process.argv.slice( 2 );
const moon = {};
for ( const pkg of [ 'src/addons/utils/a6_utils_diff_test.mbt', 'src/addons/environments/a6_environments_diff_test.mbt' ] ) {
  const r = spawnSync( 'moon', [ 'test', '--target', 'js', pkg ], { cwd: repo, env: { ...process.env, A6_DIFF: '1' }, encoding: 'utf8', maxBuffer: 1 << 28 } );
  const out = ( r.stdout || '' ) + ( r.stderr || '' );
  for ( const line of out.split( '\n' ) ) { const m = /^@@A6U (\S+) (.*)$/.exec( line.trim() ); if ( m ) moon[ m[ 1 ] ] = m[ 2 ]; }
  if ( r.status !== 0 ) console.log( `moon test ${pkg} exited ${r.status}:\n` + out.split( '\n' ).filter( ( l ) => ! l.startsWith( '@@' ) ).slice( - 30 ).join( '\n' ) );
}
const up = { ...( await runUtils() ), ...( await runEnvironments() ) };
let failed = 0, passed = 0;
for ( const name of Object.keys( up ) ) {
  if ( only.length && ! only.includes( name ) ) continue;
  const a = moon[ name ], e = up[ name ];
  if ( a === undefined ) { console.log( `MISSING  ${name}` ); failed ++; continue; }
  if ( a === e ) { console.log( `ok       ${name} (${e.length} chars)` ); passed ++; continue; }
  failed ++;
  let i = 0; while ( i < a.length && a[ i ] === e[ i ] ) i ++;
  console.log( `MISMATCH ${name} at char ${i}\n  up: ${e.slice( Math.max( 0, i - 150 ), i + 150 )}\n  mb: ${a.slice( Math.max( 0, i - 150 ), i + 150 )}` );
}
for ( const name of Object.keys( moon ) ) if ( ! ( name in up ) ) console.log( `EXTRA    ${name}` );
console.log( `\n${passed} identical, ${failed} different or missing` );
process.exit( failed ? 1 : 0 );
