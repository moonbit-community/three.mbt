// Upstream side of the A5 shader scenarios (TSL agent A5's add-ons: tsl/utils, math,
// lighting, shadows, half of display). The MoonBit side is
// src/addons/tsl/a5_<group>_shader_diff_test.mbt (runner: a5_harness_test.mbt); scenario
// names start with `a5_`. Each group (a5/<group>.mjs) runs in a fresh child process
// (a5/child.mjs, with the `three/*` resolve hooks of a4/three_hooks.mjs); both sides align
// their counters before loading the group's add-on modules.
//
//   node upstream_a5.mjs [group ...]   prints each group's records (debugging)
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.join( path.dirname( fileURLToPath( import.meta.url ) ), 'a5' );

export const A5_GROUPS = fs.readdirSync( here ).filter( ( f ) => f.endsWith( '.mjs' ) && f !== 'child.mjs' ).map( ( f ) => f.slice( 0, - 4 ) ).sort();

export function runGroup( group ) {

	const outFile = path.join( os.tmpdir(), `a5_${group}_${process.pid}.json` );
	try {

		execFileSync( 'node', [ '--import', path.join( here, '../a4/register_three.mjs' ), path.join( here, 'child.mjs' ), group ], { encoding: 'utf8', maxBuffer: 1 << 30, stdio: [ 'ignore', 'pipe', 'pipe' ], env: { ...process.env, A5_OUT: outFile } } );

	} catch ( e ) {

		return { [ 'a5_group_' + group ]: { error: ( e.stdout || '' ).slice( - 2000 ) + ( e.stderr || '' ).slice( - 4000 ) } };

	}

	const records = JSON.parse( fs.readFileSync( outFile, 'utf8' ) );
	fs.unlinkSync( outFile );
	return records;

}

export async function runUpstream() {

	const records = {};
	for ( const g of A5_GROUPS ) Object.assign( records, runGroup( g ) );
	return records;

}

if ( process.argv[ 1 ] === fileURLToPath( import.meta.url ) ) {

	const groups = process.argv.length > 2 ? process.argv.slice( 2 ) : A5_GROUPS;
	for ( const g of groups ) fs.writeSync( 1, JSON.stringify( runGroup( g ), null, 1 ) + '\n' );

}
