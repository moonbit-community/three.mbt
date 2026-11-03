// The `?webgl=1` mode of the pixel scenes (forceWebGL: true on both sides) on the recording
// mock WebGL 2 context of diff/core/webgl, as G10 uses it: a stub canvas whose
// getContext( 'webgl2' ) returns the mock, requestAnimationFrame on a timer (as webgpu.html
// does when frames are paused), and the 2D canvases of document.createElement.
import { createRequire } from 'node:module';
import { installObjectsClock } from './pixel_common.mjs'; // a6
const require = createRequire( import.meta.url );
const { createMockGL } = require( '../../webgl/harness/mock_gl.cjs' );
export const WIDTH = 128, HEIGHT = 96;

export function setupGL() {

	installObjectsClock(); // a6

	const gl = createMockGL( {} );
	if ( typeof globalThis.ImageBitmap === 'undefined' ) globalThis.ImageBitmap = class ImageBitmap {};
	const raf = ( cb ) => setTimeout( () => cb( 0 ), 0 );
	globalThis.self = { requestAnimationFrame: raf, cancelAnimationFrame() {} };
	globalThis.requestAnimationFrame = raf;
	globalThis.cancelAnimationFrame = () => {};
	let canvases = 0;
	const context2d = { fillStyle: '', fillRect() {} };
	globalThis.document = {
		createElement( tag ) {

			if ( tag !== 'canvas' ) throw new Error( 'document.createElement( ' + tag + ' )' );
			const id = ++ canvases;
			return { width: 300, height: 150, style: {}, toString: () => '[canvas2d ' + id + ']', getContext: ( type ) => type === '2d' ? context2d : null };

		},
		createElementNS( ns, tag ) { return this.createElement( tag ); },
	};
	const canvas = {
		style: {}, width: WIDTH, height: HEIGHT,
		addEventListener( type ) { gl.__note( 'canvas.addEventListener', type ); },
		removeEventListener( type ) { gl.__note( 'canvas.removeEventListener', type ); },
		setAttribute() {},
		getContext( type, attributes ) { gl.__note( 'getContext ' + type, JSON.stringify( attributes ) ); return gl; },
	};
	return { gl, canvas };

}
