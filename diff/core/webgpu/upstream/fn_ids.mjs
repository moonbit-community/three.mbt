// Prints the auto-generated layout names (`fn<id>`) upstream assigns at module load,
// in assignment order, and the next id a user Fn gets after importing the entry.
import { upstreamURL } from '../../../lib/env.mjs';
const SRC = process.argv[ 2 ] ?? upstreamURL( 'src' );
const entry = process.argv[ 3 ] ?? 'Three.WebGPU.js';
const TSL = await import( SRC + '/nodes/tsl/TSLCore.js' );
const before = TSL.Fn( () => {}, { a: 'float', return: 'float' } ).shaderNode.layout.name;
await import( SRC + '/' + entry );
const after = TSL.Fn( () => {}, { a: 'float', return: 'float' } ).shaderNode.layout.name;
console.log( JSON.stringify( { entry, firstUserIdBeforeLibrary: before, firstUserIdAfterLibrary: after } ) );
