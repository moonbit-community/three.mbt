// Minimal DOM stub shared by both sides. Every DOM call the controls make is logged,
// listeners follow DOM rules (dedup on type + listener + capture), and `fire` builds a
// fresh event object for each dispatch, as browsers do.

export const fmt = ( v ) => {

	if ( typeof v === 'number' ) return Object.is( v, - 0 ) ? '-0' : String( v );
	if ( v === undefined ) return 'undefined';
	if ( Array.isArray( v ) ) return '[' + v.map( fmt ).join( ',' ) + ']';
	if ( v !== null && typeof v === 'object' && v.__name ) return '<' + v.__name + '>';
	return JSON.stringify( v );

};

const optStr = ( o ) => o === undefined ? '-' : JSON.stringify( o );
const captureOf = ( o ) => typeof o === 'boolean' ? o : !! ( o && o.capture );

export function makeEnv( log ) {

	const registry = new Map();
	let rafId = 0;
	const rafQueue = [];

	function makeTarget( name, extra = {} ) {

		const t = Object.assign( { __name: name }, extra );
		registry.set( t, new Map() );
		t.addEventListener = ( type, fn, opts ) => {

			log( [ 'dom', name + '.add', type, optStr( opts ) ] );
			const m = registry.get( t );
			if ( ! m.has( type ) ) m.set( type, [] );
			const arr = m.get( type );
			const capture = captureOf( opts );
			if ( arr.some( ( e ) => e.fn === fn && e.capture === capture ) ) return;
			arr.push( { fn, capture } );

		};

		t.removeEventListener = ( type, fn, opts ) => {

			log( [ 'dom', name + '.remove', type, optStr( opts ) ] );
			const arr = registry.get( t ).get( type );
			if ( ! arr ) return;
			const capture = captureOf( opts );
			const i = arr.findIndex( ( e ) => e.fn === fn && e.capture === capture );
			if ( i >= 0 ) arr.splice( i, 1 );

		};

		return t;

	}

	const document = makeTarget( 'doc', {
		pointerLockElement: null,
		documentElement: { clientLeft: 0, clientTop: 0 },
		exitPointerLock() {

			log( [ 'dom', 'doc.exitPointerLock' ] );

		}
	} );

	const style = new Proxy( {}, {
		set( o, k, v ) {

			log( [ 'dom', 'el.style', String( k ), String( v ) ] );
			o[ k ] = v;
			return true;

		}
	} );

	const element = makeTarget( 'el', {
		clientWidth: 800,
		clientHeight: 600,
		offsetWidth: 800,
		offsetHeight: 600,
		offsetLeft: 10,
		offsetTop: 20,
		ownerDocument: document,
		style,
		getBoundingClientRect() {

			return { left: 10, top: 20, width: 800, height: 600, right: 810, bottom: 620, x: 10, y: 20 };

		},
		setPointerCapture( id ) {

			log( [ 'dom', 'el.setPointerCapture', fmt( id ) ] );

		},
		releasePointerCapture( id ) {

			log( [ 'dom', 'el.releasePointerCapture', fmt( id ) ] );

		},
		focus() {

			log( [ 'dom', 'el.focus' ] );

		},
		requestPointerLock( o ) {

			log( [ 'dom', 'el.requestPointerLock', JSON.stringify( o ) ] );

		}
	} );

	const window = makeTarget( 'win', {
		pageXOffset: 3,
		pageYOffset: 5,
		innerWidth: 1024,
		innerHeight: 768,
		devicePixelRatio: 2,
		requestAnimationFrame( cb ) {

			rafId ++;
			rafQueue.push( { id: rafId, cb } );
			log( [ 'dom', 'win.requestAnimationFrame', fmt( rafId ) ] );
			return rafId;

		},
		cancelAnimationFrame( id ) {

			log( [ 'dom', 'win.cancelAnimationFrame', fmt( id ) ] );
			const i = rafQueue.findIndex( ( e ) => e.id === id );
			if ( i >= 0 ) rafQueue.splice( i, 1 );

		}
	} );

	const env = {
		element, document, window,
		now: 1000,
		clipboard: '',
		install() {

			globalThis.window = window;
			globalThis.document = document;
			Object.defineProperty( globalThis, 'performance', { value: { now: () => env.now }, configurable: true, writable: true } );
			globalThis.requestAnimationFrame = window.requestAnimationFrame;
			globalThis.cancelAnimationFrame = window.cancelAnimationFrame;
			Object.defineProperty( globalThis, 'navigator', { value: {
				clipboard: {
					writeText( t ) {

						log( [ 'dom', 'clipboard.writeText', t ] );
						env.clipboard = t;

					},
					readText() {

						log( [ 'dom', 'clipboard.readText' ] );
						return { then( f ) {

							f( env.clipboard );

						} };

					}
				}
			}, configurable: true, writable: true } );

		},
		target( name ) {

			return name === 'el' ? element : name === 'doc' ? document : window;

		},
		fire( targetName, type, props = {} ) {

			const target = env.target( targetName );
			const event = Object.assign( { type, timeStamp: env.now }, props );
			event.preventDefault = () => log( [ 'dom', 'preventDefault', type ] );
			const arr = registry.get( target ).get( type );
			if ( ! arr ) return;
			for ( const e of arr.slice() ) e.fn( event );

		},
		frame( t ) {

			const queue = rafQueue.splice( 0, rafQueue.length );
			for ( const e of queue ) e.cb( t );

		},
		listenerSummary() {

			const out = [];
			for ( const [ t, m ] of registry ) for ( const [ type, arr ] of m ) if ( arr.length ) out.push( t.__name + ':' + type + 'x' + arr.length + arr.map( ( e ) => e.capture ? 'c' : '' ).join( '' ) );
			return out.sort().join( ' ' );

		}
	};

	return env;

}
