// Upstream SimplexNoise with a seeded mulberry32 over fixed point sets; prints one line
// per value: `<kind> <index> <hex bits>`. The MoonBit side
// (src/addons/math/simplex_noise_test.mbt, SIMPLEX_DIFF=1) prints the same.
import { upstreamURL } from '../../../../lib/env.mjs';
const { SimplexNoise } = await import( upstreamURL( 'examples/jsm/math/SimplexNoise.js' ) );
const mulberry32 = ( a ) => () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul( a ^ a >>> 15, 1 | a ); t = t + Math.imul( t ^ t >>> 7, 61 | t ) ^ t; return ( ( t ^ t >>> 14 ) >>> 0 ) / 4294967296; };
const bits = ( x ) => { const f = new Float64Array( [ x ] ); return new BigUint64Array( f.buffer )[ 0 ].toString( 16 ); };
const coord = ( g, i ) => { const r = g(); const k = i % 5; return k === 0 ? ( r - 0.5 ) * 100 : k === 1 ? Math.floor( ( r - 0.5 ) * 40 ) : k === 2 ? ( r - 0.5 ) * 4e9 : k === 3 ? r * 3 : ( r - 0.5 ) * 1e-3; };
const out = [];
for ( const seed of [ 1, 12345 ] ) {
	const s = new SimplexNoise( { random: mulberry32( seed ) } );
	out.push( 'perm ' + seed + ' ' + s.perm.join( ',' ) );
	const g = mulberry32( seed * 7 + 3 );
	for ( let i = 0; i < 2000; i ++ ) out.push( `n2 ${seed} ${i} ${bits( s.noise( coord( g, i ), coord( g, i + 1 ) ) )}` );
	for ( let i = 0; i < 2000; i ++ ) out.push( `n3 ${seed} ${i} ${bits( s.noise3d( coord( g, i ), coord( g, i + 2 ), coord( g, i + 4 ) ) )}` );
	for ( let i = 0; i < 2000; i ++ ) out.push( `n4 ${seed} ${i} ${bits( s.noise4d( coord( g, i ), coord( g, i + 1 ), coord( g, i + 3 ), coord( g, i + 2 ) ) )}` );
	// specials
	const sp = [ 0, - 0, 1, - 1, 0.5, 255.5, 256, - 256.25, 2147483648.5, - 2147483649.5, 1e300, NaN, Infinity, - Infinity ];
	for ( const a of sp ) for ( const b of sp ) out.push( `s2 ${seed} ${bits( a )} ${bits( b )} ${bits( s.noise( a, b ) )} ${bits( s.noise3d( a, b, a ) )} ${bits( s.noise4d( a, b, b, a ) )}` );
}
console.log( out.join( '\n' ) );
