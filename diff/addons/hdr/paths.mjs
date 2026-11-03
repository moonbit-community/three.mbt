// Paths of the HDR/EXR harness: upstream examples, the built MoonBit side, and the
// generated fixtures in OUT/addons_hdr (see gen_exr.mjs / fixtures.mjs).
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { UPSTREAM, outDir } from '../../lib/env.mjs';

export const HERE = path.dirname( fileURLToPath( import.meta.url ) );
/** Upstream `examples/`, with a trailing slash (file paths, also used as import specifiers). */
export const EX = path.join( UPSTREAM, 'examples' ) + '/';
export const EX_URL = pathToFileURL( EX ).href;
export const OUT_HDR = outDir( 'addons_hdr' );
/** Generated EXR fixtures (gen_exr.mjs). */
export const EXR_DIR = path.join( OUT_HDR, 'exr' );
/** Truncated/corrupted inputs (corrupt_run.mjs). */
export const CORRUPT_DIR = path.join( OUT_HDR, 'corrupt' );
/** The MoonBit side (mod/, `moon build --target js`). */
export const HARNESS_JS = path.join( HERE, 'mod/_build/js/debug/build/moonbit-community/three-diff-hdr/harness/harness.js' );
export const HARNESS_URL = pathToFileURL( HARNESS_JS ).href;
