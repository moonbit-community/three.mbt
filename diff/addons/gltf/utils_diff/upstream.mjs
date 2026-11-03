// Upstream side: the same builders and summaries as src/harness/harness.mbt, driving
// examples/jsm/utils/BufferGeometryUtils.js and SkeletonUtils.js.
import * as THREE from 'three';
import * as BufferGeometryUtils from 'three/addons/utils/BufferGeometryUtils.js';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';

export { THREE };

const has = ( v, k ) => v != null && v[ k ] !== undefined && v[ k ] !== null;
const clone = ( a ) => new a.constructor( a );

function buildBuffers( c ) {

	const out = [];
	if ( has( c, 'buffers' ) ) for ( const d of c.buffers ) {

		const array = clone( d.array );
		const b = d.instanced ? new THREE.InstancedInterleavedBuffer( array, d.stride, d.mpa ) : new THREE.InterleavedBuffer( array, d.stride );
		if ( has( d, 'usage' ) ) b.setUsage( d.usage );
		out.push( b );

	}

	return out;

}

function buildAttr( d, bufs ) {

	if ( has( d, 'il' ) ) {

		const a = new THREE.InterleavedBufferAttribute( bufs[ d.il ], d.itemSize, d.offset, !! d.normalized );
		if ( has( d, 'name' ) ) a.name = d.name;
		return a;

	}

	const array = clone( d.array );
	const normalized = !! d.normalized;
	const kind = has( d, 'kind' ) ? d.kind : 'plain';
	let a;
	if ( kind === 'f16' ) a = new THREE.Float16BufferAttribute( array, d.itemSize, normalized );
	else if ( kind === 'inst' ) a = new THREE.InstancedBufferAttribute( array, d.itemSize, normalized, d.mpa );
	else a = new THREE.BufferAttribute( array, d.itemSize, normalized );
	if ( has( d, 'name' ) ) a.name = d.name;
	if ( has( d, 'usage' ) ) a.setUsage( d.usage );
	if ( has( d, 'gpuType' ) ) a.gpuType = d.gpuType;
	return a;

}

export function buildBuiltin( b ) {

	const a = b.args;
	const g = ( i, d ) => i < a.length ? a[ i ] : d;
	switch ( b.type ) {

		case 'BoxGeometry': return new THREE.BoxGeometry( g( 0, 1 ), g( 1, 1 ), g( 2, 1 ), g( 3, 1 ), g( 4, 1 ), g( 5, 1 ) );
		case 'SphereGeometry': return new THREE.SphereGeometry( g( 0, 1 ), g( 1, 32 ), g( 2, 16 ) );
		case 'TorusKnotGeometry': return new THREE.TorusKnotGeometry( g( 0, 1 ), g( 1, 0.4 ), g( 2, 64 ), g( 3, 8 ), g( 4, 2 ), g( 5, 3 ) );
		case 'PlaneGeometry': return new THREE.PlaneGeometry( g( 0, 1 ), g( 1, 1 ), g( 2, 1 ), g( 3, 1 ) );
		case 'TorusGeometry': return new THREE.TorusGeometry( g( 0, 1 ), g( 1, 0.4 ), g( 2, 12 ), g( 3, 48 ) );
		case 'CylinderGeometry': return new THREE.CylinderGeometry( g( 0, 1 ), g( 1, 1 ), g( 2, 1 ), g( 3, 32 ), g( 4, 1 ) );
		case 'IcosahedronGeometry': return new THREE.IcosahedronGeometry( g( 0, 1 ), g( 1, 0 ) );
		case 'CapsuleGeometry': return new THREE.CapsuleGeometry( g( 0, 1 ), g( 1, 1 ), g( 2, 4 ), g( 3, 8 ) );

	}

	throw new Error( 'unknown builtin ' + b.type );

}

function buildGeometry( d, bufs ) {

	const g = has( d, 'builtin' ) ? buildBuiltin( d.builtin ) : new THREE.BufferGeometry();
	if ( has( d, 'attrs' ) ) for ( const [ name, a ] of d.attrs ) g.setAttribute( name, buildAttr( a, bufs ) );
	if ( has( d, 'index' ) ) g.setIndex( buildAttr( d.index, bufs ) );
	if ( has( d, 'noIndex' ) ) g.index = null;
	if ( has( d, 'morph' ) ) for ( const [ name, list ] of d.morph ) g.morphAttributes[ name ] = list.map( ( a ) => buildAttr( a, bufs ) );
	if ( has( d, 'morphRelative' ) ) g.morphTargetsRelative = !! d.morphRelative;
	if ( has( d, 'groups' ) ) {

		g.clearGroups();
		for ( const gr of d.groups ) g.addGroup( gr[ 0 ] | 0, gr[ 1 ], gr[ 2 ] | 0 );

	}

	if ( has( d, 'drawRange' ) ) g.setDrawRange( d.drawRange[ 0 ] | 0, d.drawRange[ 1 ] );
	if ( has( d, 'name' ) ) g.name = String( d.name );
	return g;

}

function setTRS( o, d ) {

	if ( has( d, 'p' ) ) o.position.set( ...d.p );
	if ( has( d, 'q' ) ) o.quaternion.set( ...d.q );
	if ( has( d, 's' ) ) o.scale.set( ...d.s );

}

function setInfluences( o, d ) {

	if ( has( d, 'influences' ) ) o.morphTargetInfluences = d.influences.slice();

}

function buildRig( d, bufs ) {

	const root = new THREE.Group();
	root.name = d.rootName;
	setTRS( root, d.root );
	const bones = [];
	for ( const b of d.bones ) {

		const bone = new THREE.Bone();
		bone.name = b.name;
		setTRS( bone, b );
		if ( ( b.parent | 0 ) < 0 ) root.add( bone ); else bones[ b.parent ].add( bone );
		bones.push( bone );

	}

	const meshes = [];
	for ( const m of d.meshes ) {

		const mesh = new THREE.SkinnedMesh( buildGeometry( m.geom, bufs ), new THREE.MeshBasicMaterial() );
		mesh.name = m.name;
		setTRS( mesh, m );
		if ( has( m, 'parentBone' ) ) bones[ m.parentBone ].add( mesh ); else root.add( mesh );
		meshes.push( mesh );

	}

	root.updateMatrixWorld( true );
	d.meshes.forEach( ( m, k ) => {

		const mesh = meshes[ k ];
		if ( has( m, 'bindMode' ) ) mesh.bindMode = m.bindMode;
		mesh.bind( new THREE.Skeleton( m.bones.map( ( i ) => bones[ i ] ) ) );
		setInfluences( mesh, m );

	} );
	if ( has( d, 'pose' ) ) for ( const p of d.pose ) setTRS( bones[ p.i ], p );
	root.updateMatrixWorld( true );
	return { root, bones, meshes };

}

function buildObject( d, bufs ) {

	if ( d.cls === 'SkinnedMesh' ) return buildRig( d.rig, bufs ).meshes[ 0 ];
	const geometry = buildGeometry( d.geom, bufs );
	let o;
	if ( d.cls === 'Mesh' ) o = new THREE.Mesh( geometry, d.multi ? [ new THREE.MeshBasicMaterial(), new THREE.MeshBasicMaterial() ] : new THREE.MeshBasicMaterial() );
	else if ( d.cls === 'Line' ) o = new THREE.Line( geometry, d.multi ? [ new THREE.LineBasicMaterial(), new THREE.LineBasicMaterial() ] : new THREE.LineBasicMaterial() );
	else if ( d.cls === 'Points' ) o = new THREE.Points( geometry, d.multi ? [ new THREE.PointsMaterial(), new THREE.PointsMaterial() ] : new THREE.PointsMaterial() );
	else throw new Error( 'unknown class ' + d.cls );
	setInfluences( o, d );
	return o;

}

// ---------------------------------------------------------------- summaries

class Ctx {

	constructor() {

		this.buffers = [];
		this.out = [];

	}

	id( b ) {

		const i = this.buffers.indexOf( b );
		if ( i >= 0 ) return i;
		this.buffers.push( b );
		this.out.push( {
			type: b.array.constructor.name, stride: b.stride, count: b.count, usage: b.usage,
			instanced: !! b.isInstancedInterleavedBuffer, mpa: b.isInstancedInterleavedBuffer ? b.meshPerAttribute : 1, array: b.array
		} );
		return this.buffers.length - 1;

	}

}

function sumAttr( ctx, a ) {

	if ( a.isInterleavedBufferAttribute ) {

		return { k: 'il', itemSize: a.itemSize, offset: a.offset, normalized: a.normalized, name: a.name, count: a.count, buf: ctx.id( a.data ) };

	}

	const kind = a.isFloat16BufferAttribute ? 'f16' : a.isStorageInstancedBufferAttribute ? 'storageInst' : a.isStorageBufferAttribute ? 'storage' : a.isInstancedBufferAttribute ? 'inst' : 'plain';
	const o = { k: 'buf', kind, type: a.array.constructor.name, itemSize: a.itemSize, normalized: a.normalized, count: a.count, name: a.name, usage: a.usage, gpuType: a.gpuType, array: a.array };
	if ( a.isInstancedBufferAttribute ) o.mpa = a.meshPerAttribute;
	return o;

}

function sumGeometryCtx( ctx, g ) {

	return {
		type: g.type, name: g.name,
		attrs: Object.keys( g.attributes ).map( ( n ) => [ n, sumAttr( ctx, g.attributes[ n ] ) ] ),
		index: g.index ? sumAttr( ctx, g.index ) : null,
		morph: Object.keys( g.morphAttributes ).map( ( n ) => [ n, g.morphAttributes[ n ].map( ( a ) => sumAttr( ctx, a ) ) ] ),
		morphRelative: g.morphTargetsRelative,
		groups: g.groups.map( ( gr ) => [ gr.start, gr.count, gr.materialIndex ] ),
		drawRange: [ g.drawRange.start, g.drawRange.count ]
	};

}

function sumGeometry( g ) {

	const ctx = new Ctx();
	const s = sumGeometryCtx( ctx, g );
	s.buffers = ctx.out;
	return s;

}

function sumAttrAlone( a ) {

	const ctx = new Ctx();
	return { attr: sumAttr( ctx, a ), buffers: ctx.out };

}

const m4 = ( m ) => Array.from( m.elements );

function nodeList( root ) {

	const nodes = [];
	root.traverse( ( n ) => nodes.push( n ) );
	return nodes;

}

function sumScene( root, sourceNodes ) {

	const nodes = nodeList( root );
	return nodes.map( ( n ) => {

		const o = {
			name: n.name, type: n.type, parent: n.parent ? nodes.indexOf( n.parent ) : - 1,
			p: n.position.toArray(), q: n.quaternion.toArray(), s: n.scale.toArray(),
			matrix: m4( n.matrix ), matrixWorld: m4( n.matrixWorld ), inSource: sourceNodes.includes( n )
		};
		if ( n.isSkinnedMesh ) {

			const src = sourceNodes[ nodes.indexOf( n ) ];
			const srcSk = src && src.isSkinnedMesh ? src : null;
			if ( n.skeleton ) {

				o.bones = n.skeleton.bones.map( ( b ) => nodes.indexOf( b ) );
				o.sourceBones = n.skeleton.bones.map( ( b ) => sourceNodes.indexOf( b ) );
				o.boneInverses = n.skeleton.boneInverses.map( m4 );
				o.skeletonShared = srcSk && srcSk.skeleton ? srcSk.skeleton === n.skeleton : false;
				o.inversesShared = srcSk && srcSk.skeleton ? srcSk.skeleton.boneInverses === n.skeleton.boneInverses : false;

			}

			o.geometryShared = srcSk ? srcSk.geometry === n.geometry : false;
			o.bindMatrix = m4( n.bindMatrix );
			o.bindMatrixInverse = m4( n.bindMatrixInverse );
			o.bindMode = n.bindMode;

		}

		return o;

	} );

}

function sumBones( bones ) {

	return bones.map( ( n ) => ( {
		name: n.name, p: n.position.toArray(), q: n.quaternion.toArray(), s: n.scale.toArray(),
		matrix: m4( n.matrix ), matrixWorld: m4( n.matrixWorld )
	} ) );

}

function buildOptions( d ) {

	const o = {};
	if ( has( d, 'names' ) ) o.names = Object.assign( {}, d.names );
	if ( has( d, 'getBoneName' ) ) {

		const [ from, to ] = d.getBoneName;
		o.getBoneName = ( bone ) => bone.name.replace( from, to );

	}

	if ( has( d, 'hip' ) ) o.hip = d.hip;
	if ( has( d, 'scale' ) ) o.scale = d.scale;
	if ( has( d, 'hipInfluence' ) ) o.hipInfluence = new THREE.Vector3( ...d.hipInfluence );
	if ( has( d, 'hipPosition' ) ) o.hipPosition = new THREE.Vector3( ...d.hipPosition );
	if ( has( d, 'preserveBoneMatrix' ) ) o.preserveBoneMatrix = !! d.preserveBoneMatrix;
	if ( has( d, 'preserveBonePositions' ) ) o.preserveBonePositions = !! d.preserveBonePositions;
	if ( has( d, 'useTargetMatrix' ) ) o.useTargetMatrix = !! d.useTargetMatrix;
	if ( has( d, 'useFirstFramePosition' ) ) o.useFirstFramePosition = !! d.useFirstFramePosition;
	if ( has( d, 'fps' ) ) o.fps = d.fps;
	if ( has( d, 'trim' ) ) o.trim = d.trim.slice();
	if ( has( d, 'localOffsets' ) ) {

		o.localOffsets = {};
		for ( const k of Object.keys( d.localOffsets ) ) o.localOffsets[ k ] = new THREE.Matrix4().fromArray( d.localOffsets[ k ] );

	}

	return o;

}

const sumOptions = ( o ) => ( { useTargetMatrix: o.useTargetMatrix === undefined ? false : o.useTargetMatrix, preserveBoneMatrix: o.preserveBoneMatrix === undefined ? true : o.preserveBoneMatrix, fps: o.fps } );

function buildClip( d ) {

	const tracks = d.tracks.map( ( t ) => {

		if ( t.type === 'quaternion' ) return new THREE.QuaternionKeyframeTrack( t.name, t.times, t.values );
		if ( t.type === 'vector' ) return new THREE.VectorKeyframeTrack( t.name, t.times, t.values );
		return new THREE.NumberKeyframeTrack( t.name, t.times, t.values );

	} );
	return new THREE.AnimationClip( d.name, d.duration, tracks );

}

const sumClip = ( clip ) => ( {
	name: clip.name, duration: clip.duration,
	tracks: clip.tracks.map( ( t ) => ( { name: t.name, type: t.ValueTypeName, times: t.times, values: t.values } ) )
} );

const refOf = ( c, key, mesh ) => ( has( c, key ) && c[ key ] === 'skeleton' ) ? mesh.skeleton : mesh;

export function runUp( c ) {

	const bufs = buildBuffers( c );
	switch ( c.op ) {

		case 'mergeGeometries': {

			const r = BufferGeometryUtils.mergeGeometries( c.geoms.map( ( d ) => buildGeometry( d, bufs ) ), !! c.useGroups );
			return r ? sumGeometry( r ) : null;

		}

		case 'mergeAttributes': {

			const r = BufferGeometryUtils.mergeAttributes( c.attrs.map( ( d ) => buildAttr( d, bufs ) ) );
			return r ? sumAttrAlone( r ) : null;

		}

		case 'interleaveAttributes': {

			const r = BufferGeometryUtils.interleaveAttributes( c.attrs.map( ( d ) => buildAttr( d, bufs ) ) );
			if ( ! r ) return null;
			const ctx = new Ctx();
			const attrs = r.map( ( a ) => sumAttr( ctx, a ) );
			return { attrs, buffers: ctx.out };

		}

		case 'deinterleaveAttribute':
			return sumAttrAlone( BufferGeometryUtils.deinterleaveAttribute( buildAttr( c.attr, bufs ) ) );
		case 'deinterleaveGeometry': {

			const g = buildGeometry( c.geom, bufs );
			BufferGeometryUtils.deinterleaveGeometry( g );
			return sumGeometry( g );

		}

		case 'deepCloneAttribute': {

			const a = buildAttr( c.attr, bufs );
			const r = BufferGeometryUtils.deepCloneAttribute( a );
			const s = sumAttrAlone( r );
			s.sameArray = r.array === a.array;
			return s;

		}

		case 'estimateBytesUsed':
			return BufferGeometryUtils.estimateBytesUsed( buildGeometry( c.geom, bufs ) );
		case 'mergeVertices': {

			const g = buildGeometry( c.geom, bufs );
			const r = has( c, 'tolerance' ) ? BufferGeometryUtils.mergeVertices( g, c.tolerance ) : BufferGeometryUtils.mergeVertices( g );
			const s = sumGeometry( r );
			s.input = sumGeometry( g );
			return s;

		}

		case 'toTrianglesDrawMode': {

			const g = buildGeometry( c.geom, bufs );
			const r = BufferGeometryUtils.toTrianglesDrawMode( g, c.drawMode | 0 );
			const s = sumGeometry( r );
			s.same = r === g;
			return s;

		}

		case 'computeMorphedAttributes': {

			const o = buildObject( c.object, bufs );
			const r = BufferGeometryUtils.computeMorphedAttributes( o );
			return {
				position: sumAttrAlone( r.positionAttribute ), normal: sumAttrAlone( r.normalAttribute ),
				morphedPosition: sumAttrAlone( r.morphedPositionAttribute ), morphedNormal: sumAttrAlone( r.morphedNormalAttribute ),
				samePosition: r.positionAttribute === o.geometry.attributes.position
			};

		}

		case 'computeMikkTSpaceTangents': {

			const g = buildGeometry( c.geom, bufs );
			const r = has( c, 'negateSign' ) ? BufferGeometryUtils.computeMikkTSpaceTangents( g, c.mikk, !! c.negateSign ) : BufferGeometryUtils.computeMikkTSpaceTangents( g, c.mikk );
			const s = sumGeometry( r );
			s.same = r === g;
			return s;

		}

		case 'toCreasedNormals': {

			const g = buildGeometry( c.geom, bufs );
			const r = has( c, 'creaseAngle' ) ? BufferGeometryUtils.toCreasedNormals( g, c.creaseAngle ) : BufferGeometryUtils.toCreasedNormals( g );
			const s = sumGeometry( r );
			s.same = r === g;
			return s;

		}

		case 'mergeGroups':
			return sumGeometry( BufferGeometryUtils.mergeGroups( buildGeometry( c.geom, bufs ) ) );
		case 'remapAttribute': {

			const buffers = new Map();
			const ctx = new Ctx();
			const attrs = c.attrs.map( ( d ) => {

				const a = buildAttr( d, bufs );
				const r = c.shared ? BufferGeometryUtils.remapAttribute( a, c.sourceIndices.map( ( x ) => x | 0 ), buffers ) : BufferGeometryUtils.remapAttribute( a, c.sourceIndices.map( ( x ) => x | 0 ) );
				return sumAttr( ctx, r );

			} );
			return { attrs, buffers: ctx.out };

		}

		case 'clone': {

			const { root, meshes } = buildRig( c.rig, bufs );
			const start = c.fromMesh ? meshes[ 0 ] : root;
			const sourceNodes = nodeList( start );
			const cl = SkeletonUtils.clone( start );
			return { clone: sumScene( cl, sourceNodes ), source: sumScene( start, sourceNodes ) };

		}

		case 'retarget': {

			const t = buildRig( c.target, bufs );
			const s = buildRig( c.source, bufs );
			const options = buildOptions( c.options );
			const target = refOf( c, 'targetAs', t.meshes[ 0 ] );
			const source = refOf( c, 'sourceAs', s.meshes[ 0 ] );
			if ( c.defaultOptions ) SkeletonUtils.retarget( target, source ); else SkeletonUtils.retarget( target, source, options );
			return { bones: sumBones( t.bones ), mesh: m4( t.meshes[ 0 ].matrixWorld ), options: sumOptions( options ) };

		}

		case 'retargetClip': {

			const t = buildRig( c.target, bufs );
			const s = buildRig( c.source, bufs );
			const options = buildOptions( c.options );
			const clip = buildClip( c.clip );
			const source = refOf( c, 'sourceAs', s.meshes[ 0 ] );
			const result = SkeletonUtils.retargetClip( t.meshes[ 0 ], source, clip, options );
			return { clip: sumClip( result ), bones: sumBones( t.bones ), options: sumOptions( options ) };

		}

	}

	throw new Error( 'unknown op ' + c.op );

}
