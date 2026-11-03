// Import-graph analysis of the upstream WebGPU / TSL directories.
//
//   node tools/webgpu_deps.mjs [three.js/src] [--files] [--json out.json]
//
// Reads every `import ... from` / `export ... from` / `import( ... )` in the
// remaining upstream directories (comments stripped), and reports:
//   1. file-level strongly connected components (Tarjan), largest first;
//   2. the upstream-directory graph and its cycles;
//   3. the proposed MoonBit package layout (`LAYOUT` below): every file's package,
//      the package graph, and a check that it has no cycle. Edges into already
//      ported packages (math, core, ...) are listed as external.
// A cycle in the package graph makes the script exit 1, so it doubles as a check
// that a new file has been put in a package it may live in.

import fs from 'node:fs';
import path from 'node:path';
import url from 'node:url';

const here = path.dirname( url.fileURLToPath( import.meta.url ) );
const args = process.argv.slice( 2 );
const flag = ( name ) => args.includes( name );
const opt = ( name ) => {

	const i = args.indexOf( name );
	return i >= 0 ? args[ i + 1 ] : undefined;

};
const VALUED = [ '--json', '--closure' ];
const positional = args.filter( ( a, i ) => ! a.startsWith( '--' ) && ! ( i > 0 && VALUED.includes( args[ i - 1 ] ) ) );
const SRC = path.resolve( positional[ 0 ] ?? path.join( here, '..', '.repos', 'three.js', 'src' ) );

// Upstream directories still to port, and the entry points.
const TARGET_DIRS = [
	'nodes', 'materials/nodes', 'lights/webgpu', 'loaders/nodes',
	'renderers/common', 'renderers/webgpu', 'renderers/webgl-fallback',
];
const ENTRY_FILES = [ 'Three.WebGPU.js', 'Three.TSL.js', 'Three.WebGPU.Nodes.js' ];

// ---------------------------------------------------------------------------
// The proposed layout. Order matters: first match wins. Each entry maps an
// upstream path prefix (relative to src, no extension) to a MoonBit package
// under `src/`. Files of one SCC must share a package.

export const LAYOUT = [
	// Entry points: re-export everything; they become the facade package.
	[ 'Three.WebGPU.Nodes', 'webgpu' ],
	[ 'Three.WebGPU', 'webgpu' ],
	[ 'Three.TSL', 'webgpu' ],

	// Already ported in core (IESSpotLight, ProjectorLight).
	[ 'lights/webgpu/', 'core' ],

	// The node system and everything that names a renderer class from inside it.
	[ 'nodes/', 'nodes' ],
	[ 'materials/nodes/', 'nodes' ],
	[ 'renderers/common/', 'nodes' ],

	// Backends. WebGPURenderer imports WebGLBackend, never the reverse.
	[ 'renderers/webgpu/', 'renderers/webgpu' ],
	[ 'renderers/webgl-fallback/', 'renderers/webgl_fallback' ],

	// Loaders for node JSON.
	[ 'loaders/nodes/', 'loaders/nodes' ],
];

// MoonBit file names: one upstream file is one `.mbt` file in its package, prefixed by
// its directory below the package root so names stay unique in a flat package
// (`nodes/core/Node.js` -> `core_node.mbt`, `renderers/common/nodes/NodeUniform.js` ->
// `common_nodes_node_uniform.mbt`). The prefix is not repeated (`tsl/TSLCore.js` ->
// `tsl_core.mbt`).
const ROOTS = [
	[ 'nodes/', '' ], [ 'materials/nodes/', 'materials/' ], [ 'renderers/common/', 'common/' ],
	[ 'renderers/webgpu/', '' ], [ 'renderers/webgl-fallback/', '' ], [ 'loaders/nodes/', '' ],
	[ 'lights/webgpu/', '' ],
];

export const snakeCase = ( s ) => s
	.replace( /\./g, '_' )
	.replace( /([a-z0-9])([A-Z])/g, '$1_$2' )
	.replace( /([A-Z]+)([A-Z][a-z])/g, '$1_$2' )
	.toLowerCase();

export function mbtFileOf( f ) {

	let rest = f;
	for ( const [ root, prefix ] of ROOTS ) if ( f.startsWith( root ) ) {

		rest = prefix + f.slice( root.length );
		break;

	}

	const parts = rest.split( '/' );
	const base = snakeCase( parts.pop() );
	const dir = parts.map( snakeCase ).join( '_' );
	if ( dir === '' ) return base + '.mbt';
	return ( base.startsWith( dir + '_' ) ? base : dir + '_' + base ) + '.mbt';

}

// Already ported packages and the upstream directories they hold.
const PORTED = [
	[ 'math/', 'math' ],
	[ 'core/', 'core' ], [ 'textures/', 'core' ], [ 'materials/', 'core' ], [ 'objects/', 'core' ],
	[ 'cameras/', 'core' ], [ 'lights/', 'core' ], [ 'scenes/', 'core' ], [ 'constants', 'core' ],
	[ 'utils', 'core' ], [ 'Three.Core', 'core' ],
	[ 'extras/', 'extras' ], [ 'geometries/', 'geometries' ],
	[ 'renderers/shaders/', 'renderers/shaders' ], [ 'renderers/webgl/', 'renderers/webgl' ],
	[ 'renderers/WebGL', 'renderers/webgl' ], [ 'renderers/webxr/', 'renderers/webgl' ],
	[ 'animation/', 'animation' ], [ 'audio/', 'audio' ], [ 'helpers/', 'helpers' ],
	[ 'loaders/', 'loaders' ],
];

// ---------------------------------------------------------------------------

function listJs( dir ) {

	const out = [];
	for ( const e of fs.readdirSync( dir, { withFileTypes: true } ) ) {

		const p = path.join( dir, e.name );
		if ( e.isDirectory() ) out.push( ...listJs( p ) );
		else if ( e.name.endsWith( '.js' ) ) out.push( p );

	}

	return out;

}

const rel = ( abs ) => path.relative( SRC, abs ).replace( /\\/g, '/' ).replace( /\.js$/, '' );

function stripComments( text ) {

	// Block comments (JSDoc examples contain `import` lines), then whole-line comments.
	return text.replace( /\/\*[\s\S]*?\*\//g, '' ).replace( /^\s*\/\/.*$/gm, '' );

}

function importsOf( file ) {

	const text = stripComments( fs.readFileSync( file, 'utf8' ) );
	const specs = new Set();
	const re = /(?:^|[;\n])\s*(?:import|export)\s+(?:[^'";]*?\s+from\s+)?['"]([^'"]+)['"]|import\(\s*['"]([^'"]+)['"]\s*\)/g;
	let m;
	while ( ( m = re.exec( text ) ) ) specs.add( m[ 1 ] ?? m[ 2 ] );
	const out = [];
	for ( const s of specs ) {

		if ( ! s.startsWith( '.' ) ) continue;
		out.push( rel( path.resolve( path.dirname( file ), s ) ) );

	}

	return out;

}

const lineCount = ( file ) => fs.readFileSync( file, 'utf8' ).split( '\n' ).length;

const files = [
	...TARGET_DIRS.flatMap( ( d ) => listJs( path.join( SRC, d ) ) ),
	...ENTRY_FILES.map( ( f ) => path.join( SRC, f ) ),
];
const nodes = files.map( rel );
const isTarget = new Set( nodes );
const lines = new Map( files.map( ( f ) => [ rel( f ), lineCount( f ) ] ) );
const edges = new Map(); // target file -> [target files]
const external = new Map(); // target file -> [non-target files]
for ( const f of files ) {

	const r = rel( f );
	const deps = importsOf( f );
	edges.set( r, deps.filter( ( d ) => isTarget.has( d ) ) );
	external.set( r, deps.filter( ( d ) => ! isTarget.has( d ) ) );

}

function tarjan( vertices, succ ) {

	let index = 0;
	const idx = new Map(), low = new Map(), onStack = new Set(), stack = [], comps = [];
	const strong = ( v ) => {

		idx.set( v, index ); low.set( v, index ); index ++;
		stack.push( v ); onStack.add( v );
		for ( const w of succ( v ) ) {

			if ( ! idx.has( w ) ) {

				strong( w ); low.set( v, Math.min( low.get( v ), low.get( w ) ) );

			} else if ( onStack.has( w ) ) low.set( v, Math.min( low.get( v ), idx.get( w ) ) );

		}

		if ( low.get( v ) === idx.get( v ) ) {

			const comp = [];
			let w;
			do {

				w = stack.pop(); onStack.delete( w ); comp.push( w );

			} while ( w !== v );
			comps.push( comp );

		}

	};

	for ( const v of vertices ) if ( ! idx.has( v ) ) strong( v );
	return comps;

}

const dirOf = ( f ) => {

	if ( ! f.includes( '/' ) ) return '(entry)';
	return f.slice( 0, f.lastIndexOf( '/' ) );

};

const packageOf = ( f, table ) => {

	for ( const [ prefix, pkg ] of table ) if ( f.startsWith( prefix ) ) return pkg;
	return undefined;

};

const report = { files: nodes.length, lines: [ ...lines.values() ].reduce( ( a, b ) => a + b, 0 ) };

// 1. File-level SCCs.
const fileSccs = tarjan( nodes, ( v ) => edges.get( v ) ).filter( ( c ) => c.length > 1 )
	.sort( ( a, b ) => b.length - a.length );
report.fileSccs = fileSccs.map( ( c ) => ( {
	size: c.length,
	lines: c.reduce( ( a, f ) => a + lines.get( f ), 0 ),
	dirs: Object.entries( c.reduce( ( m, f ) => ( m[ dirOf( f ) ] = ( m[ dirOf( f ) ] ?? 0 ) + 1, m ), {} ) )
		.sort( ( a, b ) => b[ 1 ] - a[ 1 ] ),
	files: c.sort(),
} ) );

console.log( `# ${nodes.length} files, ${report.lines} lines under ${SRC}` );
console.log( `\n## File-level SCCs (size > 1): ${fileSccs.length}` );
for ( const s of report.fileSccs ) {

	console.log( `- ${s.size} files, ${s.lines} lines: ${s.dirs.map( ( [ d, n ] ) => `${d} ${n}` ).join( ', ' )}` );
	if ( flag( '--files' ) || s.size <= 6 ) console.log( '    ' + s.files.join( '\n    ' ) );

}

const inScc = new Set( fileSccs.flat() );
console.log( `\nFiles in no cycle: ${nodes.length - inScc.size} of ${nodes.length}` );

// 2. Directory graph.
const dirs = [ ...new Set( nodes.map( dirOf ) ) ].sort();
const dirEdges = new Map( dirs.map( ( d ) => [ d, new Map() ] ) );
for ( const [ f, ds ] of edges ) for ( const d of ds ) {

	const a = dirOf( f ), b = dirOf( d );
	if ( a !== b ) dirEdges.get( a ).set( b, ( dirEdges.get( a ).get( b ) ?? 0 ) + 1 );

}

const dirSccs = tarjan( dirs, ( d ) => [ ...dirEdges.get( d ).keys() ] ).filter( ( c ) => c.length > 1 );
report.dirSccs = dirSccs.map( ( c ) => c.sort() );
console.log( `\n## Directory-level SCCs: ${dirSccs.length}` );
for ( const c of report.dirSccs ) console.log( `- ${c.length} dirs: ${c.join( ', ' )}` );

// Cross-directory edges that close the nodes <-> renderers/common cycle, as evidence.
const crossing = ( a, b ) => [ ...edges ].flatMap( ( [ f, ds ] ) => dirOf( f ).startsWith( a ) ?
	ds.filter( ( d ) => dirOf( d ).startsWith( b ) ).map( ( d ) => `${f} -> ${d}` ) : [] );
report.nodesToCommon = crossing( 'nodes', 'renderers/common' );
report.commonToNodes = crossing( 'renderers/common', 'nodes' );
report.materialsToCommon = crossing( 'materials/nodes', 'renderers/common' );
report.nodesToMaterials = crossing( 'nodes', 'materials/nodes' );
report.nodesToBackends = [ ...crossing( 'nodes', 'renderers/webgpu' ), ...crossing( 'nodes', 'renderers/webgl-fallback' ) ];
report.commonToBackends = [ ...crossing( 'renderers/common', 'renderers/webgpu' ), ...crossing( 'renderers/common', 'renderers/webgl-fallback' ) ];
report.webgpuToFallback = crossing( 'renderers/webgpu', 'renderers/webgl-fallback' );
report.fallbackToWebgpu = crossing( 'renderers/webgl-fallback', 'renderers/webgpu' );
for ( const k of [ 'nodesToCommon', 'commonToNodes', 'materialsToCommon', 'nodesToMaterials', 'nodesToBackends', 'commonToBackends', 'webgpuToFallback', 'fallbackToWebgpu' ] ) {

	console.log( `\n${k}: ${report[ k ].length} edges` );
	for ( const e of report[ k ].slice( 0, flag( '--files' ) ? 1e9 : 12 ) ) console.log( '    ' + e );

}

// 3. The proposed layout.
const pkgOf = new Map();
for ( const f of nodes ) {

	const p = packageOf( f, LAYOUT );
	if ( p === undefined ) throw new Error( `no package for ${f}` );
	pkgOf.set( f, p );

}

const sccSplit = fileSccs.filter( ( c ) => new Set( c.map( ( f ) => pkgOf.get( f ) ) ).size > 1 );
const pkgs = [ ...new Set( pkgOf.values() ) ].sort();
const pkgEdges = new Map( pkgs.map( ( p ) => [ p, new Map() ] ) );
const pkgExternal = new Map( pkgs.map( ( p ) => [ p, new Set() ] ) );
for ( const [ f, ds ] of edges ) for ( const d of ds ) {

	const a = pkgOf.get( f ), b = pkgOf.get( d );
	if ( a !== b ) pkgEdges.get( a ).set( b, [ ...( pkgEdges.get( a ).get( b ) ?? [] ), `${f} -> ${d}` ] );

}

for ( const [ f, ds ] of external ) for ( const d of ds ) {

	const p = packageOf( d, PORTED );
	pkgExternal.get( pkgOf.get( f ) ).add( p ?? `UNKNOWN(${d})` );

}

const pkgSccs = tarjan( pkgs, ( p ) => [ ...pkgEdges.get( p ).keys() ] ).filter( ( c ) => c.length > 1 );
console.log( '\n## Proposed packages' );
for ( const p of pkgs ) {

	const fs_ = nodes.filter( ( f ) => pkgOf.get( f ) === p );
	console.log( `- src/${p}: ${fs_.length} files, ${fs_.reduce( ( a, f ) => a + lines.get( f ), 0 )} lines;` +
		` imports ${[ ...pkgEdges.get( p ).keys() ].join( ', ' ) || '-'}; ported: ${[ ...pkgExternal.get( p ) ].sort().join( ', ' )}` );

}

// File names must be unique within a package.
const fileNames = new Map();
for ( const f of nodes ) {

	const key = pkgOf.get( f ) + '/' + mbtFileOf( f );
	fileNames.set( key, [ ...( fileNames.get( key ) ?? [] ), f ] );

}

const fileClashes = [ ...fileNames ].filter( ( [ , fs_ ] ) => fs_.length > 1 );
console.log( `\nMoonBit file name clashes: ${fileClashes.length}` );
for ( const [ k, fs_ ] of fileClashes ) console.log( `    ${k}: ${fs_.join( ' ' )}` );
report.mbtFiles = Object.fromEntries( nodes.map( ( f ) => [ f, `src/${pkgOf.get( f )}/${mbtFileOf( f )}` ] ) );
if ( flag( '--files' ) ) for ( const f of nodes ) console.log( `    ${f}.js -> ${report.mbtFiles[ f ]}` );

// Exported top-level names that clash within a package (one MoonBit namespace).
const namesByPkg = new Map();
for ( const f of nodes ) {

	const text = stripComments( fs.readFileSync( path.join( SRC, f + '.js' ), 'utf8' ) );
	for ( const m of text.matchAll( /^export\s+(?:default\s+)?(?:class|function|const|let)\s+([A-Za-z_$][\w$]*)/gm ) ) {

		const key = pkgOf.get( f ) + ':' + m[ 1 ];
		namesByPkg.set( key, [ ...( namesByPkg.get( key ) ?? [] ), f ] );

	}

}

const nameClashes = [ ...namesByPkg ].filter( ( [ , fs_ ] ) => new Set( fs_ ).size > 1 );
console.log( `Exported name clashes: ${nameClashes.length}` );
for ( const [ k, fs_ ] of nameClashes ) console.log( `    ${k}: ${[ ...new Set( fs_ ) ].join( ' ' )}` );
report.nameClashes = Object.fromEntries( nameClashes );

report.packages = Object.fromEntries( pkgs.map( ( p ) => [ p, {
	files: nodes.filter( ( f ) => pkgOf.get( f ) === p ),
	imports: [ ...pkgEdges.get( p ).keys() ],
	ported: [ ...pkgExternal.get( p ) ].sort(),
} ] ) );
report.packageCycles = pkgSccs;
report.splitSccs = sccSplit;
console.log( `\nSCCs split across packages: ${sccSplit.length}` );
for ( const c of sccSplit ) console.log( '    ' + c.map( ( f ) => `${f}@${pkgOf.get( f )}` ).join( ' ' ) );
console.log( `Package cycles: ${pkgSccs.length}` );
for ( const c of pkgSccs ) {

	console.log( `- ${c.join( ' <-> ' )}` );
	for ( const a of c ) for ( const b of c ) if ( pkgEdges.get( a ).has( b ) ) {

		console.log( `    ${a} -> ${b}: ${pkgEdges.get( a ).get( b ).slice( 0, 8 ).join( '; ' )}` );

	}

}

report.edges = Object.fromEntries( edges );
report.external = Object.fromEntries( external );
report.lineCounts = Object.fromEntries( lines );

// `--closure a,b` prints the transitive imports (within the remaining directories) of
// the files whose path starts with one of the given prefixes.
if ( opt( '--closure' ) ) {

	const roots = opt( '--closure' ).split( ',' );
	const seen = new Set();
	const visit = ( f ) => {

		if ( seen.has( f ) ) return;
		seen.add( f );
		for ( const d of edges.get( f ) ) visit( d );

	};

	for ( const f of nodes ) if ( roots.some( ( r ) => f.startsWith( r ) ) ) visit( f );
	const list = [ ...seen ].sort();
	console.log( `\n## Closure of ${roots.join( ', ' )}: ${list.length} files, ${list.reduce( ( a, f ) => a + lines.get( f ), 0 )} lines` );
	console.log( '    ' + list.join( '\n    ' ) );

}

if ( opt( '--json' ) ) fs.writeFileSync( opt( '--json' ), JSON.stringify( report, null, '\t' ) );
process.exit( pkgSccs.length > 0 || sccSplit.length > 0 || fileClashes.length > 0 ? 1 : 0 );
