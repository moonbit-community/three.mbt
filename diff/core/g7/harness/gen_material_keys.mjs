// node gen_material_keys.mjs [out]: the own and getter keys of every node material class upstream
// (the table behind getMaterialCacheKey's key order in the port); default out:
// diff/.out/core_g7/material_keys_table.txt.
import fs from 'fs';
import path from 'node:path';
import { outDir, upstreamURL } from '../../../lib/env.mjs';
const THREE = await import( upstreamURL( 'src/Three.WebGPU.js' ) );
const re = /^(is[A-Z]|_)|^(visible|version|uuid|name|opacity|userData|iridescenceThicknessRange)$/;
function protoGetters( obj ) {
	let protoKeys = [];
	let proto = Object.getPrototypeOf( obj );
	while ( proto ) {
		const descriptors = Object.getOwnPropertyDescriptors( proto );
		for ( const key in descriptors ) { const d = descriptors[ key ]; if ( d && typeof d.get === 'function' ) protoKeys.push( key ); }
		proto = Object.getPrototypeOf( proto );
	}
	return protoKeys;
}
const names = Object.keys( THREE ).filter( k => /NodeMaterial$/.test( k ) && typeof THREE[k] === 'function' );
let s = '';
for ( const n of names ) {
  const m = new THREE[ n ]();
  const own = Object.keys( m ).filter( k => ! re.test( k ) );
  const getters = protoGetters( m ).filter( k => ! re.test( k ) );
  s += '    ("' + n + '", "' + own.join(',') + '", "' + getters.join(',') + '"),\n';
}
fs.writeFileSync( process.argv[ 2 ] || path.join( outDir( 'core_g7' ), 'material_keys_table.txt' ), s );
console.log( s.split('\n').map(l => l.slice(0,60) + ' ... ' + l.slice(-120)).join('\n') );
