// Resolve hooks of the upstream side: the add-on's bare specifiers point at the upstream
// sources ('three' is src/Three.js, the WebGLRenderer build, as in the webgl_tsl_* examples).
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { UPSTREAM } from '../../../../lib/env.mjs';
const url = ( p ) => pathToFileURL( path.join( UPSTREAM, p ) ).href;
const MAP = {
	'three/webgpu': url( 'src/Three.WebGPU.js' ),
	'three/tsl': url( 'src/Three.TSL.js' ),
	'three': url( 'src/Three.js' ),
};
export async function resolve( specifier, context, next ) {

	if ( specifier in MAP ) return { url: MAP[ specifier ], shortCircuit: true };
	if ( specifier.startsWith( 'three/addons/' ) ) return { url: url( 'examples/jsm/' + specifier.slice( 'three/addons/'.length ) ), shortCircuit: true };
	return next( specifier, context );

}
