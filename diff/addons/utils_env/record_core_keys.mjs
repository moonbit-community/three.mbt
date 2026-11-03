// Records upstream r187 getKeys( material ) (RenderObject.js) for the core material
// classes, filtered as getMaterialCacheKey filters them: own keys, then prototype getters;
// prints the MoonBit table rows.   node record_core_keys.mjs
import { upstreamURL } from '../../lib/env.mjs';
const T = await import( upstreamURL( 'src/Three.Core.js' ) );
const skip = /^(is[A-Z]|_)|^(visible|version|uuid|name|opacity|userData|iridescenceThicknessRange)$/;
const names = [ 'LineBasicMaterial', 'LineDashedMaterial', 'MeshBasicMaterial', 'MeshDepthMaterial', 'MeshDistanceMaterial', 'MeshLambertMaterial', 'MeshMatcapMaterial', 'MeshNormalMaterial', 'MeshPhongMaterial', 'MeshPhysicalMaterial', 'MeshStandardMaterial', 'MeshToonMaterial', 'PointsMaterial', 'ShadowMaterial', 'SpriteMaterial' ];
for ( const n of names ) {
  const m = new T[ n ]();
  const own = Object.keys( m ).filter( ( k ) => ! skip.test( k ) );
  const getters = [];
  let proto = Object.getPrototypeOf( m );
  while ( proto ) {
    const d = Object.getOwnPropertyDescriptors( proto );
    for ( const k in d ) if ( d[ k ] && typeof d[ k ].get === 'function' && ! skip.test( k ) ) getters.push( k );
    proto = Object.getPrototypeOf( proto );
  }
  console.log( `  (\n    "${n}", "${own.join( ',' )}",\n    "${getters.join( ',' )}",\n  ),` );
}
