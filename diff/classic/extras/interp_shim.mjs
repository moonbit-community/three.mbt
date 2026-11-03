import { upstreamURL } from '../../lib/env.mjs';
const { CatmullRom, QuadraticBezier, CubicBezier } = await import( upstreamURL( 'src/extras/core/Interpolations.js' ) );
export const catmullRomInterp = a => [ CatmullRom( a[ 0 ], a[ 1 ], a[ 2 ], a[ 3 ], a[ 4 ] ), QuadraticBezier( a[ 0 ], a[ 1 ], a[ 2 ], a[ 3 ] ), CubicBezier( a[ 0 ], a[ 1 ], a[ 2 ], a[ 3 ], a[ 4 ] ) ];
