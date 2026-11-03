// Node resolve hook: the bare specifiers examples/jsm uses, mapped onto upstream src/.
// A6_THREE=webgpu maps 'three' to Three.WebGPU.js, as the WebGPU examples' import maps do.
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { UPSTREAM } from '../../lib/env.mjs';
const SRC = pathToFileURL( path.join( UPSTREAM, 'src' ) ).href + '/';
const JSM = pathToFileURL( path.join( UPSTREAM, 'examples/jsm' ) ).href + '/';
const MAP = { 'three': SRC + ( process.env.A6_THREE === 'webgpu' ? 'Three.WebGPU.js' : 'Three.js' ), 'three/webgpu': SRC + 'Three.WebGPU.js', 'three/tsl': SRC + 'Three.TSL.js' };
export async function resolve( specifier, context, next ) {
	if ( specifier in MAP ) return { url: MAP[ specifier ], shortCircuit: true };
	if ( specifier.startsWith( 'three/addons/' ) ) return { url: JSM + specifier.slice( 13 ), shortCircuit: true };
	return next( specifier, context );
}
