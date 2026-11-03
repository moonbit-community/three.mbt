#!/usr/bin/env node
// Generates src/nodes/core_module_node_ids.mbt: the ids upstream gives the nodes it
// creates while its entry points load.
//
// `Node`'s constructor takes `_nodeId ++`, so a node made at module load has its position
// in ES-module evaluation order as id: 856 of them in r187, and the first node user code
// creates is 856. Ids are observable (shared uniform groups sort their uniforms by id, and
// `getHash` / cache keys use them), and MoonBit initializes top-level lets eagerly but in
// its own order (dependency-driven, different in each linked program, and lets nobody
// reads are dropped), so the port cannot reproduce the ids by counting. Instead every
// top-level statement that creates nodes is a table entry `<path below src>:<name>` with
// the first id and the number of nodes it creates (they are consecutive: a statement runs
// to completion before the next one). The port wraps the initializer of the let that
// mirrors the statement in `module_nodes(key, fn() { ... })`, which allocates from the
// entry's base and records how many nodes the initializer made; the runtime counter
// starts at `NODE_FIRST_RUNTIME_ID`.
//
// A statement's name is the const/let/function/class it declares, or for a statement
// that fills a map (`for ( ... ) boolsCacheMap.set( ... )`) the map's name; consecutive
// statements with the same name are one entry. The order is the one of the published
// bundles (build/three.webgpu.js imports build/three.tsl.js, so the Three.TSL.js graph
// evaluates first); the script checks it against an instrumented copy of the bundles when
// build/ exists.
//
//   node tools/gen_module_node_ids.mjs [path/to/three.js]          (writes the .mbt file)
//   node tools/gen_module_node_ids.mjs --check [path/to/three.js]  (exit 1 if stale)
//
// Run `moonfmt -w src/nodes/core_module_node_ids.mbt` afterwards.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const self = fileURLToPath( import.meta.url );
const repoRoot = path.resolve( path.dirname( self ), '..' );
const args = process.argv.slice( 2 );

// The outermost frame of `stack` whose file starts with `prefix`: [ file, line, column ].
function outerFrame( stack, test ) {

	const frames = stack.split( '\n' ).slice( 1 )
		.map( ( s ) => /\((file:[^)]*):(\d+):(\d+)\)|at (file:\S*):(\d+):(\d+)/.exec( s ) )
		.filter( ( m ) => m !== null )
		.map( ( m ) => [ m[ 1 ] ?? m[ 4 ], + ( m[ 2 ] ?? m[ 5 ] ), + ( m[ 3 ] ?? m[ 6 ] ) ] )
		.filter( ( f ) => test( f[ 0 ] ) );
	return frames.length > 0 ? frames[ frames.length - 1 ] : null;

}

// ---------------------------------------------------------------------------
// Child mode: load the entries (comma separated) with `Node`'s constructor patched and
// print [ file, line, column, class ] for every node created, in id order.

if ( args[ 0 ] === '--measure' ) {

	const [ , srcDir, entries ] = args;
	const srcUrl = pathToFileURL( srcDir ).href + '/';
	const { registerHooks } = await import( 'node:module' );
	registerHooks( {
		load( url, context, next ) {

			const r = next( url, context );
			if ( url !== srcUrl + 'nodes/core/Node.js' ) return r;
			const text = String( r.source );
			const patched = text.replace( 'this.id = _nodeId ++;', 'this.id = _nodeId ++; globalThis.__nodeCreated?.( this, new Error().stack );' );
			if ( patched === text ) throw new Error( 'nodes/core/Node.js: `this.id = _nodeId ++;` not found' );
			return { ...r, source: patched };

		}
	} );
	globalThis.self = globalThis;
	Error.stackTraceLimit = Infinity;
	const created = [];
	globalThis.__nodeCreated = ( node, stack ) => {

		const f = outerFrame( stack, ( file ) => file.startsWith( srcUrl ) );
		created.push( { node, site: f ? [ f[ 0 ].slice( srcUrl.length ), f[ 1 ], f[ 2 ] ] : [ '?', 0, 0 ] } );

	};

	for ( const entry of entries.split( ',' ) ) await import( srcUrl + entry );
	globalThis.__nodeCreated = null;
	const { default: Node } = await import( srcUrl + 'nodes/core/Node.js' );
	const next = new Node().id;
	const sites = created.map( ( { node, site }, i ) => {

		if ( node.id !== i ) throw new Error( `node ${node.id} created as number ${i}` );
		return [ ...site, node.constructor.name ];

	} );
	console.log( JSON.stringify( { sites, next } ) );
	process.exit( 0 );

}

// Child mode: load an instrumented copy of the bundles and print each node's statement name.
if ( args[ 0 ] === '--measure-bundle' ) {

	const [ , dir ] = args;
	globalThis.self = globalThis;
	Error.stackTraceLimit = Infinity;
	const names = [];
	const files = {};
	globalThis.__nodeSite = ( stack ) => {

		const f = outerFrame( stack, ( file ) => /three\.\w+\.js$/.test( file ) );
		if ( f === null ) {

			names.push( '?' );
			return;

		}

		const base = path.basename( fileURLToPath( f[ 0 ] ) );
		files[ base ] ??= statementIndex( fs.readFileSync( path.join( dir, base ), 'utf8' ) );
		const s = files[ base ].at( f[ 1 ] );
		names.push( s.name === null ? '?' : s.name.replace( /\$\d+$/, '' ) );

	};

	const W = await import( pathToFileURL( path.join( dir, 'three.webgpu.js' ) ).href );
	globalThis.__nodeSite = () => {};
	const next = new W.Node().id;
	console.log( JSON.stringify( { names, next } ) );
	process.exit( 0 );

}

// ---------------------------------------------------------------------------
// Top-level statements of a module: a line starts one when it begins at nesting depth 0,
// outside strings, template literals and comments, with an identifier character in
// column 0 (upstream and rollup output indent everything else).

function statementIndex( text ) {

	const starts = [];
	let depth = 0;
	const modes = [ 'code' ];
	const templateDepths = [];
	let lastSignificant = '';
	let line = 0;
	for ( let i = 0; i < text.length; i ++ ) {

		const c = text[ i ];
		if ( c === '\n' ) {

			if ( modes[ modes.length - 1 ] === 'line' ) modes.pop();
			line ++;
			if ( modes[ modes.length - 1 ] === 'code' && depth === 0 && /[A-Za-z_$]/.test( text[ i + 1 ] ?? '' ) ) starts.push( line );
			continue;

		}

		const mode = modes[ modes.length - 1 ];

		if ( mode === 'line' ) continue;
		if ( mode === 'block' ) {

			if ( c === '*' && text[ i + 1 ] === '/' ) {

				modes.pop();
				i ++;

			}

			continue;

		}

		if ( mode === '\'' || mode === '"' ) {

			if ( c === '\\' ) i ++;
			else if ( c === mode ) modes.pop();
			continue;

		}

		if ( mode === '`' ) {

			if ( c === '\\' ) i ++;
			else if ( c === '`' ) modes.pop();
			else if ( c === '$' && text[ i + 1 ] === '{' ) {

				modes.push( 'code' );
				templateDepths.push( depth );
				i ++;

			}

			continue;

		}

		// code
		if ( c === '/' && text[ i + 1 ] === '/' ) {

			modes.push( 'line' );
			continue;

		}

		if ( c === '/' && text[ i + 1 ] === '*' ) {

			modes.push( 'block' );
			i ++;
			continue;

		}

		if ( c === '/' && ( lastSignificant === '' || '(,=:[!&|?{};+-*%<>~^'.includes( lastSignificant ) ) ) {

			// a regular expression literal
			let inClass = false;
			for ( i ++; i < text.length && text[ i ] !== '\n'; i ++ ) {

				if ( text[ i ] === '\\' ) i ++;
				else if ( text[ i ] === '[' ) inClass = true;
				else if ( text[ i ] === ']' ) inClass = false;
				else if ( text[ i ] === '/' && ! inClass ) break;

			}

			lastSignificant = 'r';
			continue;

		}

		if ( c === '\'' || c === '"' || c === '`' ) modes.push( c );
		else if ( c === '(' || c === '[' || c === '{' ) depth ++;
		else if ( c === '}' && templateDepths.length > 0 && templateDepths[ templateDepths.length - 1 ] === depth ) {

			templateDepths.pop();
			modes.pop();

		} else if ( c === ')' || c === ']' || c === '}' ) depth --;
		if ( ! /\s/.test( c ) ) lastSignificant = /[\w$]/.test( c ) ? 'w' : c;

	}

	if ( /^[A-Za-z_$]/.test( text ) ) starts.unshift( 0 );
	const lines = text.split( '\n' );
	return {
		// The statement around 1-based line `n`: { line, name }.
		at( n ) {

			let lo = 0, hi = starts.length - 1, found = - 1;
			while ( lo <= hi ) {

				const mid = ( lo + hi ) >> 1;
				if ( starts[ mid ] <= n - 1 ) {

					found = mid;
					lo = mid + 1;

				} else hi = mid - 1;

			}

			const start = found < 0 ? 0 : starts[ found ];
			const end = found + 1 < starts.length ? starts[ found + 1 ] : lines.length;
			const head = lines[ start ];
			const decl = /^(?:export\s+)?(?:const|let|var|function\*?|class|async\s+function)\s+([\w$]+)/.exec( head );
			if ( decl ) return { line: start + 1, name: decl[ 1 ] };
			const body = lines.slice( start, end ).join( '\n' );
			const set = /\b([\w$]+)\.set\(/.exec( body );
			return { line: start + 1, name: set ? set[ 1 ] : null, text: head };

		}
	};

}

// ---------------------------------------------------------------------------

const check = args.includes( '--check' );
const upstream = path.resolve( args.filter( ( a ) => ! a.startsWith( '--' ) )[ 0 ] ?? path.join( repoRoot, '.repos/three.js' ) );
const srcDir = path.join( upstream, 'src' );
const outFile = path.join( repoRoot, 'src/nodes/core_module_node_ids.mbt' );

function measure( entries ) {

	const r = spawnSync( process.execPath, [ self, '--measure', srcDir, entries ], { encoding: 'utf8', maxBuffer: 1 << 28 } );
	if ( r.status !== 0 ) throw new Error( `measuring ${entries} failed:\n${r.stderr}` );
	return JSON.parse( r.stdout.trim().split( '\n' ).pop() );

}

const canonical = measure( 'Three.TSL.js,Three.WebGPU.js' );
const tslAlone = measure( 'Three.TSL.js' );
const webgpuAlone = measure( 'Three.WebGPU.js' );

const indexes = {};
const names = canonical.sites.map( ( [ file, line ] ) => {

	if ( file === '?' ) throw new Error( 'a node created outside src/' );
	indexes[ file ] ??= statementIndex( fs.readFileSync( path.join( srcDir, file ), 'utf8' ) );
	const s = indexes[ file ].at( line );
	if ( s.name === null ) throw new Error( `${file}:${line}: statement without a name: ${s.text}` );
	return { file, line: s.line, name: s.name };

} );

const entries = [];
names.forEach( ( n, id ) => {

	const key = `${n.file}:${n.name}`;
	const last = entries[ entries.length - 1 ];
	if ( last !== undefined && last.key === key ) {

		last.count ++;
		last.classes.push( canonical.sites[ id ][ 3 ] );

	} else entries.push( { key, file: n.file, name: n.name, base: id, count: 1, classes: [ canonical.sites[ id ][ 3 ] ] } );

} );

const seen = new Set();
for ( const e of entries ) {

	if ( seen.has( e.key ) ) throw new Error( `${e.key}: two separate runs of nodes` );
	seen.add( e.key );

}

const firstRuntimeId = canonical.next;
if ( firstRuntimeId !== names.length ) throw new Error( `first runtime id ${firstRuntimeId} != ${names.length} nodes` );

// Cross-check with the published bundles: three.webgpu.js imports three.tsl.js.
let bundleNote = 'build/ not found: bundle order not checked';
const buildDir = path.join( upstream, 'build' );
if ( fs.existsSync( path.join( buildDir, 'three.tsl.js' ) ) ) {

	const tmp = fs.mkdtempSync( path.join( os.tmpdir(), 'module-node-ids-' ) );
	for ( const f of [ 'three.core.js', 'three.tsl.js', 'three.webgpu.js' ] ) fs.copyFileSync( path.join( buildDir, f ), path.join( tmp, f ) );
	const tslFile = path.join( tmp, 'three.tsl.js' );
	const text = fs.readFileSync( tslFile, 'utf8' );
	const patched = text.replace( 'this.id = _nodeId ++;', 'this.id = _nodeId ++; globalThis.__nodeSite( new Error().stack );' );
	if ( patched === text ) throw new Error( 'build/three.tsl.js: `this.id = _nodeId ++;` not found' );
	fs.writeFileSync( tslFile, patched );
	const r = spawnSync( process.execPath, [ self, '--measure-bundle', tmp ], { encoding: 'utf8', maxBuffer: 1 << 28 } );
	fs.rmSync( tmp, { recursive: true, force: true } );
	if ( r.status !== 0 ) throw new Error( `measuring the bundle failed:\n${r.stderr}` );
	const bundle = JSON.parse( r.stdout.trim().split( '\n' ).pop() );
	const ours = names.map( ( n ) => n.name );
	const mismatch = ours.findIndex( ( d, i ) => bundle.names[ i ] !== d );
	if ( bundle.names.length !== ours.length || mismatch >= 0 || bundle.next !== firstRuntimeId ) {

		throw new Error( `bundle order differs at id ${mismatch}: ${bundle.names[ mismatch ]} vs ${ours[ mismatch ]} (bundle: ${bundle.names.length} nodes, next ${bundle.next})` );

	}

	bundleNote = `matches build/three.webgpu.js (instrumented copy): ${bundle.names.length} nodes, next ${bundle.next}`;

}

// The MoonBit file each key belongs to (tools/webgpu_deps.mjs `mbtFileOf`).
const ROOTS = [
	[ 'nodes/', 'src/nodes/', '' ], [ 'materials/nodes/', 'src/nodes/', 'materials/' ], [ 'renderers/common/', 'src/nodes/', 'common/' ],
	[ 'renderers/webgpu/', 'src/renderers/webgpu/', '' ], [ 'renderers/webgl-fallback/', 'src/renderers/webgl_fallback/', '' ],
];
const snakeCase = ( s ) => s.replace( /\./g, '_' ).replace( /([a-z0-9])([A-Z])/g, '$1_$2' ).replace( /([A-Z]+)([A-Z][a-z])/g, '$1_$2' ).toLowerCase();
function mbtFileOf( f ) {

	let rest = f.replace( /\.js$/, '' );
	let dirOut = 'src/nodes/';
	for ( const [ root, out, prefix ] of ROOTS ) if ( rest.startsWith( root ) ) {

		rest = prefix + rest.slice( root.length );
		dirOut = out;
		break;

	}

	const parts = rest.split( '/' );
	const base = snakeCase( parts.pop() );
	const dir = parts.map( snakeCase ).join( '_' );
	if ( dir === '' ) return dirOut + base + '.mbt';
	const ruled = ( base.startsWith( dir + '_' ) ? base : dir + '_' + base ) + '.mbt';
	const repeated = dir + '_' + base + '.mbt';
	return dirOut + ( ! fs.existsSync( path.join( repoRoot, dirOut, ruled ) ) && fs.existsSync( path.join( repoRoot, dirOut, repeated ) ) ? repeated : ruled );

}

const version = JSON.parse( fs.readFileSync( path.join( upstream, 'package.json' ), 'utf8' ) ).version;
const lines = [];
lines.push( `// Generated by tools/gen_module_node_ids.mjs from three.js ${version}: do not edit.` );
lines.push( '//' );
lines.push( '// The ids upstream gives the nodes it creates while its modules load, in the order of the' );
lines.push( '// published bundles (build/three.webgpu.js imports build/three.tsl.js: the Three.TSL.js' );
lines.push( `// graph creates ${tslAlone.next} nodes, Three.WebGPU.js adds ${firstRuntimeId - tslAlone.next}). Each entry is a top-level statement that` );
lines.push( '// creates nodes: `<path below src>:<declared name>`, its first id and how many it creates.' );
lines.push( '// The let that mirrors it wraps its initializer in `module_nodes(key, fn() { ... })`;' );
lines.push( '// nodes created at run time count from `NODE_FIRST_RUNTIME_ID`. See PORTING.md,' );
lines.push( '// "Byte-identical shaders".' );
lines.push( '//' );
lines.push( `// Measured: src/Three.TSL.js then src/Three.WebGPU.js; ${bundleNote}.` );
lines.push( `// src/Three.WebGPU.js alone creates the same ${webgpuAlone.next} nodes in another order.` );
lines.push( '' );
lines.push( '///|' );
lines.push( '/// `_nodeId` after upstream\'s entry points have loaded: the id of the first node user' );
lines.push( '/// code creates.' );
lines.push( `pub const NODE_FIRST_RUNTIME_ID : Int32 = ${firstRuntimeId}` );
lines.push( '' );
lines.push( '///|' );
lines.push( '/// `(first id, count)` of the nodes upstream\'s statement `key` creates at module load.' );
lines.push( 'fn module_node_ids_entry(key : String) -> (Int32, Int32)? {' );
lines.push( '  match key {' );
let lastFile = '';
for ( const e of entries ) {

	if ( e.file !== lastFile ) {

		lines.push( `    // ${e.file} (${path.basename( mbtFileOf( e.file ) )})` );
		lastFile = e.file;

	}

	lines.push( `    ${JSON.stringify( e.key )} => Some((${e.base}, ${e.count}))` );

}

lines.push( '    _ => None' );
lines.push( '  }' );
lines.push( '}' );
lines.push( '' );
lines.push( '///|' );
lines.push( '/// Every key, in id order.' );
lines.push( 'let module_node_ids_keys : Array[String] = [' );
for ( const e of entries ) lines.push( `  ${JSON.stringify( e.key )},` );
lines.push( ']' );
lines.push( '' );
lines.push( '///|' );
lines.push( '/// The MoonBit file (below the module root) that mirrors each key\'s upstream file.' );
lines.push( 'let module_node_ids_files : Array[String] = [' );
for ( const e of entries ) lines.push( `  ${JSON.stringify( mbtFileOf( e.file ) )},` );
lines.push( ']' );
lines.push( '' );
lines.push( '///|' );
lines.push( '/// The upstream classes of each key\'s nodes, in id order.' );
lines.push( 'let module_node_ids_classes : Array[String] = [' );
for ( const e of entries ) lines.push( `  ${JSON.stringify( e.classes.join( ' ' ) )},` );
lines.push( ']' );
const out = lines.join( '\n' ) + '\n';

console.log( `${entries.length} statements create ${firstRuntimeId} nodes; Three.TSL.js alone: ${tslAlone.next}, Three.WebGPU.js alone: ${webgpuAlone.next}` );
console.log( bundleNote );

// The port side: every `module_nodes( "<key>", ... )` in src/ (tests excluded) names a
// table key, and no key is used twice. Keys without a call are listed (not ported).
const used = new Map();
( function scan( dir ) {

	for ( const f of fs.readdirSync( dir, { withFileTypes: true } ) ) {

		const p = path.join( dir, f.name );
		if ( f.isDirectory() ) {

			if ( f.name !== '_build' ) scan( p );

		} else if ( f.name.endsWith( '.mbt' ) && ! f.name.endsWith( '_test.mbt' ) ) {

			for ( const m of fs.readFileSync( p, 'utf8' ).matchAll( /module_nodes\(\s*"([^"]+)"/g ) ) {

				if ( ! used.has( m[ 1 ] ) ) used.set( m[ 1 ], [] );
				used.get( m[ 1 ] ).push( path.relative( repoRoot, p ) );

			}

		}

	}

} )( path.join( repoRoot, 'src' ) );
const portErrors = [];
for ( const [ key, files ] of used ) {

	if ( ! seen.has( key ) ) portErrors.push( `unknown key ${key} (${files.join( ', ' )})` );
	else if ( files.length > 1 ) portErrors.push( `key ${key} used ${files.length} times (${files.join( ', ' )})` );

}

const unported = entries.filter( ( e ) => ! used.has( e.key ) );
console.log( `port: ${used.size} keys used in src/; not ported: ${unported.map( ( e ) => `${e.key} (${e.count})` ).join( ', ' ) || 'none'}` );

if ( portErrors.length > 0 ) {

	for ( const e of portErrors ) console.log( 'port: ' + e );
	if ( check ) process.exit( 1 );

}

if ( check ) {

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
