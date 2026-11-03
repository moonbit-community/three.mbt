// Module resolve hook installed by register.mjs.
import { upstreamURL } from '../../lib/env.mjs';

const THREE_URL = upstreamURL( 'src/Three.js' );
const ADDONS = upstreamURL( 'examples/jsm' ) + '/';

export async function resolve( specifier, context, next ) {

	if ( specifier === 'three' ) return { url: THREE_URL, shortCircuit: true };
	if ( specifier.startsWith( 'three/addons/' ) ) return { url: ADDONS + specifier.slice( 'three/addons/'.length ), shortCircuit: true };
	return next( specifier, context );

}
