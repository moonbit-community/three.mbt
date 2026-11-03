// Upstream side of the utils scenarios (MoonBit side: src/addons/utils/a6_utils_diff_test.mbt).
import fs from 'node:fs';
const C = eval( fs.readFileSync( new URL( './common.js', import.meta.url ), 'utf8' ) );
export async function runUtils() {
  const T = await import( 'three' );
  const { radixSort } = await import( 'three/addons/utils/SortUtils.js' );
  const { setKelvin } = await import( 'three/addons/utils/ColorUtils.js' );
  const G = await import( 'three/addons/utils/GeometryUtils.js' );
  const S = await import( 'three/addons/utils/SceneUtils.js' );
  const out = {};
  const emit = ( name, value ) => { out[ name ] = C.canon( value ); };
  const xyz = ( vs ) => vs.flatMap( ( v ) => [ v.x, v.y, v.z ] );

  // ColorUtils
  { const r = []; for ( let k = 0; k <= 45000; k += 250 ) { const c = setKelvin( new T.Color(), k ); r.push( [ c.r, c.g, c.b ] ); } emit( 'kelvin', r ); }
  // GeometryUtils
  emit( 'hilbert2d', [ xyz( G.hilbert2D() ), xyz( G.hilbert2D( new T.Vector3( 1, 2, 3 ), 7, 3 ) ), xyz( G.hilbert2D( new T.Vector3( 1, 2, 3 ), 5, 2, 1, 2, 3, 0 ) ), xyz( G.hilbert2D( undefined, 10, 0 ) ) ] );
  emit( 'hilbert3d', [ xyz( G.hilbert3D() ), xyz( G.hilbert3D( new T.Vector3( - 1, 0.5, 2 ), 3, 2 ) ), xyz( G.hilbert3D( new T.Vector3( 0, 0, 0 ), 4, 1, 7, 6, 5, 4, 3, 2, 1, 0 ) ), xyz( G.hilbert3D( undefined, 10, 3 ) ) ] );
  emit( 'gosper', [ G.gosper(), G.gosper( 2.5 ) ] );
  // SortUtils
  {
    const r = [];
    for ( const n of [ 0, 1, 2, 5, 32, 33, 64, 100, 257, 1000, 5000 ] ) for ( const reversed of [ false, true ] ) for ( const scale of [ 4294967296, 4, 70000 ] ) {
      const a = C.data( n + 7, n, scale, 0, false );
      radixSort( a, { reversed } );
      r.push( a );
    }
    emit( 'radix_numbers', r );
  }
  {
    const r = [];
    for ( const n of [ 3, 40, 600 ] ) for ( const reversed of [ false, true ] ) {
      const z = C.data( n, n, 2000, - 1000, true );
      const a = z.map( ( z, id ) => ( { id, z } ) );
      radixSort( a, { get: ( el ) => el.z, reversed } );
      r.push( a.map( ( e ) => e.id ) );
    }
    emit( 'radix_get', r );
  }
  {
    const r = [];
    for ( const n of [ 10, 50, 700 ] ) for ( const reversed of [ false, true ] ) {
      const u = new Uint32Array( C.data( n + 1, n, 4294967296, 0, false ) ); const ua = new Uint32Array( n );
      radixSort( u, { aux: ua, reversed } );
      const f = new Float32Array( C.data( n + 2, n, 1e6, 0, true ) );
      radixSort( f, { reversed } );
      const b = new Uint8Array( C.data( n + 3, n, 256, 0, false ) ); const ba = new Uint8Array( n );
      radixSort( b, { aux: ba, reversed, get: ( v ) => v * 16777216 } );
      const p = C.data( n + 4, n, 1e9, - 5e8, false ); const pa = new Array( n ).fill( 0 );
      radixSort( p, { aux: pa, reversed } );
      r.push( [ Array.from( u ), Array.from( ua ), Array.from( f ), Array.from( b ), Array.from( ba ), p, pa ] );
    }
    emit( 'radix_typed', r );
  }
  // SceneUtils
  const seeded = ( seed ) => { const r = C.rng( seed ); return () => r(); };
  const instanced = ( count, seed ) => {
    const r = seeded( seed );
    const im = new T.InstancedMesh( new T.BoxGeometry( 1, 2, 3 ), new T.MeshBasicMaterial(), count );
    const m = new T.Matrix4(); const p = new T.Vector3(); const q = new T.Quaternion(); const s = new T.Vector3(); const e = new T.Euler();
    for ( let i = 0; i < count; i ++ ) {
      p.set( r() * 10 - 5, r() * 10 - 5, r() * 10 - 5 );
      q.setFromEuler( e.set( r() * 3, r() * 3, r() * 3 ) );
      s.set( r() + 0.5, r() + 0.5, r() + 0.5 );
      im.setMatrixAt( i, m.compose( p, q, s ) );
    }
    return im;
  };
  {
    const im = instanced( 4, 11 );
    im.name = 'inst'; im.position.set( 1, 2, 3 ); im.rotation.set( 0.1, 0.2, 0.3 ); im.updateMatrix();
    const child = new T.Object3D(); child.name = 'child'; im.add( child );
    const group = S.createMeshesFromInstancedMesh( im );
    emit( 'scene_instanced', [ group.toJSON(), group.children.map( ( c ) => [ c.type, c.name, c.matrixWorld.elements, xyz( [ c.position, c.scale ] ), c.quaternion.toArray(), c.geometry === im.geometry, c.material === im.material ] ) ] );
  }
  {
    const g = new T.PlaneGeometry( 1, 1 );
    const group = S.createMultiMaterialObject( g, [ new T.MeshBasicMaterial( { color: 0xff0000 } ), new T.MeshNormalMaterial() ] );
    emit( 'scene_multi_object', [ group.toJSON(), group.children.map( ( c ) => c.geometry === g ) ] );
  }
  {
    const g = new T.BoxGeometry( 1, 1, 1, 2, 1, 1 );
    g.groups.forEach( ( group, i ) => { group.materialIndex = ( i * 5 ) % 3; } );
    const materials = [ new T.MeshBasicMaterial(), new T.MeshLambertMaterial(), new T.MeshPhongMaterial() ];
    const mesh = new T.Mesh( g, materials ); mesh.name = 'multi'; mesh.position.set( 0.5, 0, 0 );
    const object = S.createMeshesFromMultiMaterialMesh( mesh );
    const single = new T.Mesh( new T.BoxGeometry(), new T.MeshBasicMaterial() );
    emit( 'scene_multi_mesh', [ object.type, object.name, object.position.toArray(), g.groups.map( ( x ) => [ x.start, x.count, x.materialIndex ] ), Array.from( g.index.array ),
      object.children.map( ( c ) => [ materials.indexOf( c.material ), Object.keys( c.geometry.attributes ), Object.values( c.geometry.attributes ).map( ( a ) => [ a.array.constructor.name, a.itemSize, a.normalized, Array.from( a.array ) ] ) ] ),
      S.createMeshesFromMultiMaterialMesh( single ) === single ] );
  }
  {
    const scene = new T.Scene();
    const box = new T.Mesh( new T.BoxGeometry( 1, 2, 3 ), new T.MeshBasicMaterial() ); box.position.set( 1, 2, 3 ); box.rotation.set( 0.3, 0.2, 0.1 ); scene.add( box );
    const morph = new T.Mesh( new T.PlaneGeometry( 2, 2 ), new T.MeshBasicMaterial() );
    morph.geometry.morphAttributes.position = [ new T.Float32BufferAttribute( C.data( 5, 12, 1, 0, true ), 3 ) ];
    morph.updateMorphTargets(); morph.morphTargetInfluences[ 0 ] = 0.5; morph.scale.set( 2, 1, 1 ); box.add( morph );
    const line = new T.Line( new T.BufferGeometry().setFromPoints( [ new T.Vector3( 0, 0, 0 ), new T.Vector3( 5, - 6, 7 ) ] ) ); line.position.x = - 4; scene.add( line );
    const points = new T.Points( new T.BufferGeometry().setFromPoints( [ new T.Vector3( 9, 9, 9 ) ] ) ); scene.add( points );
    const hidden = new T.Mesh( new T.BoxGeometry( 100, 100, 100 ) ); hidden.visible = false; scene.add( hidden );
    const sprite = new T.Sprite(); sprite.position.set( 0, - 10, 0 ); scene.add( sprite );
    const value = S.reduceVertices( scene, ( acc, v ) => [ acc[ 0 ] + v.x, acc[ 1 ] + v.y, acc[ 2 ] + v.z, acc[ 3 ] + 1, Math.max( acc[ 4 ], v.x ) ], [ 0, 0, 0, 0, - Infinity ] );
    const bbox = S.reduceVertices( box, ( b, v ) => b.expandByPoint( v ), new T.Box3() );
    emit( 'scene_reduce', [ value, bbox.min.toArray(), bbox.max.toArray() ] );
  }
  {
    const im = instanced( 7, 12 );
    const r = seeded( 13 );
    for ( let i = 0; i < 7; i ++ ) im.setColorAt( i, new T.Color( r(), r(), r() ) );
    im.geometry.setAttribute( 'offset', new T.InstancedBufferAttribute( new Float32Array( C.data( 14, 21, 1, 0, true ) ), 3 ) );
    im.geometry.setAttribute( 'weight', new T.InstancedBufferAttribute( new Float32Array( C.data( 15, 7, 1, 0, true ) ), 1 ) );
    const shared = new T.InstancedBufferAttribute( new Uint16Array( C.data( 16, 28, 1000, 0, false ) ), 4 );
    im.geometry.setAttribute( 'id4', shared ); im.geometry.setAttribute( 'id4b', shared );
    const keys = C.data( 17, 7, 100, 0, false );
    S.sortInstancedMesh( im, ( a, b ) => keys[ a ] - keys[ b ] );
    const attrs = im.geometry.attributes;
    emit( 'scene_sort_instanced', [ Array.from( im.instanceMatrix.array ), Array.from( im.instanceColor.array ), Array.from( attrs.offset.array ), Array.from( attrs.weight.array ), Array.from( attrs.id4.array ), Array.from( attrs.position.array ).slice( 0, 6 ) ] );
  }
  {
    const make = ( name, parent ) => { const o = new T.Object3D(); o.name = name; if ( parent ) parent.add( o ); return o; };
    const root = make( 'root' ); const a = make( 'a', root ); const a1 = make( 'a1', a ); make( 'a2', a ); const b = make( 'b', root ); b.visible = false; make( 'b1', b ); const c = make( 'c', root ); const c1 = make( 'c1', c ); make( 'c1x', c1 );
    const names = ( it ) => { const r = []; for ( const o of it ) r.push( o.name ); return r; };
    const all = names( S.traverseGenerator( root ) );
    const visible = names( S.traverseVisibleGenerator( root ) );
    const ancestors = names( S.traverseAncestorsGenerator( c1.children[ 0 ] ) );
    const lazy = [];
    for ( const o of S.traverseGenerator( root ) ) { lazy.push( o.name ); if ( o.name === 'a' ) { make( 'a3', a ); make( 'd', root ); } if ( o.name === 'a1' ) make( 'a1x', a1 ); }
    const early = []; for ( const o of S.traverseVisibleGenerator( root ) ) { early.push( o.name ); if ( early.length === 3 ) break; }
    const invisibleRoot = names( S.traverseVisibleGenerator( b ) );
    emit( 'scene_traverse', [ all, visible, ancestors, lazy, early, invisibleRoot, names( S.traverseAncestorsGenerator( root ) ) ] );
  }
  return out;
}
