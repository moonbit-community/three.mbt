// Cameras, lights and scenes (src/core): the MoonBit scenarios (main/main.mbt) and the
// upstream ones (upstream.mjs) each print one JSON line per observation; the two outputs
// must be identical line for line.
//
//   node run.mjs [--build]      (run_all.mjs builds the module first)
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { outDir } from '../../lib/env.mjs';

const here = path.dirname( fileURLToPath( import.meta.url ) );
if ( process.argv.includes( '--build' ) ) execFileSync( 'moon', [ 'build', '--target', 'js' ], { cwd: here, stdio: 'inherit' } );
const js = path.join( here, '_build/js/debug/build/moonbit-community/three-diff-cameras-lights/main/main.js' );
if ( ! fs.existsSync( js ) ) {

	console.log( `missing ${path.relative( here, js )}; build first (moon build --target js)` );
	process.exit( 2 );

}

const run = ( file ) => {

	const r = spawnSync( 'node', [ file ], { cwd: here, encoding: 'utf8', maxBuffer: 1 << 30 } );
	if ( r.status !== 0 ) {

		console.log( `${path.basename( file )} exited ${r.status}\n${( r.stderr || '' ).slice( - 2000 )}` );
		process.exit( 1 );

	}

	return r.stdout;

};

const mbt = run( js );
const up = run( path.join( here, 'upstream.mjs' ) );
const out = outDir( 'classic_cameras_lights' );
fs.writeFileSync( path.join( out, 'moonbit.txt' ), mbt );
fs.writeFileSync( path.join( out, 'upstream.txt' ), up );
const a = up.split( '\n' ), b = mbt.split( '\n' );
let differ = 0;
for ( let i = 0; i < Math.max( a.length, b.length ); i ++ ) {

	if ( a[ i ] !== b[ i ] ) {

		if ( differ ++ === 0 ) console.log( `first difference at line ${i + 1}:\n  up: ${( a[ i ] ?? '<missing>' ).slice( 0, 300 )}\n  mb: ${( b[ i ] ?? '<missing>' ).slice( 0, 300 )}` );

	}

}

const lines = a.length - ( a[ a.length - 1 ] === '' ? 1 : 0 );
console.log( differ === 0 ? `${lines} lines, IDENTICAL` : `${lines} upstream lines, ${differ} differ (outputs in ${out})` );
process.exit( differ ? 1 : 0 );
