// Upstream side of the G6 differential harness: upstream r187's Renderer with a stub
// backend (a subclass of upstream's Backend whose methods log their arguments) and a
// stub node builder (a NodeBuilder subclass whose prebuild/buildCode short-circuit the
// material build, which needs the not yet ported node materials). The MoonBit side
// (src/nodes/common_g6_diff_test.mbt) builds the same stubs; keep the two in step.
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { UPSTREAM } from '../../../lib/env.mjs';

export const SRC = path.join( UPSTREAM, 'src' );
const imp = async ( p ) => import( pathToFileURL( SRC + p ).href );
export const M = {};

export async function load() {

	// The entry points first, in the published bundles' order (Three.TSL.js, then
	// Three.WebGPU.js), so module-level nodes get the ids they have in the bundles and in
	// the port (src/nodes/core_module_node_ids.mbt); the imports below are then cached.
	globalThis.self ??= globalThis;
	await imp( '/Three.TSL.js' );
	await imp( '/Three.WebGPU.js' );
	Object.assign( M, await imp( '/Three.Core.js' ) );
	M.TSL = await imp( '/nodes/TSL.js' );
	M.Node = ( await imp( '/nodes/core/Node.js' ) ).default;
	M.NodeBuilder = ( await imp( '/nodes/core/NodeBuilder.js' ) ).default;
	M.NodeMaterial = ( await imp( '/materials/nodes/NodeMaterial.js' ) ).default;
	for ( const n of [ 'Renderer', 'Backend', 'QuadMesh', 'CubeRenderTarget', 'RenderPipeline', 'PostProcessing', 'DirectRenderPipeline', 'CanvasTarget', 'BundleGroup', 'InspectorBase', 'StorageBufferAttribute', 'IndirectStorageBufferAttribute', 'ReadbackBuffer', 'Lighting' ] ) {

		M[ n ] = ( await imp( '/renderers/common/' + n + '.js' ) ).default;

	}

	M.RendererUtils = await imp( '/renderers/common/RendererUtils.js' );
	M.PMREMGenerator = ( await imp( '/renderers/common/extras/PMREMGenerator.js' ) ).default;
	M.XRRenderTarget = ( await imp( '/renderers/common/XRRenderTarget.js' ) ).XRRenderTarget;

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

// ---- fake requestAnimationFrame (Animation reads `self`)

export function installFrames( log ) {

	const callbacks = [];
	globalThis.self = {
		requestAnimationFrame( cb ) { callbacks.push( cb ); return callbacks.length; },
		cancelAnimationFrame( id ) { log.push( [ 'cancelAnimationFrame', id ] ); },
	};
	return callbacks;

}

// ---- log values

const v4 = ( v ) => [ v.x, v.y, v.z, v.w ];
const id = ( o ) => ( o === null || o === undefined ) ? null : o.id;
// objects created at module load have runtime-specific ids
export const mid = ( o ) => o.id < 1000 ? 'module' : o.id;
const texIds = ( a ) => ( a === null || a === undefined ) ? null : a.map( ( t ) => t.id );

export function contextState( rc ) {

	const c = rc.clearColorValue;
	return [ rc.id, v4( rc.viewportValue ), rc.viewportValue.minDepth ?? null, rc.viewportValue.maxDepth ?? null, rc.viewport, v4( rc.scissorValue ), rc.scissor,
		rc.clearColor, [ c.r, c.g, c.b, c.a ], rc.clearDepth, rc.clearDepthValue, rc.clearStencil, rc.clearStencilValue,
		rc.depth, rc.stencil === true, rc.width, rc.height, rc.activeCubeFace, rc.activeMipmapLevel, rc.occlusionQueryCount, rc.fullscreenPass,
		rc.renderTarget ? rc.renderTarget.texture.id : null, texIds( rc.textures ), id( rc.depthTexture ), rc.camera ? mid( rc.camera ) : null, rc.mrt ? 'mrt' : null,
		rc.frustumArray ? rc.frustumArray._count : null ];

}

export function renderObjectState( ro ) {

	const g = ro.group;
	const m = ro.material;
	return [ ro.id, ro.object.name, ro.object.id, m.name, m.id, m.side, m.transparent === true, ro.context.id, mid( ro.camera ), mid( ro.scene ),
		g ? [ g.start, g.count, g.materialIndex ] : null, ro.drawRange ? [ ro.drawRange.start, ro.drawRange.count ] : null,
		ro.bundle ? ro.bundle.id : null, ro.clippingContext ? ro.clippingContext.version : null ];

}

// ---- stub node builder: skips the material build

export function createStubObserver( log ) {

	const seen = new Map();
	return {
		needsRefresh( renderObject, nodeFrame ) {

			let type;
			const last = seen.get( renderObject );
			if ( last === undefined ) type = 2;
			else if ( last !== nodeFrame.renderId ) type = 1;
			else type = 0;
			seen.set( renderObject, nodeFrame.renderId );
			log.push( [ 'needsRefresh', renderObject.id, type ] );
			return type;

		}
	};

}

export function createStubNodeBuilderClass( log, observer ) {

	class StubNodeBuilder extends M.NodeBuilder {

		prebuild() {

			const m = this.material;
			log.push( [ 'build', m ? m.name : null, m ? m.id : null, this.object ? ( this.object.isComputeNode ? 'compute' : this.object.name ) : null,
				this.fogNode ? 'fog' : null, this.environmentNode ? 'env' : null, this.lightsNode ? this.lightsNode.getLights().map( ( l ) => l.id ) : null ] );
			this.observer = observer;
			if ( m !== null ) {

				this.getAttribute( 'position', 'vec3' );
				if ( this.object.geometry && this.object.geometry.attributes.uv ) this.getAttribute( 'uv', 'vec2' );

			}

		}

		buildCode() {

			const m = this.material;
			const name = m ? m.name + ':' + m.id : 'compute';
			if ( m !== null ) {

				this.vertexShader = 'vs ' + name;
				this.fragmentShader = 'fs ' + name;

			} else {

				this.computeShader = 'cs ' + name;

			}

		}

	}

	return StubNodeBuilder;

}

// ---- stub backend

export function createStubBackend( log, options = {} ) {

	const observer = createStubObserver( log );
	const StubNodeBuilder = createStubNodeBuilderClass( log, observer );
	const canvas = { style: {}, width: 300, height: 150, addEventListener() {}, removeEventListener() {}, getContext() { return null; } };
	const b = ( ...a ) => log.push( [ 'backend', ...a ] );

	class StubBackend extends M.Backend {

		constructor() {

			super( { canvas } );
			this.isWebGPUBackend = true;
			this.capabilities = { getMaxAnisotropy() { return 16; } };
			if ( options.bundles ) {

				this.beginBundle = ( rc ) => b( 'beginBundle', rc.id );
				this.finishBundle = ( rc, bundle ) => { b( 'finishBundle', rc.id, bundle.bundleGroup.id ); this.get( bundle ).bundleGPU = {}; };
				this.addBundle = ( rc, bundle ) => b( 'addBundle', rc.id, bundle.bundleGroup.id );

			}

		}

		async init( renderer ) {

			b( 'init' );
			if ( options.failInit ) throw new Error( 'stub init failure' );
			await super.init( renderer );

		}

		get coordinateSystem() { return M.WebGPUCoordinateSystem; }

		beginRender( rc ) { b( 'beginRender', ...contextState( rc ) ); }
		finishRender( rc ) { b( 'finishRender', rc.id ); }
		setXRTarget( t ) { b( 'setXRTarget', t ); }
		beginCompute( g ) { b( 'beginCompute', Array.isArray( g ) ? g.map( ( n ) => n.id ) : g.id ); }
		finishCompute( g ) { b( 'finishCompute', Array.isArray( g ) ? g.map( ( n ) => n.id ) : g.id ); }
		compute( g, node, bindings, pipeline, dispatchSize ) {

			b( 'compute', node.id, bindings.length, pipeline.cacheKey, dispatchSize === null ? null : ( typeof dispatchSize === 'number' || Array.isArray( dispatchSize ) ? dispatchSize : 'indirect' ) );

		}

		draw( ro, info ) {

			const p = ro.getDrawParameters();
			b( 'draw', ...renderObjectState( ro ), p ? [ p.vertexCount, p.firstVertex, p.instanceCount, p.firstInstance ] : null );
			if ( p ) info.update( ro.object, p.vertexCount, p.instanceCount );

		}

		createProgram( p ) { b( 'createProgram', p.stage, p.name, p.code ); }
		destroyProgram( p ) { b( 'destroyProgram', p.stage, p.code ); }
		createBindings( g, bindings, cacheIndex ) { b( 'createBindings', g.name, bindings.length, cacheIndex ); }
		updateBindings( g ) { b( 'updateBindings', g.name ); }
		updateBinding( binding ) { b( 'updateBinding', binding.name ); }
		createRenderPipeline( ro ) {

			b( 'createRenderPipeline', ro.id, ro.pipeline.cacheKey );
			this.get( ro.pipeline ).pipeline = {};

		}

		createComputePipeline( pipeline, bindings ) {

			b( 'createComputePipeline', pipeline.cacheKey, bindings.length );
			this.get( pipeline ).pipeline = {};

		}

		destroyPipeline( pipeline ) { b( 'destroyPipeline', pipeline.cacheKey ); }
		needsRenderUpdate( ro ) { b( 'needsRenderUpdate', ro.id ); return false; }
		getRenderCacheKey( ro ) { return 's' + ro.material.side; }
		deleteVertexState( ro ) { b( 'deleteVertexState', ro.id ); }
		createNodeBuilder( object, renderer ) { return new StubNodeBuilder( object, renderer ); }
		updateSampler( s ) { b( 'updateSampler', s.name ); return 'sampler'; }
		destroySampler( s ) { b( 'destroySampler', s.name ); }
		createDefaultTexture( t ) { b( 'createDefaultTexture', t.id ); }
		createTexture( t, o ) { b( 'createTexture', t.id, o.width, o.height, o.depth, o.levels, o.sampleCount ?? null, o.renderTarget ? o.renderTarget.texture.id : null ); }
		updateTexture( t, o ) { b( 'updateTexture', t.id, o.width, o.height ); }
		generateMipmaps( t ) { b( 'generateMipmaps', t.id ); }
		destroyTexture( t, isDefault ) { b( 'destroyTexture', t.id, isDefault ?? null ); }
		async copyTextureToBuffer( t, x, y, w, h, face ) { b( 'copyTextureToBuffer', t.id, x, y, w, h, face ); return new Uint8Array( [ x, y, w, h ] ); }
		copyTextureToTexture( s, d, r, p, sl, dl ) { b( 'copyTextureToTexture', s.id, d.id, r ? [ r.min.x, r.min.y, r.max.x, r.max.y ] : null, p ? [ p.x, p.y ] : null, sl, dl ); }
		copyFramebufferToTexture( t, rc, rect ) {

			b( 'copyFramebufferToTexture', t.id, rc === null ? null : ( rc.isRenderContext ? 'context:' + rc.id : 'data:' + rc.width + 'x' + rc.height ), v4( rect ) );

		}

		createAttribute( a ) { b( 'createAttribute', a.name || '', a.array.constructor.name, a.array.length ); }
		createIndexAttribute( a ) { b( 'createIndexAttribute', a.array.length ); }
		createStorageAttribute( a ) { b( 'createStorageAttribute', a.array.length ); }
		createIndirectStorageAttribute( a ) { b( 'createIndirectStorageAttribute', a.array.length ); }
		createUniformBuffer( u ) { b( 'createUniformBuffer', u.name ); }
		destroyUniformBuffer( u ) { b( 'destroyUniformBuffer', u.name ); }
		updateAttribute( a ) { b( 'updateAttribute', a.array.length ); }
		destroyAttribute( a ) { b( 'destroyAttribute', a.array.length ); }
		getContext() { return 'context'; }
		updateSize() { b( 'updateSize' ); }
		destroyCanvasTarget( ct ) { b( 'destroyCanvasTarget', ct.isDefaultCanvasTarget === true ); }
		isOccluded( rc, o ) { b( 'isOccluded', rc.id, o.id ); return o.name === 'occluded'; }
		async getArrayBufferAsync( a, target, offset, count ) { b( 'getArrayBufferAsync', a.array.length, target ? target.name : null, offset, count ); return new ArrayBuffer( 8 ); }
		hasFeature( name ) { b( 'hasFeature', name ); return name === 'feature'; }
		setScissorTest( v ) { b( 'setScissorTest', v ); }
		resetState() { b( 'resetState' ); }
		hasCompatibility( name ) { return name === 'compat'; }
		initRenderTarget( rc ) { b( 'initRenderTarget', ...contextState( rc ) ); }
		clear( color, depth, stencil, rc ) { b( 'clear', color, depth, stencil, rc === null ? null : contextState( rc ) ); }
		async dispose() { b( 'dispose' ); await super.dispose(); }
		deleteBindGroupData( g ) { b( 'deleteBindGroupData', g.name ); }

	}

	return new StubBackend();

}

export async function createRenderer( log, parameters = {}, options = {} ) {

	const backend = createStubBackend( log, options );
	const renderer = new M.Renderer( backend, parameters );
	return renderer;

}

export function info( renderer ) {

	const i = renderer.info;
	return [ i.calls, i.frame, i.render.calls, i.render.frameCalls, i.render.drawCalls, i.render.triangles, i.render.points, i.render.lines, i.compute.calls, i.compute.frameCalls,
		i.memory.textures, i.memory.renderTargets, i.memory.attributes, i.memory.geometries, i.memory.programs ];

}

export function nodeMaterial( name, setup ) {

	const m = new M.NodeMaterial();
	m.name = name;
	if ( setup ) setup( m );
	return m;

}

export function box( w = 1 ) {

	const g = new M.BufferGeometry();
	g.setAttribute( 'position', new M.Float32BufferAttribute( [ 0, 0, 0, w, 0, 0, 0, w, 0, w, w, 0 ], 3 ) );
	g.setAttribute( 'uv', new M.Float32BufferAttribute( [ 0, 0, 1, 0, 0, 1, 1, 1 ], 2 ) );
	g.setIndex( [ 0, 1, 2, 2, 1, 3 ] );
	return g;

}
