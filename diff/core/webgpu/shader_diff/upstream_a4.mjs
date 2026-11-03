// Upstream side of the A4 shader scenarios (TSL agent A4's display add-ons). The MoonBit
// side is src/addons/tsl/a4_shader_diff_test.mbt (group `basic`) and
// src/addons/tsl/a4_<group>_shader_diff_test.mbt; scenario names start with `a4_`.
// Each group (a4/<group>.mjs) runs in a fresh child process (a4/child.mjs, with the
// `three/*` resolve hooks of a4/three_hooks.mjs), so its node / fn<id> counters start where
// the MoonBit file's `moon test` starts them.
//
//   node upstream_a4.mjs [group ...]   prints each group's records (debugging)
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.join( path.dirname( fileURLToPath( import.meta.url ) ), 'a4' );

// groups whose a4/<group>.mjs exists run (each owned by one A4 worker)
export const A4_GROUPS = [ 'basic', 'blur', 'ao', 'ssr', 'pass' ].filter( ( g ) => fs.existsSync( path.join( here, g + '.mjs' ) ) );

export function runGroup( group ) {

	let out;
	try {

		out = execFileSync( 'node', [ '--import', path.join( here, 'register_three.mjs' ), path.join( here, 'child.mjs' ), group ], { encoding: 'utf8', maxBuffer: 1 << 30, stdio: [ 'ignore', 'pipe', 'pipe' ] } );

	} catch ( e ) {

		return { [ 'a4_group_' + group ]: { error: ( e.stdout || '' ).slice( - 2000 ) + ( e.stderr || '' ).slice( - 4000 ) } };

	}

	const line = out.split( '\n' ).find( ( l ) => l.startsWith( '@@A4 ' ) );
	return line ? JSON.parse( line.slice( 5 ) ) : { [ 'a4_group_' + group ]: { error: 'no @@A4 line' } };

}

export async function runUpstream() {

	const records = {};
	for ( const g of A4_GROUPS ) Object.assign( records, runGroup( g ) );
	return records;

}

if ( process.argv[ 1 ] === fileURLToPath( import.meta.url ) ) {

	const groups = process.argv.length > 2 ? process.argv.slice( 2 ) : A4_GROUPS;
	for ( const g of groups ) fs.writeSync( 1, JSON.stringify( runGroup( g ), null, 1 ) + '\n' );

}
