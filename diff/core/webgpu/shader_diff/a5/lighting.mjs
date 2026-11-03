// Group `lighting` (src/addons/tsl/a5_lighting_shader_diff_test.mbt): tsl/lighting
// (DynamicLightsNode and its data nodes, ClusteredLightsNode, LightProbeGridNode) and
// tsl/shadows (TileShadowNode, TileShadowNodeHelper).
export const modules = [
	'tsl/lighting/data/AmbientLightDataNode.js', 'tsl/lighting/data/DirectionalLightDataNode.js',
	'tsl/lighting/data/HemisphereLightDataNode.js', 'tsl/lighting/data/PointLightDataNode.js',
	'tsl/lighting/data/SpotLightDataNode.js', 'tsl/lighting/DynamicLightsNode.js',
	'tsl/lighting/ClusteredLightsNode.js', 'tsl/lighting/LightProbeGridNode.js',
	'tsl/shadows/TileShadowNode.js', 'tsl/shadows/TileShadowNodeHelper.js',
];

export function scenarios( { T, THREE, N, A, flow, custom, buildMaterial, bindingsOf, tex, geometry, WGSLNodeBuilder, GLSLNodeBuilder } ) {

	const num = ( x ) => String( x );
	const vec = ( v ) => [ v.x, v.y, v.z, v.w ].filter( ( x ) => x !== undefined ).map( num ).join( ',' );
	const col = ( c ) => [ c.r, c.g, c.b ].map( num ).join( ',' );

	// lights (positions and targets set, world matrices updated)
	const point = ( x, castShadow = false ) => {

		const l = new THREE.PointLight( new THREE.Color( 1, 0.5, 0.25 ), 2, 10, 2 );
		l.position.set( x, 1, 2 );
		l.castShadow = castShadow;
		l.updateMatrixWorld();
		return l;

	};

	const spot = ( x, map = null ) => {

		const l = new THREE.SpotLight( new THREE.Color( 0.25, 0.75, 1 ), 3, 20, 0.6, 0.3, 1.5 );
		l.position.set( x, 4, - 1 );
		l.target.position.set( 0, - 1, 1 );
		l.map = map;
		l.updateMatrixWorld();
		l.target.updateMatrixWorld();
		return l;

	};

	const directional = ( x ) => {

		const l = new THREE.DirectionalLight( new THREE.Color( 1, 1, 0.5 ), 1.5 );
		l.position.set( x, 5, 3 );
		l.updateMatrixWorld();
		l.target.updateMatrixWorld();
		return l;

	};

	const hemisphere = () => {

		const l = new THREE.HemisphereLight( new THREE.Color( 0.5, 0.75, 1 ), new THREE.Color( 0.25, 0.125, 0 ), 0.8 );
		l.position.set( 0, 3, 1 );
		l.updateMatrixWorld();
		return l;

	};

	const ambient = ( i ) => new THREE.AmbientLight( new THREE.Color( 0.1 * i, 0.2, 0.3 ), 0.5 * i );

	const camera = () => {

		const c = new THREE.PerspectiveCamera( 60, 1.5, 0.5, 80 );
		c.position.set( 1, 2, 8 );
		c.lookAt( 0, 0, 0 );
		c.updateMatrixWorld();
		return c;

	};

	const lit = ( name, makeMaterial, makeLightsNode, opts = {} ) => custom( name, ( r, isGLSL ) => buildMaterial( makeMaterial(), r, isGLSL, { lightsNode: makeLightsNode() } ), opts );

	// DynamicLightsNode

	lit( 'dynamic_standard_batched', () => new THREE.MeshStandardNodeMaterial(),
		() => A.dynamicLights().setLights( [ ambient( 1 ), hemisphere(), directional( 1 ), point( 1 ), point( - 2 ), spot( 2 ), ambient( 2 ) ] ), { glsl: true } );
	lit( 'dynamic_phong_builtin_mix', () => new THREE.MeshPhongNodeMaterial(),
		() => A.dynamicLights().setLights( [ point( 1, true ), spot( 1, tex( 'spotMap' ) ), new THREE.IESSpotLight(), directional( 2 ), point( 3 ) ] ), { glsl: true } );
	lit( 'dynamic_small_max', () => new THREE.MeshStandardNodeMaterial(),
		() => new A.DynamicLightsNode( { maxDirectionalLights: 1, maxPointLights: 2, maxSpotLights: 1, maxHemisphereLights: 1 } ).setLights( [ point( 1 ), point( 2 ), point( 3 ), directional( 1 ), directional( 2 ), spot( 1 ), spot( 2 ), hemisphere(), hemisphere() ] ) );
	lit( 'dynamic_only_builtin', () => new THREE.MeshLambertNodeMaterial(),
		() => A.dynamicLights().setLights( [ point( 1, true ), spot( 1, tex( 'map' ) ) ] ) );
	lit( 'dynamic_empty', () => new THREE.MeshStandardNodeMaterial(), () => A.dynamicLights() );
	lit( 'dynamic_relight', () => new THREE.MeshPhysicalNodeMaterial(), () => {

		const n = A.dynamicLights( { maxPointLights: 4 } );
		n.setLights( [ point( 1 ), directional( 1 ), ambient( 1 ) ] );
		return n.setLights( [ point( 2 ) ] );

	} );
	lit( 'dynamic_color_node_spot', () => new THREE.MeshStandardNodeMaterial(), () => {

		const s = spot( 1 );
		s.colorNode = T.Fn( ( [ c ] ) => c.xyz.mul( 0.5 ) );
		return A.dynamicLights().setLights( [ s, spot( 2 ) ] );

	} );

	custom( 'dynamic_cpu', () => {

		const out = [];
		const cam = camera();
		const lights = [ ambient( 1 ), ambient( 2 ), hemisphere(), directional( 1 ), directional( - 1 ), point( 1 ), point( - 2 ), point( 5, true ), spot( 2 ), spot( - 3 ), spot( 1, tex( 'm' ) ) ];
		const n = new A.DynamicLightsNode( { maxPointLights: 1, maxSpotLights: 4 } );
		n.setLights( lights );
		out.push( 'builtin ' + n.getBuiltinLights().map( ( l ) => l.id - lights[ 0 ].id ).join( ',' ) );
		out.push( 'hasLights ' + n.hasLights + ' types ' + [ ...n._dataNodes.keys() ].join( ',' ) );
		out.push( 'cacheKey ' + num( n.customCacheKey() ) );
		for ( const [ type, d ] of n._dataNodes ) {

			d.update( { camera: cam } );
			out.push( type + ' count ' + ( d.countNode ? d.countNode.value : '-' ) );
			if ( d._color ) out.push( ' color ' + col( d._color ) );
			if ( d._colors ) out.push( ' colors ' + d._colors.map( col ).join( ' ' ) );
			if ( d._skyColors ) out.push( ' sky ' + d._skyColors.map( col ).join( ' ' ) + ' ground ' + d._groundColors.map( col ).join( ' ' ) );
			if ( d._directions ) out.push( ' dirs ' + d._directions.map( vec ).join( ' ' ) );
			if ( d._positionsAndCutoff ) out.push( ' pos ' + d._positionsAndCutoff.map( vec ).join( ' ' ) );
			if ( d._decays ) out.push( ' decays ' + d._decays.map( vec ).join( ' ' ) );
			if ( d._directionsAndDecay ) out.push( ' dirdecay ' + d._directionsAndDecay.map( vec ).join( ' ' ) );
			if ( d._cones ) out.push( ' cones ' + d._cones.map( vec ).join( ' ' ) );

		}

		n.setLights( [ point( 0 ) ] );
		out.push( 'relit builtin ' + n.getBuiltinLights().length + ' hasLights ' + n.hasLights + ' cacheKey ' + num( n.customCacheKey() ) );
		const empty = A.dynamicLights();
		out.push( 'empty hasLights ' + empty.hasLights + ' cacheKey ' + num( empty.customCacheKey() ) );
		return out.join( '\n' );

	} );

	// ClusteredLightsNode

	const clusteredMix = () => [ point( 1 ), point( - 2, true ), spot( 2 ), spot( 1, tex( 'cmap' ) ), directional( 1 ), ambient( 1 ), new THREE.IESSpotLight(), point( 3 ) ];
	lit( 'clustered_standard', () => new THREE.MeshStandardNodeMaterial(), () => new A.ClusteredLightsNode().setLights( clusteredMix() ), { glsl: true } );
	lit( 'clustered_options', () => new THREE.MeshPhongNodeMaterial(), () => new A.ClusteredLightsNode( 64, 16, 8, 6 ).setLights( [ point( 1 ), spot( 2 ) ] ), { glsl: true } );
	lit( 'clustered_tsl_default', () => new THREE.MeshLambertNodeMaterial(), () => A.clusteredLights().setLights( [ point( 1 ) ] ) );
	lit( 'clustered_only_builtin', () => new THREE.MeshPhysicalNodeMaterial(), () => new A.ClusteredLightsNode( 16, 32, 4, 4 ).setLights( [ directional( 1 ), point( 2, true ) ] ) );
	lit( 'clustered_color_node', () => new THREE.MeshStandardNodeMaterial(), () => {

		const p = point( 1 );
		p.colorNode = T.color( 1, 0, 0 );
		return new A.ClusteredLightsNode( 16, 32, 4, 4 ).setLights( [ p, point( 2 ) ] );

	} );
	custom( 'clustered_compute', ( r, isGLSL ) => {

		const n = new A.ClusteredLightsNode( 32, 16, 4, 8 ).setLights( [ point( 1 ), spot( 2 ) ] );
		const mat = buildMaterial( new THREE.MeshStandardNodeMaterial(), r, isGLSL, { lightsNode: n } );
		const Builder = isGLSL ? GLSLNodeBuilder : WGSLNodeBuilder;
		const b = new Builder( null, r );
		b.compute = n._compute;
		b.build();
		return mat + '\n####\n' + b.vertexShader + '\n@@@@\n' + b.fragmentShader + '\n@@@@\n' + b.computeShader + '\n@@@@\n' + bindingsOf( b ) + '\n' + n._compute.count + ' ' + n._invocationsPerCluster;

	}, { glsl: true } );
	custom( 'clustered_debug_count', ( r, isGLSL ) => {

		const n = new A.ClusteredLightsNode( 16, 32, 6, 4 );
		n.setSize( 320, 160 );
		n.setLights( [ point( 1 ) ] );
		const m = new THREE.MeshStandardNodeMaterial();
		m.colorNode = T.vec3( T.float( n.getClusterLightCount( T.int( - 1 ) ) ).div( 8 ), T.float( n.getClusterLightCount( T.int( 2 ) ) ), 0 );
		return buildMaterial( m, r, isGLSL, { lightsNode: n } );

	}, { glsl: true } );
	custom( 'clustered_cpu', ( r ) => {

		const out = [];
		const cam = camera();
		const n = new A.ClusteredLightsNode( 8, 16, 6, 6 );
		const wide = spot( - 3 );
		wide.angle = 1.2;
		const unbounded = spot( 3 );
		unbounded.distance = 0;
		const far = point( 0 );
		far.position.set( 0, 0, - 60 );
		far.distance = 0;
		far.updateMatrixWorld();
		const lights = [ point( 1 ), point( - 2 ), spot( 2 ), wide, point( 4, true ), spot( 1, tex( 'cm' ) ), directional( 1 ), unbounded, far, point( 6 ), point( 7 ), point( 8 ) ];
		n.setLights( lights );
		const rel = ( a ) => a.map( ( l ) => l.id - lights[ 0 ].id ).join( ',' );
		out.push( 'clustered ' + rel( n.clusteredLights ) + ' material ' + rel( n.materialLights ) + ' builtin ' + rel( n.getBuiltinLights() ) );
		n._updateLightsTexture( cam );
		out.push( 'count ' + n._lightsCount.value + ' order ' + n._lightSortOrder.join( ',' ) );
		out.push( 'viewZ ' + [ ...n._lightViewZ ].map( num ).join( ',' ) );
		out.push( 'data ' + [ ...n._lightsTexture.image.data ].map( num ).join( ',' ) );
		out.push( 'z ' + [ ...n._zSliceRangesData ].map( num ).join( ',' ) );
		out.push( 'needsUpdate ' + n._lightsTexture.version + ' ' + n._zSliceRangesTexture.version );
		const grid = () => out.push( 'grid ' + vec( n._bufferSize ) + ' dims ' + vec( n._gridDimensions.value ) + ' count ' + n._compute.count + ' elements ' + n._lightIndexes.value.array.length + ' version ' + n.version + ' inv ' + n._invocationsPerCluster + ' cacheKey ' + num( n.customCacheKey() ) );
		n.setSize( 300, 150 );
		grid();
		n.setSize( 1000, 700 );
		grid();
		n.setSize( 100, 50 );
		grid();
		n.setSize( 100, 50 );
		grid();
		n.updateSize();
		out.push( 'renderer ' + ( n._renderer === null ) );
		n._initGrid( r );
		n.updateSize();
		grid();
		n.setLights( [ point( 0 ) ] );
		n._updateLightsTexture( cam );
		out.push( 'relit count ' + n._lightsCount.value + ' order ' + n._lightSortOrder.join( ',' ) + ' z ' + [ ...n._zSliceRangesData ].map( num ).join( ',' ) );
		return out.join( '\n' );

	} );

	// LightProbeGridNode (the light: a stand-in for examples/jsm/lighting/LightProbeGrid.js)

	const grid = ( priority = 0, x = 0 ) => {

		const l = new THREE.Light( new THREE.Color( 1, 1, 1 ), 1.5 );
		l.isLightProbeGrid = true;
		l.boundingBox = new THREE.Box3( new THREE.Vector3( - 2 + x, - 1, - 3 ), new THREE.Vector3( 2 + x, 3, 1 ) );
		l.resolution = new THREE.Vector3( 4, 3, 2 );
		l.priority = priority;
		l.texture = new THREE.Data3DTexture( null, 4, 3, 28 );
		l.texture.name = 'probeAtlas';
		l._lightNode = A.LightProbeGridNode;
		return l;

	};

	lit( 'probe_grid_standard', () => new THREE.MeshStandardNodeMaterial(), () => new N.LightsNode().setLights( [ grid() ] ), { glsl: true } );
	lit( 'probe_grid_priorities', () => new THREE.MeshPhongNodeMaterial(), () => A.dynamicLights().setLights( [ grid( 1 ), point( 1 ), grid( 0, 3 ), ambient( 1 ) ] ), { glsl: true } );
	flow( 'probe_grid_irradiance', () => A.lightProbeGridIrradiance( grid( 2 ), T.vec3( 0.5, 1, - 0.5 ).toVar( 'p' ), T.vec3( 0, 1, 0 ).toVar( 'n' ) ), { glsl: true } );
	custom( 'probe_grid_cpu', () => {

		const g = grid( 3, 1 );
		const n = new A.LightProbeGridNode( g );
		n.update();
		const v = ( u ) => u.value.isVector3 ? vec( u.value ) : num( u.value );
		const out = [ [ n._min, n._max, n._resolution, n._intensity, n._priority ].map( v ).join( ' ' ) ];
		g.boundingBox.min.set( - 5, - 5, - 5 );
		g.intensity = 0.25;
		g.priority = - 1;
		n.update();
		out.push( [ n._min, n._max, n._resolution, n._intensity, n._priority ].map( v ).join( ' ' ) + ' ' + n.updateType + ' ' + n.type );
		return out.join( '\n' ) + ' ' + A.ATLAS_PADDING;

	} );

	// TileShadowNode

	const tileLight = () => {

		const l = new THREE.DirectionalLight( new THREE.Color( 1, 1, 0.8 ), 2 );
		l.position.set( 10, 20, 5 );
		l.castShadow = true;
		const c = l.shadow.camera;
		c.near = 1;
		c.far = 60;
		c.left = - 30;
		c.right = 30;
		c.top = 20;
		c.bottom = - 25;
		l.shadow.mapSize.set( 512, 256 );
		const group = new THREE.Group();
		group.add( l );
		group.add( l.target );
		l.target.position.set( 1, 0, - 2 );
		group.updateMatrixWorld();
		return l;

	};

	const tileMesh = ( material ) => {

		const m = new THREE.Mesh( geometry(), material );
		m.receiveShadow = true;
		return m;

	};

	const withShadows = ( r, type, transmitted, f ) => {

		const prev = [ r.shadowMap.enabled, r.shadowMap.type, r.shadowMap.transmitted ];
		r.shadowMap.enabled = true;
		r.shadowMap.type = type;
		r.shadowMap.transmitted = transmitted;
		try {

			return f();

		} finally {

			[ r.shadowMap.enabled, r.shadowMap.type, r.shadowMap.transmitted ] = prev;

		}

	};

	const tileBuild = ( r, isGLSL, type, makeNode, opts = {} ) => withShadows( r, type, opts.transmitted === true, () => {

		const l = tileLight();
		const tsn = makeNode( l );
		l.shadow.shadowNode = tsn;
		const m = opts.material ? opts.material() : new THREE.MeshStandardNodeMaterial();
		const text = buildMaterial( m, r, isGLSL, { lightsNode: new N.LightsNode().setLights( [ l ] ), object: tileMesh( m ) } );
		return { l, tsn, text };

	} );

	custom( 'tile_shadow_basic', ( r, isGLSL ) => tileBuild( r, isGLSL, THREE.BasicShadowMap, ( l ) => new A.TileShadowNode( l, { tilesX: 3, tilesY: 2 } ) ).text, { glsl: true } );
	custom( 'tile_shadow_pcf_default', ( r, isGLSL ) => tileBuild( r, isGLSL, THREE.PCFShadowMap, ( l ) => new A.TileShadowNode( l ) ).text, { glsl: true } );
	custom( 'tile_shadow_vsm', ( r, isGLSL ) => tileBuild( r, isGLSL, THREE.VSMShadowMap, ( l ) => new A.TileShadowNode( l, { tilesX: 2, tilesY: 3 } ) ).text );
	custom( 'tile_shadow_options', ( r, isGLSL ) => tileBuild( r, isGLSL, THREE.BasicShadowMap, ( l ) => new A.TileShadowNode( l, { tilesX: 1, tilesY: 3, resolution: new THREE.Vector2( 256, 128 ), depthType: THREE.UnsignedShortType, debug: true } ), {
		transmitted: true,
		material: () => {

			const m = new THREE.MeshPhongNodeMaterial();
			m.receivedShadowNode = T.Fn( ( [ s ] ) => s.mul( 0.5 ) );
			return m;

		}
	} ).text, { glsl: true } );
	custom( 'tile_shadow_filter_node', ( r, isGLSL ) => tileBuild( r, isGLSL, THREE.PCFShadowMap, ( l ) => {

		l.shadow.filterNode = T.Fn( ( { shadowCoord, depthLayer } ) => shadowCoord.z.oneMinus().mul( T.float( depthLayer ) ) );
		return new A.TileShadowNode( l, { tilesX: 2, tilesY: 2 } );

	} ).text );
	custom( 'tile_shadow_cpu', ( r ) => {

		const { l, tsn } = tileBuild( r, false, THREE.PCFShadowMap, ( l ) => new A.TileShadowNode( l, { tilesX: 2, tilesY: 3 } ) );
		const out = [];
		const cfg = tsn.config;
		out.push( 'config ' + [ cfg.tilesX, cfg.tilesY, cfg.resolution.width, cfg.resolution.height, cfg.depthType, cfg.debug, tsn.debug ].join( ',' ) + ' same ' + ( cfg.resolution === l.shadow.mapSize ) );
		out.push( 'tiles ' + tsn.tiles.map( ( t ) => [ ...t.x, ...t.y, t.index ].map( num ).join( ',' ) ).join( ' ' ) );
		out.push( 'size ' + [ tsn.shadowSize.top, tsn.shadowSize.bottom, tsn.shadowSize.left, tsn.shadowSize.right ].join( ',' ) + ' dir ' + vec( tsn.initialLightDirection ) );
		const sm = tsn.shadowMap;
		const dt = sm.depthTexture;
		out.push( 'map ' + [ sm.width, sm.height, sm.depth, sm.textures.length, sm.useArrayDepthTexture, dt.name, dt.type, dt.image.depth, dt.compareFunction, dt.minFilter, dt.magFilter ].join( ',' ) );
		const dumpLights = () => {

			for ( let i = 0; i < tsn.lights.length; i ++ ) {

				const lw = tsn.lights[ i ];
				const c = lw.shadow.camera;
				const sn = tsn._shadowNodes[ i ];
				out.push( 'tile ' + i + ' ' + lw.type + ' ' + lw.castShadow + ' pos ' + vec( lw.position ) + ' target ' + vec( lw.target.position ) + ' q ' + vec( lw.quaternion ) + ' cam ' + [ c.left, c.right, c.top, c.bottom, c.near, c.far, c.userData.tileIndex ].map( num ).join( ',' ) +
					' proj ' + c.projectionMatrix.elements.map( num ).join( ',' ) + ' world ' + c.matrixWorld.elements.map( num ).join( ',' ) +
					' node ' + sn.depthLayer + ' ' + sn.updateBeforeType + ' ' + sn.shadow.needsUpdate + ' ' + ( sn.shadow === lw.shadow ) + ' ' + ( sn.light === lw ) + ' bias ' + num( lw.shadow.bias ) );

			}

		};

		dumpLights();
		out.push( 'parent ' + l.parent.children.length + ' array ' + tsn.cameraArray.cameras.length + ' coord ' + l.shadow.camera.coordinateSystem + ' ' + tsn.type + ' ' + tsn.updateBeforeType );
		l.shadow.camera.left = - 40;
		l.shadow.camera.top = 30;
		l.position.set( - 5, 25, 10 );
		l.updateMatrixWorld();
		tsn.update();
		dumpLights();
		out.push( 'shadowMatrix ' + l.shadow.matrix.elements.map( num ).join( ',' ) );
		tsn.disposeLightsAndNodes();
		out.push( 'disposed ' + l.parent.children.length + ' ' + tsn.lights.length + ' ' + tsn.shadowMap );
		return out.join( '\n' );

	} );
	custom( 'tile_shadow_helper', ( r, isGLSL ) => {

		const { tsn } = tileBuild( r, isGLSL, THREE.BasicShadowMap, ( l ) => new A.TileShadowNode( l, { tilesX: 3, tilesY: 2 } ) );
		const h = new A.TileShadowNodeHelper( tsn );
		const out = [ 'helper ' + h.type + ' ' + h.children.length + ' ' + h.initialized ];
		h.update();
		out.push( 'init ' + h.children.length + ' ' + h.initialized + ' ' + h._debugMeshes.length + ' ' + h._shadowCamHelpers.length );
		for ( const mesh of h._debugMeshes.slice( 0, 3 ) ) {

			out.push( mesh.renderOrder + ' ' + mesh.frustumCulled + ' ' + mesh.material.transparent + ' ' + mesh.material.depthTest + ' ' + mesh.material.depthWrite );
			out.push( buildMaterial( mesh.material, r, isGLSL, { object: mesh } ) );

		}

		h.dispose();
		out.push( 'disposed ' + h._debugMeshes.length + ' ' + h.children.length );
		return out.join( '\n' );

	}, { glsl: true } );

}
