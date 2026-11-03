// Node module resolve hooks for the a6 (objects add-ons) child: the add-ons' bare
// specifiers point at the upstream sources (THREE_UPSTREAM), so they share the module instances the child
// imports by file URL.
import { pathToFileURL } from 'node:url';
import { UPSTREAM as REPO } from '../../../../lib/env.mjs';
const MAP = {
	'three/webgpu': REPO + '/src/Three.WebGPU.js',
	'three/tsl': REPO + '/src/Three.TSL.js',
	'three': REPO + '/src/Three.js',
};
export async function resolve( specifier, context, next ) {

	if ( specifier in MAP ) return { url: pathToFileURL( MAP[ specifier ] ).href, shortCircuit: true };
	if ( specifier.startsWith( 'three/addons/' ) ) return { url: pathToFileURL( REPO + '/examples/jsm/' + specifier.slice( 'three/addons/'.length ) ).href, shortCircuit: true };
	return next( specifier, context );

}
