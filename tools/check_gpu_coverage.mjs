// Checks that every WebGPU method, property, constant, enum value, descriptor class and
// special use that upstream makes (tools/gpu_usage.mjs) is bound by tools/gpu_spec.mjs and
// present in the generated package and mock.
//
// Usage: node tools/check_gpu_coverage.mjs [<three.js/src>] [<repo>/src/renderers/gpu]
//          [--mock diff/core/webgpu/mock_gpu.cjs] [--idl <typescript>/lib/lib.dom.d.ts]
// Exits 1 if anything is missing. `--idl` additionally lists bound members that the given
// lib.dom.d.ts does not declare (newer WebGPU members; informational).

import fs from 'node:fs';
import path from 'node:path';
import url from 'node:url';
import { spawnSync } from 'node:child_process';
import { createRequire } from 'node:module';
import {
	interfaces, dictionaries, unions, namespaces, enums, constantsTables, literalEnums, special, handWritten,
	parseMethod, parseProp, parseField, moonIdent,
} from './gpu_spec.mjs';

const here = path.dirname( url.fileURLToPath( import.meta.url ) );
const args = process.argv.slice( 2 );
const opt = ( n ) => { const i = args.indexOf( n ); return i >= 0 ? args[ i + 1 ] : undefined; };
const positional = args.filter( ( a, i ) => ! a.startsWith( '--' ) && ! [ '--mock', '--idl' ].includes( args[ i - 1 ] ) );
const SRC = path.resolve( positional[ 0 ] ?? path.join( path.resolve( here, '..', process.env.THREE_UPSTREAM || '.repos/three.js' ), 'src' ) );
const PKG = path.resolve( positional[ 1 ] ?? path.join( here, '..', 'src', 'renderers', 'gpu' ) );
const MOCK = opt( '--mock' ) ?? path.join( here, '..', 'diff', 'core', 'webgpu', 'mock_gpu.cjs' );
const IDL = opt( '--idl' );

const run = spawnSync( 'node', [ path.join( here, 'gpu_usage.mjs' ), SRC ], { encoding: 'utf8', maxBuffer: 1 << 26 } );
if ( run.status !== 0 ) { console.error( run.stderr ); process.exit( 2 ); }
const usage = JSON.parse( run.stdout );

const mbt = fs.readdirSync( PKG ).filter( ( f ) => f.endsWith( '.mbt' ) && ! f.endsWith( '_test.mbt' ) )
	.map( ( f ) => fs.readFileSync( path.join( PKG, f ), 'utf8' ) ).join( '\n' );
const hasFn = ( name ) => new RegExp( `fn(\\[[^\\]]*\\])? ${ name.replace( /[.*+?^${}()|[\]\\]/g, '\\$&' ) }\\(` ).test( mbt );

let missing = 0;
const miss = ( what ) => { console.log( 'missing', what ); missing ++; };

// spec tables
const specMethods = {};
const specProps = {};
for ( const [ kind, { methods, props } ] of Object.entries( interfaces ) ) {

	specMethods[ kind ] = new Map();
	for ( const m of methods.map( parseMethod ) ) specMethods[ kind ].set( m.js, [ ...( specMethods[ kind ].get( m.js ) ?? [] ), m ] );
	specProps[ kind ] = new Map( props.map( parseProp ).map( ( p ) => [ p.js, p ] ) );

}

// 1. methods and properties per object kind
let usedMethods = 0, usedProps = 0;
for ( const [ kind, { methods, props } ] of Object.entries( usage.kinds ) ) {

	if ( ! interfaces[ kind ] ) { miss( `interface ${ kind }` ); continue; }
	for ( const name of Object.keys( methods ) ) {

		usedMethods ++;
		const hand = handWritten[ `${ kind }.${ name }` ];
		if ( hand ) {

			for ( const f of hand ) if ( ! hasFn( f ) ) miss( `MoonBit ${ f } (hand-written)` );
			continue;

		}

		const variants = specMethods[ kind ].get( name );
		if ( ! variants ) { miss( `method ${ kind }.${ name }` ); continue; }
		for ( const m of variants ) if ( ! hasFn( `${ kind }::${ m.moon }` ) ) miss( `MoonBit ${ kind }::${ m.moon } (regenerate?)` );
		// every arity upstream uses must fit one bound signature
		for ( const a of methods[ name ] ) {

			const n = Number( a.split( ' ' )[ 0 ] );
			const fits = variants.some( ( m ) => n >= m.params.filter( ( p ) => ! p.optional ).length && n <= m.params.length );
			if ( ! fits ) miss( `arity ${ n } of ${ kind }.${ name } (${ a })` );

		}

	}

	for ( const name of Object.keys( props ) ) {

		if ( name === '(navigator.gpu)' ) { if ( ! hasFn( 'gpu' ) ) miss( 'gpu()' ); continue; }
		usedProps ++;
		const p = specProps[ kind ].get( name );
		if ( ! p ) { miss( `property ${ kind }.${ name }` ); continue; }
		const writes = props[ name ].some( ( a ) => a.startsWith( 'w' ) );
		if ( writes && p.access === 'r' ) miss( `writable property ${ kind }.${ name }` );
		if ( p.access !== 'w' && ! hasFn( `${ kind }::${ p.moon }` ) ) miss( `MoonBit ${ kind }::${ p.moon }` );
		if ( p.access !== 'r' && ! hasFn( `${ kind }::set_${ p.moon }` ) ) miss( `MoonBit ${ kind }::set_${ p.moon }` );

	}

}

// 2. flag namespaces
let usedConstants = 0;
for ( const [ ns, keys ] of Object.entries( usage.namespaces ) ) {

	for ( const k of keys ) {

		usedConstants ++;
		if ( ! namespaces[ ns ] || namespaces[ ns ][ k ] === undefined ) { miss( `constant ${ ns }.${ k }` ); continue; }
		const name = `GPU_${ moonIdent( ns.replace( /^GPU/, '' ) ).toUpperCase() }_${ k }`;
		if ( ! new RegExp( `pub const ${ name } : Int(32)? = 0x0*${ namespaces[ ns ][ k ].toString( 16 ).toUpperCase() }\\b` ).test( mbt ) ) miss( `MoonBit constant ${ name }` );

	}

}

// 3. WebGPUConstants.js tables: every value is a WebGPU enum value (or namespace flag)
let enumValues = 0;
const usedEnums = new Set();
for ( const [ table, values ] of Object.entries( usage.constantsTables ) ) {

	const target = constantsTables[ table ];
	if ( ! target ) { miss( `mapping of WebGPUConstants.${ table }` ); continue; }
	if ( target.startsWith( 'namespace:' ) ) {

		const ns = namespaces[ target.slice( 10 ) ];
		for ( const [ k, v ] of Object.entries( values ) ) {

			enumValues ++;
			const key = k.toUpperCase();
			if ( v === 0 && key === 'NONE' ) continue;
			if ( ns[ key ] !== v ) miss( `flag ${ table }.${ k } = ${ v } (spec ${ ns[ key ] })` );

		}

		continue;

	}

	usedEnums.add( target );
	for ( const v of Object.values( values ) ) {

		enumValues ++;
		if ( ! enums[ target ].includes( v ) ) miss( `enum value ${ table } '${ v }' in ${ target }` );

	}

}

// 4. string literals at enum-typed positions
for ( const [ key, values ] of Object.entries( usage.literals ) ) {

	if ( ! ( key in literalEnums ) ) { miss( `literal key ${ key } (add it to literalEnums)` ); continue; }
	const targets = literalEnums[ key ];
	if ( targets === null ) continue;
	for ( const v of values ) {

		enumValues ++;
		const ok = targets.some( ( e ) => ( enums[ e ] && enums[ e ].includes( v ) ) ||
			( unions[ e ] && unions[ e ].some( ( [ , t ] ) => t === JSON.stringify( v ) ) ) );
		if ( ! ok ) miss( `literal ${ key } '${ v }' in ${ targets.join( '/' ) }` );
		for ( const e of targets ) if ( enums[ e ]?.includes( v ) ) usedEnums.add( e );

	}

}

// 5. descriptor classes: same keys, same order, same initializers
const norm = ( s ) => s.replace( /\s+/g, ' ' ).trim();
for ( const [ cls, { extends: base, fields } ] of Object.entries( usage.descriptorClasses ) ) {

	const d = dictionaries[ cls ];
	if ( ! d || ! d.cls ) { miss( `descriptor class ${ cls }` ); continue; }
	const upstream = [ ...( base ? usage.descriptorClasses[ base ].fields : [] ), ...fields ];
	const ours = d.fields.map( parseField );
	const a = upstream.map( ( [ k, v ] ) => `${ k } = ${ norm( v ) }` ).join( ', ' );
	const b = ours.map( ( f ) => `${ f.js } = ${ norm( f.init ?? '?' ) }` ).join( ', ' );
	if ( a !== b ) miss( `class ${ cls } fields\n  upstream: ${ a }\n  spec:     ${ b }` );
	if ( ! hasFn( `${ cls }::default` ) || ! hasFn( `${ cls }::reset` ) ) miss( `MoonBit ${ cls }::default / reset` );

}

// 6. keys assigned on descriptor objects
const allFields = new Set( Object.values( dictionaries ).flatMap( ( d ) => d.fields.map( ( f ) => parseField( f ).js ) ) );
let keyCount = 0;
for ( const [ obj, keys ] of Object.entries( usage.descriptorKeys ) ) {

	for ( const k of keys ) {

		keyCount ++;
		for ( const part of k.split( '.' ) ) if ( ! allFields.has( part ) ) miss( `descriptor key ${ obj }.${ k }` );

	}

}

// 7. special uses
for ( const key of Object.keys( usage.special ) ) {

	if ( ! special[ key ] ) { miss( `special use ${ key }` ); continue; }
	if ( ! hasFn( special[ key ] ) ) miss( `MoonBit ${ special[ key ] } for ${ key }` );

}

// 8. the mock has every bound method and property
let mockOk = true;
if ( fs.existsSync( MOCK ) ) {

	const require = createRequire( import.meta.url );
	const { createMockGPU } = require( MOCK );
	const mock = createMockGPU( {} );
	for ( const [ kind, ms ] of Object.entries( specMethods ) ) {

		const proto = mock.classes[ kind ]?.prototype;
		if ( ! proto ) { miss( `mock class ${ kind }` ); mockOk = false; continue; }
		for ( const js of ms.keys() ) if ( typeof proto[ js ] !== 'function' ) { miss( `mock ${ kind }.${ js }` ); mockOk = false; }
		for ( const js of specProps[ kind ].keys() ) if ( ! Object.getOwnPropertyDescriptor( proto, js ) ) { miss( `mock ${ kind }.${ js }` ); mockOk = false; }

	}

} else {

	miss( `mock ${ MOCK } (run tools/gen_gpu_mock.mjs)` );

}

// 9. optional: members not in the given lib.dom.d.ts (newer than it)
if ( IDL ) {

	const text = fs.readFileSync( IDL, 'utf8' );
	const members = {};
	const parents = {};
	// interfaces are declared in several parts (iterables, deprecated members): merge them
	for ( const m of text.matchAll( /^interface (\w+)(?: extends ([\w, <>]+))? \{\n([\s\S]*?)^\}/gm ) ) {

		const set = ( members[ m[ 1 ] ] ??= new Set() );
		for ( const x of m[ 3 ].matchAll( /^\s+(?:readonly )?(\w+)\??[(:]/gm ) ) set.add( x[ 1 ] );
		parents[ m[ 1 ] ] = [ ...( parents[ m[ 1 ] ] ?? [] ), ...( m[ 2 ] ?? '' ).split( ',' ).map( ( s ) => s.trim() ).filter( Boolean ) ];

	}

	members[ 'ReadonlySet<string>' ] = new Set( [ 'has', 'size', 'forEach', 'values', 'keys', 'entries' ] );
	parents[ 'ReadonlySet<string>' ] = [];

	const has = ( i, n ) => members[ i ] && ( members[ i ].has( n ) || parents[ i ].some( ( p ) => has( p, n ) ) );
	const newer = [];
	for ( const [ kind, ms ] of Object.entries( specMethods ) ) {

		for ( const js of [ ...ms.keys(), ...specProps[ kind ].keys() ] ) if ( ! has( kind, js ) ) newer.push( `${ kind }.${ js }` );

	}

	for ( const [ name, d ] of Object.entries( dictionaries ) ) {

		const idlName = name === 'GPUColor' ? 'GPUColorDict' : name === 'GPUExtent3D' ? 'GPUExtent3DDict'
			: name === 'GPUOrigin3D' ? 'GPUOrigin3DDict' : name === 'GPUOrigin2D' ? 'GPUOrigin2DDict' : name;
		for ( const f of d.fields.map( parseField ) ) if ( ! has( idlName, f.js ) ) newer.push( `${ name }.${ f.js }` );

	}

	console.log( `not in ${ path.basename( IDL ) } (newer WebGPU members or upstream extras): ${ newer.join( ', ' ) || 'none' }` );

}

if ( usage.unresolved.length ) {

	for ( const u of usage.unresolved ) miss( `unresolved receiver ${ u } (classify it in gpu_usage.mjs RECEIVERS)` );

}

const specMethodCount = Object.values( specMethods ).reduce( ( n, m ) => n + m.size, 0 ) + Object.keys( handWritten ).length;
const specPropCount = Object.values( specProps ).reduce( ( n, m ) => n + m.size, 0 );
const constCount = Object.values( namespaces ).reduce( ( n, v ) => n + Object.keys( v ).length, 0 );
console.log( `object kinds: ${ Object.keys( usage.kinds ).length } used, ${ Object.keys( interfaces ).length } bound` );
console.log( `methods: ${ usedMethods } used (kind.method), ${ specMethodCount } bound` );
console.log( `properties: ${ usedProps } used, ${ specPropCount } bound` );
console.log( `constants: ${ usedConstants } used, ${ constCount } bound` );
console.log( `enums: ${ enumValues } values used across ${ usedEnums.size } enums (${ Object.keys( usage.constantsTables ).length } WebGPUConstants tables, ${ Object.keys( usage.literals ).length } literal keys), ${ Object.keys( enums ).length } enums in the spec` );
console.log( `descriptors: ${ Object.keys( usage.descriptorClasses ).length } upstream classes mirrored, ${ keyCount } assigned keys checked, ${ Object.keys( dictionaries ).length } dictionaries bound` );
console.log( `special uses: ${ Object.keys( usage.special ).length }; mock: ${ mockOk ? 'complete' : 'incomplete' }; not bound (XR): ${ usage.unbound.join( ', ' ) || 'none' }` );
console.log( `${ missing } missing` );
process.exit( missing ? 1 : 0 );
