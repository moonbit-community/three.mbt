// Paths shared by every differential harness. Import it relative to the harness file:
//
//   import { REPO, UPSTREAM, OUT, outDir, upstreamURL } from '../../lib/env.mjs';
//
// THREE_UPSTREAM   upstream three.js checkout (default `.repos/three.js`)
// THREE_DIFF_OUT   scratch/output directory (default `diff/.out`, gitignored)
// Relative values resolve against the repository root, not the current directory.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = path.dirname( fileURLToPath( import.meta.url ) );

/** `diff/` */
export const DIFF = path.resolve( here, '..' );
/** The repository root (module `moonbit-community/three`). */
export const REPO = path.resolve( DIFF, '..' );
/** The upstream three.js checkout. */
export const UPSTREAM = path.resolve( REPO, process.env.THREE_UPSTREAM || '.repos/three.js' );
/** Generated outputs, logs and scratch copies. */
export const OUT = path.resolve( REPO, process.env.THREE_DIFF_OUT || 'diff/.out' );

/** `OUT/<parts...>`, created if missing. */
export function outDir( ...parts ) {

	const d = path.join( OUT, ...parts );
	fs.mkdirSync( d, { recursive: true } );
	return d;

}

/** Absolute path of a repo-relative path. */
export const repoPath = ( ...parts ) => path.join( REPO, ...parts );
/** Absolute path inside the upstream checkout. */
export const upstreamPath = ( ...parts ) => path.join( UPSTREAM, ...parts );
/** file:// URL inside the upstream checkout (for dynamic `import()`). */
export const upstreamURL = ( ...parts ) => pathToFileURL( path.join( UPSTREAM, ...parts ) ).href;
/** file:// URL of upstream `src` (what most `runUpstream( src )` helpers take). */
export const UPSTREAM_SRC_URL = upstreamURL( 'src' );

export function requireUpstream() {

	if ( ! fs.existsSync( path.join( UPSTREAM, 'src/Three.js' ) ) ) {

		console.error( `upstream three.js not found at ${UPSTREAM}; run tools/fetch_upstream.sh or set THREE_UPSTREAM` );
		process.exit( 2 );

	}

}
