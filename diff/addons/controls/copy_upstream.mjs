// Copies upstream's controls (examples/jsm/controls) into OUT/addons_controls/upstream with
// 'three' resolved to upstream src/Three.js; ArcballControls also exports its STATE/INPUT
// enums. adapter_up.mjs calls it on every run, so the copies always match THREE_UPSTREAM.
//   node copy_upstream.mjs     (prints the directory)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { upstreamPath, upstreamURL, outDir } from '../../lib/env.mjs';

export function copyUpstream() {

	const dir = upstreamPath( 'examples/jsm/controls' );
	const three = upstreamURL( 'src/Three.js' );
	const out = outDir( 'addons_controls', 'upstream' );
	for ( const f of fs.readdirSync( dir ) ) {

		const s = fs.readFileSync( path.join( dir, f ), 'utf8' ).replace( /from 'three'/g, `from '${three}'` );
		fs.writeFileSync( path.join( out, f ), f === 'ArcballControls.js' ? s + '\nexport { STATE as __STATE, INPUT as __INPUT };\n' : s );

	}

	return out;

}

if ( process.argv[ 1 ] === fileURLToPath( import.meta.url ) ) console.log( copyUpstream() );
