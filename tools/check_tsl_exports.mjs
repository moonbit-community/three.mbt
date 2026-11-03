#!/usr/bin/env node
// Checks the re-export lists of upstream `nodes/TSL.js` (every TSL function, node and
// constant) and `nodes/Nodes.js` (every node class) against src/nodes, where one flat
// package stands in for both (src/nodes/tsl.mbt and nodes.mbt only document that).
//
// Upstream's modules are loaded under Node; each export is classified by its value:
//   - a node, a `Fn` or a plain function -> `pub let name` or `pub fn name(` with the
//     PORTING.md name (snake_case, `_` after MoonBit keywords, the measured renames);
//   - a class -> `pub(all) struct Name` / `pub struct Name` / `pub type Name`;
//   - other values (constant objects, strings) -> reported as "manual";
//   - deprecated exports (`@deprecated` in their JSDoc or body) are skipped, as PORTING.md
//     says.
// Definitions are found with a regex over src/nodes/*.mbt (tests excluded), so the
// check works while the package does not compile.
//
//   node tools/check_tsl_exports.mjs [--missing] [--strict nodes/display,nodes/gpgpu] [three.js]
//
// Prints a summary per upstream file (`ok`/`missing`); `--missing` lists the missing
// names; `--strict <dirs>` exits 1 if a name exported from those upstream directories
// is missing.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = path.resolve( path.dirname( fileURLToPath( import.meta.url ) ), '..' );
const args = process.argv.slice( 2 );
const flag = ( n ) => args.includes( n );
const opt = ( n ) => {

	const i = args.indexOf( n );
	return i >= 0 ? args[ i + 1 ] : undefined;

};

const positional = args.filter( ( a, i ) => ! a.startsWith( '--' ) && args[ i - 1 ] !== '--strict' );
const upstream = path.resolve( positional[ 0 ] ?? path.join( repoRoot, '.repos/three.js' ) );
const srcDir = path.join( upstream, 'src' );
const strict = ( opt( '--strict' ) ?? '' ).split( ',' ).filter( Boolean );

import { moonName, exportsOf as exportsOfIn, classify as classifyValue, deprecated as deprecatedIn, moonDefinitions, SKIPPED_TSL } from './export_names.mjs';

export { snakeCase } from './export_names.mjs';

const exportsOf = ( entry ) => exportsOfIn( srcDir, entry );
const deprecated = ( file, name ) => deprecatedIn( srcDir, file, name );
// Constants (numbers, strings) are reported as "manual", as before.
const classify = ( value ) => {

	const k = classifyValue( value );
	return k === 'constant' ? 'manual' : k;

};

// --- MoonBit: the definitions in src/nodes ----------------------------------------

const { values: defs, types } = moonDefinitions( path.join( repoRoot, 'src/nodes' ) );

// --- compare ------------------------------------------------------------------------

const report = new Map();
const seen = new Set();
const add = ( file, entry ) => {

	if ( seen.has( `${file}:${entry.name}` ) ) return;
	seen.add( `${file}:${entry.name}` );
	if ( ! report.has( file ) ) report.set( file, [] );
	report.get( file ).push( entry );

};

for ( const entry of [ 'nodes/TSL.js', 'nodes/Nodes.js' ] ) {

	for ( const { name, file, value } of await exportsOf( entry ) ) {

		const kind = classify( value );
		if ( SKIPPED_TSL[ `${file}:${name}` ] ) {

			add( file, { name, want: '-', ok: null, kind: 'skipped', entry } );

		} else if ( deprecated( file, name ) ) {

			add( file, { name, want: '-', ok: null, kind: 'deprecated', entry } );

		} else if ( kind === 'class' ) {

			add( file, { name, want: name, ok: types.has( name ), kind, entry } );

		} else if ( kind === 'value' ) {

			const want = moonName( file, name );
			add( file, { name, want, ok: defs.has( want ), kind, entry } );

		} else {

			add( file, { name, want: '-', ok: null, kind, entry } );

		}

	}

}

let missing = 0, strictMissing = 0, ok = 0, manual = 0;
const files = [ ...report.keys() ].sort();
for ( const f of files ) {

	const list = report.get( f );
	const miss = list.filter( ( e ) => e.ok === false );
	const man = list.filter( ( e ) => e.ok === null );
	ok += list.filter( ( e ) => e.ok === true ).length;
	missing += miss.length;
	manual += man.length;
	const isStrict = strict.some( ( d ) => f.startsWith( d ) );
	if ( isStrict ) strictMissing += miss.length;
	const status = miss.length === 0 ? 'ok     ' : 'missing';
	console.log( `${status} ${f}: ${list.length - miss.length - man.length}/${list.length - man.length}${man.length ? ` (+${man.length} manual, deprecated or skipped: ${man.map( ( e ) => e.name ).join( ' ' )})` : ''}` );
	if ( miss.length && ( flag( '--missing' ) || isStrict ) ) console.log( '        ' + miss.map( ( e ) => `${e.name} -> ${e.want}` ).join( ', ' ) );

}

console.log( `\n${ok} found, ${missing} missing, ${manual} manual, deprecated or skipped` );
if ( strict.length ) {

	console.log( `${strictMissing} missing under ${strict.join( ', ' )}` );
	process.exit( strictMissing ? 1 : 0 );

}
