// Case descriptors shared by both sides. Geometry data comes from upstream's built-in
// geometries (converted to raw descriptors) and from a seeded PRNG.
import { THREE, buildBuiltin } from './upstream.mjs';

function mulberry32( seed ) {

	return function () {

		seed |= 0; seed = seed + 0x6D2B79F5 | 0;
		let t = Math.imul( seed ^ seed >>> 15, 1 | seed );
		t = t + Math.imul( t ^ t >>> 7, 61 | t ) ^ t;
		return ( ( t ^ t >>> 14 ) >>> 0 ) / 4294967296;

	};

}

const rand = mulberry32( 12345 );
const rr = ( a, b ) => a + ( b - a ) * rand();

const BUILTINS = [
	[ 'BoxGeometry', [ 1, 1, 1 ] ],
	[ 'BoxGeometry', [ 2, 1, 3, 2, 3, 1 ] ],
	[ 'SphereGeometry', [ 1, 8, 6 ] ],
	[ 'SphereGeometry', [ 0.7, 12, 9 ] ],
	[ 'TorusKnotGeometry', [ 1, 0.3, 32, 6 ] ],
	[ 'TorusKnotGeometry', [ 1, 0.4, 20, 5, 3, 4 ] ],
	[ 'PlaneGeometry', [ 2, 2, 3, 2 ] ],
	[ 'TorusGeometry', [ 1, 0.4, 6, 12 ] ],
	[ 'CylinderGeometry', [ 1, 0.5, 2, 8, 2 ] ],
	[ 'IcosahedronGeometry', [ 1, 1 ] ],
	[ 'CapsuleGeometry', [ 0.5, 1, 2, 6 ] ],
];

const builtin = ( i ) => ( { builtin: { type: BUILTINS[ i ][ 0 ], args: BUILTINS[ i ][ 1 ] } } );
const upstreamBuiltin = ( i ) => buildBuiltin( { type: BUILTINS[ i ][ 0 ], args: BUILTINS[ i ][ 1 ] } );

function attrDesc( a ) {

	const d = { array: a.array.slice(), itemSize: a.itemSize, normalized: a.normalized };
	if ( a.name ) d.name = a.name;
	return d;

}

// A raw descriptor of an upstream geometry (BufferAttributes only).
function rawDesc( g ) {

	const d = { attrs: Object.keys( g.attributes ).map( ( n ) => [ n, attrDesc( g.attributes[ n ] ) ] ) };
	if ( g.index ) d.index = attrDesc( g.index );
	const morph = Object.keys( g.morphAttributes );
	if ( morph.length ) d.morph = morph.map( ( n ) => [ n, g.morphAttributes[ n ].map( attrDesc ) ] );
	if ( g.groups.length ) d.groups = g.groups.map( ( gr ) => [ gr.start, gr.count, gr.materialIndex ] );
	return d;

}

const raw = ( i ) => rawDesc( upstreamBuiltin( i ) );
const rawNonIndexed = ( i ) => {

	const g = upstreamBuiltin( i );
	return rawDesc( g.index ? g.toNonIndexed() : g );

};

function perturbed( a, amount ) {

	const out = a.array.slice();
	for ( let i = 0; i < out.length; i ++ ) out[ i ] += rr( - amount, amount );
	return { array: out, itemSize: a.itemSize, normalized: false };

}

function withMorphs( d, count, relative, normals = true ) {

	const pos = d.attrs.find( ( p ) => p[ 0 ] === 'position' )[ 1 ];
	const nor = d.attrs.find( ( p ) => p[ 0 ] === 'normal' );
	d.morph = [ [ 'position', Array.from( { length: count }, () => perturbed( pos, 0.3 ) ) ] ];
	if ( normals && nor ) d.morph.push( [ 'normal', Array.from( { length: count }, () => perturbed( nor[ 1 ], 0.2 ) ) ] );
	d.morphRelative = relative;
	return d;

}

function quantize( arr, step ) {

	const out = arr.slice();
	for ( let i = 0; i < out.length; i ++ ) out[ i ] = Math.round( out[ i ] / step ) * step;
	return out;

}

function int16Normalized( a ) {

	const out = new Int16Array( a.array.length );
	for ( let i = 0; i < out.length; i ++ ) out[ i ] = Math.round( Math.max( - 1, Math.min( 1, a.array[ i ] ) ) * 32767 );
	return { array: out, itemSize: a.itemSize, normalized: true };

}

function int8Normalized( a ) {

	const out = new Int8Array( a.array.length );
	for ( let i = 0; i < out.length; i ++ ) out[ i ] = Math.round( Math.max( - 1, Math.min( 1, a.array[ i ] ) ) * 127 );
	return { array: out, itemSize: a.itemSize, normalized: true };

}

function f16( a ) {

	const out = new Uint16Array( a.array.length );
	for ( let i = 0; i < out.length; i ++ ) out[ i ] = THREE.DataUtils.toHalfFloat( a.array[ i ] );
	return { array: out, itemSize: a.itemSize, normalized: false, kind: 'f16' };

}

// Moves position/normal (and uv) of a raw descriptor into one interleaved buffer.
function interleave( d, c, withUv = true ) {

	const get = ( n ) => d.attrs.find( ( p ) => p[ 0 ] === n );
	const pos = get( 'position' )[ 1 ], nor = get( 'normal' )[ 1 ], uv = get( 'uv' );
	const count = pos.array.length / 3;
	const stride = withUv && uv ? 8 : 6;
	const array = new Float32Array( count * stride );
	for ( let i = 0; i < count; i ++ ) {

		for ( let k = 0; k < 3; k ++ ) array[ i * stride + k ] = pos.array[ i * 3 + k ];
		for ( let k = 0; k < 3; k ++ ) array[ i * stride + 3 + k ] = nor.array[ i * 3 + k ];
		if ( stride === 8 ) for ( let k = 0; k < 2; k ++ ) array[ i * stride + 6 + k ] = uv[ 1 ].array[ i * 2 + k ];

	}

	c.buffers = c.buffers || [];
	const id = c.buffers.length;
	c.buffers.push( { array, stride } );
	const attrs = [ [ 'position', { il: id, itemSize: 3, offset: 0 } ], [ 'normal', { il: id, itemSize: 3, offset: 3 } ] ];
	if ( stride === 8 ) attrs.push( [ 'uv', { il: id, itemSize: 2, offset: 6 } ] );
	for ( const p of d.attrs ) if ( ! [ 'position', 'normal', 'uv' ].includes( p[ 0 ] ) || ( p[ 0 ] === 'uv' && stride === 6 ) ) attrs.push( p );
	d.attrs = attrs;
	return d;

}

function setAttr( d, name, a ) {

	const i = d.attrs.findIndex( ( p ) => p[ 0 ] === name );
	if ( i >= 0 ) d.attrs[ i ] = [ name, a ]; else d.attrs.push( [ name, a ] );
	return d;

}

const getAttr = ( d, name ) => d.attrs.find( ( p ) => p[ 0 ] === name )[ 1 ];

function randomArray( Type, n, lo, hi, integer = false ) {

	const out = new Type( n );
	for ( let i = 0; i < n; i ++ ) out[ i ] = integer ? Math.floor( rr( lo, hi ) ) : rr( lo, hi );
	return out;

}

// ---------------------------------------------------------------- rigs

function chainRig( prefix, n, opts = {} ) {

	const bones = [];
	for ( let i = 0; i < n; i ++ ) {

		const name = i === 0 ? prefix + 'hip' : prefix + 'bone' + i;
		bones.push( {
			name, parent: i === 0 ? - 1 : ( opts.branch && i > 2 ? 1 : i - 1 ),
			p: i === 0 ? [ rr( - 0.2, 0.2 ), 1 + rr( 0, 0.2 ), rr( - 0.2, 0.2 ) ] : [ rr( - 0.1, 0.1 ), 0.5 + rr( 0, 0.2 ), rr( - 0.1, 0.1 ) ],
			q: new THREE.Quaternion().setFromEuler( new THREE.Euler( rr( - 0.3, 0.3 ), rr( - 0.3, 0.3 ), rr( - 0.3, 0.3 ) ) ).toArray(),
			s: opts.scaled ? [ 1 + rr( 0, 0.3 ), 1 + rr( 0, 0.3 ), 1 + rr( 0, 0.3 ) ] : [ 1, 1, 1 ]
		} );

	}

	const geom = raw( opts.geom === undefined ? 8 : opts.geom );
	const count = getAttr( geom, 'position' ).array.length / 3;
	const skinIndex = new Uint16Array( count * 4 ), skinWeight = new Float32Array( count * 4 );
	for ( let v = 0; v < count; v ++ ) {

		let total = 0;
		for ( let k = 0; k < 4; k ++ ) {

			skinIndex[ v * 4 + k ] = Math.floor( rand() * n );
			const w = k < ( opts.weights || 2 ) ? rand() : 0;
			skinWeight[ v * 4 + k ] = w;
			total += w;

		}

		for ( let k = 0; k < 4; k ++ ) skinWeight[ v * 4 + k ] /= total || 1;

	}

	geom.attrs.push( [ 'skinIndex', { array: skinIndex, itemSize: 4 } ], [ 'skinWeight', { array: skinWeight, itemSize: 4 } ] );
	if ( opts.morph ) withMorphs( geom, 2, opts.morphRelative );
	const mesh = { name: prefix + 'mesh', geom, bones: bones.map( ( _, i ) => i ), p: opts.meshP || [ 0, 0, 0 ] };
	if ( opts.influences ) mesh.influences = opts.influences;
	if ( opts.bindMode ) mesh.bindMode = opts.bindMode;
	const rig = {
		rootName: prefix + 'root',
		root: { p: opts.rootP || [ 0, 0, 0 ], q: opts.rootQ || [ 0, 0, 0, 1 ], s: opts.rootS || [ 1, 1, 1 ] },
		bones, meshes: [ mesh ]
	};
	if ( opts.second ) rig.meshes.push( { name: prefix + 'mesh2', geom: raw( 0 ), bones: [ 0, 1 ], parentBone: opts.second === 'bone' ? 1 : undefined, p: [ 0.3, 0, 0 ] } );
	if ( opts.pose !== false ) {

		rig.pose = bones.map( ( _, i ) => ( { i, q: new THREE.Quaternion().setFromEuler( new THREE.Euler( rr( - 0.8, 0.8 ), rr( - 0.8, 0.8 ), rr( - 0.8, 0.8 ) ) ).toArray() } ) );
		if ( opts.movePose ) rig.pose[ 0 ].p = [ rr( - 1, 1 ), rr( 0, 2 ), rr( - 1, 1 ) ];

	}

	return rig;

}

// ---------------------------------------------------------------- cases

export function makeCases( mikk ) {

	const cases = [];
	const add = ( label, c ) => cases.push( { label, ...c } );
	const N = BUILTINS.length;

	// mergeGeometries
	for ( let i = 0; i < N; i ++ ) {

		const j = ( i + 3 ) % N;
		for ( const useGroups of [ false, true ] ) {

			add( `mergeGeometries indexed ${i}+${j} groups=${useGroups}`, { op: 'mergeGeometries', geoms: [ raw( i ), raw( j ), raw( i ) ], useGroups } );
			add( `mergeGeometries nonindexed ${i}+${j} groups=${useGroups}`, { op: 'mergeGeometries', geoms: [ rawNonIndexed( i ), rawNonIndexed( j ) ], useGroups } );
			add( `mergeGeometries builtin ${i}+${j} groups=${useGroups}`, { op: 'mergeGeometries', geoms: [ builtin( i ), builtin( j ) ], useGroups } );

		}

		add( `mergeGeometries indexed/nonindexed ${i}`, { op: 'mergeGeometries', geoms: [ raw( i ), rawNonIndexed( j ) ] } );
		add( `mergeGeometries nonindexed/indexed ${i}`, { op: 'mergeGeometries', geoms: [ rawNonIndexed( i ), raw( j ) ] } );
		add( `mergeGeometries morph rel ${i}`, { op: 'mergeGeometries', geoms: [ withMorphs( raw( i ), 2, true ), withMorphs( raw( j ), 2, true ) ], useGroups: true } );
		add( `mergeGeometries morph abs ${i}`, { op: 'mergeGeometries', geoms: [ withMorphs( raw( i ), 1, false ), withMorphs( raw( j ), 1, false ) ] } );
		add( `mergeGeometries morph relative mismatch ${i}`, { op: 'mergeGeometries', geoms: [ withMorphs( raw( i ), 1, false ), withMorphs( raw( j ), 1, true ) ] } );
		add( `mergeGeometries morph count mismatch ${i}`, { op: 'mergeGeometries', geoms: [ withMorphs( raw( i ), 2, false ), withMorphs( raw( j ), 1, false ) ] } );
		add( `mergeGeometries morph missing ${i}`, { op: 'mergeGeometries', geoms: [ raw( i ), withMorphs( raw( j ), 1, false ) ] } );
		add( `mergeGeometries morph normal missing ${i}`, { op: 'mergeGeometries', geoms: [ withMorphs( raw( i ), 1, false ), withMorphs( raw( j ), 1, false, false ) ] } );
		add( `mergeGeometries attr missing ${i}`, { op: 'mergeGeometries', geoms: [ raw( i ), ( () => {

			const d = raw( j ); d.attrs = d.attrs.filter( ( p ) => p[ 0 ] !== 'uv' ); return d;

		} )() ] } );
		add( `mergeGeometries attr extra ${i}`, { op: 'mergeGeometries', geoms: [ raw( i ), setAttr( raw( j ), 'color', { array: randomArray( Float32Array, getAttr( raw( j ), 'position' ).array.length, 0, 1 ), itemSize: 3 } ) ] } );
		add( `mergeGeometries type mismatch ${i}`, { op: 'mergeGeometries', geoms: [ raw( i ), setAttr( raw( j ), 'normal', int16Normalized( getAttr( raw( j ), 'normal' ) ) ) ] } );
		add( `mergeGeometries quantized normals ${i}`, { op: 'mergeGeometries', geoms: [ setAttr( raw( i ), 'normal', int16Normalized( getAttr( raw( i ), 'normal' ) ) ), setAttr( raw( j ), 'normal', int16Normalized( getAttr( raw( j ), 'normal' ) ) ) ] } );
		{

			const c = { op: 'mergeGeometries', useGroups: i % 2 === 0 };
			c.geoms = [ interleave( raw( i ), c ), interleave( raw( j ), c ), interleave( raw( i ), c ) ];
			add( `mergeGeometries interleaved ${i}+${j}`, c );

		}

		{

			const c = { op: 'mergeGeometries' };
			c.geoms = [ interleave( rawNonIndexed( i ), c, false ), rawNonIndexed( j ) ];
			add( `mergeGeometries interleaved first ${i}+${j}`, c );

		}

	}

	add( 'mergeGeometries no position useGroups', { op: 'mergeGeometries', geoms: [ { attrs: [ [ 'uv', { array: new Float32Array( 6 ), itemSize: 2 } ] ] }, { attrs: [ [ 'uv', { array: new Float32Array( 6 ), itemSize: 2 } ] ] } ], useGroups: true } );
	add( 'mergeGeometries uint32 index', { op: 'mergeGeometries', geoms: [ builtin( 0 ), { builtin: { type: 'PlaneGeometry', args: [ 1, 1, 255, 255 ] } }, builtin( 0 ) ], useGroups: true } );
	add( 'mergeGeometries single', { op: 'mergeGeometries', geoms: [ raw( 3 ) ] } );
	add( 'mergeGeometries empty morph arrays', { op: 'mergeGeometries', geoms: [ { ...raw( 0 ), morph: [ [ 'position', [] ] ] }, { ...raw( 1 ), morph: [ [ 'position', [] ] ] } ] } );
	add( 'mergeGeometries gpuType mismatch', { op: 'mergeGeometries', geoms: [ setAttr( raw( 0 ), 'uv', { ...getAttr( raw( 0 ), 'uv' ), gpuType: THREE.IntType } ), raw( 1 ) ] } );
	add( 'mergeGeometries normalized mismatch', { op: 'mergeGeometries', geoms: [ setAttr( raw( 0 ), 'uv', { ...getAttr( raw( 0 ), 'uv' ), normalized: true } ), raw( 1 ) ] } );
	add( 'mergeGeometries itemSize mismatch', { op: 'mergeGeometries', geoms: [ setAttr( raw( 0 ), 'uv', { array: new Float32Array( 24 * 3 ), itemSize: 3 } ), raw( 1 ) ] } );
	add( 'mergeGeometries integer names', { op: 'mergeGeometries', geoms: [ setAttr( setAttr( raw( 0 ), '10', { array: new Float32Array( 24 ), itemSize: 1 } ), '2', { array: new Float32Array( 24 ), itemSize: 1 } ), setAttr( setAttr( raw( 0 ), '2', { array: new Float32Array( 24 ).fill( 2 ), itemSize: 1 } ), '10', { array: new Float32Array( 24 ).fill( 1 ), itemSize: 1 } ) ] } );

	// mergeAttributes
	for ( let i = 0; i < N; i ++ ) {

		const a = raw( i ), b = raw( ( i + 1 ) % N );
		add( `mergeAttributes position ${i}`, { op: 'mergeAttributes', attrs: [ getAttr( a, 'position' ), getAttr( b, 'position' ) ] } );
		add( `mergeAttributes uv f16 ${i}`, { op: 'mergeAttributes', attrs: [ f16( getAttr( a, 'uv' ) ), f16( getAttr( b, 'uv' ) ) ] } );
		add( `mergeAttributes int16 normals ${i}`, { op: 'mergeAttributes', attrs: [ int16Normalized( getAttr( a, 'normal' ) ), int16Normalized( getAttr( b, 'normal' ) ) ] } );
		add( `mergeAttributes gpuType ${i}`, { op: 'mergeAttributes', attrs: [ { ...getAttr( a, 'uv' ), gpuType: THREE.IntType }, { ...getAttr( b, 'uv' ), gpuType: THREE.IntType } ] } );
		add( `mergeAttributes gpuType mismatch ${i}`, { op: 'mergeAttributes', attrs: [ { ...getAttr( a, 'uv' ), gpuType: THREE.IntType }, getAttr( b, 'uv' ) ] } );
		{

			const c = { op: 'mergeAttributes' };
			const ia = interleave( raw( i ), c );
			c.attrs = [ getAttr( b, 'normal' ), getAttr( ia, 'normal' ), getAttr( b, 'normal' ) ];
			add( `mergeAttributes buffer+interleaved ${i}`, c );

		}

		{

			const c = { op: 'mergeAttributes' };
			const ia = interleave( raw( i ), c );
			c.attrs = [ getAttr( ia, 'uv' ), getAttr( b, 'uv' ) ];
			add( `mergeAttributes interleaved first ${i}`, c );

		}

		{

			const c = { op: 'mergeAttributes' };
			const ia = interleave( raw( i ), c ), ib = interleave( raw( ( i + 2 ) % N ), c );
			c.attrs = [ getAttr( ia, 'normal' ), getAttr( ib, 'normal' ), getAttr( ia, 'uv' ) ];
			add( `mergeAttributes all interleaved itemSize mismatch ${i}`, c );
			add( `mergeAttributes all interleaved ${i}`, { ...c, attrs: [ getAttr( ia, 'normal' ), getAttr( ib, 'normal' ), getAttr( ia, 'position' ) ] } );
			const c2 = { op: 'mergeAttributes' };
			const na = interleave( raw( i ), c2 ), nb = interleave( raw( ( i + 1 ) % N ), c2 );
			for ( const buf of c2.buffers ) buf.array = new Int16Array( buf.array.map( ( x ) => Math.round( Math.max( - 1, Math.min( 1, x ) ) * 32767 ) ) );
			c2.attrs = [ { ...getAttr( na, 'normal' ), normalized: true }, { ...getAttr( nb, 'normal' ), normalized: true } ];
			add( `mergeAttributes all interleaved normalized ${i}`, c2 );

		}

		{

			const c = { op: 'mergeAttributes' };
			const ia = interleave( raw( i ), c );
			c.buffers[ 0 ].array = new Int16Array( c.buffers[ 0 ].array.map( ( x ) => Math.round( Math.max( - 1, Math.min( 1, x ) ) * 32767 ) ) );
			c.attrs = [ { ...getAttr( ia, 'normal' ), normalized: true }, int16Normalized( getAttr( b, 'normal' ) ) ];
			add( `mergeAttributes normalized interleaved ${i}`, c );

		}

	}

	add( 'mergeAttributes type mismatch', { op: 'mergeAttributes', attrs: [ { array: new Float32Array( 6 ), itemSize: 3 }, { array: new Uint16Array( 6 ), itemSize: 3 } ] } );
	add( 'mergeAttributes itemSize mismatch', { op: 'mergeAttributes', attrs: [ { array: new Float32Array( 6 ), itemSize: 3 }, { array: new Float32Array( 6 ), itemSize: 2 } ] } );
	add( 'mergeAttributes normalized mismatch', { op: 'mergeAttributes', attrs: [ { array: new Uint8Array( 6 ), itemSize: 3, normalized: true }, { array: new Uint8Array( 6 ), itemSize: 3 } ] } );
	add( 'mergeAttributes uint8 normalized', { op: 'mergeAttributes', attrs: [ { array: randomArray( Uint8Array, 12, 0, 256, true ), itemSize: 4, normalized: true }, { array: randomArray( Uint8Array, 8, 0, 256, true ), itemSize: 4, normalized: true } ] } );
	add( 'mergeAttributes instanced', { op: 'mergeAttributes', attrs: [ { array: randomArray( Float32Array, 12, - 1, 1 ), itemSize: 3, kind: 'inst', mpa: 2 }, { array: randomArray( Float32Array, 6, - 1, 1 ), itemSize: 3, kind: 'inst', mpa: 2 } ] } );

	// interleaveAttributes
	for ( let i = 0; i < N; i ++ ) {

		const a = raw( i );
		add( `interleaveAttributes pnu ${i}`, { op: 'interleaveAttributes', attrs: [ getAttr( a, 'position' ), getAttr( a, 'normal' ), getAttr( a, 'uv' ) ] } );
		add( `interleaveAttributes nu ${i}`, { op: 'interleaveAttributes', attrs: [ getAttr( a, 'uv' ), getAttr( a, 'normal' ) ] } );
		add( `interleaveAttributes int16 ${i}`, { op: 'interleaveAttributes', attrs: [ int16Normalized( getAttr( a, 'normal' ) ), int16Normalized( getAttr( a, 'uv' ) ) ] } );
		add( `interleaveAttributes f16 ${i}`, { op: 'interleaveAttributes', attrs: [ f16( getAttr( a, 'uv' ) ), f16( getAttr( a, 'position' ) ) ] } );
		add( `interleaveAttributes mismatch ${i}`, { op: 'interleaveAttributes', attrs: [ getAttr( a, 'position' ), int16Normalized( getAttr( a, 'normal' ) ) ] } );
		add( `interleaveAttributes vec4 ${i}`, { op: 'interleaveAttributes', attrs: [ { array: randomArray( Float32Array, getAttr( a, 'uv' ).array.length * 2, - 2, 2 ), itemSize: 4 }, getAttr( a, 'uv' ) ] } );

	}

	// deinterleaveAttribute / deinterleaveGeometry / deepCloneAttribute / remapAttribute
	for ( let i = 0; i < N; i ++ ) {

		for ( const which of [ 'position', 'normal', 'uv' ] ) {

			const c = { op: 'deinterleaveAttribute' };
			const d = interleave( raw( i ), c );
			c.attr = getAttr( d, which );
			add( `deinterleaveAttribute ${which} ${i}`, c );

		}

		{

			const c = { op: 'deinterleaveAttribute' };
			const d = interleave( raw( i ), c );
			c.buffers[ 0 ].array = new Int16Array( c.buffers[ 0 ].array.map( ( x ) => Math.round( Math.max( - 1, Math.min( 1, x ) ) * 32767 ) ) );
			c.buffers[ 0 ].instanced = true; c.buffers[ 0 ].mpa = 3; c.buffers[ 0 ].usage = THREE.DynamicDrawUsage;
			c.attr = { ...getAttr( d, 'normal' ), normalized: true, name: 'n' };
			add( `deinterleaveAttribute normalized instanced ${i}`, c );

		}

		{

			const c = { op: 'deinterleaveGeometry' };
			c.geom = interleave( withMorphs( raw( i ), 1, true ), c );
			const m = c.geom.morph[ 0 ][ 1 ][ 0 ];
			const count = m.array.length / 3;
			const mb = new Float32Array( count * 4 );
			for ( let v = 0; v < count; v ++ ) for ( let k = 0; k < 3; k ++ ) mb[ v * 4 + k ] = m.array[ v * 3 + k ];
			c.buffers.push( { array: mb, stride: 4 } );
			c.geom.morph[ 0 ][ 1 ][ 0 ] = { il: c.buffers.length - 1, itemSize: 3, offset: 0 };
			add( `deinterleaveGeometry ${i}`, c );

		}

		{

			const a = raw( i );
			add( `deepCloneAttribute plain ${i}`, { op: 'deepCloneAttribute', attr: { ...getAttr( a, 'position' ), name: 'p', usage: THREE.DynamicDrawUsage, gpuType: THREE.IntType } } );
			add( `deepCloneAttribute f16 ${i}`, { op: 'deepCloneAttribute', attr: f16( getAttr( a, 'uv' ) ) } );
			add( `deepCloneAttribute int16 ${i}`, { op: 'deepCloneAttribute', attr: int16Normalized( getAttr( a, 'normal' ) ) } );
			add( `deepCloneAttribute inst ${i}`, { op: 'deepCloneAttribute', attr: { ...getAttr( a, 'uv' ), kind: 'inst', mpa: 4, usage: THREE.StreamDrawUsage } } );
			const c = { op: 'deepCloneAttribute' };
			c.attr = getAttr( interleave( raw( i ), c ), 'uv' );
			add( `deepCloneAttribute interleaved ${i}`, c );

		}

		{

			const a = raw( i );
			const count = getAttr( a, 'position' ).array.length / 3;
			const idx = Array.from( { length: count + 5 }, () => Math.floor( rand() * count ) );
			add( `remapAttribute plain ${i}`, { op: 'remapAttribute', sourceIndices: idx, attrs: [ { ...getAttr( a, 'position' ), name: 'p', usage: THREE.DynamicDrawUsage, gpuType: THREE.IntType }, f16( getAttr( a, 'uv' ) ), int16Normalized( getAttr( a, 'normal' ) ), { ...getAttr( a, 'uv' ), kind: 'inst', mpa: 3 } ] } );
			for ( const shared of [ false, true ] ) {

				const c = { op: 'remapAttribute', sourceIndices: idx, shared };
				const d = interleave( raw( i ), c );
				c.buffers[ 0 ].usage = THREE.DynamicDrawUsage;
				if ( i % 2 ) {

					c.buffers[ 0 ].instanced = true; c.buffers[ 0 ].mpa = 2;

				}

				c.attrs = [ getAttr( d, 'position' ), getAttr( d, 'normal' ), { ...getAttr( d, 'uv' ), name: 'uvn' }, getAttr( d, 'position' ) ];
				add( `remapAttribute interleaved shared=${shared} ${i}`, c );

			}

		}

	}

	// estimateBytesUsed
	for ( let i = 0; i < N; i ++ ) {

		add( `estimateBytesUsed ${i}`, { op: 'estimateBytesUsed', geom: raw( i ) } );
		add( `estimateBytesUsed nonindexed ${i}`, { op: 'estimateBytesUsed', geom: rawNonIndexed( i ) } );
		const c = { op: 'estimateBytesUsed' };
		c.geom = interleave( setAttr( raw( i ), 'normal', int16Normalized( getAttr( raw( i ), 'normal' ) ) ), c );
		add( `estimateBytesUsed interleaved ${i}`, c );

	}

	// mergeVertices
	const tolerances = [ undefined, 0, 1e-6, 1e-4, 1e-2, 0.1, 0.5, 0.3333 ];
	for ( let i = 0; i < N; i ++ ) {

		for ( const tolerance of tolerances ) {

			const t = tolerance === undefined ? {} : { tolerance };
			add( `mergeVertices nonindexed ${i} tol=${tolerance}`, { op: 'mergeVertices', geom: rawNonIndexed( i ), ...t } );
			if ( tolerance === undefined || tolerance === 0.1 ) {

				add( `mergeVertices indexed ${i} tol=${tolerance}`, { op: 'mergeVertices', geom: raw( i ), ...t } );
				add( `mergeVertices builtin ${i} tol=${tolerance}`, { op: 'mergeVertices', geom: builtin( i ), ...t } );
				add( `mergeVertices morph ${i} tol=${tolerance}`, { op: 'mergeVertices', geom: withMorphs( rawNonIndexed( i ), 2, i % 2 === 0 ), ...t } );
				const c = { op: 'mergeVertices', ...t };
				c.geom = interleave( rawNonIndexed( i ), c );
				add( `mergeVertices interleaved ${i} tol=${tolerance}`, c );

			}

		}

		const d = rawNonIndexed( i );
		d.attrs = [ [ 'position', { array: new Float32Array( quantize( getAttr( d, 'position' ).array, 0.25 ) ), itemSize: 3 } ] ];
		add( `mergeVertices quantized position only ${i}`, { op: 'mergeVertices', geom: d } );
		add( `mergeVertices f16 + int16 ${i}`, { op: 'mergeVertices', geom: setAttr( setAttr( rawNonIndexed( i ), 'uv', f16( getAttr( rawNonIndexed( i ), 'uv' ) ) ), 'normal', int16Normalized( getAttr( rawNonIndexed( i ), 'normal' ) ) ) } );
		add( `mergeVertices big values ${i}`, { op: 'mergeVertices', geom: setAttr( rawNonIndexed( i ), 'position', { array: getAttr( rawNonIndexed( i ), 'position' ).array.map( ( x ) => x * 1e12 ), itemSize: 3 } ), tolerance: 1e-8 } );
		add( `mergeVertices skin ${i}`, { op: 'mergeVertices', geom: setAttr( rawNonIndexed( i ), 'skinIndex', { array: randomArray( Uint16Array, getAttr( rawNonIndexed( i ), 'position' ).array.length / 3 * 4, 0, 3, true ), itemSize: 4, usage: THREE.DynamicDrawUsage } ) } );

	}

	// toTrianglesDrawMode
	for ( let i = 0; i < N; i ++ ) {

		for ( const mode of [ THREE.TriangleStripDrawMode, THREE.TriangleFanDrawMode ] ) {

			add( `toTrianglesDrawMode indexed ${i} mode=${mode}`, { op: 'toTrianglesDrawMode', geom: raw( i ), drawMode: mode } );
			add( `toTrianglesDrawMode nonindexed ${i} mode=${mode}`, { op: 'toTrianglesDrawMode', geom: rawNonIndexed( i ), drawMode: mode } );

		}

	}

	add( 'toTrianglesDrawMode triangles', { op: 'toTrianglesDrawMode', geom: raw( 0 ), drawMode: THREE.TrianglesDrawMode } );
	add( 'toTrianglesDrawMode unknown', { op: 'toTrianglesDrawMode', geom: raw( 0 ), drawMode: 7 } );
	add( 'toTrianglesDrawMode no position', { op: 'toTrianglesDrawMode', geom: { attrs: [ [ 'uv', { array: new Float32Array( 8 ), itemSize: 2 } ] ] }, drawMode: THREE.TriangleStripDrawMode } );
	add( 'toTrianglesDrawMode two vertices', { op: 'toTrianglesDrawMode', geom: { attrs: [ [ 'position', { array: new Float32Array( 6 ), itemSize: 3 } ] ] }, drawMode: THREE.TriangleFanDrawMode } );
	add( 'toTrianglesDrawMode big strip', { op: 'toTrianglesDrawMode', geom: { attrs: [ [ 'position', { array: new Float32Array( 70000 * 3 ), itemSize: 3 } ] ] }, drawMode: THREE.TriangleStripDrawMode } );

	// computeMorphedAttributes
	for ( let i = 0; i < N; i ++ ) {

		for ( const relative of [ false, true ] ) {

			const infl = [ rr( 0, 1 ), rr( - 0.5, 1 ) ];
			add( `computeMorphedAttributes mesh ${i} rel=${relative}`, { op: 'computeMorphedAttributes', object: { cls: 'Mesh', geom: withMorphs( raw( i ), 2, relative ), influences: infl } } );
			add( `computeMorphedAttributes mesh nonindexed ${i} rel=${relative}`, { op: 'computeMorphedAttributes', object: { cls: 'Mesh', geom: withMorphs( rawNonIndexed( i ), 2, relative ), influences: [ 0, infl[ 1 ] ] } } );
			add( `computeMorphedAttributes multi ${i} rel=${relative}`, { op: 'computeMorphedAttributes', object: { cls: 'Mesh', multi: true, geom: { ...withMorphs( raw( i ), 2, relative ), groups: [ [ 0, 9, 0 ], [ 6, 12, 1 ], [ 24, 6, 1 ] ] }, influences: infl } } );
			add( `computeMorphedAttributes multi nonindexed ${i} rel=${relative}`, { op: 'computeMorphedAttributes', object: { cls: 'Mesh', multi: true, geom: { ...withMorphs( rawNonIndexed( i ), 2, relative ), groups: [ [ 3, 15, 0 ], [ 21, 30, 1 ] ], drawRange: [ 6, 27 ] }, influences: infl } } );

		}

		add( `computeMorphedAttributes no morph ${i}`, { op: 'computeMorphedAttributes', object: { cls: 'Mesh', geom: raw( i ) } } );
		add( `computeMorphedAttributes drawRange ${i}`, { op: 'computeMorphedAttributes', object: { cls: 'Mesh', geom: { ...withMorphs( raw( i ), 1, true ), drawRange: [ 3, 18 ] }, influences: [ 0.5 ] } } );
		add( `computeMorphedAttributes short influences ${i}`, { op: 'computeMorphedAttributes', object: { cls: 'Mesh', geom: withMorphs( raw( i ), 3, true ), influences: [ 0.5 ] } } );
		add( `computeMorphedAttributes line ${i}`, { op: 'computeMorphedAttributes', object: { cls: 'Line', geom: withMorphs( rawNonIndexed( i ), 1, false ), influences: [ 0.7 ] } } );
		add( `computeMorphedAttributes points ${i}`, { op: 'computeMorphedAttributes', object: { cls: 'Points', geom: withMorphs( raw( i ), 2, true ), influences: [ 0.2, 0.9 ] } } );
		const c = { op: 'computeMorphedAttributes' };
		c.object = { cls: 'Mesh', geom: interleave( withMorphs( raw( i ), 1, true ), c ), influences: [ 0.4 ] };
		add( `computeMorphedAttributes interleaved ${i}`, c );

	}

	for ( let k = 0; k < 8; k ++ ) {

		const geom = k % N;
		add( `computeMorphedAttributes skinned ${k}`, { op: 'computeMorphedAttributes', object: { cls: 'SkinnedMesh', rig: chainRig( '', 3 + ( k % 3 ), { geom, weights: 1 + ( k % 4 ), scaled: k % 2 === 1, meshP: [ 0.1 * k, 0, 0 ], rootP: [ 0, 0.2 * k, 0 ] } ) } } );
		add( `computeMorphedAttributes skinned morph ${k}`, { op: 'computeMorphedAttributes', object: { cls: 'SkinnedMesh', rig: chainRig( '', 4, { geom, morph: true, morphRelative: k % 2 === 0, influences: [ 0.3, 0.6 ] } ) } } );
		add( `computeMorphedAttributes skinned detached ${k}`, { op: 'computeMorphedAttributes', object: { cls: 'SkinnedMesh', rig: chainRig( '', 3, { geom, bindMode: 'detached', rootQ: new THREE.Quaternion().setFromEuler( new THREE.Euler( 0.2, 0.4, 0.1 ) ).toArray() } ) } } );

	}

	// computeMikkTSpaceTangents
	if ( mikk ) {

		for ( let i = 0; i < N; i ++ ) {

			add( `mikktspace builtin ${i}`, { op: 'computeMikkTSpaceTangents', mikk, geom: builtin( i ) } );
			add( `mikktspace nonindexed ${i}`, { op: 'computeMikkTSpaceTangents', mikk, geom: rawNonIndexed( i ), negateSign: false } );
			add( `mikktspace int16 normals ${i}`, { op: 'computeMikkTSpaceTangents', mikk, geom: setAttr( raw( i ), 'normal', int16Normalized( getAttr( raw( i ), 'normal' ) ) ) } );
			add( `mikktspace int8 normals ${i}`, { op: 'computeMikkTSpaceTangents', mikk, geom: setAttr( raw( i ), 'normal', int8Normalized( getAttr( raw( i ), 'normal' ) ) ) } );
			add( `mikktspace f16 uv ${i}`, { op: 'computeMikkTSpaceTangents', mikk, geom: setAttr( rawNonIndexed( i ), 'uv', f16( getAttr( rawNonIndexed( i ), 'uv' ) ) ) } );
			const c = { op: 'computeMikkTSpaceTangents', mikk };
			c.geom = interleave( rawNonIndexed( i ), c );
			add( `mikktspace interleaved ${i}`, c );

		}

	}

	// toCreasedNormals
	const angles = [ undefined, 0, 0.1, Math.PI / 4, Math.PI / 2, Math.PI ];
	for ( let i = 0; i < N; i ++ ) {

		for ( const creaseAngle of angles ) {

			const a = creaseAngle === undefined ? {} : { creaseAngle };
			add( `toCreasedNormals builtin ${i} angle=${creaseAngle}`, { op: 'toCreasedNormals', geom: builtin( i ), ...a } );
			if ( creaseAngle === undefined || creaseAngle === 0.1 ) add( `toCreasedNormals nonindexed ${i} angle=${creaseAngle}`, { op: 'toCreasedNormals', geom: rawNonIndexed( i ), ...a } );

		}

		const c = { op: 'toCreasedNormals' };
		c.geom = interleave( raw( i ), c );
		add( `toCreasedNormals interleaved ${i}`, c );
		add( `toCreasedNormals int16 positions ${i}`, { op: 'toCreasedNormals', geom: setAttr( rawNonIndexed( i ), 'position', int16Normalized( getAttr( rawNonIndexed( i ), 'position' ) ) ) } );
		add( `toCreasedNormals f16 positions ${i}`, { op: 'toCreasedNormals', geom: setAttr( rawNonIndexed( i ), 'position', f16( getAttr( rawNonIndexed( i ), 'position' ) ) ) } );
		add( `toCreasedNormals quantized ${i}`, { op: 'toCreasedNormals', geom: setAttr( rawNonIndexed( i ), 'position', { array: new Float32Array( quantize( getAttr( rawNonIndexed( i ), 'position' ).array, 0.01 ) ), itemSize: 3 } ) } );

	}

	for ( let i = 0; i < N; i ++ ) {

		const d = rawNonIndexed( i );
		const pos = getAttr( d, 'position' ).array;
		const out = new Float64Array( pos.length );
		for ( let k = 0; k < pos.length; k ++ ) {

			const q = Math.round( pos[ k ] / 0.01 );
			out[ k ] = ( Math.floor( k / 9 ) % 2 ) ? q / 100 : q * 0.01;

		}

		add( `toCreasedNormals float64 near boundary ${i}`, { op: 'toCreasedNormals', geom: setAttr( d, 'position', { array: out, itemSize: 3 } ) } );
		add( `mergeVertices float64 near boundary ${i}`, { op: 'mergeVertices', geom: setAttr( rawNonIndexed( i ), 'position', { array: out, itemSize: 3 } ), tolerance: 0.01 } );

	}

	add( 'toCreasedNormals vec4 positions', { op: 'toCreasedNormals', geom: { attrs: [ [ 'position', { array: randomArray( Float32Array, 36 * 4, - 1, 1 ), itemSize: 4 } ] ] } } );

	// mergeGroups
	for ( let i = 0; i < N; i ++ ) {

		const d = raw( i );
		const count = d.index ? d.index.array.length : getAttr( d, 'position' ).array.length / 3;
		const n = 6;
		const groups = [];
		let start = 0;
		for ( let g = 0; g < n; g ++ ) {

			const len = g === n - 1 ? count - start : Math.floor( count / n / 3 ) * 3;
			groups.push( [ start, len, Math.floor( rand() * 3 ) ] );
			start += len;

		}

		groups.reverse();
		add( `mergeGroups indexed ${i}`, { op: 'mergeGroups', geom: { ...d, groups } } );
		add( `mergeGroups nonindexed ${i}`, { op: 'mergeGroups', geom: { ...rawNonIndexed( i ), groups: groups.map( ( g ) => g.slice() ) } } );
		add( `mergeGroups infinity ${i}`, { op: 'mergeGroups', geom: { ...d, groups: [ [ 0, 6, 1 ], [ 6, Infinity, 0 ] ] } } );
		add( `mergeGroups ties ${i}`, { op: 'mergeGroups', geom: { ...d, groups: [ [ 6, 3, 1 ], [ 0, 6, 1 ], [ 6, 6, 1 ], [ 0, 3, 0 ] ] } } );
		add( `mergeGroups builtin ${i}`, { op: 'mergeGroups', geom: builtin( i ) } );

	}

	add( 'mergeGroups none', { op: 'mergeGroups', geom: { ...raw( 2 ), groups: [] } } );

	// SkeletonUtils.clone
	for ( let k = 0; k < 10; k ++ ) {

		const rig = chainRig( 'c' + k + '_', 2 + ( k % 4 ), { geom: k % N, branch: k % 3 === 0, scaled: k % 2 === 0, second: k % 3 === 1 ? 'root' : k % 3 === 2 ? 'bone' : undefined, rootP: [ k * 0.1, 0, 0 ], bindMode: k === 4 ? 'detached' : undefined } );
		add( `clone root ${k}`, { op: 'clone', rig } );
		if ( k % 2 === 0 ) add( `clone mesh ${k}`, { op: 'clone', rig: chainRig( 'm' + k + '_', 2, { geom: k % N } ), fromMesh: true } );

	}

	// SkeletonUtils.retarget
	const optionSets = [
		( t, s ) => ( { names: Object.fromEntries( t.bones.map( ( b, i ) => [ b.name, s.bones[ i ] ? s.bones[ i ].name : 'none' ] ) ), hip: s.bones[ 0 ].name } ),
		( t, s ) => ( { names: Object.fromEntries( t.bones.map( ( b, i ) => [ b.name, s.bones[ i ] ? s.bones[ i ].name : 'none' ] ) ), hip: s.bones[ 0 ].name, scale: 2.5, hipInfluence: [ 1, 0, 0.5 ], hipPosition: [ 0.1, 0.2, - 0.3 ] } ),
		( t, s ) => ( { getBoneName: [ 'tgt_', 'src_' ], hip: 'src_hip', preserveBonePositions: false } ),
		( t, s ) => ( { getBoneName: [ 'tgt_', 'src_' ], hip: 'src_hip', preserveBoneMatrix: false, useTargetMatrix: true } ),
		( t, s ) => ( { getBoneName: [ 'tgt_', 'src_' ], hip: 'src_hip', useTargetMatrix: true } ),
		( t, s ) => ( { getBoneName: [ 'tgt_', 'src_' ], hip: 'nothing', localOffsets: { tgt_bone1: new THREE.Matrix4().makeRotationFromEuler( new THREE.Euler( 0.3, 0.1, - 0.2 ) ).toArray(), tgt_hip: new THREE.Matrix4().makeRotationY( 0.5 ).toArray() } } ),
		( t, s ) => ( { names: { tgt_hip: 'src_hip', tgt_bone2: 'src_bone2' }, hip: 'src_hip', preserveBonePositions: false, scale: 0.5 } ),
		( t, s ) => ( {} ),
	];
	for ( let k = 0; k < 16; k ++ ) {

		const n = 3 + ( k % 3 );
		const target = chainRig( 'tgt_', n, { geom: k % N, scaled: k % 4 === 1, branch: k % 5 === 0, rootP: [ 0.5, 0, 0 ], rootQ: new THREE.Quaternion().setFromEuler( new THREE.Euler( 0, 0.3 * k, 0 ) ).toArray(), pose: k % 2 === 0, movePose: true } );
		const source = chainRig( 'src_', n + ( k % 2 ), { geom: ( k + 1 ) % N, scaled: k % 3 === 0, rootS: [ 1.5, 1.5, 1.5 ], rootP: [ 0, 0.3, - 1 ], movePose: true } );
		const opts = optionSets[ k % optionSets.length ]( target, source );
		add( `retarget ${k}`, { op: 'retarget', target, source, options: opts } );
		if ( k < 8 ) {

			add( `retarget source skeleton ${k}`, { op: 'retarget', target, source, options: opts, sourceAs: 'skeleton' } );
			add( `retarget target skeleton ${k}`, { op: 'retarget', target, source, options: opts, targetAs: 'skeleton' } );

		}

	}

	add( 'retarget default options', { op: 'retarget', target: chainRig( 'tgt_', 3 ), source: chainRig( 'src_', 3 ), options: {}, defaultOptions: true } );

	// SkeletonUtils.retargetClip
	function clipFor( rig, frames, duration, withPos ) {

		const times = Array.from( { length: frames }, ( _, f ) => duration * f / ( frames - 1 ) );
		const tracks = [];
		rig.bones.forEach( ( b, bi ) => {

			if ( bi % 2 === 1 && frames > 3 ) return;
			const values = [];
			for ( let f = 0; f < frames; f ++ ) values.push( ...new THREE.Quaternion().setFromEuler( new THREE.Euler( rr( - 1, 1 ), rr( - 1, 1 ), rr( - 1, 1 ) ) ).toArray() );
			tracks.push( { type: 'quaternion', name: '.bones[' + b.name + '].quaternion', times, values } );

		} );
		if ( withPos ) {

			const values = [];
			for ( let f = 0; f < frames; f ++ ) values.push( rr( - 1, 1 ), rr( 0, 2 ), rr( - 1, 1 ) );
			tracks.push( { type: 'vector', name: rig.bones[ 0 ].name + '.position', times: times.slice( 0, frames ), values } );

		}

		return { name: 'clip' + frames, duration: - 1, tracks };

	}

	for ( let k = 0; k < 12; k ++ ) {

		const n = 3 + ( k % 2 );
		const target = chainRig( 'tgt_', n, { geom: k % N, rootP: [ 0.2, 0, 0 ], pose: false } );
		const source = chainRig( 'src_', n, { geom: ( k + 2 ) % N, scaled: k % 3 === 0, rootP: [ 0, 0.1, 0 ], pose: false } );
		const frames = 2 + ( k % 5 );
		const clip = clipFor( source, frames, 0.5 + 0.25 * ( k % 4 ), k % 2 === 0 );
		const base = { getBoneName: [ 'tgt_', 'src_' ], hip: 'src_hip' };
		const variants = [
			{},
			{ fps: 12 },
			{ fps: 7, trim: [ 0.1, 0.4 ] },
			{ useFirstFramePosition: true, fps: 10 },
			{ names: Object.fromEntries( target.bones.map( ( b ) => [ b.name, b.name.replace( 'tgt_', 'src_' ) ] ) ), getBoneName: undefined, fps: 9 },
			{ preserveBonePositions: false, fps: 8, scale: 1.5 },
		];
		const options = { ...base, ...variants[ k % variants.length ] };
		if ( options.getBoneName === undefined ) delete options.getBoneName;
		add( `retargetClip ${k}`, { op: 'retargetClip', target, source, clip, options } );
		if ( k % 3 === 0 ) add( `retargetClip source skeleton ${k}`, { op: 'retargetClip', target, source, clip, options, sourceAs: 'skeleton' } );

	}

	return cases;

}
