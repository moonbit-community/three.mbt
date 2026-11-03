// Generates the recording mock of the WebGPU API from tools/gpu_spec.mjs:
//   <harness>/mock_gpu_body.js   MOCK_GPU_SPEC + the runtime below (a script body that
//                                defines `createMockGPU( options )`)
//   <harness>/mock_gpu.cjs       the same as a CommonJS module, for upstream-side scripts
//   <repo>/src/renderers/gpu/gpu_mock_gpu_test.mbt   the body embedded for `moon test`
//
// Only what the spec binds exists on the mock objects, so upstream code (or a port)
// calling an unbound method fails with "is not a function".
//
// Usage: node tools/gen_gpu_mock.mjs [--check] [<repo>] [<harness dir>]
//   <harness dir> defaults to <repo>/diff/core/webgpu; --check writes nothing and exits 1
//   if any of the three files is stale.
//
// The mock (see the options comment in createMockGPU):
// - `navigator.gpu` / adapter / device / queue / canvas contexts are instances of classes
//   named after the WebGPU interfaces (`instanceof GPURenderBundleEncoder` and
//   `error.constructor.name` work once `install()` has put them on globalThis).
// - Every bound method call appends `[ target, method, args ]` (plus `{ ret }` naming the
//   object a creating call returned, and `{ data }` with the bytes written into a buffer
//   mapped for writing when it is unmapped) to `mock.log`. Objects are numbered in
//   creation order across the mock (`GPUDevice#3`) and appear in arguments as
//   '<GPUBuffer#7>'. Descriptors are serialized deeply when the call is made (upstream
//   reuses and resets them right after): keys in insertion order, `undefined` dropped,
//   and only the members of the WebGPU dictionary the parameter expects (`serialize:
//   'idl'`, the default, which is what a browser reads; `'raw'` keeps every own key).
//   Typed arrays and ArrayBuffers become `{ $typed: 'Float32Array', values: [...] }`.
//   Trailing `undefined` arguments are dropped (WebIDL treats them as missing).
// - Promises: with `asyncPromises: false` (the default) every Promise the mock returns is
//   a SyncPromise, a thenable that runs `then` callbacks immediately when it is already
//   settled, so MoonBit callbacks (`request_adapter( fn( adapter ) { ... } )`) have run when
//   the call returns and a test can assert right after. `await` works on it too (one
//   microtask per await, like a native Promise). `asyncPromises: true` returns native
//   Promises.

import fs from 'node:fs';
import path from 'node:path';
import url from 'node:url';
import { handles, interfaces, dictionaries, unions, namespaces, enums, limits, parseMethod, parseProp, parseField } from './gpu_spec.mjs';

const here = path.dirname( url.fileURLToPath( import.meta.url ) );
const cliArgs = process.argv.slice( 2 );
const checkOnly = cliArgs.includes( '--check' );
const positional = cliArgs.filter( ( a ) => ! a.startsWith( '--' ) );
const repo = path.resolve( positional[ 0 ] ?? path.join( here, '..' ) );
const harness = path.resolve( positional[ 1 ] ?? path.join( repo, 'diff', 'core', 'webgpu' ) );

// ---------------------------------------------------------------------------------------
// Runtime (emitted with Function.prototype.toString; must not use anything from this
// module's scope except MOCK_GPU_SPEC).

class SyncPromise {

	constructor( executor ) {

		this.state = 'pending';
		this.value = undefined;
		this.callbacks = [];
		if ( executor ) {

			try {

				executor( ( v ) => this._resolve( v ), ( e ) => this._reject( e ) );

			} catch ( e ) {

				this._reject( e );

			}

		}

	}

	static resolve( v ) {

		return new SyncPromise( ( r ) => r( v ) );

	}

	static reject( e ) {

		return new SyncPromise( ( _, r ) => r( e ) );

	}

	_resolve( v ) {

		if ( this.state !== 'pending' ) return;
		if ( v && typeof v.then === 'function' ) {

			v.then( ( x ) => this._resolve( x ), ( e ) => this._reject( e ) );
			return;

		}

		this.state = 'fulfilled';
		this.value = v;
		this._flush();

	}

	_reject( e ) {

		if ( this.state !== 'pending' ) return;
		this.state = 'rejected';
		this.value = e;
		this._flush();

	}

	_flush() {

		const cbs = this.callbacks;
		this.callbacks = [];
		for ( const cb of cbs ) cb();

	}

	then( onFulfilled, onRejected ) {

		return new SyncPromise( ( resolve, reject ) => {

			const run = () => {

				try {

					if ( this.state === 'fulfilled' ) resolve( typeof onFulfilled === 'function' ? onFulfilled( this.value ) : this.value );
					else if ( typeof onRejected === 'function' ) resolve( onRejected( this.value ) );
					else reject( this.value );

				} catch ( e ) {

					reject( e );

				}

			};

			if ( this.state === 'pending' ) this.callbacks.push( run );
			else run();

		} );

	}

	catch( onRejected ) {

		return this.then( undefined, onRejected );

	}

	finally( f ) {

		return this.then( ( v ) => { f(); return v; }, ( e ) => { f(); throw e; } );

	}

}

function createMockGPU( options = {} ) {

	// options = {
	//   features: [ names ]             adapter features (default [ 'core-features-and-limits' ])
	//   limits: { maxFoo: n }           overrides of the WebGPU default limits
	//   preferredCanvasFormat: 'bgra8unorm'
	//   wgslLanguageFeatures: [ names ] (default []); null leaves gpu.wgslLanguageFeatures undefined
	//   adapterInfo: { vendor, architecture, device, description }
	//   noAdapter: true                 requestAdapter resolves null
	//   asyncPromises: false            native Promises instead of SyncPromises
	//   serialize: 'idl' | 'raw'        dictionary members only (default) or every own key
	//   strictEnums: true               throw TypeError for a value outside a WebGPU enum
	//   logReads: false                 also log property reads as [ target, 'get name', [] ]
	//   transientAttachment: true       define GPUTextureUsage.TRANSIENT_ATTACHMENT
	//   textureBindingViewDimension: false   expose the compatibility-mode texture attribute
	//   errorScope: ( filter, deviceId ) => null | { type: 'GPUValidationError', message }
	//   compilationMessages: ( moduleId ) => [ { message, type, lineNum, linePos } ]
	//   mappedData: ( bufferId, offset, size ) => ArrayBuffer | TypedArray | undefined
	//   maxValues: Infinity             typed data longer than this is logged as { length, hash }
	// }

	const SPEC = MOCK_GPU_SPEC;
	const opts = Object.assign( {
		features: [ 'core-features-and-limits' ], limits: {}, preferredCanvasFormat: 'bgra8unorm',
		wgslLanguageFeatures: [], adapterInfo: {}, noAdapter: false, asyncPromises: false, serialize: 'idl',
		strictEnums: true, logReads: false, transientAttachment: true, textureBindingViewDimension: false,
		errorScope: null, compilationMessages: null, mappedData: null, maxValues: Infinity,
	}, options || {} );
	const log = [];
	const ids = new WeakMap();
	let nextId = 1;
	const contexts = [];

	// ---- types
	const typeCache = new Map();
	function parseType( t ) {

		let r = typeCache.get( t );
		if ( r ) return r;
		let s = t.trim();
		let nullable = false;
		if ( s.endsWith( '?' ) ) { nullable = true; s = s.slice( 0, - 1 ); }
		let m;
		if ( ( m = /^Array\[(.+)\]$/.exec( s ) ) ) r = { kind: 'array', elem: m[ 1 ], nullable };
		else if ( ( m = /^Promise<(.+)>$/.exec( s ) ) ) r = { kind: 'promise', elem: m[ 1 ], nullable };
		else if ( ( m = /^Fn\((.*)\)$/.exec( s ) ) ) r = { kind: 'fn', nullable };
		else if ( ( m = /^(\w+)<(\w+)>$/.exec( s ) ) ) r = { kind: 'name', name: m[ 1 ], enum: m[ 2 ], nullable };
		else r = { kind: 'name', name: s, nullable };
		typeCache.set( t, r );
		return r;

	}

	// ---- objects
	const classes = {};
	const named = ( name, base ) => ( { [ name ]: class extends ( base || Object ) {} } )[ name ];
	for ( const kind of SPEC.handles ) classes[ kind ] = named( kind );
	for ( const sub of [ 'GPUValidationError', 'GPUOutOfMemoryError', 'GPUInternalError' ] ) classes[ sub ] = named( sub, classes.GPUError );
	classes.GPUPipelineError = named( 'GPUPipelineError', Error );
	classes.HTMLCanvasElement = named( 'HTMLCanvasElement' );

	function make( kind, props = {} ) {

		const o = new classes[ kind ]();
		Object.defineProperty( o, '_p', { value: props, enumerable: false } );
		ids.set( o, kind + '#' + ( nextId ++ ) );
		return o;

	}

	const isHandle = ( v ) => v !== null && typeof v === 'object' && ids.has( v );
	const idOf = ( v ) => ids.get( v );

	// ---- serialization
	function hashValues( values ) {

		let h = 2166136261;
		for ( const x of values ) {

			const s = String( x );
			for ( let i = 0; i < s.length; i ++ ) h = Math.imul( h ^ s.charCodeAt( i ), 16777619 ) >>> 0;
			h = Math.imul( h ^ 44, 16777619 ) >>> 0;

		}

		return h.toString( 16 );

	}

	function serData( v ) {

		let type, values;
		if ( v instanceof ArrayBuffer ) {

			type = 'ArrayBuffer';
			values = Array.from( new Uint8Array( v ) );

		} else if ( v instanceof DataView ) {

			type = 'DataView';
			values = Array.from( new Uint8Array( v.buffer, v.byteOffset, v.byteLength ) );

		} else if ( ArrayBuffer.isView( v ) ) {

			type = v.constructor.name;
			values = Array.from( v, ( x ) => ( typeof x === 'bigint' ? String( x ) : x ) );

		} else {

			return raw( v );

		}

		if ( values.length > opts.maxValues ) return { $typed: type, length: values.length, hash: hashValues( values ) };
		return { $typed: type, values };

	}

	function raw( v, depth = 0 ) {

		if ( v === undefined || v === null || typeof v !== 'object' ) return typeof v === 'function' ? '<function>' : v;
		if ( isHandle( v ) ) return '<' + idOf( v ) + '>';
		if ( v instanceof ArrayBuffer || ArrayBuffer.isView( v ) ) return serData( v );
		if ( depth > 16 ) return '<deep>';
		if ( Array.isArray( v ) ) return v.map( ( x ) => ( x === undefined ? null : raw( x, depth + 1 ) ) );
		const out = {};
		for ( const k of Object.keys( v ) ) {

			if ( v[ k ] === undefined ) continue;
			out[ k ] = raw( v[ k ], depth + 1 );

		}

		return out;

	}

	function checkEnum( v, e, where ) {

		const values = SPEC.enums[ e ];
		if ( opts.strictEnums && values && ! values.includes( v ) ) {

			throw new TypeError( `${ where }: '${ v }' is not a valid enum value of type ${ e }.` );

		}

	}

	function ser( v, t, where ) {

		if ( v === undefined || v === null ) return v;
		if ( typeof v === 'function' ) return '<function>';
		if ( isHandle( v ) ) return '<' + idOf( v ) + '>';
		const T = parseType( t );
		if ( T.kind === 'array' ) {

			if ( typeof v !== 'object' || typeof v[ Symbol.iterator ] !== 'function' ) return raw( v );
			return Array.from( v, ( x, i ) => ( x === undefined ? null : ser( x, T.elem, where + '[' + i + ']' ) ) );

		}

		const name = T.name;
		if ( SPEC.dictionaries[ name ] ) return serDict( v, name, where );
		if ( SPEC.unions[ name ] ) {

			if ( typeof v === 'string' ) return v;
			const dict = SPEC.unions[ name ].find( ( u ) => SPEC.dictionaries[ u ] );
			return dict ? serDict( v, dict, where ) : raw( v );

		}

		if ( name === 'Source' || v instanceof ArrayBuffer || ArrayBuffer.isView( v ) ) return serData( v );
		if ( typeof v === 'object' ) return raw( v );
		if ( T.enum ) checkEnum( v, T.enum, where );
		return v;

	}

	function serDict( v, name, where ) {

		if ( typeof v !== 'object' || Array.isArray( v ) ) return raw( v );
		const fields = SPEC.dictionaries[ name ];
		const out = {};
		if ( opts.serialize === 'raw' ) {

			for ( const k of Object.keys( v ) ) {

				if ( v[ k ] === undefined ) continue;
				out[ k ] = fields[ k ] ? ser( v[ k ], fields[ k ], where + '.' + k ) : raw( v[ k ] );

			}

			return out;

		}

		// eslint-disable-next-line guard-for-in
		for ( const k in v ) {

			if ( ! Object.prototype.hasOwnProperty.call( fields, k ) ) continue;
			const x = v[ k ];
			if ( x === undefined ) continue;
			out[ k ] = ser( x, fields[ k ], where + '.' + k );

		}

		return out;

	}

	// ---- promises
	const wrap = ( value ) => ( opts.asyncPromises ? Promise.resolve( value ) : SyncPromise.resolve( value ) );
	const wrapReject = ( e ) => ( opts.asyncPromises ? Promise.reject( e ) : SyncPromise.reject( e ) );
	function pending() {

		let resolve;
		const p = opts.asyncPromises ? new Promise( ( r ) => { resolve = r; } ) : new SyncPromise( ( r ) => { resolve = r; } );
		return { promise: p, resolve };

	}

	class Rejection {

		constructor( error ) {

			this.error = error;

		}

	}

	// ---- recording
	function record( target, method, args, extra ) {

		const entry = [ isHandle( target ) ? idOf( target ) : String( target ), method, args ];
		if ( extra ) entry.push( extra );
		log.push( entry );
		return entry;

	}

	const setExtra = ( entry, extra ) => {

		if ( entry.length > 3 ) Object.assign( entry[ 3 ], extra );
		else entry.push( extra );

	};

	function defaultResult( kind, method, t ) {

		const T = parseType( t );
		if ( T.kind === 'name' && T.name === 'Unit' ) return undefined;
		if ( T.kind === 'name' && SPEC.handles.includes( T.name ) ) return make( T.name );
		throw new Error( `mock_gpu: no behaviour for ${ kind }.${ method } returning ${ t }` );

	}

	function invoke( obj, kind, name, args ) {

		const m = SPEC.interfaces[ kind ].methods[ name ];
		const sargs = args.map( ( a, i ) => ser( a, m.params[ i ] ? m.params[ i ][ 1 ] : 'JsValue', `${ kind }.${ name } argument ${ i + 1 }` ) );
		while ( sargs.length > 0 && sargs[ sargs.length - 1 ] === undefined ) sargs.pop();
		const entry = record( obj, name, sargs );
		const ret = parseType( m.ret );
		const behaviour = BEHAVIOURS[ kind + '.' + name ];
		const inner = ret.kind === 'promise' ? ret.elem : m.ret;
		let value;
		try {

			value = behaviour ? behaviour( obj, args, entry ) : defaultResult( kind, name, inner );

		} catch ( e ) {

			if ( e instanceof Rejection && ret.kind === 'promise' ) return wrapReject( e.error );
			throw e;

		}

		if ( value instanceof Rejection ) return wrapReject( value.error );
		if ( isHandle( value ) ) setExtra( entry, { ret: idOf( value ) } );
		return ret.kind === 'promise' ? wrap( value ) : value;

	}

	// ---- behaviours (anything returning other than Unit / a new handle)
	const DEFAULT_LIMITS = SPEC.limits;
	function makeSet( kind, values ) {

		return make( kind, { set: new Set( values ) } );

	}

	function makeLimits( extra ) {

		return make( 'GPUSupportedLimits', Object.assign( {}, DEFAULT_LIMITS, opts.limits, extra || {} ) );

	}

	function makeAdapter() {

		const adapter = make( 'GPUAdapter' );
		adapter._p.features = makeSet( 'GPUSupportedFeatures', opts.features );
		adapter._p.limits = makeLimits();
		adapter._p.info = make( 'GPUAdapterInfo', Object.assign( { vendor: '', architecture: '', device: '', description: '' }, opts.adapterInfo ) );
		return adapter;

	}

	function makeDevice( adapter, descriptor ) {

		const d = descriptor || {};
		const device = make( 'GPUDevice', { label: d.label || '', scopes: [] } );
		device._p.queue = make( 'GPUQueue' );
		const supported = adapter._p.features._p.set;
		device._p.features = makeSet( 'GPUSupportedFeatures', ( d.requiredFeatures || [] ).filter( ( f ) => supported.has( f ) ) );
		device._p.limits = makeLimits( d.requiredLimits );
		const lost = pending();
		device._p.lost = lost.promise;
		device._p.resolveLost = lost.resolve;
		return device;

	}

	function makeTexture( d ) {

		const size = d.size || {};
		const width = Array.isArray( size ) ? size[ 0 ] : size.width;
		const height = ( Array.isArray( size ) ? size[ 1 ] : size.height ) ?? 1;
		const depth = ( Array.isArray( size ) ? size[ 2 ] : size.depthOrArrayLayers ) ?? 1;
		const dimension = d.dimension ?? '2d';
		let tbvd;
		if ( opts.textureBindingViewDimension ) {

			tbvd = d.textureBindingViewDimension ?? ( dimension === '1d' ? '1d' : dimension === '3d' ? '3d' : depth === 1 ? '2d' : '2d-array' );

		}

		return make( 'GPUTexture', {
			width, height, depthOrArrayLayers: depth, mipLevelCount: d.mipLevelCount ?? 1, sampleCount: d.sampleCount ?? 1,
			dimension, format: d.format, usage: d.usage, textureBindingViewDimension: tbvd, label: d.label ?? '',
		} );

	}

	function makeError( e ) {

		const cls = e.type && classes[ e.type ] && /Error$/.test( e.type ) ? e.type : 'GPUValidationError';
		return make( cls, { message: e.message || '' } );

	}

	const BEHAVIOURS = {
		'GPU.requestAdapter': () => ( opts.noAdapter ? null : makeAdapter() ),
		'GPU.getPreferredCanvasFormat': () => opts.preferredCanvasFormat,
		'WGSLLanguageFeatures.has': ( s, [ n ] ) => s._p.set.has( n ),
		'GPUSupportedFeatures.has': ( s, [ n ] ) => s._p.set.has( n ),
		'GPUAdapter.requestDevice': ( a, [ d ] ) => makeDevice( a, d ),
		'GPUDevice.destroy': ( dev ) => {

			dev._p.resolveLost( make( 'GPUDeviceLostInfo', { reason: 'destroyed', message: '' } ) );

		},
		'GPUDevice.createBuffer': ( dev, [ d ] ) => make( 'GPUBuffer', {
			size: d.size, usage: d.usage, label: d.label ?? '', mapState: d.mappedAtCreation ? 'mapped' : 'unmapped',
			mapping: d.mappedAtCreation ? { write: true, ranges: [] } : null,
		} ),
		'GPUDevice.createTexture': ( dev, [ d ] ) => makeTexture( d ),
		'GPUDevice.createQuerySet': ( dev, [ d ] ) => make( 'GPUQuerySet', { type: d.type, count: d.count } ),
		'GPUDevice.pushErrorScope': ( dev, [ filter ] ) => {

			dev._p.scopes.push( filter );

		},
		'GPUDevice.popErrorScope': ( dev ) => {

			if ( dev._p.scopes.length === 0 ) return new Rejection( new Error( 'OperationError: popErrorScope with an empty error scope stack' ) );
			const filter = dev._p.scopes.pop();
			const e = opts.errorScope ? opts.errorScope( filter, idOf( dev ) ) : null;
			return e ? makeError( e ) : null;

		},
		'GPUQueue.submit': () => {

			for ( const ctx of contexts ) ctx._p.current = null;

		},
		'GPUBuffer.mapAsync': ( b, [ mode ] ) => {

			b._p.mapState = 'mapped';
			b._p.mapping = { write: ( mode & 2 ) !== 0, ranges: [] };

		},
		'GPUBuffer.getMappedRange': ( b, [ offset = 0, size ] ) => {

			const n = size ?? ( b._p.size - offset );
			const ab = new ArrayBuffer( n );
			const data = opts.mappedData ? opts.mappedData( idOf( b ), offset, n ) : undefined;
			if ( data !== undefined ) {

				const src = data instanceof ArrayBuffer ? new Uint8Array( data ) : new Uint8Array( data.buffer, data.byteOffset, data.byteLength );
				new Uint8Array( ab ).set( src.subarray( 0, n ) );

			}

			if ( b._p.mapping ) b._p.mapping.ranges.push( [ offset, ab ] );
			return ab;

		},
		'GPUBuffer.unmap': ( b, args, entry ) => {

			const m = b._p.mapping;
			if ( m && m.write ) setExtra( entry, { data: m.ranges.map( ( [ offset, ab ] ) => ( { offset, bytes: serData( ab ) } ) ) } );
			b._p.mapping = null;
			b._p.mapState = 'unmapped';

		},
		'GPUBuffer.destroy': ( b ) => {

			b._p.mapping = null;
			b._p.mapState = 'unmapped';

		},
		'GPUShaderModule.getCompilationInfo': ( module ) => make( 'GPUCompilationInfo', {
			messages: ( opts.compilationMessages ? opts.compilationMessages( idOf( module ) ) : [] ).map( ( x ) => make( 'GPUCompilationMessage',
				Object.assign( { message: '', type: 'error', lineNum: 0, linePos: 0, offset: 0, length: 0 }, x ) ) ),
		} ),
		'GPUCanvasContext.configure': ( ctx, [ configuration ] ) => {

			ctx._p.configuration = configuration;
			ctx._p.current = null;

		},
		'GPUCanvasContext.unconfigure': ( ctx ) => {

			ctx._p.configuration = null;
			ctx._p.current = null;

		},
		'GPUCanvasContext.getCurrentTexture': ( ctx ) => {

			if ( ! ctx._p.current ) {

				const c = ctx._p.configuration || {};
				ctx._p.current = makeTexture( { size: { width: ctx._p.canvas.width, height: ctx._p.canvas.height },
					format: c.format, usage: c.usage ?? 0x10 } );

			}

			return ctx._p.current;

		},
	};

	// ---- prototypes from the spec
	for ( const [ kind, iface ] of Object.entries( SPEC.interfaces ) ) {

		const proto = classes[ kind ].prototype;
		for ( const name of Object.keys( iface.methods ) ) {

			Object.defineProperty( proto, name, {
				value: function ( ...args ) { return invoke( this, kind, name, args ); },
				writable: true, configurable: true,
			} );

		}

		for ( const [ name, p ] of Object.entries( iface.props ) ) {

			const desc = {
				get() {

					if ( opts.logReads ) record( this, 'get ' + name, [] );
					return this._p[ name ];

				},
				configurable: true,
			};
			if ( p.access !== 'r' ) {

				desc.set = function ( v ) {

					record( this, 'set ' + name, [ ser( v, p.type, `${ kind }.${ name }` ) ] );
					this._p[ name ] = v;

				};

			}

			Object.defineProperty( proto, name, desc );

		}

	}

	// set-likes: `size` and iteration are not bound but harmless
	for ( const kind of [ 'GPUSupportedFeatures', 'WGSLLanguageFeatures' ] ) {

		const proto = classes[ kind ].prototype;
		Object.defineProperty( proto, 'size', { get() { return this._p.set.size; } } );
		proto.values = function () { return this._p.set.values(); };
		proto.forEach = function ( f ) { this._p.set.forEach( ( v ) => f( v, v, this ) ); };
		proto[ Symbol.iterator ] = function () { return this._p.set.values(); };

	}

	const gpu = make( 'GPU' );
	if ( opts.wgslLanguageFeatures !== null ) gpu._p.wgslLanguageFeatures = makeSet( 'WGSLLanguageFeatures', opts.wgslLanguageFeatures );

	function createCanvas( { width = 300, height = 150 } = {} ) {

		const canvas = new classes.HTMLCanvasElement();
		ids.set( canvas, 'HTMLCanvasElement#' + ( nextId ++ ) );
		canvas.width = width;
		canvas.height = height;
		canvas.style = {};
		let context = null;
		canvas.getContext = ( type ) => {

			const entry = record( canvas, 'getContext', [ type ] );
			if ( type !== 'webgpu' ) return null;
			if ( context === null ) {

				context = make( 'GPUCanvasContext', { canvas, configuration: null, current: null } );
				contexts.push( context );

			}

			setExtra( entry, { ret: idOf( context ) } );
			return context;

		};

		canvas.setAttribute = () => {};
		canvas.addEventListener = () => {};
		canvas.removeEventListener = () => {};
		return canvas;

	}

	function install( target = globalThis ) {

		if ( target.navigator ) {

			Object.defineProperty( target.navigator, 'gpu', { value: gpu, configurable: true, writable: true } );

		} else {

			target.navigator = { gpu, userAgent: 'mock_gpu' };

		}

		for ( const [ ns, values ] of Object.entries( SPEC.namespaces ) ) {

			const v = Object.assign( {}, values );
			if ( ns === 'GPUTextureUsage' && ! opts.transientAttachment ) delete v.TRANSIENT_ATTACHMENT;
			target[ ns ] = Object.freeze( v );

		}

		for ( const [ name, cls ] of Object.entries( classes ) ) {

			if ( name !== 'HTMLCanvasElement' ) target[ name ] = cls;

		}

		return target;

	}

	return {
		gpu, log, classes, install, createCanvas, idOf,
		SyncPromise,
		serialize: ( v, type ) => ( type ? ser( v, type, 'serialize' ) : raw( v ) ),
		note: ( label, value ) => { log.push( [ 'note', label, raw( value ) ] ); },
		logText: () => log.map( ( e ) => JSON.stringify( e ) ).join( '\n' ),
		loseDevice: ( device, reason = 'unknown', message = '' ) => device._p.resolveLost( make( 'GPUDeviceLostInfo', { reason, message } ) ),
		uncapturedError: ( device, message, type = 'GPUValidationError' ) => {

			const handler = device._p.onuncapturederror;
			const event = make( 'GPUUncapturedErrorEvent', { error: makeError( { type, message } ) } );
			if ( typeof handler === 'function' ) handler( event );
			return event;

		},
	};

}

// ---------------------------------------------------------------------------------------
// MOCK_GPU_SPEC from the binding spec.

const spec = { handles: handles.map( ( [ h ] ) => h ), interfaces: {}, dictionaries: {}, unions: {}, enums, namespaces, limits };
for ( const [ kind, { methods, props } ] of Object.entries( interfaces ) ) {

	const ms = {};
	for ( const s of methods ) {

		const m = parseMethod( s );
		if ( ms[ m.js ] ) continue; // a second MoonBit name for the same JS method (create_view_js)
		ms[ m.js ] = { params: m.params.map( ( p ) => [ p.name, p.type.text + ( p.type.nullable ? '?' : '' ), p.optional ] ), ret: m.ret.text + ( m.ret.nullable ? '?' : '' ) };

	}

	const ps = {};
	for ( const s of props ) {

		const p = parseProp( s );
		ps[ p.js ] = { type: p.type.text, access: p.access };

	}

	spec.interfaces[ kind ] = { methods: ms, props: ps };

}

for ( const [ name, d ] of Object.entries( dictionaries ) ) {

	spec.dictionaries[ name ] = Object.fromEntries( d.fields.map( parseField ).map( ( f ) => [ f.js, f.type.text + ( f.type.nullable ? '?' : '' ) ] ) );

}

for ( const [ name, variants ] of Object.entries( unions ) ) spec.unions[ name ] = variants.map( ( [ , t ] ) => t );

const body = `// Generated by tools/gen_gpu_mock.mjs from tools/gpu_spec.mjs. Do not edit by hand.
// A recording mock of the WebGPU API; see the comments in createMockGPU and in the generator.
const MOCK_GPU_SPEC = ${ JSON.stringify( spec ) };

${ SyncPromise.toString() }

${ createMockGPU.toString() }
`;

const outputs = [
	[ path.join( harness, 'mock_gpu_body.js' ), body ],
	[ path.join( harness, 'mock_gpu.cjs' ), `${ body }\nmodule.exports = { createMockGPU, SyncPromise, MOCK_GPU_SPEC };\n` ],
];

const lines = `(options) => {\n${ body }\nreturn createMockGPU(options);\n}`.split( '\n' ).map( ( l ) => '  #|' + l ).join( '\n' );
const mbt = `// Generated by tools/gen_gpu_mock.mjs from tools/gpu_spec.mjs: the recording mock WebGPU
// (diff/core/webgpu/mock_gpu_body.js) embedded for the tests. Do not edit by hand.

///|
extern "js" fn ffi_mock_gpu_create(options : @core.JsValue) -> @core.JsValue =
${ lines }
`;
outputs.push( [ path.join( repo, 'src/renderers/gpu/gpu_mock_gpu_test.mbt' ), mbt ] );
if ( checkOnly ) {

	const stale = outputs.filter( ( [ f, text ] ) => ! fs.existsSync( f ) || fs.readFileSync( f, 'utf8' ) !== text ).map( ( [ f ] ) => path.relative( repo, f ) );
	if ( stale.length ) {

		console.log( `stale: ${ stale.join( ', ' ) } (run node tools/gen_gpu_mock.mjs)` );
		process.exit( 1 );

	}

	console.log( 'mock_gpu_body.js, mock_gpu.cjs and gpu_mock_gpu_test.mbt are up to date' );
	process.exit( 0 );

}

fs.mkdirSync( harness, { recursive: true } );
for ( const [ f, text ] of outputs ) fs.writeFileSync( f, text );
console.log( `mock written: ${ Object.keys( spec.interfaces ).length } interfaces, ${ Object.values( spec.interfaces ).reduce( ( n, i ) => n + Object.keys( i.methods ).length, 0 ) } methods, ${ Object.keys( spec.dictionaries ).length } dictionaries` );
