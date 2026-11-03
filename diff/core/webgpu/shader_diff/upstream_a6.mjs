// Upstream side of the a6 shader scenarios (the objects add-ons agent's WebGPU objects:
// SkyMesh, WaterMesh, Water2Mesh, LensflareMesh). The MoonBit side is
// src/addons/objects/a6_shader_diff_test.mbt (its own `moon test`, fresh counters);
// scenario names start with `a6_`. The scenarios run in a fresh child process
// (a6/child.mjs with the `three/*` resolve hooks of a6/three_hooks.mjs), so the node and
// fn<id> counters start where the MoonBit file's start.
//
//   node upstream_a6.mjs   prints the records (debugging)
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.join( path.dirname( fileURLToPath( import.meta.url ) ), 'a6' );

export function runA6() {

	let out;
	try {

		out = execFileSync( 'node', [ '--import', path.join( here, 'register_three.mjs' ), path.join( here, 'child.mjs' ) ], { encoding: 'utf8', maxBuffer: 1 << 30, stdio: [ 'ignore', 'pipe', 'pipe' ] } );

	} catch ( e ) {

		return { a6_child: { error: ( e.stdout || '' ).slice( - 2000 ) + ( e.stderr || '' ).slice( - 4000 ) } };

	}

	const line = out.split( '\n' ).find( ( l ) => l.startsWith( '@@A6 ' ) );
	return line ? JSON.parse( line.slice( 5 ) ) : { a6_child: { error: 'no @@A6 line' } };

}

export async function runUpstream() {

	return runA6();

}

if ( process.argv[ 1 ] === fileURLToPath( import.meta.url ) ) fs.writeSync( 1, JSON.stringify( runA6(), null, 1 ) + '\n' );
