// Upstream side of the G7 differential harness: upstream r187 modules, the foundation's
// recording mock GPU, a stub backend (a subclass of upstream's Backend whose methods log
// and drive the mock device) and a stub renderer with the members the renderer data
// classes read. scenarios_moon (src/nodes/common_g7_diff_test.mbt) builds the same
// objects on the MoonBit side; keep the two in step.
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { UPSTREAM } from '../../../lib/env.mjs';

import { createRequire } from 'node:module';
const require = createRequire( import.meta.url );

export const SRC = path.join( UPSTREAM, 'src' );
// the recording mock GPU of diff/core/webgpu; the MoonBit side loads it from G7_MOCK_GPU
export const MOCK_GPU = fileURLToPath( new URL( '../../webgpu/mock_gpu.cjs', import.meta.url ) );

const imp = async ( p ) => import( pathToFileURL( SRC + p ).href );

export const M = {};

export async function load() {

	// The entry points first, in the published bundles' order (Three.TSL.js, then
	// Three.WebGPU.js), so module-level nodes get the ids they have in the bundles and in
	// the port (src/nodes/core_module_node_ids.mbt); the imports below are then cached.
	globalThis.self ??= globalThis;
	await imp( '/Three.TSL.js' );
	await imp( '/Three.WebGPU.js' );
	M.Node = ( await imp( '/nodes/core/Node.js' ) ).default;
	M.TSL = await imp( '/nodes/TSL.js' );
	Object.assign( M, await imp( '/Three.Core.js' ) );
	M.NodeUniform = ( await imp( '/nodes/core/NodeUniform.js' ) ).default;
	M.NodeAttribute = ( await imp( '/nodes/core/NodeAttribute.js' ) ).default;
	M.ClippingGroup = ( await imp( '/objects/ClippingGroup.js' ) ).ClippingGroup;
	M.LightsNode = ( await imp( '/nodes/lighting/LightsNode.js' ) ).default;
	M.UniformGroups = await imp( '/nodes/core/UniformGroupNode.js' );
	M.NU = await imp( '/renderers/common/nodes/NodeUniform.js' );
	M.U = await imp( '/renderers/common/Uniform.js' );
	for ( const n of [ 'ChainMap', 'DataMap', 'Info', 'Attributes', 'Geometries', 'Textures', 'Bindings', 'Pipelines', 'RenderObjects', 'RenderObject', 'RenderList', 'RenderContexts', 'RenderContext', 'ClippingContext', 'BindGroup', 'UniformsGroup', 'UniformBuffer', 'Buffer', 'Sampler', 'StorageBuffer', 'ProgrammableStage', 'Backend', 'StorageBufferAttribute', 'StorageInstancedBufferAttribute', 'IndirectStorageBufferAttribute', 'StorageTexture', 'Storage3DTexture', 'StorageArrayTexture', 'RenderBundles', 'BundleGroup', 'ReadbackBuffer', 'TimestampQueryPool', 'Animation', 'InspectorBase' ] ) {

		M[ n ] = ( await imp( '/renderers/common/' + n + '.js' ) ).default;

	}

	M.BufferUtils = await imp( '/renderers/common/BufferUtils.js' );
	M.SampledTextures = await imp( '/renderers/common/SampledTexture.js' );
	for ( const n of [ 'NodeUniformsGroup', 'NodeSampler', 'NodeBuilderState', 'NodeManager', 'NodeLibrary', 'NodeUniformBuffer' ] ) {

		M[ n ] = ( await imp( '/renderers/common/nodes/' + n + '.js' ) ).default;

	}

	M.NodeSampledTextures = await imp( '/renderers/common/nodes/NodeSampledTexture.js' );
	M.NodeStorageBufferClass = ( await imp( '/renderers/common/nodes/NodeStorageBuffer.js' ) ).default;
	M.NodeMaterial = ( await imp( '/materials/nodes/NodeMaterial.js' ) ).default;
	M.ContextNode = await imp( '/nodes/core/ContextNode.js' );

}

// ---- counters: both sides advance the global id counters to the same values.

export const TARGETS = { node: 20000, object3d: 1000, material: 1000, texture: 1000, attribute: 1000, geometry: 1000 };

export function align( log ) {

	const probe = {
		node: () => new M.Node().id,
		object3d: () => new M.Object3D().id,
		material: () => new M.Material().id,
		texture: () => new M.Texture().id,
		attribute: () => new M.BufferAttribute( new Float32Array( 1 ), 1 ).id,
		geometry: () => new M.BufferGeometry().id,
	};
	for ( const [ k, f ] of Object.entries( probe ) ) {

		let id = f();
		if ( id >= TARGETS[ k ] ) throw new Error( `counter ${k} already at ${id}` );
		while ( id < TARGETS[ k ] - 1 ) id = f();

	}

	log.push( [ 'aligned' ] );

}

// ---- logging

export function bytes( typed ) {

	return Array.from( new Uint8Array( typed.buffer, typed.byteOffset, typed.byteLength ) );

}

// ---- mock GPU

export function createDevice() {

	const { createMockGPU } = require( MOCK_GPU );
	const mock = createMockGPU( {} );
	let device;
	mock.gpu.requestAdapter().then( ( a ) => a.requestDevice() ).then( ( d ) => { device = d; } );
	return { mock, device };

}

// ---- stub backend

export function createStubBackend( log ) {

	const { mock, device } = createDevice();
	const USAGE = { MAP_READ: 1, COPY_DST: 8, INDEX: 16, VERTEX: 32, UNIFORM: 64, STORAGE: 128, INDIRECT: 256 };

	class StubBackend extends M.Backend {

		constructor() {

			super( {} );
			this.isWebGPUBackend = true;
			this.mock = mock;
			this.device = device;
			this.needsUpdateFlag = false;

		}

		_createBuffer( kind, attribute, usage ) {

			const array = attribute.array;
			const size = array.byteLength + ( ( 4 - ( array.byteLength % 4 ) ) % 4 );
			log.push( [ 'backend', kind, attribute.name || '', array.constructor.name, array.length, attribute.version ] );
			const buffer = device.createBuffer( { label: attribute.name || '', size, usage: usage | USAGE.COPY_DST } );
			device.queue.writeBuffer( buffer, 0, new Uint8Array( array.buffer, array.byteOffset, array.byteLength ) );
			this.get( attribute ).buffer = buffer;

		}

		createAttribute( a ) { this._createBuffer( 'createAttribute', a, USAGE.VERTEX ); }
		createIndexAttribute( a ) { this._createBuffer( 'createIndexAttribute', a, USAGE.INDEX ); }
		createStorageAttribute( a ) { this._createBuffer( 'createStorageAttribute', a, USAGE.STORAGE | USAGE.VERTEX ); }
		createIndirectStorageAttribute( a ) { this._createBuffer( 'createIndirectStorageAttribute', a, USAGE.STORAGE | USAGE.INDIRECT ); }

		updateAttribute( a ) {

			log.push( [ 'backend', 'updateAttribute', a.name || '', a.version ] );
			const array = a.array;
			device.queue.writeBuffer( this.get( a ).buffer, 0, new Uint8Array( array.buffer, array.byteOffset, array.byteLength ) );

		}

		destroyAttribute( a ) {

			log.push( [ 'backend', 'destroyAttribute', a.name || '' ] );
			this.get( a ).buffer.destroy();
			this.delete( a );

		}

		createUniformBuffer( b ) {

			log.push( [ 'backend', 'createUniformBuffer', b.name, b.byteLength ] );
			this.get( b ).buffer = device.createBuffer( { label: b.name, size: b.byteLength, usage: USAGE.UNIFORM | USAGE.COPY_DST } );

		}

		updateBinding( b ) {

			log.push( [ 'backend', 'updateBinding', b.name, b.updateRanges.map( ( r ) => [ r.start, r.count ] ) ] );
			const buffer = b.buffer;
			device.queue.writeBuffer( this.get( b ).buffer, 0, new Uint8Array( buffer.buffer, buffer.byteOffset, buffer.byteLength ) );

		}

		destroyUniformBuffer( b ) {

			log.push( [ 'backend', 'destroyUniformBuffer', b.name ] );
			this.get( b ).buffer.destroy();

		}

		createBindings( bindGroup, bindings, cacheIndex ) {

			log.push( [ 'backend', 'createBindings', bindGroup.name, bindGroup.id, bindGroup.bindings.map( ( b ) => b.name ), bindings.length, cacheIndex ] );

		}

		updateBindings( bindGroup, bindings, cacheKey, version ) {

			log.push( [ 'backend', 'updateBindings', bindGroup.name, bindGroup.id, cacheKey, version ] );

		}

		deleteBindGroupData( bindGroup ) {

			log.push( [ 'backend', 'deleteBindGroupData', bindGroup.name, bindGroup.id ] );

		}

		updateSampler( b ) {

			const t = b.texture;
			const key = `${t.minFilter}-${t.magFilter}-${t.wrapS}`;
			log.push( [ 'backend', 'updateSampler', b.name, key ] );
			return key;

		}

		destroySampler( b ) {

			log.push( [ 'backend', 'destroySampler', b.name ] );

		}

		_options( o ) {

			return [ o.sampleCount === undefined ? null : o.sampleCount, o.width, o.height, o.depth, o.needsMipmaps, o.levels, o.image !== undefined, o.images === undefined ? null : o.images.length ];

		}

		createDefaultTexture( t ) { log.push( [ 'backend', 'createDefaultTexture', t.id ] ); }
		createTexture( t, o ) { log.push( [ 'backend', 'createTexture', t.id, this._options( o ) ] ); }
		updateTexture( t, o ) { log.push( [ 'backend', 'updateTexture', t.id, this._options( o ) ] ); }
		generateMipmaps( t ) { log.push( [ 'backend', 'generateMipmaps', t.id ] ); }
		destroyTexture( t, isDefault ) { log.push( [ 'backend', 'destroyTexture', t.id, isDefault === undefined ? null : isDefault ] ); }

		createProgram( p ) { log.push( [ 'backend', 'createProgram', p.id, p.stage, p.name, p.code ] ); }
		destroyProgram( p ) { log.push( [ 'backend', 'destroyProgram', p.id, p.stage ] ); }

		createRenderPipeline( renderObject ) {

			log.push( [ 'backend', 'createRenderPipeline', renderObject.id, renderObject.pipeline.cacheKey ] );
			this.get( renderObject.pipeline ).pipeline = { gpu: true };

		}

		createComputePipeline( pipeline, bindings ) { log.push( [ 'backend', 'createComputePipeline', pipeline.cacheKey, bindings.length ] ); }
		destroyPipeline( pipeline ) { log.push( [ 'backend', 'destroyPipeline', pipeline.cacheKey ] ); }

		needsRenderUpdate( renderObject ) {

			log.push( [ 'backend', 'needsRenderUpdate', renderObject.id ] );
			return this.needsUpdateFlag;

		}

		getRenderCacheKey( renderObject ) {

			return 's' + renderObject.material.side;

		}

		deleteVertexState( renderObject ) { log.push( [ 'backend', 'deleteVertexState', renderObject.id ] ); }

	}

	return new StubBackend();

}

// ---- stub renderer: the members the renderer data classes read, as in a fresh
// WebGPURenderer (mirrored by Renderer::foundation_stub on the MoonBit side).

export function createStubRenderer( backend ) {

	const renderer = {
		backend,
		info: new M.Info(),
		lighting: { enabled: true },
		shadowMap: { enabled: false, type: M.PCFShadowMap },
		_currentRenderContext: null,
		_currentSourceMaterial: null,
		contextNode: M.TSL.context(),
		_bindings: undefined,
		reversedDepthBuffer: false,
		_clearDepth: 1,
		_clearStencil: 0,
		_renderTarget: null,
		_outputRenderTarget: null,
		toneMapping: M.NoToneMapping,
		outputColorSpace: M.SRGBColorSpace,
		debug: { onNodeBuilderCreated: null },
		get isOutputTarget() { return this._renderTarget === this._outputRenderTarget || this._renderTarget === null; },
		get currentToneMapping() { return this.isOutputTarget ? this.toneMapping : M.NoToneMapping; },
		get currentColorSpace() { return this.isOutputTarget ? this.outputColorSpace : M.ColorManagement.workingColorSpace; },
		getClearDepth() { return ( this.reversedDepthBuffer === true ) ? 1 - this._clearDepth : this._clearDepth; },
		getClearStencil() { return this._clearStencil; },
		getRenderTarget() { return this._renderTarget; },
		getOutputRenderTarget() { return this._outputRenderTarget; },
	};
	backend.renderer = renderer;
	return renderer;

}

// The renderer modules wired as Renderer.init() wires them.
export function createModules( renderer ) {

	const backend = renderer.backend;
	const info = renderer.info;
	const nodes = new M.NodeManager( renderer, backend );
	const attributes = new M.Attributes( backend, info );
	const textures = new M.Textures( renderer, backend, info );
	const geometries = new M.Geometries( backend, attributes, info );
	const pipelines = new M.Pipelines( backend, nodes, info );
	const bindings = new M.Bindings( backend, nodes, textures, attributes, pipelines, info );
	renderer._bindings = bindings;
	const renderObjects = new M.RenderObjects( renderer, nodes, geometries, pipelines, bindings, info );
	const renderContexts = new M.RenderContexts( renderer );
	return { backend, info, nodes, attributes, textures, geometries, pipelines, bindings, renderObjects, renderContexts };

}

export function infoMemory( info ) {

	const m = info.memory;
	return [ m.attributes, m.attributesSize, m.geometries, m.indexAttributes, m.indexAttributesSize, m.indirectStorageAttributes, m.indirectStorageAttributesSize, m.programs, m.programsSize, m.readbackBuffers, m.readbackBuffersSize, m.renderTargets, m.storageAttributes, m.storageAttributesSize, m.textures, m.texturesSize, m.uniformBuffers, m.uniformBuffersSize, m.total ];

}
