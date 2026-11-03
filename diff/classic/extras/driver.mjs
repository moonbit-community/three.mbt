// Differential check of src/extras against upstream three.js r187 under Node.
// node driver.mjs [seed] [scale]   exit 1 on any mismatch.
// The MoonBit side is the bridge package of this module (moon build --target js here);
// BRIDGE=<file:// URL of a bridge.js> runs another build (mutants.py uses it).
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
import { upstreamURL, upstreamPath } from '../../lib/env.mjs';
import { catmullRomInterp } from './interp_shim.mjs';
const THREE = await import( upstreamURL( 'src/Three.js' ) );
const { default: earcutLib, deviation, flatten } = await import( upstreamURL( 'src/extras/lib/earcut.js' ) );
const DataUtilsModule = await import( upstreamURL( 'src/extras/DataUtils.js' ) );
const bridgeDefault = new URL( './_build/js/debug/build/moonbit-community/three-diff-extras/bridge/bridge.js', import.meta.url );
if ( ! process.env.BRIDGE && ! fs.existsSync( bridgeDefault ) ) {
	console.log( 'missing _build/.../bridge.js; build first (moon build --target js)' );
	process.exit( 2 );
}
const M = await import( process.env.BRIDGE || bridgeDefault.href );

const { Vector2, Vector3 } = THREE;
const realLog = console.log;
console.warn = () => {};
console.error = () => {};
const say = ( ...a ) => realLog( ...a );
console.log = () => {};

const seed = Number( process.argv[ 2 ] || 1 ), scale = Number( process.argv[ 3 ] || 1 );
let s = seed >>> 0;
const rnd = () => { s |= 0; s = s + 0x6D2B79F5 | 0; let t = Math.imul( s ^ s >>> 15, 1 | s ); t = t + Math.imul( t ^ t >>> 7, 61 | t ) ^ t; return ( ( t ^ t >>> 14 ) >>> 0 ) / 4294967296; };
const ri = ( a, b ) => a + Math.floor( rnd() * ( b - a + 1 ) );
const pick = a => a[ ri( 0, a.length - 1 ) ];
const WILD = [ NaN, Infinity, - Infinity, - 0, 0, 1e308, - 1e308, 5e-324, 1e-300 ];
const num = wild => {
	if ( wild && rnd() < 0.12 ) return pick( WILD );
	const m = rnd();
	if ( m < 0.3 ) return ri( - 10, 10 );
	if ( m < 0.6 ) return ( rnd() - 0.5 ) * 20;
	if ( m < 0.9 ) return ( rnd() - 0.5 ) * 2000;
	return ( rnd() - 0.5 ) * 1e-3;
};
const vec = ( dim, wild ) => Array.from( { length: dim }, () => num( wild ) );

// comparison ---------------------------------------------------------------
function same( a, b ) {
	if ( typeof a === 'number' || typeof b === 'number' ) return Object.is( a, b );
	if ( a === b ) return true;
	if ( a === null || b === null || a === undefined || b === undefined ) return false;
	if ( Array.isArray( a ) !== Array.isArray( b ) ) return false;
	if ( Array.isArray( a ) ) { if ( a.length !== b.length ) return false; for ( let i = 0; i < a.length; i ++ ) if ( ! same( a[ i ], b[ i ] ) ) return false; return true; }
	if ( ArrayBuffer.isView( a ) ) { if ( a.constructor !== b.constructor || a.length !== b.length ) return false; for ( let i = 0; i < a.length; i ++ ) if ( ! Object.is( a[ i ], b[ i ] ) ) return false; return true; }
	if ( typeof a === 'object' ) { const ka = Object.keys( a ), kb = Object.keys( b ); if ( ka.length !== kb.length ) return false; for ( let i = 0; i < ka.length; i ++ ) { if ( ka[ i ] !== kb[ i ] ) return false; if ( ! same( a[ ka[ i ] ], b[ kb[ i ] ] ) ) return false; } return true; }
	return false;
}
const mask = v => {
	if ( Array.isArray( v ) ) return v.map( mask );
	if ( v && typeof v === 'object' && ! ArrayBuffer.isView( v ) ) { const o = {}; for ( const k of Object.keys( v ) ) o[ k ] = k === 'uuid' ? 'u' : mask( v[ k ] ); return o; }
	return v;
};
const hasNull = v => v === null || v === undefined ? true : Array.isArray( v ) ? v.some( hasNull ) : false;
const stat = {}; const fails = []; const skipped = {};
function tally( group, op, jr, mr, noteErr ) {
	const key = group + ' ' + op;
	const e = stat[ key ] || ( stat[ key ] = { n: 0, err: 0, bad: 0 } );
	e.n ++;
	if ( jr.err && mr.err ) e.err ++;
	const ok = ( !! jr.err === !! mr.err ) && ( jr.err || same( jr.v, mr.v ) );
	if ( ! ok ) { e.bad ++; if ( fails.length < 300 ) fails.push( { group, op, note: noteErr, js: jr, mbt: mr } ); }
}
const attempt = f => { try { return { v: f() }; } catch ( e ) { return { err: String( e && e.message || e ).slice( 0, 80 ) }; } };

// curves ---------------------------------------------------------------------
const V = ( dim, a ) => dim === 2 ? new Vector2( a[ 0 ], a[ 1 ] ) : new Vector3( a[ 0 ], a[ 1 ], a[ 2 ] );
function applyPathOps( p, spec ) {
	for ( const o of spec.ops ) {
		switch ( o[ 0 ] ) {
			case 'moveTo': p.moveTo( o[ 1 ], o[ 2 ] ); break;
			case 'lineTo': p.lineTo( o[ 1 ], o[ 2 ] ); break;
			case 'quad': p.quadraticCurveTo( o[ 1 ], o[ 2 ], o[ 3 ], o[ 4 ] ); break;
			case 'bez': p.bezierCurveTo( o[ 1 ], o[ 2 ], o[ 3 ], o[ 4 ], o[ 5 ], o[ 6 ] ); break;
			case 'spline': p.splineThru( o[ 1 ].map( a => V( 2, a ) ) ); break;
			case 'setFromPoints': p.setFromPoints( o[ 1 ].map( a => V( 2, a ) ) ); break;
			case 'closePath': p.closePath(); break;
			case 'arc': p.arc( ...o.slice( 1 ) ); break;
			case 'absarc': p.absarc( ...o.slice( 1 ) ); break;
			case 'ellipse': p.ellipse( ...o.slice( 1 ) ); break;
			case 'absellipse': p.absellipse( ...o.slice( 1 ) ); break;
		}
	}
	if ( spec.autoClose ) p.autoClose = true;
	return p;
}
function build( spec ) {
	const v = ( d ) => spec.v.map( a => V( d, a ) );
	switch ( spec.k ) {
		case 'Base': return new THREE.Curve();
		case 'Line': return new THREE.LineCurve( ...v( 2 ) );
		case 'LineD': return new THREE.LineCurve();
		case 'QB': return new THREE.QuadraticBezierCurve( ...v( 2 ) );
		case 'QBD': return new THREE.QuadraticBezierCurve();
		case 'CB': return new THREE.CubicBezierCurve( ...v( 2 ) );
		case 'CBD': return new THREE.CubicBezierCurve();
		case 'Ell': return new THREE.EllipseCurve( ...spec.args );
		case 'EllD': return new THREE.EllipseCurve();
		case 'Arc': return new THREE.ArcCurve( ...spec.args );
		case 'ArcD': return new THREE.ArcCurve();
		case 'Spline': return new THREE.SplineCurve( v( 2 ) );
		case 'SplineD': return new THREE.SplineCurve();
		case 'Line3': return new THREE.LineCurve3( ...v( 3 ) );
		case 'Line3D': return new THREE.LineCurve3();
		case 'QB3': return new THREE.QuadraticBezierCurve3( ...v( 3 ) );
		case 'QB3D': return new THREE.QuadraticBezierCurve3();
		case 'CB3': return new THREE.CubicBezierCurve3( ...v( 3 ) );
		case 'CB3D': return new THREE.CubicBezierCurve3();
		case 'Cat': return new THREE.CatmullRomCurve3( v( 3 ), spec.closed, spec.curveType, spec.tension );
		case 'CatD': return new THREE.CatmullRomCurve3();
		case 'CP': { const c = new THREE.CurvePath(); for ( const x of spec.curves ) c.add( build( x ) ); if ( spec.autoClose ) c.autoClose = true; if ( spec.close ) c.closePath(); return c; }
		case 'Path': return applyPathOps( new THREE.Path( spec.points ? spec.points.map( a => V( 2, a ) ) : undefined ), spec );
		case 'Shape': { const p = applyPathOps( new THREE.Shape( spec.points ? spec.points.map( a => V( 2, a ) ) : undefined ), spec ); for ( const h of spec.holes ) p.holes.push( build( h ) ); return p; }
	}
	throw new Error( 'spec ' + spec.k );
}
const fresh = spec => {
	const k = spec.k.replace( /D$/, '' );
	return { Base: () => new THREE.Curve(), Line: () => new THREE.LineCurve(), QB: () => new THREE.QuadraticBezierCurve(), CB: () => new THREE.CubicBezierCurve(), Ell: () => new THREE.EllipseCurve(), Arc: () => new THREE.ArcCurve(), Spline: () => new THREE.SplineCurve(), Line3: () => new THREE.LineCurve3(), QB3: () => new THREE.QuadraticBezierCurve3(), CB3: () => new THREE.CubicBezierCurve3(), Cat: () => new THREE.CatmullRomCurve3(), CP: () => new THREE.CurvePath(), Path: () => new THREE.Path(), Shape: () => new THREE.Shape() }[ k ]();
};
const arrOf = p => p.toArray();
const ptsOf = a => a.map( x => ( x === null || x === undefined ) ? null : x.toArray() );
// toJSON() output as JSON.stringify writes it (NaN and the infinities as null, -0 as 0),
// on both sides: the port's to_json() holds null for non-finite numbers already, since
// MoonBit's Json::stringify would print them bare. Applied to the toJSON parts only.
const asText = v => v === undefined ? v : JSON.parse( JSON.stringify( v ) );
const JSON_PARTS = { toJSON: 'all', fromUpstreamJSON: 'all', selfRoundtrip: [ 0 ], clone: [ 0 ], copy: [ 0 ], cloneIndependent: [ 0, 1 ] };
const textJSON = ( op, r ) => {
	const w = JSON_PARTS[ op ];
	if ( ! w || r.err || r.v === undefined || r.v === null ) return r;
	if ( w === 'all' ) return { v: asText( r.v ) };
	const v = r.v.slice(); for ( const i of w ) v[ i ] = asText( v[ i ] ); return { v };
};
const shapesText = r => r.err || ! Array.isArray( r.v ) ? r : { v: r.v.map( e => Array.isArray( e ) ? [ ...e.slice( 0, - 1 ), asText( e[ e.length - 1 ] ) ] : e ) };
const junk = dim => dim === 2 ? new Vector2( 7, 8 ) : new Vector3( 7, 8, 9 );
function opJS( c, o, spec, dim ) {
	const n = o[ 1 ] === null ? undefined : o[ 1 ];
	switch ( o[ 0 ] ) {
		case 'getPoint': { const r = c.getPoint( o[ 1 ] ); return r ? arrOf( r ) : null; }
		case 'getPointT': { const t = junk( dim ); const r = c.getPoint( o[ 1 ], t ); return r ? [ r === t, arrOf( r ) ] : null; }
		case 'getPointAt': { const r = c.getPointAt( o[ 1 ] ); return r ? arrOf( r ) : null; }
		case 'getPointAtT': { const t = junk( dim ); const r = c.getPointAt( o[ 1 ], t ); return r ? [ r === t, arrOf( r ) ] : null; }
		case 'getPoints': return ptsOf( c.getPoints( n ) );
		case 'getSpacedPoints': return ptsOf( c.getSpacedPoints( n ) );
		case 'getLength': return c.getLength();
		case 'getLengths': return c.getLengths( n ).slice();
		case 'lengthsCached': { const a = c.getLengths(); return a === c.getLengths(); }
		case 'uToT': return c.getUtoTmapping( o[ 1 ], o[ 2 ] );
		case 'tangent': return arrOf( c.getTangent( o[ 1 ] ) );
		case 'tangentT': { const t = junk( dim ); const r = c.getTangent( o[ 1 ], t ); return [ r === t, arrOf( r ) ]; }
		case 'tangentAt': return arrOf( c.getTangentAt( o[ 1 ] ) );
		case 'tangentAtT': { const t = junk( dim ); const r = c.getTangentAt( o[ 1 ], t ); return [ r === t, arrOf( r ) ]; }
		case 'frenet': { const f = c.computeFrenetFrames( o[ 1 ], o[ 2 ] ); return [ ptsOf( f.tangents ), ptsOf( f.normals ), ptsOf( f.binormals ) ]; }
		case 'updateArc': c.updateArcLengths(); return null;
		case 'setDiv': c.arcLengthDivisions = o[ 1 ]; return null;
		case 'setNeedsUpdate': c.needsUpdate = true; return null;
		case 'curveLengths': return c.getCurveLengths().slice();
		case 'toJSON': return c.toJSON();
		case 'fromUpstreamJSON': return fresh( spec ).fromJSON( o[ 1 ] ).toJSON();
		case 'selfRoundtrip': { const r = fresh( spec ).fromJSON( asText( c.toJSON() ) ); return [ r.toJSON(), ptsOf( r.getPoints() ) ]; } // the port's to_json() is the JSON text's value (see asText)
		case 'clone': { const r = c.clone(); return [ r.toJSON(), ptsOf( r.getPoints() ), r.arcLengthDivisions, r.type ]; }
		case 'copy': { const r = fresh( spec ).copy( c ); return [ r.toJSON(), ptsOf( r.getPoints() ) ]; }
		case 'cloneIndependent': {
			const r = c.clone(), before = c.toJSON();
			if ( r.isLineCurve || r.isLineCurve3 ) r.v1.setScalar( 99 );
			else if ( r.isQuadraticBezierCurve || r.isQuadraticBezierCurve3 ) r.v0.setScalar( 99 );
			else if ( r.isCubicBezierCurve || r.isCubicBezierCurve3 ) r.v3.setScalar( 99 );
			else if ( r.isSplineCurve ) { if ( r.points.length ) r.points[ 0 ].setScalar( 99 ); }
			else if ( r.isCatmullRomCurve3 ) { if ( r.points.length ) r.points[ 0 ].x = 99; }
			else if ( r.curves ) r.curves.length = 0;
			return [ before, c.toJSON() ];
		}
		case 'aliasAutoClose': { const p = c.getPoints(); return p.length > 1 && p[ p.length - 1 ] === p[ 0 ]; }
		case 'closePath': c.closePath(); return c.curves.length;
		case 'mutate': {
			if ( c.isLineCurve || c.isLineCurve3 ) c.v2.addScalar( 1 );
			else if ( c.isQuadraticBezierCurve || c.isQuadraticBezierCurve3 ) c.v2.addScalar( 1 );
			else if ( c.isCubicBezierCurve || c.isCubicBezierCurve3 ) c.v3.addScalar( 1 );
			else if ( c.isEllipseCurve ) c.xRadius += 1;
			else if ( c.isSplineCurve ) { if ( c.points.length ) c.points[ 0 ].addScalar( 1 ); }
			else if ( c.isCatmullRomCurve3 ) { if ( c.points.length ) c.points[ 0 ].x += 1; }
			return null;
		}
	}
	throw new Error( 'op ' + o[ 0 ] );
}
const TS = [ 0, 1, 0.5, 0.25, 0.75, - 0, 1e-9, 1 - 1e-9, 0.1, 0.3, 1 / 3 ];
const WT = [ - 0.1, 1.1, NaN, Infinity, - Infinity, 2, - 1, 1e300 ];
const param = wild => ( wild && rnd() < 0.3 ) ? pick( WT ) : rnd() < 0.5 ? pick( TS ) : rnd();
const div = wild => wild && rnd() < 0.3 ? pick( [ 0, - 1 ] ) : rnd() < 0.3 ? null : pick( [ 1, 2, 3, 5, 7, 12, 40 ] );
function ops( wild, comp ) {
	const out = [];
	const count = ri( 14, 30 );
	const add = () => {
		switch ( ri( 0, 21 ) ) {
			case 0: return [ 'getPoint', param( wild ) ];
			case 1: return [ 'getPointT', param( wild ) ];
			case 2: return [ 'getPointAt', param( wild ) ];
			case 3: return [ 'getPointAtT', param( wild ) ];
			case 4: return [ 'getPoints', div( wild ) ];
			case 5: return [ 'getSpacedPoints', div( wild ) ];
			case 6: return [ 'getLength' ];
			case 7: return [ 'getLengths', div( wild ) ];
			case 8: return [ 'uToT', param( wild ), pick( [ null, null, 0, NaN, 1, 3.5, - 1, 1e9 ] ) ];
			case 9: return [ 'tangent', param( wild ) ];
			case 10: return [ 'tangentT', param( wild ) ];
			case 11: return [ 'tangentAt', param( wild ) ];
			case 12: return [ 'tangentAtT', param( wild ) ];
			case 13: return [ 'frenet', pick( wild ? [ 0, 1, 2, - 1, 8 ] : [ 1, 2, 3, 8, 20 ] ), rnd() < 0.5 ];
			case 14: return [ 'updateArc' ];
			case 15: return [ 'setDiv', pick( wild ? [ 0, - 1, 1, 2, 10, 50 ] : [ 2, 10, 50, 200 ] ) ];
			case 16: return [ 'setNeedsUpdate' ];
			case 17: return [ 'lengthsCached' ];
			case 18: return [ 'mutate' ];
			case 19: return [ 'aliasAutoClose' ];
			case 20: return comp ? [ 'curveLengths' ] : [ 'getLength' ];
			case 21: return comp && rnd() < 0.2 ? [ 'closePath' ] : [ 'getPoint', param( wild ) ];
		}
	};
	for ( let i = 0; i < count; i ++ ) out.push( add() );
	// serialization and cloning always run, in a random place
	for ( const o of [ [ 'toJSON' ], [ 'selfRoundtrip' ], [ 'clone' ], [ 'copy' ], [ 'cloneIndependent' ], [ 'getPoints', null ], [ 'getSpacedPoints', null ], [ 'frenet', 6, false ], [ 'frenet', 6, true ] ] ) out.splice( ri( 0, out.length ), 0, o );
	return out;
}
const angle = wild => pick( [ 0, Math.PI, Math.PI * 2, - Math.PI, Math.PI / 2, 4 * Math.PI, - Math.PI * 2, rnd() * 7, - rnd() * 7, rnd() * 1000, ...( wild ? [ NaN, - 0 ] : [] ) ] );
const pts = ( dim, n, wild, dup ) => { const a = []; for ( let i = 0; i < n; i ++ ) a.push( dup && i && rnd() < 0.4 ? a[ i - 1 ].slice() : vec( dim, wild ) ); return a; };
function curve2( wild, depth = 0 ) {
	const r = ri( 0, depth > 1 ? 5 : 8 );
	switch ( r ) {
		case 0: return { k: 'Line', v: pts( 2, 2, wild, true ) };
		case 1: return { k: 'QB', v: pts( 2, 3, wild, true ) };
		case 2: return { k: 'CB', v: pts( 2, 4, wild, true ) };
		case 3: return { k: 'Ell', args: [ num( wild ), num( wild ), num( wild ), num( wild ), angle( wild ), angle( wild ), rnd() < 0.5, pick( [ 0, 0, rnd(), - rnd() * 3, ...( wild ? [ NaN ] : [] ) ] ) ] };
		case 4: return { k: 'Arc', args: [ num( wild ), num( wild ), num( wild ), angle( wild ), angle( wild ), rnd() < 0.5 ] };
		case 5: return { k: 'Spline', v: pts( 2, pick( wild ? [ 0, 1, 2, 3, 4, 7 ] : [ 2, 3, 4, 5, 9 ] ), wild, true ) };
		case 6: return { k: 'CP', curves: Array.from( { length: ri( 0, 4 ) }, () => curve2( wild, depth + 1 ) ), autoClose: rnd() < 0.3, close: rnd() < 0.2 };
		case 7: return path( 'Path', wild );
		case 8: return path( 'Shape', wild );
	}
}
function path( k, wild ) {
	const ops = []; const n = ri( 0, 7 );
	const P = () => vec( 2, wild );
	if ( rnd() < 0.7 ) ops.push( [ 'moveTo', ...P() ] );
	for ( let i = 0; i < n; i ++ ) {
		switch ( ri( 0, 10 ) ) {
			case 0: case 1: case 2: ops.push( [ 'lineTo', ...P() ] ); break;
			case 3: ops.push( [ 'quad', ...P(), ...P() ] ); break;
			case 4: ops.push( [ 'bez', ...P(), ...P(), ...P() ] ); break;
			case 5: ops.push( [ 'spline', pts( 2, ri( wild ? 0 : 1, 4 ), wild, true ) ] ); break;
			case 6: ops.push( [ 'arc', ...P(), num( wild ), angle( wild ), angle( wild ), rnd() < 0.5 ] ); break;
			case 7: ops.push( [ 'absarc', ...P(), num( wild ), angle( wild ), angle( wild ), rnd() < 0.5 ] ); break;
			case 8: ops.push( [ 'ellipse', ...P(), num( wild ), num( wild ), angle( wild ), angle( wild ), rnd() < 0.5, pick( [ 0, rnd() ] ) ] ); break;
			case 9: ops.push( [ 'absellipse', ...P(), num( wild ), num( wild ), angle( wild ), angle( wild ), rnd() < 0.5, pick( [ 0, rnd() ] ) ] ); break;
			case 10: if ( rnd() < 0.3 ) ops.push( [ 'closePath' ] ); else if ( rnd() < 0.3 ) ops.push( [ 'setFromPoints', pts( 2, ri( wild ? 0 : 1, 5 ), wild, true ) ] ); break;
		}
	}
	const spec = { k, ops, autoClose: rnd() < 0.3, points: rnd() < 0.3 ? pts( 2, ri( 1, 5 ), wild, true ) : null };
	if ( k === 'Shape' ) spec.holes = Array.from( { length: ri( 0, 2 ) }, () => path( 'Path', wild ) );
	return spec;
}
function curve3( wild, depth = 0 ) {
	switch ( ri( 0, depth > 1 ? 3 : 4 ) ) {
		case 0: return { k: 'Line3', v: pts( 3, 2, wild, true ) };
		case 1: return { k: 'QB3', v: pts( 3, 3, wild, true ) };
		case 2: return { k: 'CB3', v: pts( 3, 4, wild, true ) };
		case 3: return { k: 'Cat', v: pts( 3, pick( wild ? [ 0, 1, 2, 3, 4, 8 ] : [ 2, 3, 4, 5, 8 ] ), wild, true ), closed: rnd() < 0.4, curveType: pick( wild ? [ 'centripetal', 'chordal', 'catmullrom', 'bogus' ] : [ 'centripetal', 'chordal', 'catmullrom' ] ), tension: pick( [ 0.5, rnd(), 0, 1 ] ) };
		case 4: return { k: 'CP', curves: Array.from( { length: ri( 0, 4 ) }, () => curve3( wild, depth + 1 ) ), autoClose: rnd() < 0.3, close: rnd() < 0.2 };
	}
}
function runCurve( spec, dim, group ) {
	const jb = attempt( () => build( spec ) );
	const mb = attempt( () => dim === 2 ? M.build2( spec ) : M.build3( spec ) );
	tally( group, 'build:' + spec.k, jb.err ? jb : { v: 1 }, mb.err ? mb : { v: 1 }, spec );
	if ( jb.err || mb.err ) return;
	const c = jb.v, m = mb.v;
	const list = ops( group.includes( 'wild' ), [ 'CP', 'Path', 'Shape' ].includes( spec.k ) );
	const apply = dim === 2 ? M.apply2 : M.apply3;
	for ( const o of list ) {
		let jr = attempt( () => opJS( c, o, spec, dim ) );
		if ( ! jr.err && ( o[ 0 ] === 'getLength' ) && jr.v === undefined ) jr = { v: NaN };
		// known deviation: upstream puts null/undefined from getPoint in a list where the port aborts
		if ( ! jr.err && [ 'getPoints', 'getSpacedPoints' ].includes( o[ 0 ] ) && hasNull( jr.v ) ) { skipped[ spec.k + ' ' + o[ 0 ] + ' null in list' ] = ( skipped[ spec.k + ' ' + o[ 0 ] + ' null in list' ] || 0 ) + 1; attempt( () => apply( m, o, spec ) ); continue; }
		if ( spec.k === 'Base' && [ 'selfRoundtrip', 'clone', 'copy', 'aliasAutoClose' ].includes( o[ 0 ] ) ) { skipped[ 'Base ' + o[ 0 ] + ' list of undefined' ] = ( skipped[ 'Base ' + o[ 0 ] + ' list of undefined' ] || 0 ) + 1; continue; }
		let mr = attempt( () => apply( m, o, spec ) );
		if ( ! mr.err && o[ 0 ] === 'getLength' && mr.v === undefined ) mr = { v: NaN };
		jr = textJSON( o[ 0 ], jr ); mr = textJSON( o[ 0 ], mr );
		// After the text round trip upstream's fields hold null where the text has null, and a
		// point copied from such a field (LineCurve at t = 1) is null itself; the port's Double
		// holds 0, what null is in arithmetic. Counted, not hidden.
		if ( o[ 0 ] === 'selfRoundtrip' && ! jr.err && Array.isArray( jr.v ) && hasNull( jr.v[ 1 ] ) && ! mr.err ) {
			let n = 0;
			const zero = v => Array.isArray( v ) ? v.map( zero ) : v === null ? ( n ++, 0 ) : v;
			const pts = zero( jr.v[ 1 ] );
			if ( n ) { jr = { v: [ jr.v[ 0 ], pts ] }; const k = spec.k + ' selfRoundtrip text null copied into a point (port: 0)'; skipped[ k ] = ( skipped[ k ] || 0 ) + 1; }
		}
		// getPoints skips a point equal to the previous one; upstream's null is not === 0, so a
		// point next to one with a null field is kept where the port's 0 drops it. The JSON
		// part is still compared; the points are counted, not compared.
		if ( o[ 0 ] === 'selfRoundtrip' && ! jr.err && ! mr.err && JSON.stringify( jr.v[ 0 ] ).includes( 'null' ) &&
			same( mask( jr.v[ 0 ] ), mask( mr.v[ 0 ] ) ) && ! same( jr.v[ 1 ], mr.v[ 1 ] ) && jr.v[ 1 ].length !== mr.v[ 1 ].length ) {
			const k = spec.k + ' selfRoundtrip text null !== 0 in getPoints dedupe'; skipped[ k ] = ( skipped[ k ] || 0 ) + 1; continue;
		}
		if ( ! jr.err && jr.v !== undefined ) jr.v = mask( jr.v );
		if ( ! mr.err ) mr.v = mask( mr.v );
		tally( group, spec.k + ' ' + o[ 0 ], jr, mr, { spec, o } );
		if ( o[ 0 ] === 'toJSON' && ! jr.err ) {
			const up = c.toJSON();
			tally( group, spec.k + ' fromJSON(upstream)', attempt( () => mask( asText( opJS( c, [ 'fromUpstreamJSON', up ], spec, dim ) ) ) ), attempt( () => mask( asText( apply( m, [ 'fromUpstreamJSON', up ], spec ) ) ) ), { spec } );
			const text = JSON.stringify( up );
			if ( ! text.includes( 'null' ) ) {
				const f = dim === 2 ? M.text_roundtrip2 : M.text_roundtrip3;
				tally( group, spec.k + ' fromJSON(text)', attempt( () => mask( fresh( spec ).fromJSON( JSON.parse( text ) ).toJSON() ) ), attempt( () => mask( f( m, text, spec ) ) ), { spec } );
			}
		}
	}
}
const n = Math.round( 400 * scale );
for ( const k of [ 'LineD', 'QBD', 'CBD', 'EllD', 'ArcD', 'SplineD' ] ) runCurve( { k, v: [] }, 2, 'defaults' );
for ( const k of [ 'Line3D', 'QB3D', 'CB3D', 'CatD' ] ) runCurve( { k, v: [] }, 3, 'defaults' );
for ( let i = 0; i < 20; i ++ ) { runCurve( { k: 'Base' }, 2, 'defaults' ); runCurve( { k: 'Base' }, 3, 'defaults' ); }
for ( let i = 0; i < n; i ++ ) { runCurve( curve2( false ), 2, 'curve2' ); runCurve( curve3( false ), 3, 'curve3' ); }
for ( let i = 0; i < n; i ++ ) { runCurve( curve2( true ), 2, 'curve2-wild' ); runCurve( curve3( true ), 3, 'curve3-wild' ); }

// earcut --------------------------------------------------------------------
const ringStar = ( cx, cy, r, n, jag, cw, snap ) => { const a = []; for ( let i = 0; i < n; i ++ ) { const t = ( cw ? - 1 : 1 ) * i / n * Math.PI * 2, R = r * ( 1 - jag * rnd() ); let x = cx + R * Math.cos( t ), y = cy + R * Math.sin( t ); if ( snap ) { x = Math.round( x ); y = Math.round( y ); } a.push( [ x, y ] ); } return a; };
function ecCase( data, holes, dim, group ) {
	const j = attempt( () => earcutLib( data, holes.length ? holes : undefined, dim ) );
	const m = attempt( () => Array.from( M.earcut( data, holes, dim ) ) );
	const j2 = attempt( () => THREE.ShapeUtils && earcutLib( data, holes, dim ) );
	tally( group, 'triangulate', j, m, { data, holes, dim } );
	tally( group, 'triangulate([] holes)', j2, m, { data, holes, dim } );
	if ( ! j.err && ! m.err ) tally( group, 'deviation', attempt( () => deviation( data, holes, dim, j.v ) ), attempt( () => M.earcut_dev( data, holes, dim, j.v ) ), { data, holes, dim } );
}
function rings( rs, dim ) { const data = [], holes = []; rs.forEach( ( r, i ) => { if ( i ) holes.push( data.length / dim ); for ( const p of r ) { data.push( p[ 0 ], p[ 1 ] ); for ( let d = 2; d < dim; d ++ ) data.push( rnd() ); } } ); return { data, holes }; }
const ecN = Math.round( 1500 * scale );
for ( let i = 0; i < ecN; i ++ ) {
	const dim = rnd() < 0.15 ? 3 : 2, snap = rnd() < 0.5;
	const nv = pick( [ 3, 4, 5, 8, 16, 40, 90, 150, 400 ] );
	const outer = ringStar( 0, 0, 100, nv, pick( [ 0, 0.1, 0.5, 0.9 ] ), false, snap );
	const hs = []; const h = ri( 0, 6 );
	for ( let k = 0; k < h; k ++ ) { const a = rnd() * 7, R = rnd() * 60; hs.push( ringStar( R * Math.cos( a ), R * Math.sin( a ), 3 + rnd() * 15, pick( [ 1, 2, 3, 4, 6, 12 ] ), pick( [ 0, 0.3 ] ), rnd() < 0.8, snap ) ); }
	const { data, holes } = rings( [ outer, ...hs ], dim );
	ecCase( data, holes, dim, 'earcut-holes' );
}
for ( let i = 0; i < ecN; i ++ ) { // self-intersecting, duplicate and collinear rings on a small grid
	const g = pick( [ 2, 3, 5, 10 ] ), nv = pick( [ 3, 4, 5, 6, 8, 12, 20, 50, 100 ] );
	const r = () => Array.from( { length: ri( 1, nv ) }, () => [ ri( 0, g ), ri( 0, g ) ] );
	const rs = [ Array.from( { length: nv }, () => [ ri( 0, g ), ri( 0, g ) ] ) ];
	for ( let k = ri( 0, 3 ); k > 0; k -- ) rs.push( r() );
	const { data, holes } = rings( rs, 2 );
	ecCase( data, holes, 2, 'earcut-degenerate' );
}
for ( let i = 0; i < ecN; i ++ ) { // sharing vertices, so compareXYSlope and the bridge rules decide
	const rs = [ [ [ 0, 0 ], [ 10, 0 ], [ 10, 10 ], [ 0, 10 ] ] ];
	const v = [ ri( 1, 9 ), ri( 1, 9 ) ];
	for ( let k = ri( 1, 5 ); k > 0; k -- ) { rs.push( [ v.slice(), [ v[ 0 ] + ri( 0, 3 ), v[ 1 ] + ri( - 3, 3 ) ], [ v[ 0 ] + ri( 0, 3 ), v[ 1 ] + ri( - 3, 3 ) ] ] ); }
	const { data, holes } = rings( rs, 2 );
	ecCase( data, holes, 2, 'earcut-touching' );
}
for ( let i = 0; i < ecN; i ++ ) { // NaN, Infinity, hole indices past the end, odd data
	const nv = pick( [ 0, 1, 2, 3, 4, 7, 12, 45, 90 ] );
	const data = Array.from( { length: nv * 2 + ( rnd() < 0.2 ? 1 : 0 ) }, () => rnd() < 0.2 ? pick( [ NaN, Infinity, - Infinity, - 0, 1e308, 5e-324 ] ) : ri( - 5, 5 ) + ( rnd() < 0.5 ? rnd() : 0 ) );
	const holes = rnd() < 0.5 ? [] : Array.from( { length: ri( 1, 3 ) }, () => ri( 0, nv + 2 ) ).sort( ( a, b ) => a - b );
	ecCase( data, holes, pick( [ 2, 2, 3 ] ), 'earcut-wild' );
}
tally( 'earcut-wild', 'empty', attempt( () => earcutLib( [] ) ), attempt( () => Array.from( M.earcut( [], [], 2 ) ) ) );
for ( let i = 0; i < 200 * scale; i ++ ) {
	const d = ri( 2, 3 ); const data = Array.from( { length: ri( 1, 4 ) }, () => pts( d, ri( 1, 5 ), false, false ) );
	tally( 'earcut-flatten', 'flatten', attempt( () => { const r = flatten( data ); return [ r.vertices, r.holes, r.dimensions ]; } ), attempt( () => M.earcut_flat( data ) ), { data } );
}

// ShapeUtils ----------------------------------------------------------------
const mkV = a => a.map( p => new Vector2( p[ 0 ], p[ 1 ] ) );
for ( let i = 0; i < 1500 * scale; i ++ ) {
	const wild = i % 3 === 0;
	const c = pts( 2, pick( [ 0, 1, 2, 3, 4, 8, 30, 100 ] ), wild, true );
	if ( c.length > 2 && rnd() < 0.5 ) c.push( c[ 0 ].slice() );
	const hs = Array.from( { length: ri( 0, 3 ) }, () => { const h = pts( 2, ri( 1, 8 ), wild, true ); if ( h.length > 2 && rnd() < 0.5 ) h.push( h[ 0 ].slice() ); return h; } );
	tally( 'ShapeUtils', 'area', attempt( () => THREE.ShapeUtils.area( mkV( c ) ) ), attempt( () => M.shape_area( c ) ), { c } );
	tally( 'ShapeUtils', 'isClockWise', attempt( () => THREE.ShapeUtils.isClockWise( mkV( c ) ) ), attempt( () => M.shape_cw( c ) ), { c } );
	tally( 'ShapeUtils', 'triangulateShape', attempt( () => { const a = mkV( c ), b = hs.map( mkV ); const f = THREE.ShapeUtils.triangulateShape( a, b ); return [ f, ptsOf( a ), b.map( ptsOf ) ]; } ), attempt( () => M.shape_tri( c, hs ) ), { c, hs } );
}

// ShapePath ------------------------------------------------------------------
function spJS( spec ) {
	const sp = new THREE.ShapePath(); sp.userData = spec.userData;
	for ( const o of spec.ops ) {
		switch ( o[ 0 ] ) {
			case 'moveTo': sp.moveTo( o[ 1 ], o[ 2 ] ); break;
			case 'lineTo': sp.lineTo( o[ 1 ], o[ 2 ] ); break;
			case 'quad': sp.quadraticCurveTo( o[ 1 ], o[ 2 ], o[ 3 ], o[ 4 ] ); break;
			case 'bez': sp.bezierCurveTo( ...o.slice( 1 ) ); break;
			case 'spline': sp.splineThru( o[ 1 ].map( a => V( 2, a ) ) ); break;
		}
	}
	return sp.toShapes().map( s => { const e = s.extractPoints( 12 ); return [ ptsOf( e.shape ), e.holes.map( ptsOf ), s.curves.map( c => c.type ), s.holes.map( h => h.curves.map( c => c.type ) ), s.uuid !== '', mask( s.toJSON() ) ]; } );
}
const STYLES = [ {}, { style: {} }, { style: { fillRule: 'nonzero' } }, { style: { fillRule: 'evenodd' } }, { style: { fillRule: 'bogus' } }, { style: { fillRule: '' } }, { style: null } ];
const sq = ( ops, x, y, w, h, cw ) => { const c = [ [ x, y ], [ x + w, y ], [ x + w, y + h ], [ x, y + h ] ]; if ( cw ) c.reverse(); ops.push( [ 'moveTo', ...c[ 0 ] ] ); for ( const p of c.slice( 1 ) ) ops.push( [ 'lineTo', ...p ] ); ops.push( [ 'lineTo', ...c[ 0 ] ] ); };
for ( let i = 0; i < 2000 * scale; i ++ ) {
	const ops = []; const n = ri( 0, 7 ); const wild = i % 4 === 0;
	for ( let k = 0; k < n; k ++ ) {
		const m = ri( 0, 5 );
		if ( m < 3 ) sq( ops, ri( 0, 10 ), ri( 0, 10 ), ri( 0, 12 ), ri( 0, 12 ), rnd() < 0.5 );
		else if ( m === 3 ) { ops.push( [ 'moveTo', ...vec( 2, wild ) ], [ 'quad', ...vec( 2, wild ), ...vec( 2, wild ) ], [ 'lineTo', ...vec( 2, wild ) ] ); }
		else if ( m === 4 ) { ops.push( [ 'moveTo', ...vec( 2, wild ) ], [ 'bez', ...vec( 2, wild ), ...vec( 2, wild ), ...vec( 2, wild ) ], [ 'lineTo', ...vec( 2, wild ) ] ); }
		else { ops.push( [ 'moveTo', ...vec( 2, wild ) ], [ 'spline', pts( 2, ri( 1, 5 ), wild, true ) ] ); } // eslint-disable-line
	}
	const spec = { ops, userData: pick( STYLES ) };
	tally( 'ShapePath', 'toShapes', shapesText( attempt( () => spJS( spec ) ) ), shapesText( attempt( () => M.to_shapes( spec ) ) ), spec );
}
for ( let i = 0; i < 1500 * scale; i ++ ) { // concentric and side-by-side nesting with random windings
	const ops = []; const depth = ri( 1, 6 ); let x = 0, w = 64;
	for ( let k = 0; k < depth; k ++ ) { sq( ops, x, x, w, w, rnd() < 0.5 ); if ( rnd() < 0.3 ) sq( ops, x + w * 0.55, x + w * 0.55, w * 0.3, w * 0.3, rnd() < 0.5 ); x += w * 0.1; w *= pick( [ 0.4, 0.5, 0.8 ] ); }
	const spec = { ops, userData: pick( STYLES ) };
	tally( 'ShapePath', 'toShapes nested', shapesText( attempt( () => spJS( spec ) ) ), shapesText( attempt( () => M.to_shapes( spec ) ) ), spec );
}
{ const spec = { ops: [ [ 'lineTo', 1, 1 ] ], userData: {} }; tally( 'ShapePath', 'no moveTo', shapesText( attempt( () => spJS( spec ) ) ), shapesText( attempt( () => M.to_shapes( spec ) ) ), spec ); }

// real glyph outlines, through both ShapePath and triangulation --------------
const fontDir = upstreamPath( 'examples/fonts' ) + '/';
for ( const file of fs.readdirSync( fontDir ).filter( f => f.endsWith( '.typeface.json' ) ) ) {
	const font = JSON.parse( fs.readFileSync( fontDir + file ) );
	for ( const [ ch, g ] of Object.entries( font.glyphs ) ) {
		if ( ! g.o ) continue;
		const t = g.o.split( ' ' ), ops = [];
		for ( let i = 0; i < t.length; ) {
			const a = t[ i ++ ];
			if ( a === 'm' ) ops.push( [ 'moveTo', Number( t[ i ++ ] ), Number( t[ i ++ ] ) ] );
			else if ( a === 'l' ) ops.push( [ 'lineTo', Number( t[ i ++ ] ), Number( t[ i ++ ] ) ] );
			else if ( a === 'q' ) { const x = Number( t[ i ++ ] ), y = Number( t[ i ++ ] ), x1 = Number( t[ i ++ ] ), y1 = Number( t[ i ++ ] ); ops.push( [ 'quad', x1, y1, x, y ] ); }
			else if ( a === 'b' ) { const x = Number( t[ i ++ ] ), y = Number( t[ i ++ ] ), x1 = Number( t[ i ++ ] ), y1 = Number( t[ i ++ ] ), x2 = Number( t[ i ++ ] ), y2 = Number( t[ i ++ ] ); ops.push( [ 'bez', x1, y1, x2, y2, x, y ] ); }
		}
		for ( const userData of [ {}, { style: { fillRule: 'evenodd' } } ] ) {
			const spec = { ops, userData };
			const jr = attempt( () => spJS( spec ) );
			tally( 'fonts', 'toShapes', jr, attempt( () => M.to_shapes( spec ) ), { file, ch } );
			if ( ! jr.err && userData.style === undefined ) for ( const [ shape, holes ] of jr.v ) {
				tally( 'fonts', 'triangulateShape', attempt( () => { const a = mkV( shape ), b = holes.map( mkV ); return [ THREE.ShapeUtils.triangulateShape( a, b ), ptsOf( a ), b.map( ptsOf ) ]; } ), attempt( () => M.shape_tri( shape, holes ) ), { file, ch } );
			}
		}
	}
}

// utilities ------------------------------------------------------------------
const names = Object.keys( THREE ).filter( k => typeof THREE[ k ] === 'number' && /(Format|Type)$/.test( k ) );
const formats = names.filter( k => /Format$/.test( k ) ).map( k => THREE[ k ] ), types = names.filter( k => /Type$/.test( k ) ).map( k => THREE[ k ] );
for ( const f of formats ) for ( const t of types ) for ( const [ w, h ] of [ [ 1, 1 ], [ 3, 5 ], [ 16, 8 ], [ 33, 17 ], [ 256, 128 ], [ 1024, 1024 ], [ 0, 0 ], [ 65536, 65536 ] ] ) tally( 'TextureUtils', 'getByteLength', attempt( () => THREE.TextureUtils.getByteLength( w, h, f, t ) ), attempt( () => M.byte_length( w, h, f, t ) ), { w, h, f, t } );
for ( let i = 0; i < 2000 * scale; i ++ ) {
	const mode = ri( 0, 2 ), kind = ri( 0, 2 ), w = pick( [ 0, 1, 2, 16, 640, ri( 1, 2000 ) ] ), h = pick( [ 0, 1, 9, 480, ri( 1, 2000 ) ] ), aspect = pick( [ 1, 2, 0.5, rnd() * 4, 0, NaN ] );
	const jr = attempt( () => { const t = new THREE.Texture(); if ( kind ) t.image = kind === 1 ? { width: w, height: h } : { data: null, width: w, height: h }; t.repeat.x = 5; t.offset.y = 5; ( mode === 0 ? THREE.TextureUtils.contain : mode === 1 ? THREE.TextureUtils.cover : THREE.TextureUtils.fill )( t, aspect ); return [ t.repeat.x, t.repeat.y, t.offset.x, t.offset.y ]; } );
	tally( 'TextureUtils', 'contain/cover/fill', jr, attempt( () => M.fit( mode, kind, w, h, aspect ) ), { mode, kind, w, h, aspect } );
}
for ( const mk of [ () => new Uint8Array( [ 0, 1, 64, 127, 128, 200, 255 ] ), () => new Uint8ClampedArray( [ 0, 3, 90, 255 ] ), () => new Float32Array( [ 0, 0.04, 0.5, 1, 2 ] ), () => new Float64Array( [ 0.1, 0.9 ] ), () => new Uint16Array( [ 0, 1, 65535 ] ) ] ) {
	tally( 'ImageUtils', 'sRGBToLinear', attempt( () => THREE.ImageUtils.sRGBToLinear( { data: mk(), width: 2, height: 3 } ) ), attempt( () => M.srgb( { data: mk(), width: 2, height: 3 } ) ) );
}
{ const o = { foo: 1 }; tally( 'ImageUtils', 'sRGBToLinear unsupported', attempt( () => THREE.ImageUtils.sRGBToLinear( o ) === o ), attempt( () => M.srgb( o ) === o ) ); }
for ( let i = 0; i < 70000; i ++ ) {
	if ( i < 65536 ) tally( 'DataUtils', 'fromHalfFloat', attempt( () => DataUtilsModule.fromHalfFloat( i ) ), attempt( () => M.half_from( i ) ) );
	const x = pick( [ num( true ), rnd(), rnd() * 70000 - 35000, rnd() * 1e-6 ] );
	tally( 'DataUtils', 'toHalfFloat', attempt( () => DataUtilsModule.toHalfFloat( x ) ), attempt( () => M.half_to( x ) ), { x } );
}
for ( let i = 0; i < 3000; i ++ ) {
	const a = [ param( true ), num( true ), num( true ), num( true ), num( true ) ];
	tally( 'Interpolations', 'all', attempt( () => catmullRomInterp( a ) ), attempt( () => M.interp( a ) ), { a } );
}
tally( 'harness', 'abort is catchable', { err: 'x' }, attempt( () => M.panic_probe() ) );

// report --------------------------------------------------------------------
const groups = {}; let total = 0, bad = 0, errs = 0;
for ( const [ k, e ] of Object.entries( stat ) ) { const g = k.split( ' ' )[ 0 ]; const x = groups[ g ] || ( groups[ g ] = { n: 0, err: 0, bad: 0 } ); x.n += e.n; x.err += e.err; x.bad += e.bad; total += e.n; bad += e.bad; errs += e.err; }
say( 'seed', seed, 'scale', scale );
say( 'group'.padEnd( 20 ), 'compared'.padStart( 9 ), 'both-threw'.padStart( 11 ), 'mismatch'.padStart( 9 ) );
for ( const [ g, x ] of Object.entries( groups ) ) say( g.padEnd( 20 ), String( x.n ).padStart( 9 ), String( x.err ).padStart( 11 ), String( x.bad ).padStart( 9 ) );
say( 'TOTAL'.padEnd( 20 ), String( total ).padStart( 9 ), String( errs ).padStart( 11 ), String( bad ).padStart( 9 ) );
say( 'known deviation, skipped:', JSON.stringify( skipped ) );
if ( process.env.DUMP ) fs.writeFileSync( process.env.DUMP, JSON.stringify( stat, null, 0 ) );
const seen = new Set();
for ( const f of fails ) {
	const key = f.group + f.op; if ( seen.has( key ) && ! process.env.ALL ) continue; seen.add( key );
	say( '--- MISMATCH', f.group, f.op ); say( JSON.stringify( f.note, ( k, v ) => typeof v === 'number' && ! Number.isFinite( v ) ? String( v ) : v )?.slice( 0, 600 ) );
	say( ' js ', JSON.stringify( f.js, ( k, v ) => typeof v === 'number' && ( ! Number.isFinite( v ) || Object.is( v, - 0 ) ) ? ( Object.is( v, - 0 ) ? '-0' : String( v ) ) : v )?.slice( 0, 500 ) );
	say( ' mbt', JSON.stringify( f.mbt, ( k, v ) => typeof v === 'number' && ( ! Number.isFinite( v ) || Object.is( v, - 0 ) ) ? ( Object.is( v, - 0 ) ? '-0' : String( v ) ) : v )?.slice( 0, 500 ) );
}
process.exit( bad ? 1 : 0 );
