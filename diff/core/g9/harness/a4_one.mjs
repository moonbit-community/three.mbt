// node --import <register_three.mjs> a4_one.mjs up|mbt <name>: the mock GPU log of one A4
// scenario on one side (@@LOG <json>).
import url from 'node:url';
import { setup, flush, SRC, TARGETS } from './common.mjs';
const [ side, name ] = process.argv.slice( 2 );
const mock = setup();
if ( side === 'up' ) {
	const TSL = await import( url.pathToFileURL( SRC + '/Three.TSL.js' ).href );
	const THREE = await import( url.pathToFileURL( SRC + '/Three.WebGPU.js' ).href );
	const Node = ( await import( url.pathToFileURL( SRC + '/nodes/core/Node.js' ).href ) ).default;
	const { scenarios } = await import( './a4_scenarios.mjs' );
	const s = scenarios[ name ];
	const A = {};
	for ( const path of s.modules ) {
		const m = await import( url.pathToFileURL( SRC + '/../examples/jsm/' + path ).href );
		for ( const [ k, v ] of Object.entries( m ) ) if ( k !== 'default' ) A[ k ] = v;
		if ( m.default ) A[ m.default.name ] = m.default;
	}
	const probe = {
		node: () => new Node().id,
		object3d: () => new THREE.Object3D().id,
		material: () => new THREE.Material().id,
		texture: () => new THREE.Texture().id,
		attribute: () => new THREE.BufferAttribute( new Float32Array( 1 ), 1 ).id,
		geometry: () => new THREE.BufferGeometry().id,
	};
	for ( const [ k, f ] of Object.entries( probe ) ) {
		let id = f();
		if ( id >= TARGETS[ k ] ) throw new Error( `counter ${k} already at ${id}` );
		while ( id < TARGETS[ k ] - 1 ) id = f();
	}
	const canvas = mock.createCanvas( { width: 4, height: 4 } );
	await s.run( { THREE, TSL, mock, canvas, note: mock.note, name }, A );
} else {
	const MAIN = new URL( '../mbt/_build/js/debug/build/moonbit-community/three-g9-diff/a4/a4.js', import.meta.url );
	const mbt = await import( MAIN.href );
	const canvas = mock.createCanvas( { width: 4, height: 4 } );
	await new Promise( ( resolve ) => mbt.run_scenario( name, { canvas, note: mock.note, mock }, resolve ) );
}
await flush();
// a pipe may take a large log in pieces (and refuse with EAGAIN while full)
const fs = await import( 'node:fs' );
const out = Buffer.from( '@@LOG ' + JSON.stringify( mock.log ) + '\n' );
for ( let off = 0; off < out.length; ) {
	try {
		off += fs.writeSync( 1, out, off );
	} catch ( e ) {
		if ( e.code !== 'EAGAIN' ) throw e;
	}
}
process.exit( 0 );
