// Upstream scenarios. Each takes `log` (an array of JSON entries) and must do exactly
// what the MoonBit scenario of the same name in src/nodes/common_g7_diff_test.mbt does.

import { M, align, bytes, createStubBackend, createStubRenderer, createModules, infoMemory } from './common.mjs';

function nodeUniformClass( type ) {

	if ( type === 'float' || type === 'int' || type === 'uint' || type === 'bool' ) return M.NU.NumberNodeUniform;
	if ( /^[iu]?vec2$/.test( type ) ) return M.NU.Vector2NodeUniform;
	if ( /^[iu]?vec3$/.test( type ) ) return M.NU.Vector3NodeUniform;
	if ( /^[iu]?vec4$/.test( type ) ) return M.NU.Vector4NodeUniform;
	if ( type === 'color' ) return M.NU.ColorNodeUniform;
	if ( type === 'mat2' ) return M.NU.Matrix2NodeUniform;
	if ( type === 'mat3' ) return M.NU.Matrix3NodeUniform;
	if ( type === 'mat4' ) return M.NU.Matrix4NodeUniform;
	throw new Error( type );

}

function groupState( group ) {

	return [ group.name, group.byteLength, group.uniforms.map( ( u ) => [ u.name, u.offset, u.index, u.boundary, u.itemSize ] ) ];

}

function ranges( binding ) {


	return binding.updateRanges.map( ( r ) => [ r.start, r.count ] );

}

function m3() {

	return new M.Matrix3().set( 1, 2, 3, 4, 5, 6, 7, 8, 9 );

}

function m4() {

	return new M.Matrix4().set( 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 );

}

function makeGroup( specs ) {

	const { uniform } = M.TSL;
	const group = new M.NodeUniformsGroup( 'object', M.UniformGroups.objectGroup );
	const nodes = [];
	specs.forEach( ( [ type, value ], i ) => {

		const node = uniform( value );
		nodes.push( node );
		const Cls = nodeUniformClass( type );
		group.addUniform( new Cls( new M.NodeUniform( 'u' + i, type, node ) ) );

	} );
	return { group, nodes };

}

function meshFixture() {

	const geometry = new M.BufferGeometry();
	geometry.setAttribute( 'position', new M.BufferAttribute( new Float32Array( [ 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0 ] ), 3 ) );
	geometry.setAttribute( 'normal', new M.BufferAttribute( new Float32Array( [ 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1 ] ), 3 ) );
	geometry.setAttribute( 'uv', new M.BufferAttribute( new Float32Array( [ 0, 0, 1, 0, 0, 1, 1, 1 ] ), 2 ) );
	geometry.setIndex( new M.BufferAttribute( new Uint16Array( [ 0, 1, 2, 2, 1, 3 ] ), 1 ) );
	return geometry;

}

// A NodeMaterial whose customProgramCacheKey is fixed (NodeMaterial's own one hashes
// its node graph, group G5's port). Overridden on a subclass, not the instance: an own
// function property would itself enter getMaterialCacheKey.
let TestNodeMaterial = null;

function nodeMaterial() {

	if ( TestNodeMaterial === null ) {

		TestNodeMaterial = class extends M.NodeMaterial {

			customProgramCacheKey() {

				return 'custom';

			}

		};

	}

	return new TestNodeMaterial();

}

function stateFixture( nodeAttributes = [], bindings = [], vs = 'vs', fs = 'fs' ) {

	return new M.NodeBuilderState( vs, fs, null, nodeAttributes, bindings, [], [], [], null, false );

}

export const scenarios = {

	buffer_utils_chain_map( log ) {

		align( log );
		const { getFloatLength, getVectorLength, getStrideLength } = M.BufferUtils;
		log.push( [ 'floatLength', [ 0, 1, 4, 15, 16, 17, 33 ].map( getFloatLength ) ] );
		log.push( [ 'vectorLength', [ [ 1, 4 ], [ 2, 3 ], [ 3, 2 ], [ 5, 1 ] ].map( ( [ c, v ] ) => getVectorLength( c, v ) ), getVectorLength( 3 ) ] );
		log.push( [ 'strideLength', [ 1, 2, 3, 4, 5, 7, 8 ].map( getStrideLength ) ] );
		const map = new M.ChainMap();
		const a = {}, b = {}, c = {};
		map.set( [ a, b ], 'ab' );
		map.set( [ a ], 'a' );
		map.set( [ a, b, c ], 'abc' );
		const g = ( k ) => { const v = map.get( k ); return v === undefined ? null : v; };
		log.push( [ 'get', g( [ a, b ] ), g( [ a ] ), g( [ a, b, c ] ), g( [ b, a ] ), g( [ a, c ] ), g( [ c ] ) ] );
		log.push( [ 'delete', map.delete( [ a, b ] ), map.delete( [ a, b ] ), map.delete( [ c, b ] ), g( [ a, b ] ), g( [ a, b, c ] ) ] );
		map.set( [ a, b ], 'ab2' );
		log.push( [ 'reset', g( [ a, b ] ) ] );
		const dm = new M.DataMap();
		const r1 = dm.get( a );
		r1.x = 1;
		log.push( [ 'dm', dm.has( a ), dm.has( b ), dm.get( a ) === r1, dm.get( a ).x, dm.delete( b ) === null, dm.delete( a ) === r1, dm.has( a ), dm.get( a ).x === undefined ] );
		dm.get( c );
		dm.dispose();
		log.push( [ 'dm dispose', dm.has( c ), dm.has( a ) ] );

	},

	uniforms_layout( log ) {

		align( log );
		const orders = [
			[ [ 'float', 1.5 ], [ 'vec2', new M.Vector2( 1, 2 ) ], [ 'vec3', new M.Vector3( 3, 4, 5 ) ], [ 'color', new M.Color( 0.1, 0.2, 0.3 ) ], [ 'vec4', new M.Vector4( 6, 7, 8, 9 ) ], [ 'mat3', m3() ], [ 'float', 2 ], [ 'mat4', m4() ], [ 'vec2', new M.Vector2( 10, 11 ) ] ],
			[ [ 'vec3', new M.Vector3( 1, 2, 3 ) ], [ 'float', 4 ], [ 'float', 5 ], [ 'vec2', new M.Vector2( 6, 7 ) ], [ 'float', 8 ], [ 'vec3', new M.Vector3( 9, 10, 11 ) ], [ 'mat3', m3() ], [ 'vec2', new M.Vector2( 12, 13 ) ], [ 'vec2', new M.Vector2( 14, 15 ) ], [ 'float', 16 ], [ 'mat4', m4() ], [ 'color', new M.Color( 0.5, 0.25, 0.125 ) ] ],
			[ [ 'float', 1 ], [ 'float', 2 ], [ 'float', 3 ], [ 'vec3', new M.Vector3( 4, 5, 6 ) ], [ 'float', 7 ], [ 'vec4', new M.Vector4( 8, 9, 10, 11 ) ], [ 'vec2', new M.Vector2( 12, 13 ) ], [ 'float', 14 ], [ 'vec3', new M.Vector3( 15, 16, 17 ) ] ],
			[],
		];
		for ( const specs of orders ) {

			const { group, nodes } = makeGroup( specs );
			log.push( [ 'layout', groupState( group ), group.isUniformsGroup, group.isUniformBuffer, group.isBuffer, group.isNodeUniformsGroup ] );
			log.push( [ 'update', group.update(), bytes( group.buffer ), ranges( group ) ] );
			group.clearUpdateRanges();
			log.push( [ 'update again', group.update(), ranges( group ) ] );
			if ( nodes.length > 2 ) {

				const v3 = specs.findIndex( ( s ) => s[ 0 ] === 'vec3' );
				const f1 = specs.findIndex( ( s ) => s[ 0 ] === 'float' );
				nodes[ f1 ].value = 42;
				nodes[ v3 ].value.set( - 1, - 2, - 3 );
				log.push( [ 'update changed', group.update(), bytes( group.buffer ), ranges( group ) ] );
				nodes[ v3 ].value.set( - 1, - 2, - 4 );
				log.push( [ 'update changed2', group.update(), ranges( group ) ] );
				group.clearUpdateRanges();

			}

			const clone = group.clone();
			log.push( [ 'clone', clone.name, clone.id, group.id, clone.uniforms === group.uniforms, clone.byteLength, clone.update(), ranges( clone ), ranges( group ) ] );
			group.release();
			log.push( [ 'release', bytes( group.buffer ) ] );

		}

	},

	uniforms_types( log ) {

		align( log );
		const { group, nodes } = makeGroup( [
			[ 'int', - 3.7 ], [ 'uint', - 1 ], [ 'bool', true ], [ 'float', NaN ], [ 'bool', false ], [ 'int', 2147483648 ],
			[ 'ivec3', new M.Vector3( 1.5, - 2.5, 3.9 ) ], [ 'uvec2', new M.Vector2( - 1, 7.5 ) ], [ 'ivec4', new M.Vector4( - 0, 1, 2, 3 ) ],
			[ 'float', - 0 ], [ 'uint', 4294967296 ], [ 'vec2', new M.Vector2( 1e-40, 3.4e39 ) ],
		] );
		log.push( [ 'layout', groupState( group ) ] );
		log.push( [ 'update', group.update(), bytes( group.buffer ), ranges( group ) ] );
		group.clearUpdateRanges();
		log.push( [ 'again', group.update(), ranges( group ) ] );
		group.clearUpdateRanges();
		nodes[ 2 ].value = false;
		nodes[ 4 ].value = 0;
		nodes[ 9 ].value = 0;
		log.push( [ 'changed', group.update(), bytes( group.buffer ), ranges( group ) ] );
		const m2 = makeGroup( [ [ 'mat2', new M.Matrix2() ], [ 'float', 1 ] ] );
		log.push( [ 'mat2', groupState( m2.group ), m2.group.update(), bytes( m2.group.buffer ) ] );

	},

	bindings( log ) {

		align( log );
		const { uniform } = M.TSL;
		const backend = createStubBackend( log );
		const renderer = createStubRenderer( backend );
		const mod = createModules( renderer );
		const a = uniform( 1 ), b = uniform( new M.Vector3( 1, 2, 3 ) ), c = uniform( 2 ), d = uniform( new M.Vector4( 1, 2, 3, 4 ) );
		const texture = new M.DataTexture( new Uint8Array( 16 ), 2, 2 );
		const textureNode = uniform( texture );
		const objectGroup = M.UniformGroups.objectGroup, renderGroup = M.UniformGroups.renderGroup;
		const obj = new M.NodeUniformsGroup( 'object', objectGroup );
		obj.addUniform( new M.NU.NumberNodeUniform( new M.NodeUniform( 'a', 'float', a ) ) );
		obj.addUniform( new M.NU.Vector3NodeUniform( new M.NodeUniform( 'b', 'vec3', b ) ) );
		const sampler = new M.NodeSampler( 'map_sampler', textureNode, objectGroup );
		const sampled = new M.NodeSampledTextures.NodeSampledTexture( 'map', textureNode, objectGroup );
		const ren = new M.NodeUniformsGroup( 'render', renderGroup );
		ren.addUniform( new M.NU.Vector4NodeUniform( new M.NodeUniform( 'd', 'vec4', d ) ) );
		ren.addUniform( new M.NU.NumberNodeUniform( new M.NodeUniform( 'c', 'float', c ) ) );
		const objGroup = new M.BindGroup( 'object', [ obj, sampler, sampled ] );
		const renGroup = new M.BindGroup( 'render', [ ren ] );
		const state = stateFixture( [], [ objGroup, renGroup ] );
		const ctx1 = mod.renderContexts.get(), ctx2 = mod.renderContexts.get( null, null, 1 );
		const describe = ( groups ) => groups.map( ( g ) => [ g.name, g.id, g.bindings.map( ( x ) => [ x.name, x.id === undefined ? null : x.id, x.isSampledTexture === true, x.visibility ] ) ] );
		const bg1 = state.createBindings( mod.bindings, ctx1 );
		log.push( [ 'bg1', describe( bg1 ), bg1[ 1 ] === renGroup, ren.uniforms.map( ( u ) => u.name ) ] );
		const bg2 = state.createBindings( mod.bindings, ctx1 );
		log.push( [ 'bg2', describe( bg2 ), bg2[ 1 ] === bg1[ 1 ], bg2[ 0 ] === bg1[ 0 ], bg2[ 0 ].bindings[ 0 ] === obj ] );
		const bg3 = state.createBindings( mod.bindings, ctx2 );
		log.push( [ 'bg3', describe( bg3 ), bg3[ 1 ] === bg1[ 1 ], bg3[ 1 ].bindings[ 0 ] === ren ] );
		const bg4 = state.createBindings( mod.bindings, null );
		log.push( [ 'bg4', describe( bg4 ) ] );
		mod.bindings._createBindings( bg1 );
		mod.bindings._createBindings( bg2 );
		log.push( [ 'used', mod.bindings.get( bg1[ 1 ] ).usedTimes, mod.bindings.get( bg1[ 0 ] ).usedTimes, infoMemory( mod.info ) ] );
		mod.bindings._updateBindings( bg1 );
		log.push( [ 'updated1' ] );
		mod.bindings._updateBindings( bg1 );
		log.push( [ 'updated2' ] );
		a.value = 5;
		d.value.set( 9, 8, 7, 6 );
		texture.needsUpdate = true;
		mod.bindings._updateBindings( bg1 );
		log.push( [ 'updated3', ren.uniforms.map( ( u ) => u.name ) ] );
		renderGroup.needsUpdate = true;
		mod.bindings._updateBindings( bg1 );
		mod.bindings._updateBindings( bg2 );
		log.push( [ 'updated4' ] );
		const other = new M.DataTexture( new Uint8Array( 4 ), 1, 1 );
		other.needsUpdate = true;
		textureNode.value = other;
		mod.bindings._updateBindings( bg1 );
		log.push( [ 'updated5', bg1[ 0 ].bindings[ 2 ].generation, bg1[ 0 ].bindings[ 1 ].samplerKey ] );
		texture.dispose();
		mod.bindings._destroyBindings( bg2 );
		log.push( [ 'destroyed2', mod.bindings.has( bg1[ 1 ] ), infoMemory( mod.info ) ] );
		mod.bindings._destroyBindings( bg1 );
		log.push( [ 'destroyed1', mod.bindings.has( bg1[ 1 ] ), mod.bindings.has( bg1[ 0 ] ), infoMemory( mod.info ) ] );
		const bg5 = state.createBindings( mod.bindings, ctx1 );
		log.push( [ 'bg5', describe( bg5 ), bg5[ 1 ] === bg1[ 1 ] ] );
		log.push( [ 'gpu', backend.mock.log ] );

	},

	render_objects( log ) {

		align( log );
		const backend = createStubBackend( log );
		const renderer = createStubRenderer( backend );
		const mod = createModules( renderer );
		const scene = new M.Scene();
		const camera = new M.PerspectiveCamera();
		const geometry = meshFixture();
		const material = nodeMaterial();
		const mesh = new M.Mesh( geometry, material );
		const lightsNode = new M.Node();
		const ctx = mod.renderContexts.get();
		const prep = ( ro ) => { if ( ro._nodeBuilderState === null ) ro._nodeBuilderState = stateFixture(); return ro; };
		const get = () => prep( mod.renderObjects.get( mesh, material, scene, camera, lightsNode, ctx, null, undefined ) );
		const keys = ( ro ) => [ ro.id, ro.initialCacheKey, ro.initialNodesCacheKey, ro.initialGeometryCacheKey, ro.getMaterialCacheKey(), ro.getDynamicCacheKey(), ro.version, ro.geometryVersion ];
		const ro1 = get();
		log.push( [ 'ro1', keys( ro1 ) ] );
		log.push( [ 'same', get() === ro1 ] );
		material.needsUpdate = true;
		const ro2 = get();
		log.push( [ 'version bump', ro2 === ro1, keys( ro2 ) ] );
		material.side = M.DoubleSide;
		material.needsUpdate = true;
		const ro3 = get();
		log.push( [ 'side change', ro3 === ro1, keys( ro3 ) ] );
		const geometry2 = meshFixture();
		mesh.geometry = geometry2;
		ro3.getAttributes();
		const ro4 = get();
		log.push( [ 'geometry swap', ro4 === ro3, keys( ro4 ), ro4.geometry === geometry2 ] );
		const geometry3 = meshFixture();
		geometry3.setAttribute( 'color', new M.BufferAttribute( new Float32Array( 12 ), 3, true ) );
		mesh.geometry = geometry3;
		const ro5 = get();
		log.push( [ 'geometry layout', ro5 === ro4, keys( ro5 ) ] );
		mesh.receiveShadow = true;
		const ro6 = get();
		log.push( [ 'receive shadow', ro6 === ro5, keys( ro6 ) ] );
		material.transparent = true;
		material.depthWrite = false;
		material.blending = M.AdditiveBlending;
		material.colorNode = M.TSL.uniform( 1 );
		material.needsUpdate = true;
		const ro7 = get();
		log.push( [ 'material props', ro7 === ro6, keys( ro7 ) ] );
		const map = new M.Texture();
		map.wrapS = M.RepeatWrapping;
		map.channel = 2;
		material.map = map;
		material.needsUpdate = true;
		const ro8 = get();
		log.push( [ 'texture prop', ro8 === ro7, keys( ro8 ) ] );
		ro8.drawRange = mesh.geometry.drawRange;
		const dp = ( p ) => ( p === null ? null : { ...p } );
		log.push( [ 'draw', dp( ro8.getDrawParameters() ), ro8.getIndex().count ] );
		mesh.geometry.setDrawRange( 1, 3 );
		ro8.group = { start: 2, count: 10, materialIndex: 0 };
		log.push( [ 'draw range', dp( ro8.getDrawParameters() ) ] );
		material.wireframe = true;
		ro8.group = null;
		log.push( [ 'draw wireframe', dp( ro8.getDrawParameters() ) ] );
		material.wireframe = false;
		log.push( [ 'chain', ro8.getChainArray().length, ro8.needsUpdate, ro8.clippingNeedsUpdate ] );
		const clip = new M.ClippingContext();
		const ro9 = prep( mod.renderObjects.get( mesh, material, scene, camera, lightsNode, ctx, clip, undefined ) );
		log.push( [ 'clip same', ro9 === ro8, ro9.clippingNeedsUpdate, ro9.clippingContextCacheKey ] );
		const group = new M.ClippingGroup();
		group.clippingPlanes = [ new M.Plane( new M.Vector3( 0, 1, 0 ), 1 ) ];
		const groupContext = clip.getGroupContext( group );
		const ro10 = prep( mod.renderObjects.get( mesh, material, scene, camera, lightsNode, ctx, groupContext, undefined ) );
		log.push( [ 'clip group', ro10 === ro9, keys( ro10 ), ro10.clippingContextCacheKey ] );
		const ro11 = prep( mod.renderObjects.get( mesh, material, scene, camera, lightsNode, ctx, groupContext, 'shadow' ) );
		log.push( [ 'pass', ro11 === ro10, ro11.id ] );
		material.dispose();
		log.push( [ 'material dispose', get() === ro10 ] );
		mod.renderObjects.dispose();
		log.push( [ 'disposed', infoMemory( mod.info ) ] );

	},

	render_list( log ) {

		align( log );
		const scene = new M.Scene();
		const camera = new M.PerspectiveCamera();
		const lightsNode = new M.LightsNode();
		const lighting = { enabled: true, getNode: () => lightsNode };
		const list = new M.RenderList( lighting, scene, camera );
		const geometry = new M.BufferGeometry();
		const opaque = new M.NodeMaterial();
		const transparent = new M.NodeMaterial();
		transparent.transparent = true;
		const backdrop = new M.NodeMaterial();
		backdrop.backdropNode = M.TSL.uniform( 1 );
		const objects = [];
		for ( let i = 0; i < 8; i ++ ) {

			const o = new M.Mesh( geometry, opaque );
			o.renderOrder = [ 0, 1, 0, 0, - 1, 0, 2, 0 ][ i ];
			objects.push( o );

		}

		objects[ 3 ].occlusionTest = true;
		objects[ 5 ].occlusionTest = true;
		const ids = ( items ) => items.map( ( it ) => [ it.id - objects[ 0 ].id, it.groupOrder, it.renderOrder, it.z, it.group === null ? null : it.group.start ] );
		const g = { start: 3, count: 6, materialIndex: 0 };
		list.begin();
		list.push( objects[ 0 ], geometry, opaque, 0, 5, null, null );
		list.push( objects[ 1 ], geometry, opaque, 0, 1, null, null );
		list.push( objects[ 2 ], geometry, transparent, 0, 3, null, null );
		list.push( objects[ 3 ], geometry, opaque, 1, 2, g, null );
		list.push( objects[ 3 ], geometry, transparent, 1, 2, null, null );
		list.push( objects[ 4 ], geometry, backdrop, 0, - 1, null, null );
		list.push( objects[ 5 ], geometry, opaque, 0, 5, null, null );
		list.unshift( objects[ 6 ], geometry, opaque, 0, 0, null, null );
		list.unshift( objects[ 7 ], geometry, transparent, 0, 7, null, null );
		list.push( objects[ 2 ], geometry, transparent, 0, 3, null, null );
		list.push( objects[ 7 ], geometry, opaque, 0, 3, null, null );
		list.push( objects[ 2 ], geometry, opaque, 0, - 4, null, null );
		log.push( [ 'pushed', ids( list.opaque ), ids( list.transparent ), ids( list.transparentDoublePass ), list.occlusionQueryCount, list.renderItemsIndex ] );
		list.sort( null, null );
		log.push( [ 'sorted', ids( list.opaque ), ids( list.transparent ) ] );
		list.sort( ( a, b ) => b.z - a.z, ( a, b ) => a.renderOrder - b.renderOrder );
		log.push( [ 'custom', ids( list.opaque ), ids( list.transparent ) ] );
		camera._reversedDepth = true;
		list.begin();
		list.push( objects[ 0 ], geometry, transparent, 0, 5, null, null );
		list.push( objects[ 1 ], geometry, transparent, 0, - 2, null, null );
		list.push( objects[ 2 ], geometry, transparent, 0, 1, null, null );
		list.sort( null, null );
		log.push( [ 'reversed', ids( list.transparent ), list.renderItems.length, list.renderItemsIndex ] );
		list.clear();
		log.push( [ 'cleared', list.renderItems.map( ( it ) => it.id === null ), list.opaque.length ] );
		list.begin();
		const l1 = new M.PointLight(), l2 = new M.DirectionalLight();
		list.pushLight( l1 );
		list.pushLight( l2 );
		list.push( objects[ 0 ], geometry, opaque, 0, 1, null, null );
		list.finish();
		log.push( [ 'finish', lightsNode.getLights().length, lightsNode.getLights()[ 0 ] === l1, list.renderItems.map( ( it ) => it.id === null ) ] );
		lighting.enabled = false;
		list.begin();
		list.pushLight( l1 );
		list.finish();
		log.push( [ 'finish disabled', lightsNode.getLights().length, list.lightsArray.length ] );

	},

	render_contexts( log ) {

		align( log );
		const backend = createStubBackend( log );
		const renderer = createStubRenderer( backend );
		const contexts = new M.RenderContexts( renderer );
		const state = ( c ) => [ c.id, c.stateKey, c.sampleCount, c.clearDepthValue, c.clearStencilValue, c.mrt === null ? null : c.mrt.id ];
		const c1 = contexts.get();
		const rt = new M.RenderTarget( 4, 2, { samples: 4, depthBuffer: true, stencilBuffer: true } );
		const c2 = contexts.get( rt );
		const mrt = new M.Node();
		const c3 = contexts.get( rt, mrt, 0 );
		const c4 = contexts.get( null, null, 2, new M.OrthographicCamera() );
		renderer._clearDepth = 0.25;
		renderer._clearStencil = 3;
		const c5 = contexts.get();
		renderer.reversedDepthBuffer = true;
		const rt2 = new M.RenderTarget( 4, 2, { samples: 0, count: 2, type: M.HalfFloatType } );
		const c6 = contexts.get( rt2, null, 0, new M.PerspectiveCamera() );
		log.push( [ 'contexts', [ c1, c2, c3, c4, c5, c6 ].map( state ), c5 === c1 ] );
		c2.textures = rt.textures;
		c2.depthTexture = null;
		c2.activeCubeFace = 3;
		c2.activeMipmapLevel = 1;
		log.push( [ 'cacheKey', c2.getCacheKey() ] );
		rt.depthTexture = new M.DepthTexture( 4, 2 );
		c2.depthTexture = rt.depthTexture;
		log.push( [ 'cacheKey depth', c2.getCacheKey() ] );
		contexts.dispose();
		log.push( [ 'after dispose', contexts.get().id ] );

	},

	attributes_geometries( log ) {

		align( log );
		const backend = createStubBackend( log );
		const renderer = createStubRenderer( backend );
		const mod = createModules( renderer );
		const scene = new M.Scene();
		const camera = new M.PerspectiveCamera();
		const geometry = meshFixture();
		const dynamic = new M.BufferAttribute( new Float32Array( [ 1, 2, 3, 4 ] ), 1 );
		dynamic.setUsage( M.DynamicDrawUsage );
		geometry.setAttribute( 'dynamic', dynamic );
		const ib = new M.InterleavedBuffer( new Float32Array( 16 ), 4 );
		geometry.setAttribute( 'ia', new M.InterleavedBufferAttribute( ib, 2, 0 ) );
		geometry.setAttribute( 'ib', new M.InterleavedBufferAttribute( ib, 2, 2 ) );
		geometry.setAttribute( 'storage', new M.StorageBufferAttribute( 4, 2 ) );
		geometry.setIndirect( new M.IndirectStorageBufferAttribute( 5, 1 ) );
		const material = nodeMaterial();
		const mesh = new M.Mesh( geometry, material );
		const lightsNode = new M.Node();
		const ctx = mod.renderContexts.get();
		const names = [ 'position', 'normal', 'uv', 'missing', 'dynamic', 'ia', 'ib', 'storage' ];
		const state = stateFixture( names.map( ( n ) => new M.NodeAttribute( n, 'vec3' ) ) );
		const ro = mod.renderObjects.get( mesh, material, scene, camera, lightsNode, ctx, null, undefined );
		ro._nodeBuilderState = state;
		const attrs = ro.getAttributes();
		log.push( [ 'attributes', attrs.length, ro.getVertexBuffers().length, attrs.map( ( a ) => a.isInterleavedBufferAttribute === true ) ] );
		mod.geometries.updateForRender( ro );
		log.push( [ 'first', mod.geometries.has( geometry ), infoMemory( mod.info ) ] );
		mod.geometries.updateForRender( ro );
		log.push( [ 'same call' ] );
		mod.info.render.calls ++;
		mod.geometries.updateForRender( ro );
		log.push( [ 'next call' ] );
		geometry.attributes.position.needsUpdate = true;
		ib.needsUpdate = true;
		mod.info.render.calls ++;
		mod.geometries.updateForRender( ro );
		log.push( [ 'needsUpdate' ] );
		material.wireframe = true;
		const wire = ro.getIndex();
		log.push( [ 'wireframe', wire.array.constructor.name, Array.from( wire.array ), wire.version ] );
		mod.info.render.calls ++;
		mod.geometries.updateForRender( ro );
		log.push( [ 'wire upload', infoMemory( mod.info ) ] );
		geometry.index.needsUpdate = true;
		const wire2 = ro.getIndex();
		log.push( [ 'wire rebuilt', wire2 === wire, wire2.version ] );
		const plain = new M.BufferGeometry();
		plain.setAttribute( 'position', new M.BufferAttribute( new Float32Array( 18 ), 3 ) );
		const mesh2 = new M.Mesh( plain, material );
		const ro2 = mod.renderObjects.get( mesh2, material, scene, camera, lightsNode, ctx, null, undefined );
		ro2._nodeBuilderState = stateFixture( [ new M.NodeAttribute( 'position', 'vec3' ) ] );
		log.push( [ 'plain wire', Array.from( ro2.getIndex().array ) ] );
		mod.geometries.updateForRender( ro2 );
		material.wireframe = false;
		geometry.dispose();
		log.push( [ 'geometry dispose', mod.geometries.has( geometry ), infoMemory( mod.info ), ro.attributes === null ] );
		mod.attributes.dispose();
		log.push( [ 'attributes dispose', infoMemory( mod.info ), mod.attributes.disposeVersion ] );
		mod.geometries.dispose();
		log.push( [ 'geometries dispose', infoMemory( mod.info ) ] );
		log.push( [ 'gpu', backend.mock.log ] );

	},

	textures( log ) {

		align( log );
		const backend = createStubBackend( log );
		const renderer = createStubRenderer( backend );
		const mod = createModules( renderer );
		const t = mod.textures;
		const data = ( n ) => new Uint8Array( n );
		const tex = new M.Texture();
		log.push( [ 'default', t.updateTexture( tex ), t.get( tex ).isDefaultTexture, infoMemory( mod.info ) ] );
		log.push( [ 'default again', t.updateTexture( tex ) ] );
		const dt = new M.DataTexture( data( 64 ), 4, 4 );
		dt.needsUpdate = true;
		log.push( [ 'data', t.updateTexture( dt ), t.get( dt ).isDefaultTexture, infoMemory( mod.info ) ] );
		const mip = new M.DataTexture( data( 256 ), 8, 8 );
		mip.generateMipmaps = true;
		mip.type = M.FloatType;
		mip.format = M.RGFormat;
		mip.needsUpdate = true;
		log.push( [ 'mip', t.updateTexture( mip ), t.getMipLevels( mip, 8, 8 ), t.needsMipmaps( mip ), infoMemory( mod.info ) ] );
		const size = t.getSize( mip );
		log.push( [ 'size', size.width, size.height, size.depth ] );
		const rt = new M.RenderTarget( 4, 2, { depthBuffer: true } );
		t.updateRenderTarget( rt );
		const rtData = t.get( rt );
		log.push( [ 'rt', rtData.width, rtData.height, rtData.sampleCount, rtData.depthTexture.id, rtData.depthTexture.type, rtData.depthTexture.format, rtData.depthTexture.image.width, infoMemory( mod.info ) ] );
		t.updateRenderTarget( rt );
		log.push( [ 'rt again' ] );
		rt.setSize( 8, 4 );
		t.updateRenderTarget( rt );
		log.push( [ 'rt resized', rtData.width, rtData.depthTexture.image.width ] );
		t.updateRenderTarget( rt, 1 );
		log.push( [ 'rt mip1', Object.keys( rtData.depthTextureMips ) ] );
		const rts = new M.RenderTarget( 2, 2, { depthBuffer: true, stencilBuffer: true, samples: 4 } );
		renderer.reversedDepthBuffer = true;
		t.updateRenderTarget( rts );
		log.push( [ 'rt stencil', t.get( rts ).depthTexture.type, t.get( rts ).depthTexture.format, t.get( rts ).sampleCount ] );
		renderer.reversedDepthBuffer = false;
		const st = new M.StorageTexture( 4, 4 );
		log.push( [ 'storage', t.updateTexture( st ), st.isStorageTexture ] );
		const faces = [];
		for ( let i = 0; i < 6; i ++ ) faces.push( new M.DataTexture( data( 16 ), 2, 2 ) );
		const cube = new M.CubeTexture( faces );
		cube.generateMipmaps = false;
		cube.needsUpdate = true;
		log.push( [ 'cube', t.updateTexture( cube ), t.getSize( cube ).depth ] );
		const s3 = new M.Storage3DTexture( 2, 2, 3 );
		log.push( [ 'storage3d', t.updateTexture( s3 ), t.getSize( s3 ).depth, s3.wrapR, s3.isArrayTexture ] );
		dt.dispose();
		log.push( [ 'dispose data', t.has( dt ), infoMemory( mod.info ) ] );
		rt.dispose();
		log.push( [ 'dispose rt', t.has( rt ), infoMemory( mod.info ) ] );
		t.dispose();
		log.push( [ 'dispose all', infoMemory( mod.info ) ] );

	},

	pipelines( log ) {

		align( log );
		const backend = createStubBackend( log );
		const renderer = createStubRenderer( backend );
		const mod = createModules( renderer );
		const scene = new M.Scene();
		const camera = new M.PerspectiveCamera();
		const lightsNode = new M.Node();
		const ctx = mod.renderContexts.get();
		const geometry = meshFixture();
		const make = ( vs, fs, side ) => {

			const material = nodeMaterial();
			material.side = side;
			material.name = 'm' + vs + fs;
			const mesh = new M.Mesh( geometry, material );
			const ro = mod.renderObjects.get( mesh, material, scene, camera, lightsNode, ctx, null, undefined );
			ro._nodeBuilderState = stateFixture( [], [], vs, fs );
			return ro;

		};

		const ro1 = make( 'v1', 'f1', M.FrontSide ), ro2 = make( 'v1', 'f1', M.FrontSide ), ro3 = make( 'v1', 'f2', M.BackSide );
		const p1 = mod.pipelines.getForRender( ro1 );
		const p2 = mod.pipelines.getForRender( ro2 );
		const p3 = mod.pipelines.getForRender( ro3 );
		const ps = ( p ) => [ p.cacheKey, p.usedTimes, p.vertexProgram.id, p.vertexProgram.usedTimes, p.fragmentProgram.id, p.fragmentProgram.usedTimes ];
		log.push( [ 'pipelines', ps( p1 ), p1 === p2, ps( p3 ), mod.pipelines.isReady( ro1 ), mod.pipelines.caches.size, infoMemory( mod.info ) ] );
		mod.pipelines.getForRender( ro1 );
		log.push( [ 'cached' ] );
		backend.needsUpdateFlag = true;
		ro1.material.side = M.BackSide;
		const p4 = mod.pipelines.getForRender( ro1 );
		log.push( [ 'update', ps( p4 ), p4 === p3, ps( p1 ) ] );
		backend.needsUpdateFlag = false;
		mod.pipelines.delete( ro2 );
		log.push( [ 'delete2', mod.pipelines.caches.size, ps( p1 ), infoMemory( mod.info ) ] );
		mod.pipelines.delete( ro3 );
		mod.pipelines.delete( ro1 );
		log.push( [ 'deleted all', mod.pipelines.caches.size, mod.pipelines.programs.vertex.size, mod.pipelines.programs.fragment.size, infoMemory( mod.info ), mod.pipelines.isReady( ro1 ) ] );

	},

	info( log ) {

		align( log );
		const info = new M.Info();
		const geometry = new M.BufferGeometry();
		const mat = new M.Material();
		info.update( new M.Mesh( geometry, mat ), 36, 2 );
		info.update( new M.Points( geometry, mat ), 10, 1 );
		info.update( new M.LineSegments( geometry, mat ), 10, 3 );
		info.update( new M.Line( geometry, mat ), 10, 1 );
		info.update( new M.LineLoop( geometry, mat ), 5, 1 );
		info.update( new M.Mesh( geometry, mat ), 7, 1 );
		info.update( new M.Group(), 7, 1 );
		const r = info.render;
		log.push( [ 'render', r.drawCalls, r.triangles, r.points, r.lines ] );
		const texs = [];
		const mk = ( w, h, type, format, gen ) => { const t = new M.DataTexture( new Uint8Array( 4 ), w, h, format, type ); t.generateMipmaps = gen; texs.push( t ); return t; };
		mk( 3, 3, M.UnsignedByteType, M.RGBAFormat, false );
		mk( 5, 7, M.FloatType, M.RGFormat, true );
		mk( 2, 2, M.HalfFloatType, M.RedFormat, false );
		mk( 4, 4, M.UnsignedShort4444Type, M.RGBAFormat, true );
		mk( 0, 3, M.UnsignedInt248Type, M.DepthStencilFormat, false );
		const withMips = mk( 8, 8, M.UnsignedByteType, M.RGBFormat, false );
		withMips.mipmaps = [ { data: new Uint8Array( 10 ), width: 4, height: 4 }, { width: 0, height: 0 } ];
		for ( const t of texs ) info.createTexture( t );
		log.push( [ 'textures', infoMemory( info ) ] );
		info.destroyTexture( texs[ 1 ] );
		info.destroyTexture( new M.Texture() );
		log.push( [ 'textures destroyed', infoMemory( info ) ] );
		const attr = new M.BufferAttribute( new Float32Array( 6 ), 3 );
		const ib = new M.InterleavedBuffer( new Float32Array( 8 ), 4 );
		info.createAttribute( attr );
		info.createIndexAttribute( new M.BufferAttribute( new Uint16Array( 3 ), 1 ) );
		info.createStorageAttribute( ib );
		info.createIndirectStorageAttribute( new M.BufferAttribute( new Uint32Array( 5 ), 1 ) );
		log.push( [ 'attributes', infoMemory( info ) ] );
		info.destroyAttribute( attr );
		info.destroyAttribute( attr );
		info.destroyAttribute( ib );
		log.push( [ 'attributes destroyed', infoMemory( info ) ] );
		const group = makeGroup( [ [ 'vec3', new M.Vector3() ], [ 'float', 1 ] ] ).group;
		info.createUniformBuffer( group );
		const stage = new M.ProgrammableStage( 'void main() {}', 'vertex', 'v' );
		info.createProgram( stage );
		const rb = new M.ReadbackBuffer( 128 );
		info.createReadbackBuffer( rb );
		log.push( [ 'misc', infoMemory( info ) ] );
		info.destroyUniformBuffer( group );
		info.destroyProgram( stage );
		info.destroyReadbackBuffer( rb );
		log.push( [ 'misc destroyed', infoMemory( info ) ] );
		info.calls = 5;
		info.render.calls = 3;
		info.reset();
		log.push( [ 'reset', info.calls, info.render.calls, info.render.drawCalls, info.render.triangles ] );
		info.dispose();
		log.push( [ 'dispose', info.calls, info.render.calls, infoMemory( info ) ] );

	},

	clipping_context( log ) {

		align( log );
		const scene = new M.Scene();
		const root = new M.ClippingContext();
		const parent = new M.ClippingGroup();
		parent.clippingPlanes = [ new M.Plane( new M.Vector3( 1, 2, 3 ).normalize(), - 2 ), new M.Plane( new M.Vector3( 0, 0, 1 ), 0.5 ) ];
		const child = new M.ClippingGroup();
		child.clipIntersection = true;
		child.clippingPlanes = [ new M.Plane( new M.Vector3( - 2, 1, 1 ).normalize(), 3 ) ];
		const grand = new M.ClippingGroup();
		grand.clippingPlanes = [ new M.Plane( new M.Vector3( 0, 1, 0 ), 1 ) ];
		const planes = ( c ) => [ c.id, c.version, c.cacheKey, c.clipIntersection, c.parentVersion, c.intersectionPlanes.map( ( v ) => v.toArray() ), c.unionPlanes.map( ( v ) => v.toArray() ), c.unionClippingCount ];
		const camera = new M.PerspectiveCamera();
		camera.position.set( - 3, 7, 5 );
		camera.rotation.set( 0.5, - 0.6, 0.2 );
		camera.updateMatrixWorld();
		root.updateGlobal( scene, camera );
		const pc = root.getGroupContext( parent );
		const cc = pc.getGroupContext( child );
		const gc = cc.getGroupContext( grand );
		log.push( [ 'contexts', planes( root ), planes( pc ), planes( cc ), planes( gc ) ] );
		log.push( [ 'reuse', root.getGroupContext( parent ) === pc, pc.getGroupContext( child ) === cc, planes( cc ) ] );
		parent.clippingPlanes.push( new M.Plane( new M.Vector3( 1, 0, 0 ), 2 ) );
		root.getGroupContext( parent );
		pc.getGroupContext( child );
		log.push( [ 'grown', planes( pc ), planes( cc ) ] );
		child.clipIntersection = false;
		pc.getGroupContext( child );
		log.push( [ 'flipped', planes( cc ) ] );
		const arrayCamera = new M.ArrayCamera();
		arrayCamera.position.set( 8, - 4, 3 );
		arrayCamera.updateMatrixWorld();
		root.updateGlobal( scene, arrayCamera );
		pc.getGroupContext( child );
		log.push( [ 'array camera', planes( cc ), root.viewMatrix.toArray(), root.viewNormalMatrix.toArray() ] );

	},

	node_manager( log ) {

		align( log );
		const { uniform } = M.TSL;
		const backend = createStubBackend( log );
		const renderer = createStubRenderer( backend );
		const mod = createModules( renderer );
		const nodes = mod.nodes;
		const objectGroup = M.UniformGroups.objectGroup;
		const group = M.TSL.sharedUniformGroup( 'custom' );
		const a = new M.NodeUniformsGroup( 'object', objectGroup );
		const b = new M.NodeUniformsGroup( 'custom', group );
		const b2 = new M.NodeUniformsGroup( 'custom', group );
		log.push( [ 'groups', nodes.updateGroup( a ), nodes.updateGroup( a ), nodes.updateGroup( b ), nodes.updateGroup( b ), nodes.updateGroup( b2 ) ] );
		group.needsUpdate = true;
		log.push( [ 'groups bumped', nodes.updateGroup( b ), nodes.updateGroup( b ), nodes.updateGroup( b2 ) ] );
		const scene = new M.Scene();
		const lightsNode = new M.Node();
		const k1 = nodes.getCacheKey( scene, lightsNode );
		const k2 = nodes.getCacheKey( scene, lightsNode );
		renderer.lighting.enabled = false;
		const k3 = nodes.getCacheKey( scene, lightsNode );
		renderer.info.calls ++;
		const k4 = nodes.getCacheKey( scene, lightsNode );
		renderer.lighting.enabled = true;
		renderer.shadowMap.enabled = true;
		renderer.info.calls ++;
		const k5 = nodes.getCacheKey( scene, lightsNode );
		lightsNode.name = 'renamed';
		const k6 = nodes.getCacheKey( scene, new M.Node() );
		log.push( [ 'cacheKeys', k1, k2, k3, k4, k5, k6, nodes.getEnvironmentNode( scene ), nodes.getFogNode( scene ), nodes.getBackgroundNode( scene ) ] );
		const material = new M.NodeMaterial();
		let calls = 0;
		material.customProgramCacheKey = () => 'key' + ( calls ++ );
		const c1 = nodes.getCustomProgramCacheKey( material, scene );
		const c2 = nodes.getCustomProgramCacheKey( material, scene );
		material.needsUpdate = true;
		const c3 = nodes.getCustomProgramCacheKey( material, scene );
		scene.overrideMaterial = material;
		const c4 = nodes.getCustomProgramCacheKey( material, scene );
		const c5 = nodes.getCustomProgramCacheKey( material, scene );
		log.push( [ 'programKeys', c1, c2, c3, c4, c5 ] );
		const frame = nodes.getNodeFrame();
		log.push( [ 'frame', frame.renderer === renderer, frame.scene, frame.object, frame.camera, frame.material, frame.compute, nodes.isToneMappingState ] );
		const out = M.TSL.uniform( 0 );
		log.push( [ 'output index', out.id > 0 ] );

	},

	render_bindings( log ) {

		align( log );
		const { uniform } = M.TSL;
		const backend = createStubBackend( log );
		const renderer = createStubRenderer( backend );
		const mod = createModules( renderer );
		const scene = new M.Scene();
		const camera = new M.PerspectiveCamera();
		const lightsNode = new M.Node();
		const ctx = mod.renderContexts.get();
		renderer._currentRenderContext = ctx;
		const a = uniform( new M.Color( 0.25, 0.5, 1 ) ), b = uniform( new M.Matrix4().makeTranslation( 1, 2, 3 ) ), c = uniform( 0.5 );
		const objectGroup = M.UniformGroups.objectGroup, renderGroup = M.UniformGroups.renderGroup;
		const obj = new M.NodeUniformsGroup( 'object', objectGroup );
		obj.addUniform( new M.NU.ColorNodeUniform( new M.NodeUniform( 'a', 'color', a ) ) );
		obj.addUniform( new M.NU.Matrix4NodeUniform( new M.NodeUniform( 'b', 'mat4', b ) ) );
		const ren = new M.NodeUniformsGroup( 'render', renderGroup );
		ren.addUniform( new M.NU.NumberNodeUniform( new M.NodeUniform( 'c', 'float', c ) ) );
		const groups = [ new M.BindGroup( 'object', [ obj ] ), new M.BindGroup( 'render', [ ren ] ) ];
		const material = nodeMaterial();
		const geometry = meshFixture();
		const make = () => {

			const mesh = new M.Mesh( geometry, material );
			const ro = mod.renderObjects.get( mesh, material, scene, camera, lightsNode, ctx, null, undefined );
			ro._nodeBuilderState = stateFixture( [], groups );
			return { mesh, ro };

		};

		const r1 = make(), r2 = make();
		const b1 = mod.bindings.getForRender( r1.ro );
		const b2 = mod.bindings.getForRender( r2.ro );
		log.push( [ 'bindings', b1.map( ( g ) => [ g.name, g.id ] ), b2.map( ( g ) => [ g.name, g.id ] ), b1[ 1 ] === b2[ 1 ], b1[ 0 ] === b2[ 0 ], r1.ro.getBindingGroup( 'render' ) === b1[ 1 ], r1.ro.getBindingGroup( 'nope' ) === undefined ] );
		mod.bindings.updateForRender( r1.ro );
		mod.bindings.updateForRender( r2.ro );
		log.push( [ 'updated' ] );
		c.value = 0.75;
		mod.bindings.updateSharedForRender( r1.ro );
		log.push( [ 'shared updated' ] );
		renderGroup.needsUpdate = true;
		mod.bindings.updateSharedForRender( r1.ro );
		mod.bindings.updateSharedForRender( r2.ro );
		log.push( [ 'shared updated2' ] );
		a.value.setRGB( 1, 0, 0 );
		b.value.makeScale( 2, 2, 2 );
		mod.bindings.updateForRender( r1.ro );
		log.push( [ 'object updated', infoMemory( mod.info ) ] );
		r1.mesh.dispatchEvent( { type: 'dispose' } );
		log.push( [ 'ro1 disposed', mod.bindings.get( b1[ 1 ] ).usedTimes, infoMemory( mod.info ) ] );
		r2.ro.dispose();
		log.push( [ 'ro2 disposed', mod.bindings.has( b1[ 1 ] ), infoMemory( mod.info ) ] );
		log.push( [ 'gpu', backend.mock.log ] );

	},

	animation( log ) {

		align( log );
		const backend = createStubBackend( log );
		const renderer = createStubRenderer( backend );
		renderer._inspector = new M.InspectorBase();
		const mod = createModules( renderer );
		const callbacks = [];
		const context = {
			requestAnimationFrame( cb ) { callbacks.push( cb ); log.push( [ 'raf', callbacks.length ] ); return callbacks.length; },
			cancelAnimationFrame( id ) { log.push( [ 'cancel', id ] ); },
		};
		const animation = new M.Animation( renderer, mod.nodes, mod.info );
		animation.setContext( context );
		log.push( [ 'context', animation.getContext() === context, animation.getAnimationLoop() ] );
		const loopCalls = [];
		animation.setAnimationLoop( ( time ) => loopCalls.push( time === undefined ? null : time ) );
		mod.info.render.drawCalls = 4;
		animation.start();
		log.push( [ 'started', mod.info.render.drawCalls, mod.info.frame, renderer._inspector.isRunning, [ ...loopCalls ] ] );
		animation.start();
		mod.info.render.drawCalls = 2;
		mod.info.autoReset = false;
		callbacks[ 0 ]( 16 );
		log.push( [ 'frame', mod.info.render.drawCalls, mod.info.frame, mod.nodes.nodeFrame.frameId, renderer._inspector.isRunning, [ ...loopCalls ] ] );
		animation.stop();
		log.push( [ 'stopped', renderer._inspector.isRunning ] );
		animation.dispose();
		log.push( [ 'disposed', animation.getAnimationLoop() ] );

	},

	node_buffers( log ) {

		align( log );
		const { buffer, storage } = M.TSL;
		const backend = createStubBackend( log );
		const renderer = createStubRenderer( backend );
		const mod = createModules( renderer );
		const objectGroup = M.UniformGroups.objectGroup;
		const bufferNode = buffer( new Float32Array( [ 1, 2, 3, 4, 5, 6, 7, 8 ] ), 'vec4', 2 );
		const ub = new M.NodeUniformBuffer( bufferNode, objectGroup );
		const ub2 = new M.NodeUniformBuffer( buffer( new Float32Array( 4 ), 'vec4', 1 ).setName( 'weights' ), objectGroup );
		log.push( [ 'uniform buffers', ub.name, ub2.name, ub.byteLength, bytes( ub.buffer ), ub.isNodeUniformBuffer === true, ub.isUniformBuffer === true, ub.groupNode === objectGroup ] );
		ub.addUpdateRange( 0, 4 );
		log.push( [ 'ranges', ranges( ub ), bufferNode.updateRanges.length ] );
		const uc = ub.clone();
		const ub3 = new M.NodeUniformBuffer( buffer( new Float32Array( 4 ), 'vec4', 1 ), objectGroup );
		log.push( [ 'clone', uc.name, uc.updateRanges === ub.updateRanges, ub3.name ] );
		ub.clearUpdateRanges();
		log.push( [ 'cleared', bufferNode.updateRanges.length ] );
		ub.updateRanges = [ { start: 1, count: 2 } ];
		log.push( [ 'set', ranges( ub ), bufferNode.updateRanges.length ] );
		ub.clearUpdateRanges();
		const attr = new M.StorageBufferAttribute( 4, 4 );
		const sb = new M.NodeStorageBufferClass( storage( attr, 'vec4', 4 ), objectGroup );
		const ind = new M.IndirectStorageBufferAttribute( 5, 1 );
		const sb2 = new M.NodeStorageBufferClass( storage( ind, 'uint', 5 ).toReadOnly(), objectGroup );
		log.push( [ 'storage', sb.name, sb.access, sb.attribute === attr, sb.buffer === attr.array, sb.isStorageBuffer === true, sb.byteLength, sb2.name, sb2.access ] );
		const group = new M.BindGroup( 'object', [ ub, sb, sb2 ] );
		mod.bindings._createBindings( [ group ] );
		log.push( [ 'created', infoMemory( mod.info ) ] );
		mod.bindings._updateBindings( [ group ] );
		log.push( [ 'updated' ] );
		mod.bindings._updateBindings( [ group ] );
		log.push( [ 'updated again' ] );
		attr.needsUpdate = true;
		bufferNode.value[ 0 ] = 9;
		mod.bindings._updateBindings( [ group ] );
		log.push( [ 'updated changed' ] );
		mod.attributes.delete( ind );
		mod.bindings._updateBindings( [ group ] );
		log.push( [ 'regenerated', infoMemory( mod.info ) ] );
		mod.bindings._destroyBindings( [ group ] );
		log.push( [ 'destroyed', infoMemory( mod.info ) ] );
		log.push( [ 'gpu', backend.mock.log ] );

	},

	// Node cache keys include the ids of module-level nodes (renderGroup, screenUV, the
	// fog factors, ...): both sides give those upstream's ids (bundle load order here,
	// src/nodes/core_module_node_ids.mbt in the port), so the keys are logged.
	scene_nodes( log ) {

		align( log );
		const backend = createStubBackend( log );
		const renderer = createStubRenderer( backend );
		const mod = createModules( renderer );
		const nodes = mod.nodes;
		const scene = new M.Scene();
		const lightsNode = new M.Node();
		const kind = ( n ) => n === null ? null : [ n.type, n.id ];
		scene.fog = new M.Fog( 0x336699, 2, 20 );
		const f1 = nodes.getFogNode( scene );
		log.push( [ 'fog', kind( f1 ), nodes.getFogNode( scene ) === f1 ] );
		const key1 = nodes.getCacheKey( scene, lightsNode );
		const fog2 = new M.FogExp2( 0x112233, 0.5 );
		scene.fog = fog2;
		const f2 = nodes.getFogNode( scene );
		renderer.info.calls ++;
		const key2 = nodes.getCacheKey( scene, lightsNode );
		log.push( [ 'fog exp2', kind( f2 ), f2 === f1, key1 === key2 ] );
		scene.fog = null;
		log.push( [ 'no fog', nodes.getFogNode( scene ) ] );
		const env = new M.Texture();
		scene.environment = env;
		const e1 = nodes.getEnvironmentNode( scene );
		log.push( [ 'environment', kind( e1 ), nodes.getEnvironmentNode( scene ) === e1 ] );
		const cubeEnv = new M.CubeTexture();
		scene.environment = cubeEnv;
		const e2 = nodes.getEnvironmentNode( scene );
		log.push( [ 'cube environment', kind( e2 ) ] );
		env.dispose();
		scene.environment = env;
		const e3 = nodes.getEnvironmentNode( scene );
		log.push( [ 'disposed environment', kind( e3 ), e3 === e1 ] );
		renderer.lighting.enabled = false;
		log.push( [ 'lighting off', nodes.getEnvironmentNode( scene ) ] );
		renderer.lighting.enabled = true;
		const bgTexture = new M.Texture();
		scene.background = bgTexture;
		const b1 = nodes.getBackgroundNode( scene );
		log.push( [ 'background', kind( b1 ) ] );
		const cubeBg = new M.CubeTexture();
		scene.background = cubeBg;
		const b2 = nodes.getBackgroundNode( scene );
		log.push( [ 'cube background', kind( b2 ) ] );
		scene.background = new M.Color( 1, 0, 0 );
		log.push( [ 'color background', nodes.getBackgroundNode( scene ) ] );
		scene.background = null;
		log.push( [ 'no background', nodes.getBackgroundNode( scene ) ] );
		const rtTexture = new M.Texture();
		const out = nodes.getOutputNode( rtTexture );
		log.push( [ 'output', kind( out ) ] );
		const arrayTexture = new M.Texture();
		arrayTexture.isArrayTexture = true;
		const out2 = nodes.getOutputNode( arrayTexture );
		nodes.setOutputLayerIndex( 3 );
		log.push( [ 'output array', kind( out2 ) ] );
		// cache keys hash node ids, the module-level ones (fog factors, renderGroup
		// uniforms, ...) included
		log.push( [ 'cache keys', key1, key2, [ f1, f2, e1, e2, e3, b1, b2, out, out2 ].map( ( n ) => n.getCacheKey() ) ] );

	},

	misc_classes( log ) {

		align( log );
		const sba = new M.StorageBufferAttribute( 3, 4 );
		const sia = new M.StorageInstancedBufferAttribute( new Int32Array( [ 1, 2, 3, 4 ] ), 2 );
		const isa = new M.IndirectStorageBufferAttribute( 2, 5 );
		const flags = ( a ) => [ a.array.constructor.name, a.array.length, a.count, a.itemSize, a.isStorageBufferAttribute === true, a.isStorageInstancedBufferAttribute === true, a.isIndirectStorageBufferAttribute === true, a.isInstancedBufferAttribute === true ];
		log.push( [ 'storage attributes', flags( sba ), flags( sia ), flags( isa ) ] );
		const st = new M.StorageTexture( 3, 5 );
		const sat = new M.StorageArrayTexture( 2, 2, 4 );
		const s3t = new M.Storage3DTexture( 2, 3, 4 );
		const tflags = ( t ) => [ t.image.width, t.image.height, t.image.depth === undefined ? null : t.image.depth, t.magFilter, t.minFilter, t.is3DTexture === true ? t.wrapR : null, t.isArrayTexture, t.mipmapsAutoUpdate, t.isStorageTexture ];
		log.push( [ 'storage textures', tflags( st ), tflags( sat ), tflags( s3t ) ] );
		let disposed = 0;
		st.addEventListener( 'dispose', () => disposed ++ );
		st.setSize( 3, 5 );
		st.setSize( 4, 5 );
		s3t.addEventListener( 'dispose', () => disposed ++ );
		s3t.setSize( 2, 3, 4 );
		s3t.setSize( 2, 3, 5 );
		log.push( [ 'setSize', disposed, tflags( st ), tflags( s3t ) ] );
		const s3c = s3t.clone();
		log.push( [ 'clone3d', tflags( s3c ) ] );
		const bg = new M.BundleGroup();
		bg.needsUpdate = true;
		bg.needsUpdate = false;
		bg.needsUpdate = true;
		log.push( [ 'bundle group', bg.type, bg.isBundleGroup, bg.isGroup, bg.static, bg.version ] );
		const bundles = new M.RenderBundles();
		const camera = new M.PerspectiveCamera();
		const ctx = new M.RenderContext();
		const rb1 = bundles.get( bg, camera, ctx );
		log.push( [ 'bundles', bundles.get( bg, camera, ctx ) === rb1, bundles.get( bg, new M.PerspectiveCamera(), ctx ) === rb1, rb1.renderContext.id ] );
		bundles.dispose();
		log.push( [ 'bundles disposed', bundles.get( bg, camera, ctx ) === rb1 ] );
		const readback = new M.ReadbackBuffer( 64 );
		const events = [];
		readback.addEventListener( 'release', ( e ) => events.push( e.type ) );
		readback.addEventListener( 'dispose', ( e ) => events.push( e.type ) );
		readback.release();
		readback.dispose();
		log.push( [ 'readback', events, readback.maxByteLength, readback.name, readback.buffer ] );
		const pool = new M.TimestampQueryPool( 8 );
		pool.timestamps.set( 'r:0:0:f0', 1.5 );
		log.push( [ 'pool', pool.maxQueries, pool.getTimestamp( 'r:0:0:f0' ), pool.getTimestamp( 'missing' ), pool.hasTimestampQuery( 'r:0:0:f0' ), pool.hasTimestampQuery( 'x' ), pool.getTimestampFrames() ] );
		const lib = new M.NodeLibrary();
		lib.addMaterial( M.NodeMaterial, 'MeshBasicMaterial' );
		lib.addMaterial( M.NodeMaterial, 'MeshBasicMaterial' );
		const basic = new M.MeshBasicMaterial( { color: 0x336699, transparent: true, side: M.DoubleSide, name: 'b' } );
		basic.userData.k = 1;
		const nm = lib.fromMaterial( basic );
		log.push( [ 'library', nm.isNodeMaterial, nm.type, nm.color.getHex(), nm.transparent, nm.side, nm.name, nm.uuid === basic.uuid, nm.userData === basic.userData, nm.id === basic.id, nm.version === basic.version, nm.color === basic.color, lib.fromMaterial( nm ) === nm, lib.fromMaterial( new M.MeshLambertMaterial() ), lib.getToneMappingFunction( 1 ) ] );
		const sampled = [ new M.SampledTextures.SampledTexture( 's', null ), new M.SampledTextures.SampledArrayTexture( 'a', null ), new M.SampledTextures.Sampled3DTexture( '3', null ), new M.SampledTextures.SampledCubeTexture( 'c', null ) ];
		log.push( [ 'sampled', sampled.map( ( s ) => [ s.id, s.isSampledTexture === true, s.isSampledArrayTexture === true, s.isSampled3DTexture === true, s.isSampledCubeTexture === true, s.isSampler === true, s.store, s.mipLevel, s.version, s.generation ] ) ] );
		const cl = sampled[ 0 ].clone();
		log.push( [ 'sampled clone', cl.id, sampled[ 0 ].id, new M.SampledTextures.SampledTexture( 'x', null ).id ] );
		const buffer = new M.UniformBuffer( 'ub', new Float32Array( 5 ) );
		buffer.addUpdateRange( 0, 2 );
		const bc = buffer.clone();
		bc.addUpdateRange( 4, 1 );
		log.push( [ 'uniform buffer', buffer.byteLength, buffer.update(), buffer.updateRanges.map( ( r ) => [ r.start, r.count ] ), bc.updateRanges === buffer.updateRanges, bc.isUniformBuffer ] );
		buffer.clearUpdateRanges();
		buffer.release();
		log.push( [ 'released', buffer.buffer, bc.updateRanges.length ] );
		const binding = new M.Buffer( 'b' );
		binding.setVisibility( 1 );
		binding.setVisibility( 4 );
		log.push( [ 'visibility', binding.visibility, binding.clone().visibility ] );

	},

};
