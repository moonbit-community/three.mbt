#!/usr/bin/env node
// Checks the three WebGPU entry points of upstream, `Three.WebGPU.js`, `Three.TSL.js` and
// `Three.WebGPU.Nodes.js`, against the port, and generates their facade package
// src/webgpu (G11, PORTING.md "Packages"). Extends tools/check_tsl_exports.mjs (G4),
// which checks nodes/TSL.js and nodes/Nodes.js against src/nodes alone.
//
// Upstream's entry files are loaded under Node and every export is followed to the file
// that defines it (`export *`, `export { x } from`, `export { default as X }`,
// `import * as N; export { N }`). Each export then has a MoonBit name and a package:
//   - a class -> the type `Name` (`pub(all) struct`, `pub type`, ...);
//   - a function, node or `Fn` -> `snake_case` (PORTING.md's rules and renames,
//     tools/export_names.mjs);
//   - a number or string constant -> `pub const Name` (constants keep upstream's names);
//   - a constant object (`MOUSE`, `TimestampQuery`, `NodeType`) -> its members:
//     `MOUSE_LEFT`, `TimestampQuery_COMPUTE`, `node_type_float`, or the type `Name`
//     with static members (`NodeUpdateType::frame()`), plus `snake_case` for an instance
//     (`DefaultLoadingManager` -> `default_loading_manager`);
//   - a namespace (`RendererUtils`, `NodeUtils`, `MathUtils`) -> its member functions,
//     which the facade wraps as static methods of a type of that name
//     (`RendererUtils::save_renderer_state`); `TSL` -> the Three.TSL.js names;
//   - deprecated exports and the documented skips (SKIPPED below) are skipped.
// The package comes from the upstream path (PACKAGES); a name found in another package
// only is accepted and noted.
//
// The facade is `pub using @pkg { ... }` per package (MoonBit has no `export *`), so
// `@webgpu.WebGPURenderer::new()`, `@webgpu.MeshBasicNodeMaterial::new()`,
// `@webgpu.Scene::new()` and `@webgpu.uv()` work from one import. Names that two packages
// define (`log`: utils.js's console function in Three.WebGPU.js, TSL's `log` in
// Three.TSL.js) keep the TSL one; the tool lists them.
//
//   node tools/check_webgpu_exports.mjs [--missing] [--write] [three.js]
//
// Prints a summary per entry file and per kind; `--missing` lists missing names. Without
// `--write` the generated files are compared with src/webgpu (stale -> exit 1); `--write`
// writes them. Exits 1 if an export is missing.

import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { moonName, snakeCase, resolveExports, classify, deprecated, moonDefinitions, SKIPPED_TSL } from './export_names.mjs';

const repoRoot = path.resolve( path.dirname( fileURLToPath( import.meta.url ) ), '..' );
const args = process.argv.slice( 2 );
const flag = ( n ) => args.includes( n );
const positional = args.filter( ( a ) => ! a.startsWith( '--' ) );
const upstream = path.resolve( positional[ 0 ] ?? path.join( repoRoot, '.repos/three.js' ) );
const srcDir = path.join( upstream, 'src' );
const outDir = path.join( repoRoot, 'src/webgpu' );

const ENTRIES = [ 'Three.TSL.js', 'Three.WebGPU.js', 'Three.WebGPU.Nodes.js' ];

// Upstream path prefix -> port package (PORTING.md's package tables), first match wins.
const PACKAGES = [
	[ 'renderers/webgpu/', 'renderers/webgpu' ],
	[ 'renderers/webgl-fallback/', 'renderers/webgl_fallback' ],
	[ 'renderers/common/', 'nodes' ],
	[ 'nodes/', 'nodes' ],
	[ 'materials/nodes/', 'nodes' ],
	[ 'loaders/nodes/', 'loaders/nodes' ],
	[ 'lights/webgpu/', 'core' ],
	[ 'renderers/shaders/', 'renderers/shaders' ],
	[ 'renderers/', 'renderers/webgl' ],
	[ 'extras/PMREMGenerator.js', 'renderers/webgl' ],
	[ 'math/', 'math' ],
	[ 'geometries/', 'geometries' ],
	[ 'extras/', 'extras' ],
	[ 'animation/', 'animation' ],
	[ 'audio/', 'audio' ],
	[ 'helpers/', 'helpers' ],
	[ 'loaders/', 'loaders' ],
	[ '', 'core' ], // core, textures, materials, objects, cameras, lights, scenes, constants.js, utils.js
];
const packageOf = ( file ) => PACKAGES.find( ( [ p ] ) => file.startsWith( p ) )[ 1 ];

// Import aliases of the facade (`loaders/nodes` and `renderers/webgpu` would clash with
// `nodes` and with the facade's own name).
const ALIAS = {
	'core': 'core', 'math': 'math', 'geometries': 'geometries', 'extras': 'extras',
	'animation': 'animation', 'audio': 'audio', 'helpers': 'helpers', 'loaders': 'loaders',
	'loaders/nodes': 'loaders_nodes', 'nodes': 'nodes', 'renderers/webgl': 'webgl',
	'renderers/shaders': 'shaders', 'renderers/webgpu': 'renderers_webgpu',
	'renderers/webgl_fallback': 'webgl_fallback',
};
const PACKAGE_ORDER = Object.keys( ALIAS );

// MoonBit names that differ from the mechanical rule, `<file>:<export>` -> name.
const NAMES = {
	// The `.Nodes` variant of WebGPURenderer (BasicNodeLibrary only) is its own type: one
	// package cannot hold two `WebGPURenderer`s.
	'renderers/webgpu/WebGPURenderer.Nodes.js:WebGPURenderer': 'WebGPURendererNodes',
	// `mergeContext( target, source )` is `NodeContext::merge` (core_node_builder.mbt).
	'nodes/core/NodeUtils.js:mergeContext': 'NodeContext::merge',
};

// Exports the port does not have, with the reason (PORTING.md).
const SKIPPED = {
	...SKIPPED_TSL,
	'utils.js:setConsoleFunction': 'logging stays on `println` (PORTING.md "Rules"; src/core/utils.mbt)',
	'utils.js:getConsoleFunction': 'logging stays on `println` (PORTING.md "Rules"; src/core/utils.mbt)',
};

// MoonBit types the port's public signatures use where upstream takes plain JS values
// (typed arrays, `material` slots, TSL arguments): not upstream exports, but a user of the
// facade needs them, so it re-exports them too (Three.WebGPU.js section).
// Port-specific forms of TSL names (PORTING.md "TSL in MoonBit"): `vec3_of([x, y, z])`
// for each `X` with an `X_of`, and these.
const TSL_FORMS = [ 'if_value', 'array_of_type', 'node_context', 'loop_range' ];

const SUPPORT = {
	'core': [ 'JsValue', 'TypedArray', 'TypedArrayInit', 'ArrayBuffer', 'MaterialSlot', 'TextureImage', 'SceneBackground', 'SceneFog' ],
	'nodes': [ 'IntoTsl', 'TslValue', 'ShaderFn', 'FnInputs', 'FnLayout', 'FnLayoutArg', 'ComputeDispatchSize' ],
};

// --- MoonBit side -----------------------------------------------------------------

const defs = {};
for ( const pkg of PACKAGE_ORDER ) defs[ pkg ] = moonDefinitions( path.join( repoRoot, 'src', pkg ) );

// The package that really defines `name` (follows `pub using` re-exports).
function definer( pkg, name, sort ) {

	const has = ( p ) => ( sort === 'value' ? defs[ p ].values : defs[ p ].types ).has( name );
	if ( has( pkg ) && ! defs[ pkg ].using.has( name ) ) return pkg;
	if ( ! has( pkg ) ) return null;
	return PACKAGE_ORDER.find( ( p ) => has( p ) && ! defs[ p ].using.has( name ) ) ?? pkg;

}

// Looks `name` up in `pkg`, else in any package: `{ pkg, name, sort, note }` or null.
function lookup( pkg, name, sort ) {

	const d = definer( pkg, name, sort );
	if ( d ) return { pkg: d, name, sort: sort === 'type' && defs[ d ].traits.has( name ) ? 'trait' : sort };
	const others = PACKAGE_ORDER.filter( ( p ) => ( sort === 'value' ? defs[ p ].values : defs[ p ].types ).has( name ) && ! defs[ p ].using.has( name ) );
	if ( others.length === 1 ) return { pkg: others[ 0 ], name, sort: sort === 'type' && defs[ others[ 0 ] ].traits.has( name ) ? 'trait' : sort, note: `in ${others[ 0 ]}, not ${pkg}` };
	return null;

}

// Signatures for the namespace wrappers, from `moon ide doc "@pkg"` (falls back to the
// package's pkg.generated.mbti when the package does not check).
const signatures = {};
function signatureOf( pkg, fn ) {

	if ( ! signatures[ pkg ] ) {

		let text = '';
		try {

			text = execFileSync( 'moon', [ 'ide', 'doc', `@${pkg.split( '/' ).pop()}` ], { cwd: path.join( repoRoot, 'src', pkg ), encoding: 'utf8', stdio: [ 'ignore', 'pipe', 'ignore' ] } );

		} catch {}

		if ( ! text.includes( `package "bobzhang/three/${pkg}"` ) ) text = fs.readFileSync( path.join( repoRoot, 'src', pkg, 'pkg.generated.mbti' ), 'utf8' );
		signatures[ pkg ] = text.split( '\n' );

	}

	const re = new RegExp( `^\\s*pub fn(?:\\[[^\\]]*\\])? ${fn}\\(` );
	return signatures[ pkg ].find( ( l ) => re.test( l ) )?.trim() ?? null;

}

// --- upstream side ----------------------------------------------------------------

const memo = new Map();
const entries = {};
for ( const e of ENTRIES ) entries[ e ] = await resolveExports( srcDir, e, memo );

const results = []; // { entry, name, file, kind, items: [...], skip, missing: [...], note }

function constObjectMembers( file, name, value ) {

	const pkg = packageOf( file );
	const items = [], missing = [], notes = [];
	const asType = lookup( pkg, name, 'type' );
	if ( asType ) items.push( asType );
	const inst = lookup( pkg, snakeCase( name ), 'value' );
	if ( inst ) items.push( inst );
	if ( ! Array.isArray( value ) && Object.getPrototypeOf( value ) === Object.prototype && ! inst ) {

		for ( const k of Object.keys( value ) ) {

			const v = value[ k ];
			if ( typeof v === 'function' ) {

				const it = lookup( pkg, moonName( file, k ), 'value' );
				if ( it ) items.push( it ); else missing.push( `${name}.${k}` );
				continue;

			}

			// A type of that name with static members (`NodeUpdateType::frame()`) covers them.
			const cands = [ `${name}_${k}`, `${snakeCase( name )}_${snakeCase( k )}`.toLowerCase() ];
			const it = cands.map( ( c ) => lookup( pkg, c, 'value' ) ).find( Boolean );
			if ( it ) items.push( it ); else if ( ! asType ) missing.push( `${name}.${k}` );

		}

	}

	if ( ! items.length && ! missing.length ) missing.push( name );
	return { items, missing, notes };

}

// A namespace: its member functions become static methods of a wrapper type.
async function namespaceMembers( nsFile, name ) {

	const pkg = packageOf( nsFile );
	const members = [], missing = [], skipped = [];
	const list = await resolveExports( srcDir, nsFile, memo );
	for ( const m of list ) {

		if ( m.name === 'default' ) continue;
		const key = `${m.file}:${m.name}`;
		const target = NAMES[ key ] ?? moonName( m.file, m.name );
		if ( typeof m.value !== 'function' ) {

			const c = lookup( pkg, m.name, 'value' );
			if ( c ) skipped.push( `${name}.${m.name} (a constant: ${ALIAS[ c.pkg ] ? '@' + ALIAS[ c.pkg ] : c.pkg}.${m.name})` );
			else missing.push( `${name}.${m.name}` );
			continue;

		}

		const sig = signatureOf( pkg, target );
		if ( sig ) members.push( { upstream: m.name, method: moonName( m.file, m.name ), target, sig, pkg } );
		else missing.push( `${name}.${m.name} -> ${target}` );

	}

	return { members, missing, skipped };

}

const namespaces = []; // { entry, name, file, members }

// A namespace object or static class: functions are wrapped, constants are noted.
function objectNamespace( r, entry, name, file, pkg, members0 ) {

	r.kind = 'namespace';
	const members = [], missing = [], skipped = [];
	for ( const [ k, v ] of members0 ) {

		if ( typeof v !== 'function' ) {

			const c = lookup( pkg, k, 'value' );
			if ( c ) skipped.push( `${name}.${k} (a constant: @${ALIAS[ c.pkg ]}.${k})` ); else missing.push( `${name}.${k}` );
			continue;

		}

		const target = NAMES[ `${file}:${k}` ] ?? moonName( file, k );
		const sig = signatureOf( pkg, target );
		if ( sig ) members.push( { upstream: k, method: moonName( file, k ), target, sig, pkg } ); else missing.push( `${name}.${k} -> ${target}` );

	}

	r.missing = missing;
	r.note = skipped.length ? 'not wrapped: ' + skipped.join( ', ' ) : null;
	if ( ! namespaces.some( ( x ) => x.name === name ) ) namespaces.push( { entry, name, file, members } );

}
for ( const entry of ENTRIES ) {

	for ( const { name, file, value, ns } of entries[ entry ] ) {

		const key = `${file}:${name}`;
		const r = { entry, name, file, items: [], missing: [], skip: null, note: null };
		results.push( r );
		if ( SKIPPED[ key ] ) {

			r.kind = 'skipped'; r.skip = SKIPPED[ key ]; continue;

		}

		if ( ns ) {

			r.kind = 'namespace';
			if ( name === 'TSL' ) {

				r.skip = 'the Three.TSL.js names are this package\'s (three_tsl.mbt)'; continue;

			}

			const n = await namespaceMembers( file, name );
			r.missing = n.missing;
			r.note = n.skipped.length ? 'not wrapped: ' + n.skipped.join( ', ' ) : null;
			if ( ! namespaces.some( ( x ) => x.name === name ) ) namespaces.push( { entry, name, file, members: n.members } );
			continue;

		}

		const kind = classify( value );
		const pkg = packageOf( file );
		if ( deprecated( srcDir, file, name ) ) {

			// Skipped (PORTING.md), but re-exported where the port has it anyway.
			r.kind = 'deprecated';
			const it = kind === 'class' ? lookup( pkg, NAMES[ key ] ?? name, 'type' ) : lookup( pkg, kind === 'constant' ? name : NAMES[ key ] ?? moonName( file, name ), 'value' );
			if ( it ) r.items.push( it ); else r.skip = '@deprecated upstream';
			continue;

		}

		r.kind = kind;
		if ( kind === 'class' ) {

			const it = lookup( pkg, NAMES[ key ] ?? name, 'type' );
			const statics = Object.getOwnPropertyNames( value ).filter( ( k ) => typeof value[ k ] === 'function' );
			if ( it ) { r.items.push( it ); r.note = it.note; } else if ( statics.length && Object.getOwnPropertyNames( value.prototype ).length === 1 ) {

				// A class of static methods only (AnimationUtils) is a namespace too.
				objectNamespace( r, entry, name, file, pkg, statics.map( ( k ) => [ k, value[ k ] ] ) );

			} else r.missing.push( name );

		} else if ( kind === 'value' ) {

			const it = lookup( pkg, NAMES[ key ] ?? moonName( file, name ), 'value' );
			if ( it ) { r.items.push( it ); r.note = it.note; } else r.missing.push( `${name} -> ${moonName( file, name )}` );

		} else if ( kind === 'constant' ) {

			const it = lookup( pkg, name, 'value' );
			if ( it ) { r.items.push( it ); r.note = it.note; } else r.missing.push( name );

		} else {

			// Objects: a plain object of a namespace's functions (MathUtils) is a namespace.
			if ( value && Object.getPrototypeOf( value ) === Object.prototype && Object.values( value ).length && Object.values( value ).every( ( v ) => typeof v === 'function' || typeof v === 'number' ) && Object.values( value ).some( ( v ) => typeof v === 'function' ) && ! lookup( pkg, name, 'type' ) ) {

				objectNamespace( r, entry, name, file, pkg, Object.entries( value ) );

			} else {

				r.kind = 'object';
				const o = constObjectMembers( file, name, value );
				r.items = o.items; r.missing = o.missing;

			}

		}

	}

}

// --- facade -----------------------------------------------------------------------

const support = { entry: 'Three.WebGPU.js', name: '(MoonBit support types)', file: '-', kind: 'support', items: [], missing: [], skip: null, note: null };
for ( const [ pkg, names ] of Object.entries( SUPPORT ) ) {

	for ( const n of names ) {

		const it = lookup( pkg, n, 'type' );
		if ( it ) support.items.push( it ); else support.missing.push( `${pkg}.${n}` );

	}

}

results.push( support );

const forms = { entry: 'Three.TSL.js', name: '(port-specific TSL forms)', file: '-', kind: 'tsl form', items: [], missing: [], skip: null, note: null };
const tslValues = new Set( results.filter( ( r ) => r.entry === 'Three.TSL.js' ).flatMap( ( r ) => r.items ).filter( ( it ) => it.sort === 'value' && it.pkg === 'nodes' ).map( ( it ) => it.name ) );
for ( const n of [ ...[ ...tslValues ].map( ( v ) => v + '_of' ).filter( ( v ) => defs.nodes.values.has( v ) ), ...TSL_FORMS ] ) {

	const it = lookup( 'nodes', n, 'value' );
	if ( it ) forms.items.push( it ); else forms.missing.push( n );

}

results.push( forms );

// One MoonBit name per sort (values and types are separate namespaces). A later entry's
// item never replaces an earlier one; Three.TSL.js comes first, so TSL names win.
const taken = new Map(); // `${sortKey}:${name}` -> { item, entry, upstream }
const clashes = [];
const facade = { 'Three.TSL.js': [], 'Three.WebGPU.js': [], 'Three.WebGPU.Nodes.js': [] };
for ( const r of results ) {

	for ( const it of r.items ) {

		const k = `${it.sort === 'value' ? 'v' : 't'}:${it.name}`;
		const prev = taken.get( k );
		if ( prev ) {

			if ( prev.item.pkg !== it.pkg && ! clashes.some( ( c ) => c.startsWith( `${it.name}: ` ) && c.includes( r.file ) ) ) clashes.push( `${it.name}: ${r.entry} ${r.file} (@${ALIAS[ it.pkg ]}) is not re-exported; ${prev.entry} ${prev.upstream} (@${ALIAS[ prev.item.pkg ]}) is` );
			continue;

		}

		taken.set( k, { item: it, entry: r.entry, upstream: r.file } );
		facade[ r.entry ].push( it );

	}

}

for ( const n of namespaces ) {

	if ( taken.has( `t:${n.name}` ) ) clashes.push( `${n.name}: namespace type clashes with a type` );
	taken.set( `t:${n.name}`, { item: { pkg: 'webgpu', name: n.name }, entry: n.entry, upstream: n.file } );

}

const BUILTIN_TYPES = new Set( [ 'Double', 'Float', 'Int', 'Int32', 'UInt', 'UInt32', 'Int64', 'UInt64', 'Int16', 'UInt16', 'Byte', 'Bool', 'Char', 'String', 'Unit', 'Array', 'FixedArray', 'Map', 'Bytes', 'Json', 'Iter', 'Ref', 'Result', 'Option', 'Self', 'ArrayView', 'StringView', 'BytesView', 'Error' ] );

function wrapper( ns, m ) {

	// `pub fn name(A, label? : B) -> R` -> parameters and a forwarding call.
	const qualify = ( t ) => t.replace( /(@[\w/]+\.)?\b([A-Z][A-Za-z0-9_]*)\b/g, ( all, q, n ) => n === 'Self' && self ? self : q || BUILTIN_TYPES.has( n ) || tparams.has( n ) ? all : `@${ALIAS[ m.pkg ]}.${n}` ).replace( /@json\.Json\b/g, 'Json' );
	const sig = /^pub fn(\[[^\]]*\])? ([\w:]+)\((.*)\) -> (.*)$/.exec( m.sig );
	const tparams = new Set( [ ...( sig[ 1 ] ?? '' ).matchAll( /\b([A-Z]\w*)\s*:/g ) ].map( ( x ) => x[ 1 ] ) );
	const self = m.target.includes( '::' ) ? `@${ALIAS[ m.pkg ]}.${m.target.split( '::' )[ 0 ]}` : null;
	const params = [];
	let depth = 0, cur = '';
	for ( const ch of sig[ 3 ] ) {

		if ( ch === '(' || ch === '[' ) depth ++;
		if ( ch === ')' || ch === ']' ) depth --;
		if ( ch === ',' && depth === 0 ) { params.push( cur.trim() ); cur = ''; } else cur += ch;

	}

	if ( cur.trim() ) params.push( cur.trim() );
	const decl = [], call = [];
	params.forEach( ( p, i ) => {

		const lab = /^(\w+)([?~]) : (.*)$/.exec( p );
		if ( lab ) {

			decl.push( `${lab[ 1 ]}${lab[ 2 ] === '?' ? '?' : '~'} : ${qualify( lab[ 3 ] )}` );
			call.push( `${lab[ 1 ]}${lab[ 2 ]}` );

		} else {

			decl.push( `a${i} : ${qualify( p )}` );
			call.push( `a${i}` );

		}

	} );
	const callee = `@${ALIAS[ m.pkg ]}.${m.target}`;
	return `///|\n/// \`${ns}.${m.upstream}\`.\npub fn${sig[ 1 ] ?? ''} ${ns}::${m.method}(${decl.join( ', ' )}) -> ${qualify( sig[ 4 ] )} {\n  ${callee}(${call.join( ', ' )})\n}\n`;

}

function usingBlocks( items ) {

	const byPkg = new Map();
	for ( const it of items ) {

		if ( ! byPkg.has( it.pkg ) ) byPkg.set( it.pkg, [] );
		byPkg.get( it.pkg ).push( it.sort === 'value' ? it.name : `${it.sort} ${it.name}` );

	}

	let out = '';
	for ( const pkg of PACKAGE_ORDER ) {

		if ( ! byPkg.has( pkg ) ) continue;
		out += `\n///|\n/// src/${pkg}.\npub using @${ALIAS[ pkg ]} {\n${byPkg.get( pkg ).map( ( s ) => `  ${s},\n` ).join( '' )}}\n`;

	}

	return out;

}

const GENERATED = '// Generated by `node tools/check_webgpu_exports.mjs --write`; do not edit.';
const files = {};
files[ 'three_tsl.mbt' ] = `// Three.TSL.js: \`import './Three.Core.js'\` and \`export * from './nodes/TSL.js'\`. MoonBit
// has no \`export *\`, so the TSL names of src/nodes are listed here; src/nodes/tsl.mbt
// documents where they are defined. Three.WebGPU.js's \`TSL\` namespace is these names.
${GENERATED}
${usingBlocks( facade[ 'Three.TSL.js' ] )}`;

let nsText = '';
for ( const n of namespaces.filter( ( x ) => x.entry === 'Three.WebGPU.js' ) ) {

	nsText += `\n///|\n/// \`${n.name}\` (${n.file}), a namespace upstream: its functions are static methods here.\n#external\npub type ${n.name}\n`;
	for ( const m of n.members ) nsText += '\n' + wrapper( n.name, m );

}

files[ 'three_web_gpu.mbt' ] = `// Three.WebGPU.js: \`export * from './Three.Core.js'\`, the node materials, the renderer
// classes, \`export * from './nodes/Nodes.js'\` and the \`RendererUtils\` and \`TSL\`
// namespaces. Each upstream export is re-exported from the package that defines it
// (\`pub using\`); namespaces become types with static methods (\`RendererUtils::...\`,
// \`NodeUtils::...\`, \`MathUtils::...\`), and the \`TSL\` names are three_tsl.mbt's.
${GENERATED}
${usingBlocks( facade[ 'Three.WebGPU.js' ] )}${nsText}`;

files[ 'three_web_gpu_nodes.mbt' ] = `// Three.WebGPU.Nodes.js: the exports of Three.WebGPU.js minus \`Renderer\`, \`Backend\`,
// \`WebGLCapabilities\`, \`CubeRenderTarget\`, the storage 3D/array textures and the node
// builders and libraries, with \`WebGPURenderer\` from WebGPURenderer.Nodes.js (only
// BasicNodeLibrary). Its other names are three_web_gpu.mbt's; that renderer is
// \`WebGPURendererNodes\` here, since one package holds both entry points.
${GENERATED}
${usingBlocks( facade[ 'Three.WebGPU.Nodes.js' ] )}`;

const used = new Set( Object.values( facade ).flat().map( ( it ) => it.pkg ) );
for ( const n of namespaces ) for ( const m of n.members ) used.add( m.pkg );
files[ 'moon.pkg' ] = `import {\n${PACKAGE_ORDER.filter( ( p ) => used.has( p ) ).map( ( p ) => `  "bobzhang/three/${p}"${ALIAS[ p ] !== p.split( '/' ).pop() ? ` @${ALIAS[ p ]}` : ''},\n` ).join( '' )}}\n\nwarnings = "-79"\n`;

// --- report -----------------------------------------------------------------------

let missing = 0;
for ( const entry of ENTRIES ) {

	const extra = results.filter( ( r ) => r.entry === entry && r.file === '-' );
	const list = results.filter( ( r ) => r.entry === entry && r.file !== '-' );
	const kinds = {};
	for ( const r of list ) {

		const k = ( kinds[ r.kind ] ??= { ok: 0, missing: 0, skipped: 0 } );
		if ( r.missing.length ) k.missing ++; else if ( r.skip ) k.skipped ++; else k.ok ++;

	}

	const miss = list.filter( ( r ) => r.missing.length );
	missing += miss.length;
	console.log( `${entry}: ${list.length} exports, ${list.length - miss.length} ok or skipped, ${miss.length} missing` );
	for ( const [ k, v ] of Object.entries( kinds ) ) console.log( `  ${k.padEnd( 10 )} ${v.ok} ok${v.skipped ? `, ${v.skipped} skipped` : ''}${v.missing ? `, ${v.missing} missing` : ''}` );
	for ( const r of list.filter( ( r ) => r.skip && r.kind !== 'deprecated' ) ) console.log( `  skip ${r.name} (${r.file}): ${r.skip}` );
	const dep = list.filter( ( r ) => r.kind === 'deprecated' );
	if ( dep.length ) console.log( `  deprecated: ${dep.map( ( r ) => r.name + ( r.items.length ? ' (ported, re-exported)' : ' (not ported)' ) ).join( ', ' )}` );
	for ( const r of list.filter( ( r ) => r.note ) ) console.log( `  note ${r.name}: ${r.note}` );
	if ( flag( '--missing' ) || miss.length ) for ( const r of miss ) console.log( `  missing ${r.name} (${r.file} -> ${packageOf( r.file )}): ${r.missing.join( ', ' )}` );
	for ( const r of extra ) {

		console.log( `  + ${r.name}: ${r.items.length} re-exported${r.missing.length ? `, missing ${r.missing.join( ' ' )}` : ''}` );
		missing += r.missing.length ? 1 : 0;

	}

}

console.log( `\nfacade: ${Object.values( facade ).flat().length} re-exported items, ${namespaces.reduce( ( a, n ) => a + n.members.length, 0 )} namespace wrappers (${namespaces.map( ( n ) => n.name ).join( ', ' )})` );
for ( const c of clashes ) console.log( `  clash ${c}` );

let stale = 0;
if ( flag( '--write' ) ) {

	fs.mkdirSync( outDir, { recursive: true } );
	for ( const [ f, text ] of Object.entries( files ) ) fs.writeFileSync( path.join( outDir, f ), text );
	console.log( `wrote ${Object.keys( files ).map( ( f ) => 'src/webgpu/' + f ).join( ', ' )} (run moonfmt -w on the .mbt files)` );

} else {

	for ( const f of Object.keys( files ) ) {

		const p = path.join( outDir, f );
		// Compare modulo formatting: moonfmt re-wraps lines and drops trailing commas.
		const norm = ( s ) => s.replace( /[\s,]+/g, '' );
		if ( ! fs.existsSync( p ) || norm( fs.readFileSync( p, 'utf8' ) ) !== norm( files[ f ] ) ) {

			console.log( `stale src/webgpu/${f} (run with --write)` );
			stale ++;

		}

	}

}

process.exit( missing || stale ? 1 : 0 );
