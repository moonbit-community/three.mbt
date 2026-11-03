// Lists the classes of upstream JS files with their constructor fields and methods,
// typed from the JSDoc, as a starting point for MoonBit signatures.
//
//   node tools/jsdoc_signatures.mjs <file.js> [more.js ...] [--mbt]
//
// Without `--mbt` it prints `Class extends Base`, `field : {jsdoc type}` in assignment
// order (the order `Node._getChildren` sees), and `method( name : {type}, ... ) : {return}`.
// With `--mbt` it prints draft MoonBit stubs using the type mapping in `mbtType`, with
// `abort("dispatch arm: Class::method")` bodies. The draft needs review: JSDoc `number`
// is `Double` unless the name suggests a count or index, and `Object` is `JsValue`.

import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice( 2 );
const asMbt = args.includes( '--mbt' );
const files = args.filter( ( a ) => ! a.startsWith( '--' ) );

const snake = ( s ) => s
	.replace( /([a-z0-9])([A-Z])/g, '$1_$2' )
	.replace( /([A-Z]+)([A-Z][a-z])/g, '$1_$2' )
	.toLowerCase();

const INTISH = /(count|index|length|id|level|offset|size|version|stride|width|height|depth|layer|samples|slot|group|binding)$/i;

function mbtType( t, name = '' ) {

	if ( t === undefined ) return 'JsValue';
	t = t.trim();
	let optional = false;
	if ( t.startsWith( '?' ) ) {

		optional = true; t = t.slice( 1 );

	}

	if ( t.startsWith( '(' ) && t.endsWith( ')' ) ) t = t.slice( 1, - 1 );
	if ( t.includes( '|' ) ) {

		const parts = t.split( '|' ).map( ( p ) => p.trim() );
		if ( parts.includes( 'null' ) ) {

			optional = true;
			t = parts.filter( ( p ) => p !== 'null' ).join( '|' );

		}

		if ( t.includes( '|' ) ) return 'JsValue /* ' + t + ' */' + ( optional ? '?' : '' );

	}

	const arr = t.match( /^Array<(.+)>$/ );
	let out;
	if ( arr ) out = `Array[${mbtType( arr[ 1 ], name.replace( /s$/, '' ) )}]`;
	else if ( t === 'string' ) out = 'String';
	else if ( t === 'boolean' ) out = 'Bool';
	else if ( t === 'number' ) out = INTISH.test( name ) ? 'Int' : 'Double';
	else if ( t === 'Object' || t === 'any' || t === '*' ) out = 'JsValue';
	else if ( t === 'Function' ) out = '(() -> Unit) /* Function */';
	else if ( /^(Vector[234]|Matrix[234]|Color|Quaternion|Euler|Plane|Sphere|Box3)$/.test( t ) ) out = '@math.' + t;
	else if ( /^(Object3D|Material|Texture|BufferGeometry|BufferAttribute|RenderTarget|Camera|Scene|Light|Mesh|InterleavedBuffer|InterleavedBufferAttribute|EventDispatcher)$/.test( t ) ) out = '@core.' + t;
	else out = t;
	return optional ? out + '?' : out;

}

function parseJsDoc( doc ) {

	const params = [];
	let ret, type;
	for ( const m of doc.matchAll( /@param\s+\{([^}]+)\}\s+(\[?[\w.$]+(?:=[^\]]*)?\]?)/g ) ) {

		let name = m[ 2 ];
		const opt = name.startsWith( '[' );
		name = name.replace( /^\[|\]$/g, '' );
		const def = name.includes( '=' ) ? name.slice( name.indexOf( '=' ) + 1 ) : undefined;
		name = name.split( '=' )[ 0 ];
		if ( name.includes( '.' ) ) continue;
		params.push( { name, type: m[ 1 ], opt, def } );

	}

	const r = doc.match( /@returns?\s+\{([^}]+)\}/ );
	if ( r ) ret = r[ 1 ];
	const ty = doc.match( /@type\s+\{([^}]+)\}/ );
	if ( ty ) type = ty[ 1 ];
	return { params, ret, type };

}

function classesOf( text ) {

	const out = [];
	const re = /(?:^|\n)(?:export\s+(?:default\s+)?)?class\s+(\w+)(?:\s+extends\s+([\w.]+))?\s*\{/g;
	let m;
	while ( ( m = re.exec( text ) ) ) {

		let i = re.lastIndex, depth = 1;
		while ( depth > 0 && i < text.length ) {

			const c = text[ i ];
			if ( c === '{' ) depth ++;
			else if ( c === '}' ) depth --;
			else if ( c === '`' || c === '\'' || c === '"' ) {

				const q = c; i ++;
				while ( i < text.length && text[ i ] !== q ) {

					if ( text[ i ] === '\\' ) i ++;
					i ++;

				}

			}

			i ++;

		}

		out.push( { name: m[ 1 ], base: m[ 2 ], body: text.slice( re.lastIndex, i - 1 ) } );

	}

	return out;

}

function membersOf( body ) {

	const members = [];
	// Methods at one tab of indentation, with their preceding JSDoc.
	const re = /(\/\*\*(?:(?!\*\/)[\s\S])*\*\/\s*)?\n\t(static\s+)?(get\s+|set\s+|async\s+)?(\w+)\s*\(([^)]*)\)\s*\{/g;
	let m;
	while ( ( m = re.exec( body ) ) ) {

		const doc = m[ 1 ] ? parseJsDoc( m[ 1 ] ) : { params: [] };
		const kind = ( m[ 3 ] || '' ).trim();
		const jsParams = m[ 5 ].split( ',' ).map( ( p ) => p.replace( /\/\*.*?\*\//g, '' ).trim() ).filter( Boolean );
		members.push( { static: !! m[ 2 ], kind, name: m[ 4 ], jsParams, doc, at: m.index } );

	}

	return members;

}

function fieldsOf( body ) {

	const ctor = body.match( /\n\tconstructor\s*\(([^)]*)\)\s*\{([\s\S]*?)\n\t\}/ );
	if ( ! ctor ) return { params: '', fields: [] };
	const fields = [];
	const seen = new Set();
	const re = /(\/\*\*(?:(?!\*\/)[\s\S])*\*\/\s*)?this\.(\w+)\s*=\s*([^;\n]*)/g;
	let m;
	while ( ( m = re.exec( ctor[ 2 ] ) ) ) {

		if ( seen.has( m[ 2 ] ) ) continue;
		seen.add( m[ 2 ] );
		const doc = m[ 1 ] ? parseJsDoc( m[ 1 ] ) : {};
		fields.push( { name: m[ 2 ], init: m[ 3 ].trim(), type: doc.type } );

	}

	const sup = ctor[ 2 ].match( /super\(([^)]*)\)/ );
	return { params: ctor[ 1 ].trim(), fields, superArgs: sup ? sup[ 1 ].trim() : undefined };

}

for ( const file of files ) {

	const text = fs.readFileSync( file, 'utf8' );
	console.log( `// ${path.basename( file )}` );
	for ( const cls of classesOf( text ) ) {

		const typeName = ( cls.body.match( /static get type\(\)\s*\{\s*return\s*'(\w+)'/ ) || [] )[ 1 ];
		const { params, fields, superArgs } = fieldsOf( cls.body );
		const members = membersOf( cls.body ).filter( ( m ) => m.name !== 'constructor' && ! ( m.static && m.name === 'type' ) );
		if ( ! asMbt ) {

			console.log( `class ${cls.name}${cls.base ? ' extends ' + cls.base : ''}${typeName ? ` (type '${typeName}')` : ''}` );
			console.log( `  constructor( ${params} )${superArgs !== undefined ? ` super( ${superArgs} )` : ''}` );
			for ( const f of fields ) console.log( `  .${f.name} : ${f.type ?? '?'} = ${f.init}` );
			for ( const m of members ) {

				const ps = m.jsParams.map( ( p ) => {

					const n = p.split( '=' )[ 0 ].trim().replace( /^\.\.\./, '...' );
					const d = m.doc.params.find( ( q ) => q.name === n.replace( /^\.\.\./, '' ) );
					return `${p}${d ? ' : ' + d.type : ''}`;

				} );
				console.log( `  ${m.static ? 'static ' : ''}${m.kind ? m.kind + ' ' : ''}${m.name}( ${ps.join( ', ' )} )${m.doc.ret ? ' : ' + m.doc.ret : ''}` );

			}

		} else {

			console.log( `\n///|\npub(all) struct ${cls.name} {` );
			for ( const f of fields ) console.log( `  mut ${snake( f.name )} : ${mbtType( f.type, f.name )} // = ${f.init}` );
			console.log( '}' );
			for ( const m of members ) {

				const ps = [ `self : ${cls.name}` ];
				for ( const p of m.jsParams ) {

					const [ raw, def ] = p.split( '=' ).map( ( s ) => s.trim() );
					const n = raw.replace( /^\.\.\./, '' );
					const d = m.doc.params.find( ( q ) => q.name === n );
					const ty = mbtType( d?.type, n ) + ( raw.startsWith( '...' ) ? ' /* rest */' : '' );
					ps.push( def !== undefined ? `${snake( n )}? : ${ty} /* = ${def} */` : `_${snake( n )} : ${ty}` );

				}

				const ret = m.doc.ret ? ' -> ' + mbtType( m.doc.ret ) : '';
				const nm = ( m.kind === 'set' ? 'set_' : '' ) + snake( m.name );
				console.log( `\n///|\npub fn ${cls.name}::${nm}(${ps.join( ', ' )})${ret} {\n  abort("dispatch arm: ${cls.name}::${nm}")\n}` );

			}

		}

	}

}
