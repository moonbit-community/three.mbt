// Upstream side of the G10 differential harness: upstream r187's
// `WebGPURenderer( { forceWebGL: true } )` (a `Renderer` on a `WebGLBackend`) renders on
// the recording mock WebGL 2 context of diff/core/webgl (harness/mock_gl.cjs). The
// MoonBit side (src/renderers/webgl_fallback/g10_diff_test.mbt) builds
// `Renderer::new( WebGLBackend::new( parameters ) )` with the StandardNodeLibrary on the
// same mock; keep the two in step.
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { UPSTREAM } from '../../../lib/env.mjs';
import { createRequire } from 'node:module';

export const SRC = path.join( UPSTREAM, 'src' );
const imp = async ( p ) => import( pathToFileURL( SRC + p ).href );
export const M = {};
const require = createRequire( import.meta.url );
export const { createMockGL } = require( '../../webgl/harness/mock_gl.cjs' );

export async function load() {

	if ( typeof globalThis.ImageBitmap === 'undefined' ) globalThis.ImageBitmap = class ImageBitmap {};
	M.TSL = await imp( '/Three.TSL.js' );
	Object.assign( M, await imp( '/Three.WebGPU.js' ) );
	M.Node = ( await imp( '/nodes/core/Node.js' ) ).default;

}

// ---- counters: both sides advance the global id counters to the same values.

export const TARGETS = { node: 20000, object3d: 1000, material: 1000, texture: 1000, attribute: 1000, geometry: 1000 };

export function align() {

	const probe = {
		node: () => new M.Node().id,
		object3d: () => new M.Object3D().id,
		material: () => new M.Material().id,
		texture: () => new M.Texture().id,
		attribute: () => new M.BufferAttribute( new Float32Array( 1 ), 1 ).id,
		geometry: () => new M.BufferGeometry().id,
	};
	for ( const [ k, f ] of Object.entries( probe ) ) {

		let id = f();
		if ( id >= TARGETS[ k ] ) throw new Error( `counter ${k} already at ${id}` );
		while ( id < TARGETS[ k ] - 1 ) id = f();

	}

}

// ---- a fake `self` with requestAnimationFrame (the renderer's Animation reads it)

export function installFrames( gl ) {

	const callbacks = [];
	globalThis.self = {
		requestAnimationFrame( cb ) { callbacks.push( cb ); return callbacks.length; },
		cancelAnimationFrame( id ) { gl.__note( 'cancelAnimationFrame', id ); },
	};
	globalThis.requestAnimationFrame = ( cb ) => { callbacks.push( cb ); return callbacks.length; };
	return callbacks;

}

// ---- the renderer: a stub canvas whose getContext( 'webgl2', attributes ) notes the
// attributes and returns the mock.

export function makeCanvas( gl, width = 300, height = 150 ) {

	return {
		style: {}, width, height,
		addEventListener( type ) { gl.__note( 'canvas.addEventListener', type ); },
		removeEventListener( type ) { gl.__note( 'canvas.removeEventListener', type ); },
		setAttribute() {},
		getContext( type, attributes ) { gl.__note( 'getContext ' + type, JSON.stringify( attributes ) ); return gl; },
	};

}

export async function makeRenderer( options = {}, mockOptions = {} ) {

	const gl = createMockGL( mockOptions );
	installFrames( gl );
	const canvas = makeCanvas( gl, options.width, options.height );
	const parameters = Object.assign( { canvas, forceWebGL: true }, options.parameters || {} );
	const renderer = new M.WebGPURenderer( parameters );
	await renderer.init();
	return { renderer, gl, canvas };

}
