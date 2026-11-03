// Prints the first differing shaderSource of a scenario (debug aid).
import { spawnSync } from 'node:child_process';
const name = process.argv[ 2 ];
import { REPO as repo } from '../../../lib/env.mjs';
const up = JSON.parse( spawnSync( process.execPath, [ new URL( 'upstream_one.mjs', import.meta.url ).pathname, name ], { encoding: 'utf8', maxBuffer: 1 << 28 } ).stdout.trim().split( '\n' ).pop() );
const r = spawnSync( 'moon', [ 'test', '--target', 'js', 'src/renderers/webgl_fallback/g10_diff_test.mbt', '-f', `g10diff ${name}` ], { cwd: repo, env: { ...process.env, G10_DIFF: '1' }, encoding: 'utf8', maxBuffer: 1 << 28 } );
const line = ( r.stdout + r.stderr ).split( '\n' ).find( ( l ) => l.startsWith( '@@G10_LOG ' + name + ' ' ) );
const mb = JSON.parse( line.slice( ( '@@G10_LOG ' + name + ' ' ).length ) );
const su = up.filter( ( x ) => x.startsWith( 'shaderSource' ) ), sm = mb.filter( ( x ) => x.startsWith( 'shaderSource' ) );
for ( let i = 0; i < Math.max( su.length, sm.length ); i ++ ) {
	if ( su[ i ] !== sm[ i ] ) {
		const a = JSON.parse( '[' + su[ i ].slice( 'shaderSource('.length, -1 ) + ']' )[ 1 ].split( '\n' );
		const b = JSON.parse( '[' + sm[ i ].slice( 'shaderSource('.length, -1 ) + ']' )[ 1 ].split( '\n' );
		console.log( 'shader', i );
		for ( let j = 0; j < Math.max( a.length, b.length ); j ++ ) if ( a[ j ] !== b[ j ] ) console.log( j, '\n up:', a[ j ], '\n mb:', b[ j ] );
		break;
	}
}
console.log( su.length, sm.length );
