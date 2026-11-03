#!/usr/bin/env node
// Generates src/nodes/tsl_fn_layout_names.mbt: the `fn<id>` layout names upstream gives
// library `Fn`s with short layouts (`Fn( f, { a: 'float', return: 'vec3' } )`) while its
// entry points load.
//
// `FnNode.setLayout` names a short layout `'fn' + fnId ++`, so a library function's name
// is its position in ES-module evaluation order. Those names appear in shader text
// (`fn57( color )`), and MoonBit initializes top-level lets in its own order, so the port
// cannot reproduce them by counting. Instead every library `Fn` passes its upstream key
// (`FnLayout::short(inputs, return_=..., upstream="nodes/display/ToneMappingFunctions.js:
// RRTAndODTFit")`), `FnNode::set_layout` looks the number up here without touching the
// counter, and the counter starts at the number the first user `Fn` gets upstream.
//
// The measured order is the one of the published bundles: build/three.webgpu.js imports
// build/three.tsl.js, so the `Three.TSL.js` graph evaluates first (122 names) and the
// files only `Three.WebGPU.js` reaches follow (8 more). Loading src/Three.WebGPU.js alone
// interleaves them differently; the script prints that order's count too, and checks the
// measured order against an instrumented copy of the bundles when build/ exists.
//
// A key is `<path below src>:<declared const>`. The script fails if a site is not a
// `const NAME = Fn(` declaration or if two sites share a key.
//
//   node tools/gen_fn_layout_names.mjs [path/to/three.js]     (writes the .mbt file)
//   node tools/gen_fn_layout_names.mjs --check [path/to/three.js]  (exit 1 if stale)
//
// Run `moonfmt -w src/nodes/tsl_fn_layout_names.mbt` afterwards.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const self = fileURLToPath( import.meta.url );
const repoRoot = path.resolve( path.dirname( self ), '..' );
const args = process.argv.slice( 2 );

// ---------------------------------------------------------------------------
// Child mode: load the entries (comma separated) with `FnNode.setLayout` patched and
// print one JSON line per short layout: [ name, file, line, column ].

if ( args[ 0 ] === '--measure' ) {

	const [ , srcDir, entries ] = args;
	Error.stackTraceLimit = 200;
	const srcUrl = pathToFileURL( srcDir ).href + '/';
	const TSL = await import( srcUrl + 'nodes/tsl/TSLCore.js' );
	// A layout-less Fn: does not consume an id.
	const FnNode = TSL.Fn( () => {} ).constructor;
	const setLayout = FnNode.prototype.setLayout;
	const sites = [];
	FnNode.prototype.setLayout = function ( layout ) {

		const short = typeof layout.inputs !== 'object';
		const result = setLayout.call( this, layout );
		if ( short ) {

			const frame = new Error().stack.split( '\n' ).slice( 1 )
				.map( ( s ) => /\((file:[^)]*):(\d+):(\d+)\)|at (file:\S*):(\d+):(\d+)/.exec( s ) )
				.filter( ( m ) => m !== null )
				.map( ( m ) => ( { file: m[ 1 ] ?? m[ 4 ], line: + ( m[ 2 ] ?? m[ 5 ] ), column: + ( m[ 3 ] ?? m[ 6 ] ) } ) )
				.find( ( f ) => f.file.startsWith( srcUrl ) && ! f.file.endsWith( '/nodes/tsl/TSLCore.js' ) );
			sites.push( [ this.shaderNode.layout.name, frame ? frame.file.slice( srcUrl.length ) : '?', frame?.line ?? 0, frame?.column ?? 0 ] );

		}

		return result;

	};

	for ( const entry of entries.split( ',' ) ) await import( srcUrl + entry );
	FnNode.prototype.setLayout = setLayout;
	const next = TSL.Fn( () => {}, { a: 'float' } ).shaderNode.layout.name;
	console.log( JSON.stringify( { sites, next } ) );
	process.exit( 0 );

}

// Child mode: load an instrumented copy of the bundles and print the declared names.
if ( args[ 0 ] === '--measure-bundle' ) {

	const [ , dir ] = args;
	Error.stackTraceLimit = 200;
	const names = [];
	const files = {};
	globalThis.__fnLayoutSite = ( stack ) => {

		for ( const s of stack.split( '\n' ).slice( 1 ) ) {

			const m = /(three\.\w+\.js):(\d+):(\d+)/.exec( s );
			if ( ! m ) continue;
			const text = ( files[ m[ 1 ] ] ??= fs.readFileSync( path.join( dir, m[ 1 ] ), 'utf8' ).split( '\n' ) )[ + m[ 2 ] - 1 ];
			const d = declaredName( text, + m[ 3 ] );
			if ( d ) {

				names.push( d.replace( /\$\d+$/, '' ) );
				return;

			}

		}

		names.push( '?' );

	};

	const { TSL } = await import( pathToFileURL( path.join( dir, 'three.webgpu.js' ) ).href );
	globalThis.__fnLayoutSite = () => {};
	const next = TSL.Fn( () => {}, { a: 'float' } ).shaderNode.layout.name;
	console.log( JSON.stringify( { names, next } ) );
	process.exit( 0 );

}

// ---------------------------------------------------------------------------

function declaredName( text, column ) {

	if ( text === undefined ) return null;
	const before = text.slice( 0, column - 1 );
	if ( ! text.slice( column - 1 ).startsWith( 'Fn(' ) ) return null;
	const m = /(?:const|let|var)\s+([\w$]+)\s*=\s*(?:\/\*\s*@__PURE__\s*\*\/\s*)?$/.exec( before );
	return m ? m[ 1 ] : null;

}

const check = args.includes( '--check' );
const upstream = path.resolve( args.filter( ( a ) => ! a.startsWith( '--' ) )[ 0 ] ?? path.join( repoRoot, '.repos/three.js' ) );
const srcDir = path.join( upstream, 'src' );
const outFile = path.join( repoRoot, 'src/nodes/tsl_fn_layout_names.mbt' );

function measure( entries ) {

	const r = spawnSync( process.execPath, [ self, '--measure', srcDir, entries ], { encoding: 'utf8', maxBuffer: 1 << 26 } );
	if ( r.status !== 0 ) throw new Error( `measuring ${entries} failed:\n${r.stderr}` );
	return JSON.parse( r.stdout.trim().split( '\n' ).pop() );

}

const canonical = measure( 'Three.TSL.js,Three.WebGPU.js' );
const webgpuAlone = measure( 'Three.WebGPU.js' );
const tslAlone = measure( 'Three.TSL.js' );

const sourceLines = {};
const entries = canonical.sites.map( ( [ name, file, line, column ], i ) => {

	if ( name !== 'fn' + i ) throw new Error( `unexpected name order: ${name} at ${i}` );
	const text = ( sourceLines[ file ] ??= fs.readFileSync( path.join( srcDir, file ), 'utf8' ).split( '\n' ) )[ line - 1 ];
	const decl = declaredName( text, column );
	if ( ! decl ) throw new Error( `${file}:${line}:${column} is not a \`const NAME = Fn(\` declaration: ${text}` );
	return { id: i, file, line, decl, key: `${file}:${decl}` };

} );

const seen = new Set();
for ( const e of entries ) {

	if ( seen.has( e.key ) ) throw new Error( `duplicate key ${e.key}` );
	seen.add( e.key );

}

const firstUserId = + canonical.next.slice( 2 );
if ( firstUserId !== entries.length ) throw new Error( `first user id ${firstUserId} != ${entries.length} library names` );

// Cross-check with the published bundles: three.webgpu.js imports three.tsl.js.
let bundleNote = 'build/ not found: bundle order not checked';
const buildDir = path.join( upstream, 'build' );
if ( fs.existsSync( path.join( buildDir, 'three.tsl.js' ) ) ) {

	const tmp = fs.mkdtempSync( path.join( os.tmpdir(), 'fn-layout-names-' ) );
	for ( const f of [ 'three.core.js', 'three.tsl.js', 'three.webgpu.js' ] ) fs.copyFileSync( path.join( buildDir, f ), path.join( tmp, f ) );
	const tslFile = path.join( tmp, 'three.tsl.js' );
	const text = fs.readFileSync( tslFile, 'utf8' );
	const patched = text.replace( 'name: \'fn\' + fnId ++,', 'name: ( globalThis.__fnLayoutSite( new Error().stack ), \'fn\' + fnId ++ ),' );
	if ( patched === text ) throw new Error( 'build/three.tsl.js: `name: \'fn\' + fnId ++` not found' );
	fs.writeFileSync( tslFile, patched );
	const r = spawnSync( process.execPath, [ self, '--measure-bundle', tmp ], { encoding: 'utf8', maxBuffer: 1 << 26 } );
	fs.rmSync( tmp, { recursive: true, force: true } );
	if ( r.status !== 0 ) throw new Error( `measuring the bundle failed:\n${r.stderr}` );
	const bundle = JSON.parse( r.stdout.trim().split( '\n' ).pop() );
	const ours = entries.map( ( e ) => e.decl );
	const mismatch = ours.findIndex( ( d, i ) => bundle.names[ i ] !== d );
	if ( bundle.names.length !== ours.length || mismatch >= 0 || bundle.next !== canonical.next ) {

		throw new Error( `bundle order differs at ${mismatch}: ${bundle.names[ mismatch ]} vs ${ours[ mismatch ]} (bundle next ${bundle.next})` );

	}

	bundleNote = `matches build/three.webgpu.js (instrumented copy): ${bundle.names.length} names, next ${bundle.next}`;

}

// The MoonBit file each key belongs to (tools/webgpu_deps.mjs `mbtFileOf`).
const ROOTS = [ [ 'nodes/', '' ], [ 'materials/nodes/', 'materials/' ], [ 'renderers/common/', 'common/' ], [ 'renderers/webgpu/', '' ], [ 'lights/webgpu/', '' ] ];
const snakeCase = ( s ) => s.replace( /\./g, '_' ).replace( /([a-z0-9])([A-Z])/g, '$1_$2' ).replace( /([A-Z]+)([A-Z][a-z])/g, '$1_$2' ).toLowerCase();
function mbtFileOf( f ) {

	let rest = f.replace( /\.js$/, '' );
	for ( const [ root, prefix ] of ROOTS ) if ( rest.startsWith( root ) ) {

		rest = prefix + rest.slice( root.length );
		break;

	}

	const parts = rest.split( '/' );
	const base = snakeCase( parts.pop() );
	const dir = parts.map( snakeCase ).join( '_' );
	if ( dir === '' ) return base + '.mbt';
	const ruled = ( base.startsWith( dir + '_' ) ? base : dir + '_' + base ) + '.mbt';
	// A few foundation files repeat the prefix (math_math_node.mbt): name the file that exists.
	const repeated = dir + '_' + base + '.mbt';
	return ! fs.existsSync( path.join( repoRoot, 'src/nodes', ruled ) ) && fs.existsSync( path.join( repoRoot, 'src/nodes', repeated ) ) ? repeated : ruled;

}

const version = JSON.parse( fs.readFileSync( path.join( upstream, 'package.json' ), 'utf8' ) ).version;
const lines = [];
lines.push( `// Generated by tools/gen_fn_layout_names.mjs from three.js ${version}: do not edit.` );
lines.push( '//' );
lines.push( '// The `fn<id>` names upstream gives library `Fn`s with short layouts while it loads, in' );
lines.push( '// the order of the published bundles (build/three.webgpu.js imports build/three.tsl.js:' );
lines.push( `// the Three.TSL.js graph gives ${tslAlone.sites.length} names, Three.WebGPU.js adds ${entries.length - tslAlone.sites.length}). A library \`Fn\` passes its` );
lines.push( '// key to `FnLayout::short(..., upstream=key)`; `FnNode::set_layout` takes the name from' );
lines.push( '// here, and user `Fn`s count from `TSL_FN_FIRST_USER_ID`. See PORTING.md, "Byte-identical' );
lines.push( '// shaders".' );
lines.push( '//' );
lines.push( `// Measured: src/Three.TSL.js then src/Three.WebGPU.js; ${bundleNote}.` );
lines.push( `// src/Three.WebGPU.js alone would give the same ${webgpuAlone.sites.length} names in another order.` );
lines.push( '' );
lines.push( '///|' );
lines.push( '/// `fnId` after upstream\'s entry points have loaded: the first user `Fn`\'s number.' );
lines.push( `const TSL_FN_FIRST_USER_ID : Int32 = ${firstUserId}` );
lines.push( '' );
lines.push( '///|' );
lines.push( '/// The number in the `fn<id>` name of the library `Fn` with this upstream key.' );
lines.push( 'fn tsl_fn_library_id(key : String) -> Int32? {' );
lines.push( '  match key {' );
let lastFile = '';
for ( const e of entries ) {

	if ( e.file !== lastFile ) {

		lines.push( `    // ${e.file} (${mbtFileOf( e.file )})` );
		lastFile = e.file;

	}

	lines.push( `    ${JSON.stringify( e.key )} => Some(${e.id})` );

}

lines.push( '    _ => None' );
lines.push( '  }' );
lines.push( '}' );
lines.push( '' );
lines.push( '///|' );
lines.push( '/// Every key, in id order.' );
lines.push( 'let tsl_fn_library_keys : Array[String] = [' );
for ( const e of entries ) lines.push( `  ${JSON.stringify( e.key )},` );
lines.push( ']' );
lines.push( '' );
lines.push( '///|' );
lines.push( '/// The MoonBit file that declares each library `Fn`, in id order.' );
lines.push( 'let tsl_fn_library_files : Array[String] = [' );
for ( const e of entries ) lines.push( `  ${JSON.stringify( mbtFileOf( e.file ) )},` );
lines.push( ']' );
lines.push( '' );
lines.push( '///|' );
lines.push( '/// How many `Fn`s `FnNode::set_layout` has named after each library key.' );
lines.push( 'let tsl_fn_library_created : Map[String, Int32] = Map::from_array([])' );
lines.push( '' );
lines.push( '///|' );
lines.push( '/// `(key, name, MoonBit file, created)` for every upstream library `Fn`. Top-level lets' );
lines.push( '/// are initialized at load, so `created` is 1 once the file is ported with `upstream=`.' );
lines.push( 'pub fn tsl_fn_library_status() -> Array[(String, String, String, Int32)] {' );
lines.push( '  tsl_fn_library_keys.mapi(fn(i, key) {' );
lines.push( '    (key, "fn\\{i}", tsl_fn_library_files[i], tsl_fn_library_created.get(key).unwrap_or(0))' );
lines.push( '  })' );
lines.push( '}' );
const out = lines.join( '\n' ) + '\n';

console.log( `${entries.length} library names, first user id fn${firstUserId}; Three.TSL.js alone: ${tslAlone.sites.length}, Three.WebGPU.js alone: ${webgpuAlone.sites.length} (${webgpuAlone.next})` );
console.log( bundleNote );

if ( check ) {

	// Compare ignoring formatting: the committed file is moonfmt'ed.
	const norm = ( s ) => s.replace( /[\s,]+/g, '' );
	const current = fs.existsSync( outFile ) ? fs.readFileSync( outFile, 'utf8' ) : '';
	if ( norm( current ) !== norm( out ) ) {

		console.log( `${path.relative( repoRoot, outFile )} is stale` );
		process.exit( 1 );

	}

	console.log( `${path.relative( repoRoot, outFile )} is up to date` );

} else {

	fs.writeFileSync( outFile, out );
	console.log( `wrote ${path.relative( repoRoot, outFile )}` );

}
