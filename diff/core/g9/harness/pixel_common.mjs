// Shared by pixel_up.mjs / pixel_mbt.mjs: the scenes of examples/pixel_compare
// (webgpu_scenes.js and webgpu/main.mbt) on the recording mock GPU. Adds what those scenes
// need beyond common.mjs: `document.createElement( 'canvas' )` for 2D canvases (the
// procedural CanvasTexture), a mock canvas whose `getContext( '2d' )` returns a stub that
// records nothing (2D drawing is not GPU work).
// Additive (A5): SMAANode creates `new Image()`s for its area / search textures (an unloaded
// stub under Node, on both sides), and FilmNode reads the `time` uniform, so the clock is
// deterministic on both sides (a fixed step per `performance.now()` call).
import path from 'node:path';
import { REPO } from '../../../lib/env.mjs';

if ( typeof globalThis.Image === 'undefined' ) {

	globalThis.Image = class Image { constructor() { this.src = ''; this.onload = null; this.width = 0; this.height = 0; } };

}

{

	let now = 1000;
	performance.now = () => ( now += 16 );

}

export const PIXEL_DIR = path.join( REPO, 'examples/pixel_compare' );
export const WIDTH = 128, HEIGHT = 96;

export function installDocument( mock ) {

	const context2d = { fillStyle: '', fillRect() {} };
	globalThis.document = {
		createElement( tag ) {

			if ( tag !== 'canvas' ) throw new Error( 'document.createElement( ' + tag + ' )' );
			const canvas = mock.createCanvas( { width: 300, height: 150 } );
			const getContext = canvas.getContext;
			canvas.getContext = ( type ) => type === '2d' ? context2d : getContext( type );
			return canvas;

		},
		createElementNS( ns, tag ) {

			return this.createElement( tag );

		},
	};
	installObjectsClock(); // a6

}

// The readback, summarized as a note (the mock GPU returns zeros).
export function pixelNote( mock, pixels ) {

	mock.note( 'pixels', pixels === null ? null : [ pixels.constructor.name, pixels.length ] );

}

// Additive (objects add-ons, a6): the objects scenes read the `time` node (SkyMesh's clouds,
// WaterMesh's waves) and NodeFrame's deltaTime (Water2Mesh's flow), which come from
// performance.now; give both sides the same clock (1000, +16 per call) in those scenes.
export const OBJECTS_CLOCK_SCENES = [ 'addon_sky_mesh', 'addon_water_mesh', 'addon_water2_mesh', 'addon_lensflare_mesh' ];
export function installObjectsClock( name = process.argv[ 2 ] ) {

	if ( ! OBJECTS_CLOCK_SCENES.includes( name ) ) return;
	let t = 1000;
	performance.now = () => ( t += 16 );

}
