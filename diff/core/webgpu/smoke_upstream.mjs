// Upstream-side smoke test: upstream WebGPURenderer (three.js r187 sources) initialises and
// renders a mesh against the generated mock, and the call log is printed.
// Usage: node diff/core/webgpu/smoke_upstream.mjs [<three.js/src>] [--summary] [--async]
import { createRequire } from 'node:module';
import path from 'node:path';
import url from 'node:url';
import { UPSTREAM } from '../../lib/env.mjs';
const require = createRequire( import.meta.url );
const { createMockGPU } = require( './mock_gpu.cjs' );

const args = process.argv.slice( 2 );
const src = args.find( ( a ) => ! a.startsWith( '--' ) ) ?? path.join( UPSTREAM, 'src' );
const mock = createMockGPU( { asyncPromises: args.includes( '--async' ) } );
mock.install( globalThis );
// the little DOM the renderer touches outside the canvas
globalThis.self ??= globalThis;
globalThis.requestAnimationFrame ??= ( f ) => setTimeout( () => f( performance.now() ), 0 );
globalThis.cancelAnimationFrame ??= ( id ) => clearTimeout( id );

const THREE = await import( url.pathToFileURL( path.join( src, 'Three.WebGPU.js' ) ).href );
const canvas = mock.createCanvas( { width: 4, height: 4 } );
const renderer = new THREE.WebGPURenderer( { canvas, antialias: false } );
await renderer.init();
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera( 50, 1, 0.1, 10 );
camera.position.z = 3;
const material = new THREE.MeshBasicNodeMaterial();
material.color.set( 0xff0000 );
scene.add( new THREE.Mesh( new THREE.BoxGeometry(), material ) );
renderer.render( scene, camera );
if ( args.includes( '--summary' ) ) {

	const counts = {};
	for ( const [ , method ] of mock.log ) counts[ method ] = ( counts[ method ] ?? 0 ) + 1;
	console.log( mock.log.length, 'calls', JSON.stringify( counts ) );

} else {

	console.log( mock.logText() );

}

renderer.setAnimationLoop( null );
process.exit( 0 );
