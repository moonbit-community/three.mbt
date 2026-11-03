// Shared behaviour of the demo pages. A page calls `boot( name )` to load its MoonBit
// bundle (examples/<name>/_build/...), then `ready()` once the renderer has started, or
// `fail( message )` with a sentence a non-programmer can act on.

import { ASSETS } from './assets.js';

export { ASSETS };

const $ = ( selector ) => document.querySelector( selector );

// An embedded or background page may get no animation frames; fall back to a timer there
// so the demo still runs.
const framesRun = await Promise.race( [
	new Promise( ( resolve ) => requestAnimationFrame( () => resolve( true ) ) ),
	new Promise( ( resolve ) => setTimeout( () => resolve( false ), 250 ) )
] );
if ( ! framesRun ) window.requestAnimationFrame = ( f ) => setTimeout( () => f( performance.now() ), 16 );

export function fail( message ) {

	const loading = $( '.loading' );
	loading.classList.add( 'failed' );
	loading.querySelector( 'h2' ).textContent = 'This demo can\'t run here';
	loading.querySelector( 'p' ).textContent = message;

}

export function hasWebGPU() {

	return navigator.gpu !== undefined;

}

// Loads examples/<name>/'s MoonBit bundle: `main.js` next to the page on the published site
// (tools/build_site.sh), else the local build output. The debug build comes first: release
// JS builds currently hit a compiler ordering bug (repro/release_hoist_cycle).
export async function boot( name ) {

	const candidates = [
		'./main.js',
		...[ 'debug', 'release' ].map( ( mode ) => `./_build/js/${ mode }/build/moonbit-community/three-${ name }/main/main.js` )
	];
	for ( const path of candidates ) {

		const url = new URL( path, location.href );
		try {

			const module = await import( url.href );
			if ( module.set_assets ) module.set_assets( ASSETS );
			return module;

		} catch ( e ) { /* try the next build mode */ }

	}

	fail( 'The demo files are missing. If you are running this from a copy of the repository, build it first with `moon build --target js`.' );
	return undefined;

}

// Hides the loading screen, starts the frame counter when the URL has ?stats, and fades
// the gesture hint after the first interaction (or after a while).
export function ready( backend ) {

	$( '.loading' ).classList.add( 'done' );
	if ( $( '.panel' ) ) {

		// Phones: the controls stay out of the way until asked for (see shell.css).
		const toggle = document.createElement( 'button' );
		toggle.className = 'settings-toggle';
		toggle.type = 'button';
		toggle.textContent = 'Settings';
		toggle.addEventListener( 'click', () => {

			const shown = document.body.classList.toggle( 'show-settings' );
			toggle.textContent = shown ? 'Done' : 'Settings';

		} );
		document.body.appendChild( toggle );

	}
	const hint = $( '.hint' );
	if ( hint ) {

		const hide = () => hint.classList.add( 'gone' );
		addEventListener( 'pointerdown', hide, { once: true } );
		addEventListener( 'wheel', hide, { once: true } );
		setTimeout( hide, 9000 );

	}

	if ( new URLSearchParams( location.search ).has( 'stats' ) ) {

		const stats = document.createElement( 'div' );
		stats.className = 'stats';
		document.body.appendChild( stats );
		let frames = 0, last = performance.now();
		( function tick() {

			frames ++;
			const now = performance.now();
			if ( now - last >= 500 ) {

				stats.textContent = `${ backend } · ${ Math.round( frames * 1000 / ( now - last ) ) } fps`;
				frames = 0; last = now;

			}
			requestAnimationFrame( tick );

		} )();

	}

}

// `start( canvas, width, height, pixelRatio, onReady )` of a demo, with resize wired up.
export function run( demo ) {

	const canvas = $( 'canvas' );
	demo.start( canvas, innerWidth, innerHeight, Math.min( devicePixelRatio, 2 ), ( error, backend ) => {

		if ( error ) fail( 'Your graphics card or browser refused to start the 3D renderer (' + error + ').' );
		else ready( backend );

	} );
	addEventListener( 'resize', () => demo.resize( innerWidth, innerHeight ) );
	return canvas;

}
