// The G9 harness setup (diff/core/g9/harness/common.mjs, reused as is) plus a
// `document` stub: `createElementNS( ..., 'canvas' )` gives a mock-GPU canvas,
// `createElement( 'canvas' )` a 2D canvas whose drawImage calls are noted.
import { setup as g9setup, flush, TARGETS, SRC } from '../../../core/g9/harness/common.mjs';
export { flush, TARGETS, SRC };
export function setup() {
	const mock = g9setup( {} );
	let canvases2d = 0;
	globalThis.document = {
		createElementNS: ( ns, name ) => mock.createCanvas( {} ),
		createElement: ( name ) => {
			const id = 'Canvas2D#' + ( canvases2d ++ );
			const canvas = { __id: id, width: 300, height: 150 };
			canvas.getContext = ( type ) => {
				mock.note( 'getContext', [ id, type ] );
				return { drawImage: ( image, x, y, w, h ) => mock.note( 'drawImage', [ id, image && image.__id ? image.__id : mock.idOf( image ), x, y, w, h, canvas.width, canvas.height ] ) };
			};
			return canvas;
		},
	};
	return mock;
}
