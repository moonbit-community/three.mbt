// Differential runner: `node --import ../register.mjs run.mjs [filter]`.
// Builds every case of cases.mjs on both sides, runs the util and compares the
// summaries (typed arrays byte for byte, numbers with Object.is) and console output.
import { runUp } from './upstream.mjs';
import { makeCases } from './cases.mjs';
import * as MikkTSpace from 'three/addons/libs/mikktspace.module.js';

const port = await import( './_build/js/debug/build/utilsdiff/real/harness/harness.js' );

function capture( fn ) {

	const msgs = [];
	const saved = { log: console.log, warn: console.warn, error: console.error };
	for ( const k of Object.keys( saved ) ) console[ k ] = ( ...args ) => msgs.push( args.map( String ).join( ' ' ) );
	try {

		return { value: fn(), msgs };

	} catch ( e ) {

		return { threw: String( e && e.message || e ).slice( 0, 160 ), msgs };

	} finally {

		Object.assign( console, saved );

	}

}

function show( v ) {

	if ( ArrayBuffer.isView( v ) ) return v.constructor.name + '[' + v.length + ']';
	try {

		return JSON.stringify( v, ( k, x ) => ( typeof x === 'number' && ! Number.isFinite( x ) ) ? String( x ) : ArrayBuffer.isView( x ) ? x.constructor.name + '[' + x.length + ']' : x ).slice( 0, 200 );

	} catch ( e ) {

		return String( v );

	}

}

function cmp( a, b, path, diffs ) {

	if ( diffs.length >= 4 ) return;
	if ( ArrayBuffer.isView( a ) || ArrayBuffer.isView( b ) ) {

		if ( ! ArrayBuffer.isView( a ) || ! ArrayBuffer.isView( b ) ) return diffs.push( `${path}: ${show( a )} vs ${show( b )}` );
		if ( a.constructor.name !== b.constructor.name ) return diffs.push( `${path}: type ${a.constructor.name} vs ${b.constructor.name}` );
		if ( a.length !== b.length ) return diffs.push( `${path}: length ${a.length} vs ${b.length}` );
		const ua = new Uint8Array( a.buffer, a.byteOffset, a.byteLength ), ub = new Uint8Array( b.buffer, b.byteOffset, b.byteLength );
		for ( let i = 0; i < ua.length; i ++ ) if ( ua[ i ] !== ub[ i ] ) {

			const k = Math.floor( i / a.BYTES_PER_ELEMENT );
			return diffs.push( `${path}[${k}]: ${a[ k ]} vs ${b[ k ]}` );

		}

		return;

	}

	if ( Array.isArray( a ) || Array.isArray( b ) ) {

		if ( ! Array.isArray( a ) || ! Array.isArray( b ) ) return diffs.push( `${path}: ${show( a )} vs ${show( b )}` );
		if ( a.length !== b.length ) return diffs.push( `${path}: length ${a.length} vs ${b.length} (${show( a )} vs ${show( b )})` );
		for ( let i = 0; i < a.length; i ++ ) cmp( a[ i ], b[ i ], `${path}[${i}]`, diffs );
		return;

	}

	if ( a === null || b === null || typeof a !== 'object' || typeof b !== 'object' ) {

		if ( ! Object.is( a, b ) ) diffs.push( `${path}: ${show( a )} vs ${show( b )}` );
		return;

	}

	const keys = new Set( [ ...Object.keys( a ), ...Object.keys( b ) ] );
	for ( const k of keys ) cmp( a[ k ], b[ k ], `${path}.${k}`, diffs );

}

const filter = process.argv[ 2 ];
const cases = makeCases( MikkTSpace );
let pass = 0, fail = 0, both = 0, checked = 0;
const byOp = {};
for ( const c of cases ) {

	if ( filter && ! c.label.includes( filter ) ) continue;
	const up = capture( () => runUp( c ) );
	const mb = capture( () => port.run_case( c ) );
	const diffs = [];
	if ( up.threw !== undefined || mb.threw !== undefined ) {

		if ( up.threw === undefined || mb.threw === undefined ) diffs.push( `threw: upstream=${up.threw} port=${mb.threw}` );
		else both ++;

	} else {

		cmp( up.value, mb.value, 'result', diffs );
		cmp( up.msgs, mb.msgs, 'console', diffs );

	}

	const s = byOp[ c.op ] = byOp[ c.op ] || { pass: 0, fail: 0 };
	checked ++;
	if ( diffs.length ) {

		fail ++; s.fail ++;
		if ( fail <= 25 ) console.log( `FAIL ${c.label}\n  ` + diffs.join( '\n  ' ) );

	} else {

		pass ++; s.pass ++;

	}

}

for ( const [ op, s ] of Object.entries( byOp ) ) console.log( `${op.padEnd( 28 )} ${s.pass}/${s.pass + s.fail}` );
console.log( `cases: ${checked}, pass: ${pass}, fail: ${fail} (both threw: ${both})` );
process.exitCode = fail ? 1 : 0;
