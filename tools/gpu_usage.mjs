// Scans the upstream three.js sources for every WebGPU API use: methods called and
// properties read or written on each WebGPU object kind, the constant namespaces
// (`GPUBufferUsage.COPY_DST`, ...), the string-enum tables of WebGPUConstants.js and the
// enum-valued string literals passed to the API.
//
// Usage: node tools/gpu_usage.mjs [three.js/src] [--out usage.json]
//   -> prints (or writes) JSON:
//   { kinds: { GPUDevice: { methods: { createBuffer: [ '1 @WebGPUBackend.js', ... ] },
//                           props: { queue: [ 'r' ], onuncapturederror: [ 'w' ] } }, ... },
//     namespaces: { GPUBufferUsage: [ 'COPY_DST', ... ], ... },
//     constantsTables: { GPUTextureFormat: { RGBA8Unorm: 'rgba8unorm', ... }, ... },
//     literals: { loadOp: [ 'clear' ], pushErrorScope: [ 'validation' ], ... },
//     unresolved: [ 'file:line recv.member' ], unbound: [ notes ] }
//
// Attribution is by member name and receiver. Members that exist on exactly one WebGPU
// interface (createBuffer, beginRenderPass, writeBuffer, ...) are attributed wherever the
// receiver is not one of three's own helper objects (`this`, `*Utils`, `backend`). Shared
// names (destroy, end, finish, draw, format, size, ...) need a receiver listed in
// RECEIVERS; anything else with a WebGPU-only name lands in `unresolved`, which
// check_gpu_coverage.mjs requires to be empty.

import fs from 'node:fs';
import path from 'node:path';
import url from 'node:url';

const here = path.dirname( url.fileURLToPath( import.meta.url ) );
const args = process.argv.slice( 2 );
const outIdx = args.indexOf( '--out' );
const outFile = outIdx >= 0 ? args[ outIdx + 1 ] : null;
const positional = args.filter( ( a, i ) => ! a.startsWith( '--' ) && ! ( i > 0 && args[ i - 1 ] === '--out' ) );
const SRC = path.resolve( positional[ 0 ] ?? path.join( here, '..', '.repos', 'three.js', 'src' ) );

// WebGPU IDL members (methods `m()`, attributes `a`) per interface, from the WebGPU spec
// (as in TypeScript's lib.dom.d.ts plus the members upstream touches that are newer).
const IDL = {
	GPU: [ 'requestAdapter()', 'getPreferredCanvasFormat()', 'wgslLanguageFeatures' ],
	GPUAdapter: [ 'features', 'limits', 'info', 'requestDevice()' ],
	GPUAdapterInfo: [ 'vendor', 'architecture', 'device', 'description', 'subgroupMinSize', 'subgroupMaxSize', 'isFallbackAdapter' ],
	// `values()` / `forEach()` / `size` also exist on Map and Set; upstream only calls `has`.
	GPUSupportedFeatures: [ 'has()' ],
	WGSLLanguageFeatures: [ 'has()' ],
	GPUSupportedLimits: [], // every `maxFoo` / `minFoo` read on a limits object
	GPUDevice: [ 'features', 'limits', 'adapterInfo', 'queue', 'lost', 'onuncapturederror', 'label',
		'destroy()', 'createBuffer()', 'createTexture()', 'createSampler()', 'importExternalTexture()',
		'createBindGroupLayout()', 'createPipelineLayout()', 'createBindGroup()', 'createShaderModule()',
		'createComputePipeline()', 'createRenderPipeline()', 'createComputePipelineAsync()',
		'createRenderPipelineAsync()', 'createCommandEncoder()', 'createRenderBundleEncoder()',
		'createQuerySet()', 'pushErrorScope()', 'popErrorScope()', 'addEventListener()' ],
	GPUQueue: [ 'submit()', 'onSubmittedWorkDone()', 'writeBuffer()', 'writeTexture()',
		'copyExternalImageToTexture()', 'copyElementImageToTexture()', 'label' ],
	GPUBuffer: [ 'size', 'usage', 'mapState', 'mapAsync()', 'getMappedRange()', 'unmap()', 'destroy()', 'label' ],
	GPUTexture: [ 'createView()', 'destroy()', 'width', 'height', 'depthOrArrayLayers', 'mipLevelCount',
		'sampleCount', 'dimension', 'format', 'usage', 'textureBindingViewDimension', 'label' ],
	GPUTextureView: [ 'label' ],
	GPUSampler: [ 'label' ],
	GPUBindGroupLayout: [ 'label' ],
	GPUBindGroup: [ 'label' ],
	GPUPipelineLayout: [ 'label' ],
	GPUShaderModule: [ 'getCompilationInfo()', 'label' ],
	GPUCompilationInfo: [ 'messages' ],
	// `offset` and `length` are left out: they collide with array reads and upstream never
	// reads them on a message.
	GPUCompilationMessage: [ 'message', 'type', 'lineNum', 'linePos' ],
	GPURenderPipeline: [ 'getBindGroupLayout()', 'label' ],
	GPUComputePipeline: [ 'getBindGroupLayout()', 'label' ],
	GPUCommandEncoder: [ 'beginRenderPass()', 'beginComputePass()', 'copyBufferToBuffer()',
		'copyBufferToTexture()', 'copyTextureToBuffer()', 'copyTextureToTexture()', 'clearBuffer()',
		'resolveQuerySet()', 'finish()', 'pushDebugGroup()', 'popDebugGroup()', 'insertDebugMarker()', 'label' ],
	GPURenderPassEncoder: [ 'setViewport()', 'setScissorRect()', 'setBlendConstant()', 'setStencilReference()',
		'beginOcclusionQuery()', 'endOcclusionQuery()', 'executeBundles()', 'end()', 'setPipeline()',
		'setIndexBuffer()', 'setVertexBuffer()', 'draw()', 'drawIndexed()', 'drawIndirect()',
		'drawIndexedIndirect()', 'setBindGroup()', 'pushDebugGroup()', 'popDebugGroup()', 'insertDebugMarker()', 'label' ],
	GPUComputePassEncoder: [ 'setPipeline()', 'dispatchWorkgroups()', 'dispatchWorkgroupsIndirect()', 'end()',
		'setBindGroup()', 'pushDebugGroup()', 'popDebugGroup()', 'insertDebugMarker()', 'label' ],
	GPURenderBundleEncoder: [ 'finish()', 'setPipeline()', 'setIndexBuffer()', 'setVertexBuffer()', 'draw()',
		'drawIndexed()', 'drawIndirect()', 'drawIndexedIndirect()', 'setBindGroup()', 'label' ],
	GPURenderBundle: [ 'label' ],
	GPUCommandBuffer: [ 'label' ],
	GPUQuerySet: [ 'destroy()', 'type', 'count', 'label' ],
	GPUCanvasContext: [ 'canvas', 'configure()', 'unconfigure()', 'getConfiguration()', 'getCurrentTexture()' ],
	GPUExternalTexture: [ 'label' ],
	GPUDeviceLostInfo: [ 'reason', 'message' ],
	GPUError: [ 'message' ],
	GPUUncapturedErrorEvent: [ 'error' ],
};

// Receiver expressions (normalized: `this.` and `?.` dropped, `[ ... ]` -> `[]`) that hold
// WebGPU objects. Keys are matched against the whole normalized receiver, then against its
// last segment. A `file:` prefix scopes an entry to one upstream file (basename).
const RECEIVERS = {
	'navigator.gpu': 'GPU',
	adapter: 'GPUAdapter',
	'adapter.features': 'GPUSupportedFeatures',
	'navigator.gpu.wgslLanguageFeatures': 'WGSLLanguageFeatures',
	device: 'GPUDevice', 'backend.device': 'GPUDevice', 'this.device': 'GPUDevice',
	'device.features': 'GPUSupportedFeatures', 'device.limits': 'GPUSupportedLimits',
	'backend.device.limits': 'GPUSupportedLimits',
	'device.queue': 'GPUQueue',
	context: 'GPUCanvasContext',
	// buffers
	'WebGPUBackend.js:buffer': 'GPUBuffer', 'WebGPUAttributeUtils.js:buffer': 'GPUBuffer', readBuffer: 'GPUBuffer', readBufferGPU: 'GPUBuffer', bufferGPU: 'GPUBuffer',
	resultBuffer: 'GPUBuffer', resolveBuffer: 'GPUBuffer', currentOcclusionQueryBuffer: 'GPUBuffer',
	'data.buffer': 'GPUBuffer', 'uniformBufferData.buffer': 'GPUBuffer',
	// textures
	'WebGPUBackend.js:texture': 'GPUTexture', textureGPU: 'GPUTexture', sourceGPU: 'GPUTexture', destinationGPU: 'GPUTexture',
	'textureData.texture': 'GPUTexture', 'depthTextureData.texture': 'GPUTexture', tempTexture: 'GPUTexture',
	msaaTexture: 'GPUTexture', msaaDepthTexture: 'GPUTexture', 'textureData.msaaTexture': 'GPUTexture',
	sourceTexture: 'GPUTexture', destinationTexture: 'GPUTexture', colorBuffer: 'GPUTexture',
	'msaaTextures[]': 'GPUTexture', 'textureData.msaaTextures[]': 'GPUTexture',
	'context.getCurrentTexture()': 'GPUTexture',
	// query sets
	querySet: 'GPUQuerySet', currentOcclusionQuerySet: 'GPUQuerySet', occlusionQuerySet: 'GPUQuerySet',
	// pipelines, modules
	pipeline: 'GPURenderPipeline', module: 'GPUShaderModule',
	// encoders
	encoder: 'GPUCommandEncoder', commandEncoder: 'GPUCommandEncoder', cmdEncoder: 'GPUCommandEncoder',
	cmdEncoderGPU: 'GPUCommandEncoder',
	// a render pass, or a bundle encoder between beginBundle and finishBundle
	currentPass: [ 'GPURenderPassEncoder', 'GPURenderBundleEncoder' ], renderPass: 'GPURenderPassEncoder',
	// `_draw( ..., passEncoderGPU )` and `draw` record into passes and bundle encoders;
	// `compute` destructures the compute pass as `passEncoderGPU` too
	'WebGPUBackend.js:pass': [ 'GPURenderPassEncoder', 'GPURenderBundleEncoder' ],
	'WebGPUBackend.js:passEncoderGPU': [ 'GPURenderPassEncoder', 'GPURenderBundleEncoder', 'GPUComputePassEncoder' ],
	'WebGPUBackend.js:groupData.passEncoderGPU': 'GPUComputePassEncoder',
	// WebGPUTexturePassUtils: `passEncoder` is a render pass in flipY/_mipmapRunBundles and a
	// bundle encoder in _mipmapCreateBundles
	'WebGPUTexturePassUtils.js:passEncoder': [ 'GPURenderPassEncoder', 'GPURenderBundleEncoder' ],
	bundleEncoder: 'GPURenderBundleEncoder',
	// errors and info objects
	'WebGPUBackend.js:info': 'GPUDeviceLostInfo', event: 'GPUUncapturedErrorEvent', gpuError: 'GPUError',
	err: 'GPUError', errorScope: 'GPUError', 'WebGPUPipelineUtils.js:info': 'GPUCompilationInfo',
	msg: 'GPUCompilationMessage',
	// three.js objects whose names collide with the ones above
	'WebGPUBindingUtils.js:buffer': 'none', // a GPUBufferBindingLayout dictionary
	'WebGPUTextureUtils.js:texture': 'none', // a three.js Texture
	'WebGPUTextureUtils.js:textureData.textureDescriptorGPU': 'none', // the descriptor kept beside the texture
};

// Uses that are not plain member accesses: feature tests, instanceof checks and helpers.
const SPECIAL = [
	[ /typeof\s+[\w.]+\.copyElementImageToTexture\s*!==\s*'function'/, 'GPUQueue.copyElementImageToTexture:typeof' ],
	[ /\.copyElementImageToTexture\.length/, 'GPUQueue.copyElementImageToTexture:length' ],
	[ /\.setBlendConstant\s*!==\s*undefined/, 'GPURenderPassEncoder.setBlendConstant:defined' ],
	[ /instanceof\s+GPURenderBundleEncoder/, 'instanceof:GPURenderBundleEncoder' ],
	[ /GPUTextureUsage\.TRANSIENT_ATTACHMENT\s*!==\s*undefined/, 'GPUTextureUsage.TRANSIENT_ATTACHMENT:defined' ],
	[ /gpuError\.constructor\.name/, 'GPUError.constructor.name' ],
	[ /getContext\(\s*'webgpu'\s*\)/, 'HTMLCanvasElement.getContext:webgpu' ],
	[ /new BigUint64Array\(/, 'BigUint64Array' ],
	[ /navigator\.gpu\s*!==\s*undefined/, 'navigator.gpu:defined' ],
	[ /navigator\.gpu\.wgslLanguageFeatures\s*!==\s*undefined/, 'GPU.wgslLanguageFeatures:defined' ],
	[ /\(\s*err\s*\)\s*\{[^}]*asyncError\s*=\s*err/, 'createRenderPipelineAsync:reject' ],
];


// Receivers that are three.js objects, never WebGPU ones.
const NOT_GPU = /^(this|super|backend|renderer|this\.backend|.*[uU]tils(\(\))?|.*Utils\.|textureUtils|.*\._getPassUtils\(\)|Object|Math|Array|navigator|options|parameters|descriptor.*|_.*[dD]escriptor.*|_extent3D.*|_texelCopy.*|_copyExternal.*|_colorAttachment|_renderPassTimestampWrites|_clearValue|_blendConstant|layer.*|textureDescriptorGPU.*|msaaTextureDescriptorGPU.*|textureGPUDescriptor.*|depthStencil.*|colorAttachment.*|attachment|sourceAttachment|renderContext.*|renderTarget.*|renderObject.*|material.*|geometry.*|object.*|binding.*|bindGroup|bindingsData.*|bufferAttribute.*|attribute.*|geometryAttribute.*|image.*|mipmap.*|texture\.image.*|canvasTarget.*|vp|rectangle|range|next|updateRanges.*|computeNode.*|dispatchSize.*|blendColor|clearColor|target.*|array.*|paddedArray|data|results|times|framesDuration|frames|currentOffsets|this\.queryOffsets|this\.timestamps|textureData|depthTextureData|renderContextData|occlusionData|groupGPU|groupData|pipelineData|pipelineGPU|computeNodeData|cameraData|uniformBufferData|readbackInfo|bufferData|samplerData|this\.transferPipelines|passes|pass\.passDescriptor|viewInfo|info\.update|msaaTextures|textureViews|colorAttachments|entries|vertexBufferLayout.*|targets|stages|program|computeStage|sourceLines|stencilFront|blendMode|mrt|cameras|subCamera|context\.(textures|camera|viewportValue|renderTarget|depth|stencil|mrt)|deviceLossInfo|err\.message|errorScope\.message|asyncError.*|e|_tail|bytes|colorTexture.*|depthTexture.*|textures|srcTexture.*|dstTexture.*|viewDescriptors|renderStages|workgroupSize|vertexBuffers|indirectOffsets|currentOcclusionQueryObjects|compilationHints|viewFormats|size|storageTexture|sampler|blockData|texture\.(layerUpdates|type|image)|.*\.copyElementImageToTexture|backend\..*|info\.messages|occlusionData\..*)$/;

const FILES = [];
const walk = ( dir ) => {

	for ( const f of fs.readdirSync( dir ) ) {

		const p = path.join( dir, f );
		if ( fs.statSync( p ).isDirectory() ) walk( p );
		else if ( f.endsWith( '.js' ) ) FILES.push( p );

	}

};

walk( path.join( SRC, 'renderers', 'webgpu' ) );
const OTHER_DIRS = [ 'renderers/common', 'nodes', 'materials/nodes', 'renderers/webgl-fallback' ];
const otherFiles = [];
{

	const keep = FILES.slice();
	FILES.length = 0;
	for ( const d of OTHER_DIRS ) if ( fs.existsSync( path.join( SRC, d ) ) ) walk( path.join( SRC, d ) );
	otherFiles.push( ...FILES );
	FILES.length = 0;
	FILES.push( ...keep );

}

function stripComments( text ) {

	// Keep string and template contents (labels, WGSL) but drop comments; good enough for
	// three.js sources, which never put `//` inside a string next to an API call.
	let out = '';
	let i = 0;
	let str = null;
	while ( i < text.length ) {

		const c = text[ i ];
		if ( str ) {

			out += c;
			if ( c === '\\' ) { out += text[ i + 1 ] ?? ''; i += 2; continue; }
			if ( c === str ) str = null;
			i ++;
			continue;

		}

		if ( c === '\'' || c === '"' || c === '`' ) { str = c; out += c; i ++; continue; }
		if ( c === '/' && text[ i + 1 ] === '*' ) {

			const end = text.indexOf( '*/', i + 2 );
			const chunk = text.slice( i, end + 2 );
			out += chunk.replace( /[^\n]/g, ' ' );
			i = end + 2;
			continue;

		}

		if ( c === '/' && text[ i + 1 ] === '/' ) {

			while ( i < text.length && text[ i ] !== '\n' ) { out += ' '; i ++; }
			continue;

		}

		out += c;
		i ++;

	}

	return out;

}

function argCount( text, start ) {

	let depth = 0, n = 0, any = false;
	for ( let i = start; i < text.length; i ++ ) {

		const c = text[ i ];
		if ( c === '(' || c === '[' || c === '{' ) { depth ++; if ( depth > 1 ) any = true; continue; }
		if ( c === ')' || c === ']' || c === '}' ) { depth --; if ( depth === 0 ) return any ? n + 1 : n; continue; }
		if ( depth === 1 && c === ',' ) { n ++; any = false; } else if ( depth === 1 && ! /\s/.test( c ) ) any = true;

	}

	return - 1;

}

// The receiver expression ending right before `text[ end ]` (the `.` of `.member`).
function receiverBefore( text, end ) {

	let i = end - 1;
	let depth = 0;
	while ( i >= 0 ) {

		const c = text[ i ];
		if ( c === ']' || c === ')' ) { depth ++; i --; continue; }
		if ( c === '[' || c === '(' ) { if ( depth === 0 ) break; depth --; i --; continue; }
		if ( depth > 0 ) { i --; continue; }
		if ( /[\w$.?]/.test( c ) ) { i --; continue; }
		if ( /\s/.test( c ) && /[\s.]/.test( text[ i + 1 ] ?? '' ) && text.slice( i + 1 ).trimStart()[ 0 ] === '.' ) { i --; continue; }
		break;

	}

	return text.slice( i + 1, end );

}

function normalize( recv ) {

	return recv.replace( /\s+/g, '' ).replace( /\?\./g, '.' ).replace( /\?$/, '' )
		.replace( /\[[^\]]*\]/g, '[]' ).replace( /\([^()]*\)/g, '()' ).replace( /^this\./, '' );

}

const memberKinds = new Map(); // name -> [ kinds ]
for ( const [ kind, members ] of Object.entries( IDL ) ) {

	for ( const m of members ) {

		const name = m.replace( '()', '' );
		if ( ! memberKinds.has( name ) ) memberKinds.set( name, [] );
		memberKinds.get( name ).push( kind );

	}

}

const kinds = {};
const add = ( kind, member, isCall, info ) => {

	const k = ( kinds[ kind ] ??= { methods: {}, props: {} } );
	const table = isCall ? k.methods : k.props;
	( table[ member ] ??= new Set() ).add( info );

};

const unresolved = [];
const receivers = {}; // 'Kind.member' -> receivers seen, for review

function resolveReceiver( file, recv ) {

	const base = path.basename( file );
	const n = normalize( recv );
	const last = n.split( '.' ).pop();
	for ( const key of [ `${ base }:${ n }`, n, `${ base }:${ last }`, last ] ) {

		if ( RECEIVERS[ key ] ) return RECEIVERS[ key ] === 'none' ? [] : RECEIVERS[ key ];

	}

	if ( n.startsWith( 'navigator.gpu' ) ) return 'GPU';
	return null;

}

function scanFile( file, text, gpuDir ) {

	const base = path.basename( file );
	const re = /\.\s*([A-Za-z_$][\w$]*)\b(\s*\()?(\s*=(?!=))?/g;
	let m;
	while ( ( m = re.exec( text ) ) ) {

		const [ , name, call, assign ] = m;
		const dot = m.index;
		const recv = receiverBefore( text, dot );
		if ( recv === '' ) continue;
		const n = normalize( recv );
		const line = text.slice( 0, dot ).split( '\n' ).length;
		// limits: any maxFoo / minFoo on a limits receiver
		if ( /(^|\.)limits$/.test( n ) && /^(max|min)[A-Z]/.test( name ) ) {

			add( 'GPUSupportedLimits', name, false, 'r @' + base );
			continue;

		}

		if ( n === 'navigator' && name === 'gpu' ) { add( 'GPU', '(navigator.gpu)', false, 'r @' + base ); continue; }
		const candidates = memberKinds.get( name );
		if ( ! candidates ) continue;
		if ( ! gpuDir && ! n.startsWith( 'navigator.gpu' ) ) continue;
		const member = call ? name + '()' : name;
		const owners = candidates.filter( ( c ) => IDL[ c ].includes( member ) );
		if ( owners.length === 0 ) continue;
		const resolved = resolveReceiver( file, recv );
		let targets;
		if ( resolved ) {

			targets = [ resolved ].flat().filter( ( k ) => IDL[ k ].includes( member ) );

		} else if ( NOT_GPU.test( n ) ) {

			continue;

		} else if ( owners.length === 1 && call ) {

			// a method only one WebGPU interface has
			targets = owners;

		} else {

			targets = [];

		}

		if ( targets.length === 0 && resolved && resolved.length === 0 ) continue;
		if ( targets.length === 0 ) {

			if ( gpuDir ) unresolved.push( `${ base }:${ line } ${ n }.${ member }` );
			continue;

		}

		const info = call ? `${ argCount( text, m.index + m[ 0 ].length - 1 ) } @${ base }` : `${ assign ? 'w' : 'r' } @${ base }`;
		for ( const kind of targets ) {

			add( kind, name, !! call, info );
			( receivers[ `${ kind }.${ name }` ] ??= new Set() ).add( n );

		}

	}

}

const namespaces = {};
const special = {};
const literals = {};
const addLit = ( key, v ) => ( literals[ key ] ??= new Set() ).add( v );
const LIT_KEYS = [ 'type', 'loadOp', 'storeOp', 'depthLoadOp', 'depthStoreOp', 'stencilLoadOp', 'stencilStoreOp',
	'aspect', 'dimension', 'format', 'alphaMode', 'mode', 'compare', 'minFilter', 'magFilter', 'mipmapFilter',
	'addressModeU', 'addressModeV', 'addressModeW', 'access', 'sampleType', 'viewDimension', 'layout',
	'featureLevel', 'powerPreference', 'colorSpace', 'swizzle', 'stepMode', 'topology', 'cullMode', 'frontFace' ];
const litRe = new RegExp( `\\b(${ LIT_KEYS.join( '|' ) })\\s*(?::|=(?!=))\\s*'([^']+)'`, 'g' );

for ( const file of [ ...FILES, ...otherFiles ] ) {

	const gpuDir = file.includes( path.join( 'renderers', 'webgpu' ) + path.sep ) && ! file.includes( path.join( 'webgpu', 'nodes' ) );
	const text = stripComments( fs.readFileSync( file, 'utf8' ) );
	scanFile( file, text, gpuDir );
	for ( const m of text.matchAll( /\b(GPUBufferUsage|GPUTextureUsage|GPUShaderStage|GPUMapMode|GPUColorWrite)\.([A-Z_]+)\b/g ) ) {

		( namespaces[ m[ 1 ] ] ??= new Set() ).add( m[ 2 ] );

	}

	if ( ! gpuDir ) {

		for ( const [ re, key ] of SPECIAL ) if ( re.test( text ) ) ( special[ key ] ??= new Set() ).add( path.basename( file ) );
		for ( const m of text.matchAll( /wgslLanguageFeatures\.has\(\s*'([^']+)'/g ) ) addLit( 'wgslLanguageFeatures', m[ 1 ] );
		continue;

	}

	for ( const [ re, key ] of SPECIAL ) if ( re.test( text ) ) ( special[ key ] ??= new Set() ).add( path.basename( file ) );
	for ( const m of text.matchAll( litRe ) ) addLit( m[ 1 ], m[ 2 ] );
	for ( const m of text.matchAll( /pushErrorScope\(\s*'([^']+)'/g ) ) addLit( 'pushErrorScope', m[ 1 ] );
	for ( const m of text.matchAll( /getContext\(\s*'([^']+)'/g ) ) addLit( 'getContext', m[ 1 ] );
	for ( const m of text.matchAll( /features\.has\(\s*'([^']+)'/g ) ) addLit( 'features', m[ 1 ] );
	for ( const m of text.matchAll( /mapState\s*[!=]==\s*'([^']+)'/g ) ) addLit( 'mapState', m[ 1 ] );
	for ( const m of text.matchAll( /reason\s*[!=]==\s*'([^']+)'/g ) ) addLit( 'reason', m[ 1 ] );
	for ( const m of text.matchAll( /msg\.type\s*[!=]==\s*'([^']+)'/g ) ) addLit( 'messageType', m[ 1 ] );

}

// WebGPUConstants.js: `export const Name = { Key: value, ... }` tables.
const constantsTables = {};
{

	const text = stripComments( fs.readFileSync( path.join( SRC, 'renderers/webgpu/utils/WebGPUConstants.js' ), 'utf8' ) );
	for ( const m of text.matchAll( /export const (\w+) = (?:\([^\n]*\? self\.\w+ : )?\{([^}]*)\}/g ) ) {

		const table = {};
		for ( const e of m[ 2 ].matchAll( /'?([\w-]+)'?\s*:\s*('([^']*)'|0x[0-9A-Fa-f]+|\d+)/g ) ) {

			table[ e[ 1 ] ] = e[ 3 ] !== undefined ? e[ 3 ] : Number( e[ 2 ] );

		}

		constantsTables[ m[ 1 ] ] = table;

	}

}

// renderers/webgpu/descriptors/*.js: the reusable descriptor classes, with their keys in
// constructor order (nested classes in the same file too). The bindings mirror them.
const descriptorClasses = {};
{

	const dir = path.join( SRC, 'renderers/webgpu/descriptors' );
	for ( const f of fs.readdirSync( dir ).sort() ) {

		const text = stripComments( fs.readFileSync( path.join( dir, f ), 'utf8' ) );
		for ( const c of text.matchAll( /class (\w+)(?: extends (\w+))? \{[\s\S]*?constructor\(\) \{([\s\S]*?)\n\t\}/g ) ) {

			const keys = [ ...c[ 3 ].matchAll( /this\.(\w+) = ([^;]+);/g ) ].map( ( k ) => [ k[ 1 ], k[ 2 ].trim() ] );
			descriptorClasses[ c[ 1 ] ] = { extends: c[ 2 ] ?? null, fields: keys };

		}

	}

}

// Keys assigned on descriptor objects outside the classes (`depthStencil.format = ...`,
// `bindingGPU.buffer = ...`, `_viewDescriptor.baseMipLevel = ...`) and keys of object
// literals that are WebGPU dictionaries: every one must be a field of a bound dictionary.
const descriptorKeys = {};
{

	const DESC = /^(_\w*([dD]escriptor|[aA]ttachment|Info|Layout|Writes|extent3D)\w*|descriptor|layerDescriptor|passDescriptor|depthStencilAttachment|colorAttachment|attachment|layerColorAttachment|layerDepthStencilAttachment|depthAttachment|passColorAttachment|textureDescriptorGPU|msaaTextureDescriptorGPU|depthStencil|bindingGPU|storageTexture|texture|sampler|buffer)$/;
	for ( const file of FILES ) {

		if ( file.includes( path.sep + 'descriptors' + path.sep ) || file.includes( path.sep + 'nodes' + path.sep ) ) continue;
		const base = path.basename( file );
		const text = stripComments( fs.readFileSync( file, 'utf8' ) );
		for ( const m of text.matchAll( /([\w$]+)\.([A-Za-z]\w*)(?:\.(\w+))?\s*=(?!=)/g ) ) {

			if ( ! DESC.test( m[ 1 ] ) ) continue;
			if ( base !== 'WebGPUBindingUtils.js' && /^(texture|sampler|buffer)$/.test( m[ 1 ] ) ) continue;
			const key = m[ 3 ] ? `${ m[ 2 ] }.${ m[ 3 ] }` : m[ 2 ];
			( descriptorKeys[ m[ 1 ] ] ??= new Set() ).add( key );

		}

	}

}

// Not part of the core WebGPU API: noted for the report, bound later if needed.
const unbound = [];
for ( const file of otherFiles ) {

	const text = stripComments( fs.readFileSync( file, 'utf8' ) );
	for ( const m of text.matchAll( /webgpuBinding\.(\w+)\(/g ) ) unbound.push( `XRGPUBinding.${ m[ 1 ] } @${ path.basename( file ) }` );

}

const sortObj = ( o, f ) => Object.fromEntries( Object.keys( o ).sort().map( ( k ) => [ k, f( o[ k ] ) ] ) );
const out = {
	kinds: sortObj( kinds, ( k ) => ( { methods: sortObj( k.methods, ( s ) => [ ...s ].sort() ), props: sortObj( k.props, ( s ) => [ ...s ].sort() ) } ) ),
	namespaces: sortObj( namespaces, ( s ) => [ ...s ].sort() ),
	constantsTables,
	literals: sortObj( literals, ( s ) => [ ...s ].sort() ),
	descriptorClasses,
	descriptorKeys: sortObj( descriptorKeys, ( s ) => [ ...s ].sort() ),
	special: sortObj( special, ( s ) => [ ...s ].sort() ),
	unresolved,
	receivers: sortObj( receivers, ( s ) => [ ...s ].sort() ),
	unbound: [ ...new Set( unbound ) ].sort(),
};
const json = JSON.stringify( out, null, 1 );
if ( outFile ) fs.writeFileSync( outFile, json + '\n' );
else console.log( json );
