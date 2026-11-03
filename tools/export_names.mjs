// Shared by tools/check_tsl_exports.mjs and tools/check_webgpu_exports.mjs: how an
// upstream export is named in the port (PORTING.md "Rules" and "TSL in MoonBit"), how
// upstream re-export lists are resolved, and which MoonBit items a package defines.

import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

// MoonBit keywords, reserved words and prelude names a TSL name collides with.
export const KEYWORDS = new Set( [ 'fn', 'if', 'else', 'loop', 'switch', 'case', 'var', 'const', 'return', 'break', 'continue', 'not', 'type', 'local', 'atomic', 'and', 'struct', 'match', 'let', 'mut', 'while', 'for', 'in', 'enum', 'trait', 'impl', 'with', 'pub', 'priv', 'test', 'try', 'catch', 'raise', 'guard', 'is', 'as', 'extern', 'typealias', 'traitalias', 'derive', 'using', 'lazy', 'defer', 'module', 'move', 'ref', 'static', 'super', 'unsafe', 'use', 'where', 'await', 'async', 'dyn', 'abstract', 'do', 'final', 'macro', 'override', 'package', 'private', 'protected', 'readonly', 'sealed', 'throw', 'virtual', 'yield', 'loop', 'define', 'debug', 'inspect' ] );

// Renames measured by tools/webgpu_deps.mjs (PORTING.md, "Packages") and the TSL table,
// keyed by `<upstream file below src>:<export name>`.
export const RENAMES = {
	'nodes/math/Hash.js:hash': 'hash_tsl',
	'nodes/core/StackNode.js:stack': 'stack',
	'nodes/tsl/TSLCore.js:Stack': 'stack_',
	'nodes/accessors/ReferenceBaseNode.js:reference': 'reference_base',
	'nodes/accessors/ReferenceBaseNode.js:referenceBuffer': 'reference_base_buffer',
	// `call` is `Node::call` (FnNode/ShaderFn), so the TSL function is `function_call`.
	'nodes/code/FunctionCallNode.js:call': 'function_call',
};

// TSL exports the port does not have, with the reason (PORTING.md "TSL in MoonBit").
export const SKIPPED_TSL = {
	'nodes/tsl/TSLCore.js:addMethodChaining': 'chained TSL methods are `Node` methods (PORTING.md "TSL in MoonBit")',
	'nodes/tsl/TSLCore.js:nodeProxy': 'one explicit function per TSL name (PORTING.md "TSL in MoonBit")',
	'nodes/tsl/TSLCore.js:nodeProxyAssignable': 'one explicit function per TSL name (PORTING.md "TSL in MoonBit")',
	'nodes/tsl/TSLCore.js:nodeProxyConstructor': 'one explicit function per TSL name (PORTING.md "TSL in MoonBit")',
	'nodes/tsl/TSLCore.js:nodeImmutable': 'immutables are `pub let`s (PORTING.md "TSL in MoonBit")',
};

// camelCase -> snake_case with digits kept attached (`applyMatrix4` -> `apply_matrix4`,
// `texImage2D` -> `tex_image2d`, `triNoise3D` -> `tri_noise3d`; a digit before a capital
// that starts a word or a number gets `_`: `dot4I8Packed` -> `dot4_i8_packed`), as PORTING.md says.
export const snakeCase = ( s ) => s
	.replace( /\./g, '_' )
	.replace( /([a-z])([A-Z])/g, '$1_$2' )
	.replace( /([0-9])(?=[A-Z][a-z0-9])/g, '$1_' )
	.replace( /([A-Z]+)([A-Z][a-z])/g, '$1_$2' )
	.toLowerCase();

export function moonName( file, name ) {

	const key = `${file}:${name}`;
	if ( RENAMES[ key ] ) return RENAMES[ key ];
	if ( file === 'nodes/materialx/lib/mx_noise.js' || file.endsWith( 'MaterialXNoise.js' ) ) {

		if ( name.startsWith( 'mx_' ) ) return name + '_impl';

	}

	const s = snakeCase( name );
	return KEYWORDS.has( s ) ? s + '_' : s;

}

const stripComments = ( text ) => text.replace( /\/\*[\s\S]*?\*\//g, '' ).replace( /\/\/[^\n]*/g, '' );

// The `export ... from` lines of an upstream file, `from` resolved below src.
// `names: null` is `export *`; `ns` marks `import * as N from 'x'; export { N }`.
export function reexports( srcDir, file ) {

	const text = stripComments( fs.readFileSync( path.join( srcDir, file ), 'utf8' ) );
	const out = [];
	const rel = ( from ) => path.posix.join( path.posix.dirname( file ), from );
	for ( const m of text.matchAll( /export\s+\*\s+from\s+'([^']+)'/g ) ) out.push( { from: rel( m[ 1 ] ), names: null } );
	for ( const m of text.matchAll( /export\s+\{([^}]*)\}\s+from\s+'([^']+)'/g ) ) {

		const names = m[ 1 ].split( ',' ).map( ( s ) => s.trim() ).filter( Boolean ).map( ( s ) => {

			const [ a, b ] = s.split( /\s+as\s+/ );
			return { local: a.trim(), exported: ( b ?? a ).trim() };

		} );
		out.push( { from: rel( m[ 2 ] ), names } );

	}

	const namespaces = new Map();
	for ( const m of text.matchAll( /import\s+\*\s+as\s+(\w+)\s+from\s+'([^']+)'/g ) ) namespaces.set( m[ 1 ], rel( m[ 2 ] ) );
	for ( const m of text.matchAll( /export\s+\{([^}]*)\}\s*;/g ) ) {

		for ( const n of m[ 1 ].split( ',' ).map( ( s ) => s.trim() ).filter( Boolean ) ) {

			if ( namespaces.has( n ) ) out.push( { from: namespaces.get( n ), names: [ { local: '*', exported: n } ], ns: true } );

		}

	}

	return out;

}

// Every export of `entry` (a file below src) as `{ name, file, value, ns }`, where `file`
// is the upstream file that defines it: `export *` and `export { x } from` are followed
// to the defining file, `export { default as X }` names the file of the default export,
// and `ns` is set for namespace exports (`file` is then the namespace's module).
export async function resolveExports( srcDir, entry, memo = new Map() ) {

	if ( memo.has( entry ) ) return memo.get( entry );
	const mod = await import( pathToFileURL( path.join( srcDir, entry ) ).href );
	const origin = new Map();
	for ( const r of reexports( srcDir, entry ) ) {

		if ( r.names === null ) {

			for ( const e of await resolveExports( srcDir, r.from, memo ) ) if ( ! origin.has( e.name ) && e.name !== 'default' ) origin.set( e.name, e );

		} else if ( r.ns ) {

			origin.set( r.names[ 0 ].exported, { name: r.names[ 0 ].exported, file: r.from, ns: true } );

		} else {

			for ( const n of r.names ) {

				let e = { name: n.exported, file: r.from };
				if ( n.local !== 'default' ) {

					const inner = ( await resolveExports( srcDir, r.from, memo ) ).find( ( x ) => x.name === n.local );
					if ( inner ) e = { ...inner, name: n.exported };

				}

				origin.set( n.exported, e );

			}

		}

	}

	const list = [];
	for ( const k of Object.keys( mod ) ) {

		const o = origin.get( k ) ?? { name: k, file: entry };
		list.push( { name: k, file: o.file, ns: o.ns === true, value: mod[ k ] } );

	}

	memo.set( entry, list );
	return list;

}

// Classic G4 form: like resolveExports, but `export *` names attributed only through nested
// `export *`s (enough for nodes/TSL.js and nodes/Nodes.js).
export async function exportsOf( srcDir, entry ) {

	return ( await resolveExports( srcDir, entry ) ).filter( ( e ) => e.name !== 'default' );

}

export function classify( value ) {

	if ( value === null || value === undefined ) return 'manual';
	if ( value.isNode === true || value.isFn === true ) return 'value';
	if ( typeof value === 'function' ) {

		const src = Function.prototype.toString.call( value );
		if ( /^class\b/.test( src ) ) return 'class';
		return 'value';

	}

	if ( typeof value === 'number' || typeof value === 'string' ) return 'constant';
	return 'manual';

}

const sources = {};
export function deprecated( srcDir, file, name ) {

	const text = ( sources[ file ] ??= fs.readFileSync( path.join( srcDir, file ), 'utf8' ) );
	// `export class X`, or `class X` exported by a later `export { X }`.
	const m = new RegExp( `^(?:export\\s+)?(?:const|function|class)\\s+${ name.replace( /\$/g, '\\$' ) }\\b`, 'm' ).exec( text );
	if ( ! m ) return false;
	const before = text.slice( 0, m.index );
	const doc = /\/\*\*((?:(?!\*\/)[\s\S])*)\*\/\s*$/.exec( before );
	if ( doc && doc[ 1 ].includes( '@deprecated' ) ) return true;
	// A class is deprecated by its own JSDoc only (its body documents deprecated members).
	if ( /\bclass\s/.test( m[ 0 ] ) ) return false;
	const rest = text.slice( m.index + m[ 0 ].length );
	const next = rest.search( /\n(?:export\s|\/\*\*)/ );
	return ( next >= 0 ? rest.slice( 0, next ) : rest ).includes( '@deprecated' );

}

// The public items one MoonBit package directory defines (tests excluded), found with
// regexes so the check works while the package does not compile: `values` (pub let/fn/
// const/extern fn) and `types` (struct/type/enum/suberror/trait; `traits` lists the
// traits). `using` maps names a package re-exports with `pub using @pkg { ... }` to the
// alias they come from.
export function moonDefinitions( dir ) {

	const values = new Set(), types = new Set(), traits = new Set(), using = new Map();
	if ( ! fs.existsSync( dir ) ) return { values, types, traits, using };
	for ( const f of fs.readdirSync( dir ) ) {

		if ( ! f.endsWith( '.mbt' ) || f.endsWith( '_test.mbt' ) ) continue;
		const text = fs.readFileSync( path.join( dir, f ), 'utf8' );
		for ( const m of text.matchAll( /^pub (?:let|const|fn(?:\[[^\]]*\])?|async fn|extern "js" fn) ([A-Za-z_][A-Za-z0-9_]*)\b/gm ) ) values.add( m[ 1 ] );
		for ( const m of text.matchAll( /^pub(?:\((?:all|open|readonly)\))? (struct|type|enum|suberror|trait) ([A-Z][A-Za-z0-9_]*)\b/gm ) ) {

			types.add( m[ 2 ] );
			if ( m[ 1 ] === 'trait' ) traits.add( m[ 2 ] );

		}

		for ( const m of text.matchAll( /^pub using @(\w+)\s*\{([^}]*)\}/gm ) ) {

			for ( let item of m[ 2 ].split( ',' ).map( ( s ) => s.trim() ).filter( Boolean ) ) {

				const sort = /^(type|trait)\s+/.exec( item )?.[ 1 ] ?? 'value';
				item = item.replace( /^(type|trait)\s+/, '' );
				using.set( item, m[ 1 ] );
				if ( sort === 'value' ) values.add( item ); else types.add( item );
				if ( sort === 'trait' ) traits.add( item );

			}

		}

	}

	return { values, types, traits, using };

}
