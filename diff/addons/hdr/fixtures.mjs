// Makes sure the generated EXR fixtures in OUT/addons_hdr/exr are current: unpacks
// them (node gen_exr.mjs, about a second, no OpenEXR tools needed) when they are missing
// or the generator or archive changed. Every script reading exr/ awaits ensureExr().
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { EXR_DIR, HERE, OUT_HDR } from './paths.mjs';

export function ensureExr() {

	const h = crypto.createHash( 'sha256' );
	for ( const f of [ 'gen_exr.mjs', 'gen_dwa_deflate.mjs', 'fixtures/exr.tar.xz' ] ) h.update( fs.readFileSync( path.join( HERE, f ) ) );
	const stamp = h.digest( 'hex' );
	const stampFile = path.join( OUT_HDR, 'exr.stamp' );
	if ( fs.existsSync( EXR_DIR ) && fs.existsSync( stampFile ) && fs.readFileSync( stampFile, 'utf8' ) === stamp ) return EXR_DIR;
	execFileSync( 'node', [ path.join( HERE, 'gen_exr.mjs' ) ], { stdio: [ 'ignore', 'ignore', 'inherit' ] } );
	fs.writeFileSync( stampFile, stamp );
	return EXR_DIR;

}
