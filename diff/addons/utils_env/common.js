// Shared by both sides (embedded verbatim in the MoonBit tests as an extern).
(function () {
  function rng( seed ) {
    let a = seed >>> 0;
    return function () {
      a |= 0; a = a + 0x6D2B79F5 | 0;
      let t = Math.imul( a ^ a >>> 15, 1 | a );
      t = t + Math.imul( t ^ t >>> 7, 61 | t ) ^ t;
      return ( ( t ^ t >>> 14 ) >>> 0 ) / 4294967296;
    };
  }
  // n values: floor( r * scale ) + offset, or r * scale + offset when float
  function data( seed, n, scale, offset, float ) {
    const r = rng( seed ); const out = [];
    for ( let i = 0; i < n; i ++ ) out.push( float ? r() * scale + offset : Math.floor( r() * scale ) + offset );
    return out;
  }
  // canonical JSON: uuids replaced by their order of first appearance
  function canon( json ) {
    const ids = new Map();
    const s = JSON.stringify( json );
    return s.replace( /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi, ( u ) => { if ( ! ids.has( u ) ) ids.set( u, 'uuid' + ids.size ); return ids.get( u ); } );
  }
  return { rng, data, canon };
})()
