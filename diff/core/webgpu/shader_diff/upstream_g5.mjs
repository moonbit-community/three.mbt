// Upstream side of the G5 (materials/nodes, loaders/nodes) scenarios. The MoonBit side is
// src/nodes/g5_shader_diff_test.mbt; scenario names start with `g5_`.
//
// Whole-material scenarios: a mesh (points, line, sprite) with a node material is built
// with `G5Builder`, a NodeBuilder with G3Builder's parser, ternary and texture methods,
// builtin names for the backend-only methods, and a `buildCode()` that records each
// stage's flow code and result, vars, uniforms, varyings and attributes. The builder gets
// what NodeManager.getForRender sets (scene, camera, lightsNode, fogNode, clipping
// context) and `build()` runs prebuild -> NodeMaterial.build -> the three stages.
//
// Other records (`g5_key_*`, `g5_observer_*`, `g5_json_*`, `g5_copy_*`, `g5_from_*`)
// compare cache keys, NodeMaterialObserver.needsRefresh sequences, JSON round trips,
// copy() and fromMaterial() results.

// @@G5 shared begin (as upstream_g3.mjs)
const g5ParseFunction = ( source ) => {

	const m = /^fn (\w+)\( (.*?) \) -> (\w+) \{/.exec( source );
	const inputs = m[ 2 ] === '' ? [] : m[ 2 ].split( ', ' ).map( ( p ) => p.split( ' : ' ) );
	return [ m[ 1 ], m[ 3 ], inputs ];

};

const g5FunctionCode = ( source, name, newName ) => source.replace( 'fn ' + name + '(', 'fn ' + newName + '(' );
// @@G5 shared end

const fmt = ( v ) => v === null || v === undefined ? '-' : Array.isArray( v ) ? '[' + v.map( fmt ).join( ',' ) + ']' : String( v );

export async function runUpstream( src ) {

	const T = await import( src + '/Three.TSL.js' );
	const THREE = await import( src + '/Three.WebGPU.js' );
	const { default: NodeBuilder } = await import( src + '/nodes/core/NodeBuilder.js' );
	const { WebGPURenderer } = THREE;
	const { default: NodeFunction } = await import( src + '/nodes/core/NodeFunction.js' );
	const { default: NodeFunctionInput } = await import( src + '/nodes/core/NodeFunctionInput.js' );
	const { default: NodeParser } = await import( src + '/nodes/core/NodeParser.js' );
	const imp = async ( p ) => import( src + '/' + p );
	const N = await imp( 'nodes/Nodes.js' );
	const { default: ClippingContext } = await imp( 'renderers/common/ClippingContext.js' );
	const { default: NodeMaterialInstance } = await imp( 'materials/nodes/NodeMaterialInstance.js' );

	if ( typeof globalThis.ImageBitmap === 'undefined' ) globalThis.ImageBitmap = class ImageBitmap {};

	class G5Function extends NodeFunction {

		constructor( source ) {

			const [ name, type, params ] = g5ParseFunction( source );
			super( type, params.map( ( [ n, t ] ) => new NodeFunctionInput( t, n ) ), name );
			this.source = source;

		}

		getCode( name = this.name ) {

			return g5FunctionCode( this.source, this.name, name );

		}

	}

	class G5Parser extends NodeParser {

		parseFunction( source ) {

			return new G5Function( source );

		}

	}

	class G5Builder extends NodeBuilder {

		constructor( object, renderer ) {

			super( object, renderer, new G5Parser() );
			this.recorded = null;
			this.clipDistance = false;

		}

		getTernary( c, a, b ) {

			return `select( ${ b }, ${ a }, ${ c } )`;

		}

		generateTexture( texture, p, uv, depth, offset ) {

			return `tex(${ p }, ${ uv }, ${ fmt( depth ) }, ${ fmt( offset ) })`;

		}

		generateTextureLevel( texture, p, uv, level, depth, offset ) {

			return `texLevel(${ p }, ${ uv }, ${ level }, ${ fmt( depth ) }, ${ fmt( offset ) })`;

		}

		generateTextureBias( texture, p, uv, bias, depth, offset ) {

			return `texBias(${ p }, ${ uv }, ${ bias }, ${ fmt( depth ) }, ${ fmt( offset ) })`;

		}

		generateTextureCompare( texture, p, uv, compare, depth, offset ) {

			return `texCompare(${ p }, ${ uv }, ${ compare }, ${ fmt( depth ) }, ${ fmt( offset ) })`;

		}

		generateTextureLoad( texture, p, uv, level, depth, offset ) {

			return `texLoad(${ p }, ${ uv }, ${ fmt( level ) }, ${ fmt( depth ) }, ${ fmt( offset ) })`;

		}

		generateTextureSize( texture, p, level ) {

			return `size(${ p }, ${ level })`;

		}

		getUniformBufferLimit() {

			return 65536;

		}

		getOutputStructName() {

			return 'output';

		}

		getFrontFacing() {

			return 'frontFacing';

		}

		getFragCoord() {

			return 'fragCoord';

		}

		getFragDepth() {

			return 'fragDepth';

		}

		getInstanceIndex() {

			return 'instanceIndex';

		}

		getVertexIndex() {

			return 'vertexIndex';

		}

		getDrawIndex() {

			return null;

		}

		getClipDistance() {

			return 'clipDistances';

		}

		enableHardwareClipping() {}

		isAvailable( name ) {

			return name === 'clipDistance' ? this.clipDistance : false;

		}

		buildFunctionCode( shaderNode ) {

			const layout = shaderNode.layout;
			const flowData = this.flowShaderNode( shaderNode );
			const parameters = layout.inputs.map( ( input ) => input.name + ' : ' + this.getType( input.type ) );
			let code = `fn ${ layout.name }( ${ parameters.join( ', ' ) } ) -> ${ this.getType( layout.type ) } {\n${ flowData.vars }\n${ flowData.code }\n`;
			if ( flowData.result ) code += `\treturn ${ flowData.result };\n`;
			code += '\n}\n';
			return code;

		}

		buildCode() {

			let code = '';
			const vars = [];
			const codes = [];
			for ( const stage of [ 'vertex', 'fragment' ] ) {

				code += `// ${ stage }\n`;
				for ( const node of this.flowNodes[ stage ] ) {

					const flow = this.getFlowData( node );
					code += flow.code + `\n=> ${ typeof flow.result === 'string' ? flow.result : '' }\n`;

				}

				vars.push( `${ stage }: ${ this.getVars( stage ) }` );
				codes.push( this.getCodes( stage ) );

			}

			this.recorded = { code, vars: vars.join( '\n' ), codes };

		}

	}

	const canvas = { style: {}, width: 300, height: 150, addEventListener() {}, removeEventListener() {}, getContext() { return null; } };
	const newRenderer = () => {

		const renderer = new WebGPURenderer( { canvas } );
		renderer._bindings = undefined;
		return renderer;

	};

	const attr = ( n, itemSize ) => new THREE.BufferAttribute( new Float32Array( n * itemSize ), itemSize );
	const meshGeometry = () => {

		const g = new THREE.BufferGeometry();
		for ( const [ name, itemSize ] of [ [ 'position', 3 ], [ 'normal', 3 ], [ 'uv', 2 ], [ 'uv1', 2 ], [ 'tangent', 4 ], [ 'color', 4 ] ] ) g.setAttribute( name, attr( 24, itemSize ) );
		return g;

	};

	const geometry = meshGeometry();
	const line2Geometry = () => {

		const g = new THREE.BufferGeometry();
		for ( const [ name, itemSize ] of [ [ 'position', 3 ], [ 'uv', 2 ], [ 'instanceStart', 3 ], [ 'instanceEnd', 3 ], [ 'instanceDistanceStart', 1 ], [ 'instanceDistanceEnd', 1 ], [ 'instanceColorStart', 3 ], [ 'instanceColorEnd', 3 ] ] ) g.setAttribute( name, attr( 8, itemSize ) );
		return g;

	};

	const lineGeometry = () => {

		const g = new THREE.BufferGeometry();
		g.setAttribute( 'position', attr( 4, 3 ) );
		g.setAttribute( 'color', attr( 4, 3 ) );
		g.setAttribute( 'lineDistance', attr( 4, 1 ) );
		return g;

	};

	const tex = ( name ) => {

		const t = new THREE.Texture();
		t.name = name;
		return t;

	};

	const cube = ( name ) => {

		const t = new THREE.CubeTexture();
		t.name = name;
		return t;

	};

	const skinnedMesh = ( material ) => {

		const g = new THREE.BufferGeometry();
		for ( const [ name, itemSize ] of [ [ 'position', 3 ], [ 'normal', 3 ], [ 'uv', 2 ], [ 'skinWeight', 4 ] ] ) g.setAttribute( name, attr( 24, itemSize ) );
		g.setAttribute( 'skinIndex', new THREE.BufferAttribute( new Uint16Array( 24 * 4 ), 4 ) );
		const bones = [ new THREE.Bone(), new THREE.Bone() ];
		bones[ 0 ].add( bones[ 1 ] );
		const mesh = new THREE.SkinnedMesh( g, material );
		mesh.add( bones[ 0 ] );
		mesh.bind( new THREE.Skeleton( bones ) );
		return mesh;

	};

	const morphMesh = ( material ) => {

		const g = new THREE.BufferGeometry();
		for ( const [ name, itemSize ] of [ [ 'position', 3 ], [ 'normal', 3 ], [ 'uv', 2 ], [ 'color', 4 ] ] ) g.setAttribute( name, attr( 24, itemSize ) );
		g.morphAttributes.position = [ attr( 24, 3 ), attr( 24, 3 ) ];
		g.morphAttributes.normal = [ attr( 24, 3 ), attr( 24, 3 ) ];
		g.morphAttributes.color = [ attr( 24, 4 ), attr( 24, 4 ) ];
		return new THREE.Mesh( g, material );

	};

	const instancedMesh = ( material ) => {

		const mesh = new THREE.InstancedMesh( geometry, material, 3 );
		mesh.setColorAt( 0, new THREE.Color( 1, 0, 0 ) );
		return mesh;

	};

	const batchedMesh = ( material ) => {

		const mesh = new THREE.BatchedMesh( 2, 48, 72, material );
		mesh.setColorAt( mesh.addInstance( mesh.addGeometry( geometry ) ), new THREE.Color( 1, 0, 0 ) );
		return mesh;

	};

	const point = () => new THREE.PointLight( 0xff0000, 2, 10, 2 );
	const directional = () => new THREE.DirectionalLight( 0x00ff00, 3 );

	// [ name, makeMaterial, options ]
	const scenarios = [];
	const add = ( name, material, options = {} ) => scenarios.push( [ 'g5_' + name, material, options ] );
	const lit = { lights: () => [ point() ] };
	const M = THREE;
	const set = ( make, f ) => () => {

		const m = make();
		f( m );
		return m;

	};

	// --- NodeMaterial and the variants of its setup
	add( 'node_material', () => new M.NodeMaterial() );
	add( 'basic', () => new M.MeshBasicNodeMaterial() );
	add( 'basic_maps', set( () => new M.MeshBasicNodeMaterial(), ( m ) => {

		m.map = tex( 'map' ); m.alphaMap = tex( 'alpha' ); m.aoMap = tex( 'ao' ); m.lightMap = tex( 'light' ); m.envMap = cube( 'env' ); m.specularMap = tex( 'spec' );

	} ) );
	add( 'basic_vertex_colors', set( () => new M.MeshBasicNodeMaterial(), ( m ) => { m.vertexColors = true; } ) );
	add( 'basic_alpha_test', set( () => new M.MeshBasicNodeMaterial(), ( m ) => { m.alphaTest = 0.5; } ) );
	add( 'basic_alpha_to_coverage', set( () => new M.MeshBasicNodeMaterial(), ( m ) => { m.alphaTest = 0.5; m.alphaToCoverage = true; } ) );
	add( 'basic_alpha_hash', set( () => new M.MeshBasicNodeMaterial(), ( m ) => { m.alphaHash = true; } ) );
	add( 'basic_transparent_premultiplied', set( () => new M.MeshBasicNodeMaterial(), ( m ) => { m.transparent = true; m.premultipliedAlpha = true; } ) );
	add( 'basic_fog', () => new M.MeshBasicNodeMaterial(), { fog: true } );
	add( 'basic_fog_disabled', set( () => new M.MeshBasicNodeMaterial(), ( m ) => { m.fog = false; } ), { fog: true } );
	add( 'basic_clipping', () => new M.MeshBasicNodeMaterial(), { clipping: true } );
	add( 'basic_clipping_hardware', () => new M.MeshBasicNodeMaterial(), { clipping: true, clipDistance: true } );
	add( 'basic_clipping_alpha_to_coverage', set( () => new M.MeshBasicNodeMaterial(), ( m ) => { m.alphaToCoverage = true; } ), { clipping: true, samples: 4 } );
	add( 'basic_skinning', () => new M.MeshBasicNodeMaterial(), { object: skinnedMesh } );
	add( 'basic_morph', set( () => new M.MeshBasicNodeMaterial(), ( m ) => { m.vertexColors = true; } ), { object: morphMesh } );
	add( 'basic_instanced', () => new M.MeshBasicNodeMaterial(), { object: instancedMesh } );
	add( 'basic_batched', () => new M.MeshBasicNodeMaterial(), { object: batchedMesh } );
	add( 'basic_log_depth', () => new M.MeshBasicNodeMaterial(), { logarithmic: true } );
	add( 'basic_log_depth_ortho', () => new M.MeshBasicNodeMaterial(), { logarithmic: true, ortho: true } );
	add( 'basic_reversed_depth', () => new M.MeshBasicNodeMaterial(), { reversed: true } );
	add( 'basic_no_depth', set( () => new M.MeshBasicNodeMaterial(), ( m ) => { m.depthTest = false; m.depthWrite = false; m.depthNode = T.float( 0.5 ); } ), { logarithmic: true } );
	add( 'basic_mrt', () => new M.MeshBasicNodeMaterial(), { mrt: () => T.mrt( { output: T.output, normal: T.normalView } ) } );
	add( 'basic_mrt_material', set( () => new M.MeshBasicNodeMaterial(), ( m ) => { m.mrtNode = T.mrt( { emissive: T.vec4( 1, 0, 0, 1 ) } ); } ), { mrt: () => T.mrt( { output: T.output } ) } );
	add( 'basic_mrt_depth', () => new M.MeshBasicNodeMaterial(), { mrt: () => T.mrt( { output: T.output, depth: T.float( 0.25 ) } ) } );
	add( 'basic_material_mrt_only', set( () => new M.MeshBasicNodeMaterial(), ( m ) => { m.mrtNode = T.mrt( { output: T.vec4( 1 ) } ); } ), { renderTarget: true } );
	add( 'basic_output_node_mrt', set( () => new M.MeshBasicNodeMaterial(), ( m ) => { m.outputNode = T.vec4( 0, 1, 0, 1 ); } ), { mrt: () => T.mrt( { output: T.output } ) } );
	add( 'basic_nodes', set( () => new M.MeshBasicNodeMaterial(), ( m ) => {

		m.colorNode = T.vec3( 1, 0.5, 0.25 ); m.opacityNode = T.float( 0.5 ); m.positionNode = T.positionLocal.mul( 2 );
		m.alphaTestNode = T.float( 0.1 ); m.maskNode = T.uv().x.greaterThan( 0.5 ); m.depthNode = T.float( 0.75 );

	} ) );
	add( 'basic_output_node', set( () => new M.MeshBasicNodeMaterial(), ( m ) => { m.outputNode = T.vec4( 0, 1, 0, 1 ); } ) );
	add( 'basic_backdrop', set( () => new M.NodeMaterial(), ( m ) => { m.backdropNode = T.vec3( 0.2 ); m.backdropAlphaNode = T.float( 0.5 ); } ) );
	add( 'basic_fragment_node', set( () => new M.MeshBasicNodeMaterial(), ( m ) => { m.fragmentNode = T.vec3( 1, 0, 0 ); } ) );
	add( 'basic_fragment_output_struct', set( () => new M.NodeMaterial(), ( m ) => { m.fragmentNode = T.outputStruct( T.vec4( 1 ), T.vec4( 0.5 ) ); } ) );
	add( 'basic_vertex_node', set( () => new M.MeshBasicNodeMaterial(), ( m ) => { m.vertexNode = T.vec4( 0, 0, 0, 1 ); } ) );
	add( 'basic_lights_node', set( () => new M.NodeMaterial(), ( m ) => { m.lightsNode = new N.LightsNode().setLights( [ point() ] ); } ) );
	add( 'basic_context_getters', () => new M.MeshBasicNodeMaterial(), { aoGi: true } );
	add( 'basic_displacement', set( () => new M.MeshBasicNodeMaterial(), ( m ) => { m.displacementMap = tex( 'disp' ); } ) );

	// --- lit materials
	add( 'lambert', () => new M.MeshLambertNodeMaterial(), lit );
	add( 'lambert_maps', set( () => new M.MeshLambertNodeMaterial(), ( m ) => { m.emissiveMap = tex( 'emissive' ); m.normalMap = tex( 'normal' ); m.envMap = cube( 'env' ); } ), lit );
	add( 'lambert_emissive_node', set( () => new M.MeshLambertNodeMaterial(), ( m ) => { m.emissiveNode = T.vec3( 0.1 ); } ), lit );
	add( 'lambert_emissive_node_no_color', set( () => new M.MeshLambertNodeMaterial(), ( m ) => { m.emissive = null; m.emissiveNode = T.vec3( 0.2 ); } ), lit );
	add( 'phong', () => new M.MeshPhongNodeMaterial(), lit );
	add( 'phong_nodes', set( () => new M.MeshPhongNodeMaterial(), ( m ) => { m.shininessNode = T.float( 50 ); m.specularNode = T.vec3( 0.5 ); m.emissiveNode = T.vec3( 0.1 ); } ), lit );
	add( 'phong_env_bump', set( () => new M.MeshPhongNodeMaterial(), ( m ) => { m.envMap = tex( 'env2d' ); m.bumpMap = tex( 'bump' ); m.specularMap = tex( 'spec' ); } ), lit );
	add( 'standard', () => new M.MeshStandardNodeMaterial(), lit );
	add( 'standard_no_lights', () => new M.MeshStandardNodeMaterial() );
	add( 'standard_maps', set( () => new M.MeshStandardNodeMaterial(), ( m ) => {

		m.map = tex( 'map' ); m.roughnessMap = tex( 'rough' ); m.metalnessMap = tex( 'metal' ); m.normalMap = tex( 'normal' ); m.emissiveMap = tex( 'emissive' ); m.aoMap = tex( 'ao' ); m.lightMap = tex( 'light' );

	} ), lit );
	add( 'standard_nodes', set( () => new M.MeshStandardNodeMaterial(), ( m ) => { m.metalnessNode = T.float( 0.5 ); m.roughnessNode = T.float( 0.25 ); m.normalNode = T.vec3( 0, 0, 1 ); m.emissiveNode = T.color( 0x112233 ); } ), lit );
	add( 'standard_env', set( () => new M.MeshStandardNodeMaterial(), ( m ) => { m.envNode = T.vec3( 0.1, 0.2, 0.3 ); } ), lit );
	add( 'standard_flat', set( () => new M.MeshStandardNodeMaterial(), ( m ) => { m.flatShading = true; } ), lit );
	add( 'standard_fog_clipping', () => new M.MeshStandardNodeMaterial(), { lights: () => [ point() ], fog: true, clipping: true } );
	add( 'physical', () => new M.MeshPhysicalNodeMaterial(), lit );
	add( 'physical_clearcoat', set( () => new M.MeshPhysicalNodeMaterial(), ( m ) => { m.clearcoat = 1; m.clearcoatNormalMap = tex( 'ccn' ); } ), lit );
	add( 'physical_clearcoat_node', set( () => new M.MeshPhysicalNodeMaterial(), ( m ) => { m.clearcoatNode = T.float( 0.5 ); m.clearcoatRoughnessNode = T.float( 0.2 ); m.clearcoatNormalNode = T.vec3( 0, 0, 1 ); } ), lit );
	add( 'physical_sheen', set( () => new M.MeshPhysicalNodeMaterial(), ( m ) => { m.sheen = 1; } ), lit );
	add( 'physical_iridescence', set( () => new M.MeshPhysicalNodeMaterial(), ( m ) => { m.iridescence = 1; } ), lit );
	add( 'physical_anisotropy', set( () => new M.MeshPhysicalNodeMaterial(), ( m ) => { m.anisotropy = 0.5; } ), lit );
	add( 'physical_anisotropy_node', set( () => new M.MeshPhysicalNodeMaterial(), ( m ) => { m.anisotropyNode = T.vec2( 0.5, 0.25 ); } ), lit );
	add( 'physical_retroreflection', set( () => new M.MeshPhysicalNodeMaterial(), ( m ) => { m.retroreflectivity = 0.5; } ), lit );
	add( 'physical_diffuse_roughness', set( () => new M.MeshPhysicalNodeMaterial(), ( m ) => { m.diffuseRoughness = 0.5; } ), lit );
	add( 'physical_specular_nodes', set( () => new M.MeshPhysicalNodeMaterial(), ( m ) => { m.iorNode = T.float( 1.8 ); m.specularColorNode = T.vec3( 1, 0.5, 0.5 ); m.specularIntensityNode = T.float( 0.5 ); } ), lit );
	add( 'sss', set( () => new M.MeshSSSNodeMaterial(), ( m ) => { m.thicknessColorNode = T.vec3( 0.5, 0.1, 0.1 ); } ), lit );
	add( 'sss_default', () => new M.MeshSSSNodeMaterial(), lit );
	add( 'toon', () => new M.MeshToonNodeMaterial(), lit );
	add( 'toon_gradient', set( () => new M.MeshToonNodeMaterial(), ( m ) => { m.gradientMap = tex( 'gradient' ); } ), { lights: () => [ directional() ] } );
	add( 'matcap', () => new M.MeshMatcapNodeMaterial() );
	add( 'matcap_texture', set( () => new M.MeshMatcapNodeMaterial(), ( m ) => { m.matcap = tex( 'matcap' ); } ) );
	add( 'normal', () => new M.MeshNormalNodeMaterial() );
	add( 'normal_opacity', set( () => new M.MeshNormalNodeMaterial(), ( m ) => { m.opacityNode = T.float( 0.5 ); m.transparent = true; } ) );
	add( 'shadow', () => new M.ShadowNodeMaterial(), { lights: () => [ directional() ] } );
	add( 'volume', () => new M.VolumeNodeMaterial(), lit );
	add( 'volume_scattering', set( () => new M.VolumeNodeMaterial(), ( m ) => { m.steps = 12; m.scatteringNode = T.Fn( () => T.vec3( 0.5 ) ); m.offsetNode = T.float( 0.1 ); } ), lit );

	// --- lines, points, sprites
	const lineObject = ( material ) => new THREE.Line( lineGeometry(), material );
	const line2Object = ( material ) => new THREE.Mesh( line2Geometry(), material );
	const pointsObject = ( material ) => new THREE.Points( lineGeometry(), material );
	const spriteObject = ( material ) => new THREE.Sprite( material );
	add( 'line_basic', () => new M.LineBasicNodeMaterial(), { object: lineObject } );
	add( 'line_basic_vertex_colors', set( () => new M.LineBasicNodeMaterial(), ( m ) => { m.vertexColors = true; } ), { object: lineObject } );
	add( 'line_dashed', () => new M.LineDashedNodeMaterial(), { object: lineObject } );
	add( 'line_dashed_nodes', set( () => new M.LineDashedNodeMaterial(), ( m ) => { m.dashOffset = 1; m.offsetNode = T.float( 2 ); m.dashScaleNode = T.float( 3 ); m.dashSizeNode = T.float( 4 ); m.gapSizeNode = T.float( 5 ); } ), { object: lineObject } );
	add( 'line2', () => new M.Line2NodeMaterial(), { object: line2Object } );
	add( 'line2_world_units', set( () => new M.Line2NodeMaterial(), ( m ) => { m.worldUnits = true; } ), { object: line2Object } );
	add( 'line2_dashed', () => new M.Line2NodeMaterial( { dashed: true } ), { object: line2Object } );
	add( 'line2_dashed_world_units', set( () => new M.Line2NodeMaterial( { dashed: true } ), ( m ) => { m.worldUnits = true; m.dashOffset = 0.5; } ), { object: line2Object } );
	add( 'line2_no_alpha_to_coverage', set( () => new M.Line2NodeMaterial(), ( m ) => { m.alphaToCoverage = false; } ), { object: line2Object } );
	add( 'line2_alpha_to_coverage_samples', () => new M.Line2NodeMaterial(), { object: line2Object, samples: 4 } );
	add( 'line2_world_units_samples', set( () => new M.Line2NodeMaterial(), ( m ) => { m.worldUnits = true; } ), { object: line2Object, samples: 4 } );
	add( 'line2_vertex_colors_transparent', set( () => new M.Line2NodeMaterial( { vertexColors: true } ), ( m ) => { m.transparent = true; } ), { object: line2Object } );
	add( 'line2_dashed_nodes', set( () => new M.Line2NodeMaterial( { dashed: true } ), ( m ) => { m.offsetNode = T.float( 2 ); m.dashScaleNode = T.float( 3 ); m.dashSizeNode = T.float( 4 ); m.gapSizeNode = T.float( 5 ); } ), { object: line2Object } );
	add( 'points', () => new M.PointsNodeMaterial(), { object: pointsObject } );
	add( 'points_sprite', () => new M.PointsNodeMaterial(), { object: ( m ) => new THREE.Mesh( geometry, m ) } );
	add( 'points_sprite_nodes', set( () => new M.PointsNodeMaterial(), ( m ) => { m.sizeNode = T.float( 4 ); m.rotationNode = T.float( 0.5 ); m.scaleNode = T.vec2( 2, 3 ); m.positionNode = T.vec3( 1, 2, 3 ); } ), { object: ( m ) => new THREE.Mesh( geometry, m ) } );
	add( 'points_sprite_no_attenuation_ortho', set( () => new M.PointsNodeMaterial(), ( m ) => { m.sizeAttenuation = false; } ), { object: ( m ) => new THREE.Mesh( geometry, m ), ortho: true } );
	add( 'sprite', () => new M.SpriteNodeMaterial(), { object: spriteObject } );
	add( 'sprite_nodes', set( () => new M.SpriteNodeMaterial(), ( m ) => { m.rotationNode = T.float( 0.5 ); m.scaleNode = T.vec2( 2, 3 ); m.positionNode = T.vec3( 1, 2, 3 ); m.sizeAttenuation = false; } ), { object: spriteObject } );
	add( 'sprite_map', set( () => new M.SpriteNodeMaterial(), ( m ) => { m.map = tex( 'sprite' ); m.rotation = 1; } ), { object: spriteObject, ortho: true } );

	// --- NodeMaterialInstance
	add( 'instance', () => {

		const base = new M.MeshStandardNodeMaterial();
		base.colorNode = T.vec3( 1, 0, 0 );
		const instance = new NodeMaterialInstance( base );
		instance.color = new THREE.Color( 0, 1, 0 );
		instance.map = tex( 'instance_map' );
		return instance;

	}, lit );

	const records = {};
	for ( const [ name, makeMaterial, options ] of scenarios ) {

		const material = makeMaterial();
		const object = options.object ? options.object( material ) : new THREE.Mesh( geometry, material );
		object.position.set( 1, 2, 3 );
		object.updateMatrixWorld( true );
		const renderer = newRenderer();
		renderer.logarithmicDepthBuffer = options.logarithmic === true;
		renderer.reversedDepthBuffer = options.reversed === true;
		if ( options.samples ) renderer._samples = options.samples;
		if ( options.mrt || options.renderTarget ) renderer._renderTarget = new THREE.RenderTarget( 4, 4 );
		if ( options.mrt ) renderer._mrt = options.mrt();
		const builder = new G5Builder( object, renderer );
		builder.clipDistance = options.clipDistance === true;
		const scene = new THREE.Scene();
		builder.scene = scene;
		builder.camera = options.ortho ? new THREE.OrthographicCamera() : new THREE.PerspectiveCamera();
		const lightsNode = new N.LightsNode().setLights( options.lights ? options.lights() : [] );
		builder.lightsNode = lightsNode;
		if ( options.fog ) builder.fogNode = T.fog( T.color( 0x8899aa ), T.rangeFogFactor( 1, 10 ) );
		if ( options.clipping ) {

			const c = new ClippingContext();
			c.unionPlanes = [ new THREE.Vector4( 0, 1, 0, 0 ), new THREE.Vector4( 1, 0, 0, 2 ) ];
			c.intersectionPlanes = [ new THREE.Vector4( 0, 0, 1, 1 ) ];
			builder.clippingContext = c;

		}

		if ( options.aoGi ) {

			builder.context.getAO = ( ao ) => ao === null ? T.float( 0.5 ) : ao.mul( 0.5 );
			builder.context.getGI = () => T.vec3( 0.1, 0.2, 0.3 );

		}

		try {

			builder.build();

		} catch ( e ) {

			records[ name ] = { error: String( e ) };
			continue;

		}

		const uniforms = [];
		for ( const s of [ 'vertex', 'fragment', 'compute' ] ) {

			for ( const u of builder.uniforms[ s ] ) uniforms.push( `${s}:${u.name}:${u.type}` );

		}

		const varyings = builder.varyings.map( ( v ) => `${v.name}:${v.type}:${v.needsInterpolation}` );
		const attributes = builder.attributes.map( ( a ) => `${a.name}:${a.type}` );
		const extra = [ 'varyings=' + varyings.join( ',' ), 'attributes=' + attributes.join( ',' ), 'hasNode=' + builder.observer.hasNode, 'hasAnimation=' + builder.observer.hasAnimation, 'hardwareClipping=' + builder.hardwareClipping, 'updates=' + builder.updateNodes.length + '/' + builder.updateBeforeNodes.length + '/' + builder.updateAfterNodes.length ].join( '\n' );
		records[ name ] = { code: builder.recorded.code, result: '', vars: builder.recorded.vars, uniforms, codes: builder.recorded.codes, extra };

	}

	Object.assign( records, await nonShaderRecords( src, THREE, T, N, NodeMaterialInstance ) );
	return records;

}

// ---------------------------------------------------------------------------
// Cache keys, copy, fromMaterial, JSON round trips and observer sequences.

async function nonShaderRecords( src, THREE, T, N, NodeMaterialInstance ) {

	const records = {};
	const imp = async ( p ) => import( src + '/' + p );
	const M = THREE;
	const classes = [ 'NodeMaterial', 'LineBasicNodeMaterial', 'LineDashedNodeMaterial', 'Line2NodeMaterial', 'MeshNormalNodeMaterial', 'MeshBasicNodeMaterial', 'MeshLambertNodeMaterial', 'MeshPhongNodeMaterial', 'MeshStandardNodeMaterial', 'MeshPhysicalNodeMaterial', 'MeshSSSNodeMaterial', 'MeshToonNodeMaterial', 'MeshMatcapNodeMaterial', 'PointsNodeMaterial', 'SpriteNodeMaterial', 'ShadowNodeMaterial', 'VolumeNodeMaterial' ];

	// custom program cache keys without node slots (deterministic), and whether keys
	// with the same / different nodes are equal
	for ( const c of classes ) {

		const a = new M[ c ]();
		const b = new M[ c ]();
		const shared = T.float( 1 );
		a.colorNode = shared;
		b.colorNode = shared;
		const d = new M[ c ]();
		d.colorNode = T.float( 1 );
		const e = new M[ c ]();
		d.opacityNode = T.float( 2 );
		// node cache keys include node ids (`customCacheKey()` is `this.id`): classes with
		// default node slots (MeshSSSNodeMaterial) are not compared
		const fresh = new M[ c ]();
		records[ 'g5_key_program_' + c ] = { code: fresh._getNodeChildren().length > 0 ? c + ':id-dependent' : fresh.customProgramCacheKey(), result: String( a.customProgramCacheKey() === b.customProgramCacheKey() ) + ',' + String( a.customProgramCacheKey() === d.customProgramCacheKey() ) + ',' + String( e.customProgramCacheKey() === d.customProgramCacheKey() ) };

	}

	// property values and flags a class answers (get_property / flags)
	const props = [ 'type', 'lights', 'fog', 'transparent', 'side', 'depthTest', 'depthWrite', 'blending', 'vertexColors', 'alphaToCoverage', 'sizeAttenuation', 'worldUnits', 'dashed', 'dashOffset', 'steps', 'useClearcoat', 'useSheen', 'useIridescence', 'useAnisotropy', 'useTransmission', 'useDispersion', 'useRetroreflection', 'useDiffuseRoughness', 'useSSS', 'isMeshStandardMaterial', 'isMeshPhysicalMaterial', 'isLineBasicMaterial', 'isSpriteNodeMaterial', 'isNodeMaterial', 'version' ];
	const show = ( v ) => v === undefined ? 'undefined' : v === null ? 'null' : typeof v === 'object' ? ( v.isColor ? '#' + v.getHexString() : v.isNode ? 'node' : 'object' ) : String( v );
	for ( const c of classes ) {

		const m = new M[ c ]();
		records[ 'g5_props_' + c ] = { code: props.map( ( p ) => p + '=' + show( m[ p ] ) ).join( ',' ) };

	}

	const physical = new M.MeshPhysicalNodeMaterial();
	physical.clearcoat = 1; physical.sheenNode = T.vec3( 1 ); physical.transmission = 0.5; physical.anisotropyNode = T.vec2( 1 );
	records.g5_props_physical_features = { code: props.map( ( p ) => p + '=' + show( physical[ p ] ) ).join( ',' ) };

	// copy / clone
	const copyProps = [ 'type', 'name', 'color', 'opacity', 'transparent', 'roughness', 'metalness', 'clearcoat', 'sheen', 'transmission', 'ior', 'emissive', 'emissiveIntensity', 'alphaTest', 'side', 'dashOffset', 'steps', 'worldUnits', 'dashed', 'sizeAttenuation', 'size', 'rotation', 'linewidth', 'version', 'colorNode', 'emissiveNode', 'clearcoatNode', 'sizeNode', 'offsetNode', 'scatteringNode', 'thicknessColorNode', 'userData' ];
	const showCopy = ( m ) => copyProps.map( ( p ) => p + '=' + ( p === 'userData' ? JSON.stringify( m.userData ) : show( m[ p ] ) ) ).join( ',' );
	for ( const c of classes ) {

		const source = new M[ c ]();
		source.name = 'src';
		if ( source.color ) source.color.setHex( 0x336699 );
		source.opacity = 0.5;
		source.transparent = true;
		source.alphaTest = 0.25;
		source.userData = { a: 1, b: [ 2 ] };
		source.colorNode = T.float( 3 );
		if ( 'roughness' in source ) source.roughness = 0.3;
		if ( c === 'MeshPhysicalNodeMaterial' || c === 'MeshSSSNodeMaterial' ) {

			source.clearcoat = 0.5; source.sheen = 1; source.transmission = 0.2; source.clearcoatNode = T.float( 1 );

		}

		if ( 'dashOffset' in source ) source.dashOffset = 2;
		if ( c === 'VolumeNodeMaterial' ) { source.steps = 7; source.scatteringNode = T.float( 1 ); }
		if ( c === 'Line2NodeMaterial' ) { source.worldUnits = true; source.dashed = true; }
		if ( c === 'PointsNodeMaterial' ) { source.sizeNode = T.float( 2 ); source.size = 3; }
		if ( c === 'SpriteNodeMaterial' || c === 'PointsNodeMaterial' ) source.sizeAttenuation = false;
		if ( c === 'MeshSSSNodeMaterial' ) source.thicknessColorNode = T.vec3( 1 );
		const clone = source.clone();
		const sameNode = clone.colorNode === source.colorNode;
		records[ 'g5_copy_' + c ] = { code: showCopy( clone ), result: String( sameNode ) + ',' + String( clone.color === source.color ) };

	}

	// fromMaterial (renderer.library = StandardNodeLibrary)
	const canvas = { style: {}, width: 300, height: 150, addEventListener() {}, removeEventListener() {}, getContext() { return null; } };
	const renderer = new THREE.WebGPURenderer( { canvas } );
	const coreMaterials = [ 'MeshPhongMaterial', 'MeshStandardMaterial', 'MeshPhysicalMaterial', 'MeshToonMaterial', 'MeshBasicMaterial', 'MeshLambertMaterial', 'MeshNormalMaterial', 'MeshMatcapMaterial', 'LineBasicMaterial', 'LineDashedMaterial', 'PointsMaterial', 'SpriteMaterial', 'ShadowMaterial', 'MeshDepthMaterial' ];
	const fromProps = [ 'type', 'color', 'opacity', 'roughness', 'shininess', 'size', 'sizeAttenuation', 'rotation', 'dashSize', 'linewidth', 'clearcoat', 'transparent', 'lights', 'fog', 'isNodeMaterial' ];
	for ( const c of coreMaterials ) {

		const m = new M[ c ]();
		m.name = 'core';
		m.opacity = 0.75;
		if ( m.color ) m.color.setHex( 0x445566 );
		const nm = renderer.library.fromMaterial( m );
		records[ 'g5_from_' + c ] = { code: nm === null ? 'null' : fromProps.map( ( p ) => p + '=' + show( nm[ p ] ) ).join( ',' ) + ',name=' + nm.name };

	}

	// JSON round trips: toJSON of a node material, NodeMaterialLoader / NodeObjectLoader
	// parse, toJSON again (uuids replaced by their order of appearance)
	const { default: NodeMaterialLoader } = await imp( 'loaders/nodes/NodeMaterialLoader.js' );
	const { default: NodeObjectLoader } = await imp( 'loaders/nodes/NodeObjectLoader.js' );
	const { default: NodeLoader } = await imp( 'loaders/nodes/NodeLoader.js' );
	const normalize = ( json ) => {

		const ids = new Map();
		// the version of a shared uniform group counts the updates of earlier scenarios
		const s = JSON.stringify( json ).replace( /"version":\d+,"shared"/g, '"version":#,"shared"' );
		return s.replace( /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi, ( u ) => {

			if ( ! ids.has( u ) ) ids.set( u, '#' + ids.size );
			return ids.get( u );

		} );

	};

	const nodeLib = { ConstNode: N.ConstNode, UniformNode: N.UniformNode, TextureNode: N.TextureNode };
	const materialLib = {};
	for ( const c of classes ) materialLib[ c ] = M[ c ];
	const jsonCases = [
		[ 'standard', () => {

			const m = new M.MeshStandardNodeMaterial();
			m.name = 'std'; m.roughness = 0.25; m.color.setHex( 0x123456 );
			m.colorNode = T.uniform( new THREE.Color( 0xff0000 ) );
			m.opacityNode = T.float( 0.5 );
			m.roughnessNode = T.uniform( 0.75 );
			return m;

		} ],
		[ 'physical', () => {

			const m = new M.MeshPhysicalNodeMaterial();
			m.clearcoat = 1; m.sheenColor.setHex( 0x00ff00 );
			m.clearcoatNode = T.float( 0.25 );
			m.map = new THREE.Texture();
			m.emissiveNode = T.texture( m.map );
			return m;

		} ],
		[ 'basic_empty', () => new M.MeshBasicNodeMaterial() ],
		[ 'line_dashed', () => {

			const m = new M.LineDashedNodeMaterial();
			m.dashOffset = 3; m.dashSizeNode = T.float( 2 );
			return m;

		} ],
		[ 'points', () => {

			const m = new M.PointsNodeMaterial();
			m.sizeNode = T.uniform( 4 ); m.size = 2;
			return m;

		} ],
	];
	for ( const [ name, make ] of jsonCases ) {

		const material = make();
		const json = material.toJSON();
		const first = normalize( json );
		const textures = {};
		for ( const t of json.textures || [] ) {

			const tex = new THREE.Texture();
			tex.uuid = t.uuid;
			textures[ t.uuid ] = tex;

		}

		// r187's NodeLoader assigns `node.uuid`, which only has a getter: parsing any
		// node throws (both sides record the error)
		try {

			const nodeLoader = new NodeLoader();
			nodeLoader.setNodes( nodeLib );
			nodeLoader.setTextures( textures );
			const nodes = nodeLoader.parseNodes( json.nodes );
			const loader = new NodeMaterialLoader();
			loader.setTextures( textures );
			loader.setNodes( nodes );
			loader.setNodeMaterials( materialLib );
			const parsed = loader.parse( json );
			const second = normalize( parsed.toJSON() );
			records[ 'g5_json_' + name ] = { code: first, result: second, vars: parsed.type + ',' + Object.keys( nodes ).length };

		} catch ( e ) {

			records[ 'g5_json_' + name ] = { code: first, result: String( e ), vars: '' };

		}

	}

	{

		// a scene through NodeObjectLoader
		const m = new M.MeshPhongNodeMaterial();
		m.colorNode = T.uniform( new THREE.Color( 0x00ff00 ) );
		m.shininessNode = T.float( 8 );
		const mesh = new THREE.Mesh( new THREE.BoxGeometry(), m );
		mesh.name = 'box';
		const scene = new THREE.Scene();
		scene.add( mesh );
		const json = scene.toJSON();
		const loader = new NodeObjectLoader();
		loader.setNodes( nodeLib );
		loader.setNodeMaterials( materialLib );
		let result;
		try {

			const parsed = loader.parse( json );
			result = normalize( parsed.toJSON() );

		} catch ( e ) {

			result = String( e );

		}

		records.g5_json_object_loader = { code: normalize( json ), result };
		// a scene whose node material has no node slots parses
		const plain = new THREE.Scene();
		plain.add( new THREE.Mesh( new THREE.BoxGeometry(), new M.MeshToonNodeMaterial() ) );
		const plainJson = plain.toJSON();
		const plainParsed = loader.parse( plainJson );
		records.g5_json_object_loader_plain = { code: normalize( plainJson ), result: normalize( plainParsed.toJSON() ), vars: plainParsed.children[ 0 ].material.type };

	}

	Object.assign( records, await observerRecords( src, THREE, T, N ) );
	return records;

}

// NodeMaterialObserver.needsRefresh sequences on a render object built with the
// renderer data classes (G7's stub modules: NodeManager, Geometries, Attributes).
async function observerRecords( src, THREE, T, N ) {

	const imp = async ( p ) => ( await import( src + '/' + p ) ).default;
	const RenderObject = await imp( 'renderers/common/RenderObject.js' );
	const RenderContext = await imp( 'renderers/common/RenderContext.js' );
	const NodeManager = await imp( 'renderers/common/nodes/NodeManager.js' );
	const Geometries = await imp( 'renderers/common/Geometries.js' );
	const Attributes = await imp( 'renderers/common/Attributes.js' );
	const Info = await imp( 'renderers/common/Info.js' );
	const NodeBuilder = await imp( 'nodes/core/NodeBuilder.js' );
	const NodeFrame = await imp( 'nodes/core/NodeFrame.js' );
	const NodeMaterialObserver = await imp( 'materials/nodes/manager/NodeMaterialObserver.js' );
	const canvas = { style: {}, width: 300, height: 150, addEventListener() {}, removeEventListener() {}, getContext() { return null; } };
	const records = {};

	const run = ( name, makeMaterial, makeObject, steps ) => {

		const renderer = new THREE.WebGPURenderer( { canvas } );
		renderer._bindings = undefined;
		const outputTarget = new THREE.RenderTarget( 8, 8 );
		renderer._outputRenderTarget = outputTarget;
		const info = new Info();
		const nodes = new NodeManager( renderer, renderer.backend );
		const attributes = new Attributes( renderer.backend );
		const geometries = new Geometries( attributes, info );
		const material = makeMaterial();
		const object = makeObject( material );
		const scene = new THREE.Scene();
		const camera = new THREE.PerspectiveCamera();
		const lights = [];
		const lightsNode = new N.LightsNode();
		const context = new RenderContext();
		context.width = 8; context.height = 8;
		const ro = new RenderObject( nodes, geometries, renderer, object, material, scene, camera, lightsNode, context, null );
		const builder = new NodeBuilder( object, renderer );
		const observer = new NodeMaterialObserver( builder );
		const frame = new NodeFrame();
		frame.renderer = renderer;
		const log = [ 'hasNode=' + observer.hasNode ];
		const env = { renderer, material, object, scene, lights, lightsNode, context, frame, outputTarget, THREE };
		let renderId = 0;
		for ( const step of steps ) {

			if ( step !== null ) step( env );
			frame.renderId = renderId ++;
			log.push( observer.needsRefresh( ro, frame ) );

		}

		records[ 'g5_observer_' + name ] = { code: log.join( ',' ) };

	};

	const M = THREE;
	// RenderObject.getMaterialCacheKey for each class (G7's key order and the class
	// getters), and variants that change class properties
	const keyOf = ( material ) => {

		const renderer = new THREE.WebGPURenderer( { canvas } );
		renderer._bindings = undefined;
		const info = new Info();
		const nodes = new NodeManager( renderer, renderer.backend );
		const geometries = new Geometries( new Attributes( renderer.backend ), info );
		const ro = new RenderObject( nodes, geometries, renderer, new THREE.Mesh( new THREE.BoxGeometry(), material ), material, new THREE.Scene(), new THREE.PerspectiveCamera(), new N.LightsNode(), new RenderContext(), null );
		return String( ro.getMaterialCacheKey() );

	};

	const keyClasses = [ 'NodeMaterial', 'LineBasicNodeMaterial', 'LineDashedNodeMaterial', 'Line2NodeMaterial', 'MeshNormalNodeMaterial', 'MeshBasicNodeMaterial', 'MeshLambertNodeMaterial', 'MeshPhongNodeMaterial', 'MeshStandardNodeMaterial', 'MeshPhysicalNodeMaterial', 'MeshToonNodeMaterial', 'MeshMatcapNodeMaterial', 'PointsNodeMaterial', 'SpriteNodeMaterial', 'ShadowNodeMaterial', 'VolumeNodeMaterial' ];
	for ( const c of keyClasses ) records[ 'g5_key_material_' + c ] = { code: keyOf( new M[ c ]() ) };
	const variant = ( name, make ) => { records[ 'g5_key_material_' + name ] = { code: keyOf( make() ) }; };
	variant( 'physical_features', () => { const m = new M.MeshPhysicalNodeMaterial(); m.clearcoat = 1; m.sheen = 0.5; m.transmission = 0.2; m.map = new THREE.Texture(); return m; } );
	variant( 'line2_options', () => { const m = new M.Line2NodeMaterial( { dashed: true, vertexColors: true } ); m.worldUnits = true; m.alphaToCoverage = false; m.dashOffset = 1; return m; } );
	variant( 'points_options', () => { const m = new M.PointsNodeMaterial(); m.sizeAttenuation = false; m.alphaToCoverage = true; return m; } );
	variant( 'volume_steps', () => { const m = new M.VolumeNodeMaterial(); m.steps = 0; return m; } );
	variant( 'standard_maps', () => { const m = new M.MeshStandardNodeMaterial(); m.map = new THREE.Texture(); m.normalMap = new THREE.Texture(); m.flatShading = true; return m; } );
	const basic = () => new M.MeshBasicMaterial();
	const mesh = ( m ) => new THREE.Mesh( new THREE.BoxGeometry(), m );
	const same = null;
	run( 'static_sequence', () => new M.MeshStandardNodeMaterial(), mesh, [ same, same, same, ( e ) => { e.frame.renderId = 0; }, same ] );
	run( 'material_changes', () => new M.MeshStandardNodeMaterial(), mesh, [ same, same, ( e ) => { e.material.roughness = 0.5; }, same, ( e ) => { e.material.color.setHex( 0xff0000 ); }, same, ( e ) => { e.material.map = new THREE.Texture(); }, same, ( e ) => { e.material.map.version ++; }, same, ( e ) => { e.material.map.offset.set( 0.5, 0 ); }, same, ( e ) => { e.material.map = null; }, same ] );
	run( 'world_matrix', () => new M.MeshBasicNodeMaterial(), mesh, [ same, same, ( e ) => { e.object.position.x = 2; e.object.updateMatrixWorld( true ); }, same ] );
	run( 'geometry_changes', () => new M.MeshBasicNodeMaterial(), mesh, [ same, same, ( e ) => { e.object.geometry.attributes.position.needsUpdate = true; }, same, ( e ) => { e.object.geometry.setDrawRange( 0, 6 ); }, same, ( e ) => { e.object.geometry.deleteAttribute( 'uv' ); }, same ] );
	run( 'output_target_resize', () => new M.MeshBasicNodeMaterial(), mesh, [ same, same, ( e ) => { e.context.width = 16; }, same, ( e ) => { e.renderer._renderTarget = new THREE.RenderTarget( 2, 2 ); }, same, same ] );
	run( 'node_material_with_node', () => {

		const m = new M.MeshBasicNodeMaterial();
		m.colorNode = T.float( 1 );
		return m;

	}, mesh, [ same, same ] );
	run( 'skinned', () => new M.MeshBasicNodeMaterial(), ( m ) => {

		const g = new THREE.BoxGeometry();
		const bones = [ new THREE.Bone() ];
		const s = new THREE.SkinnedMesh( g, m );
		s.add( bones[ 0 ] );
		s.bind( new THREE.Skeleton( bones ) );
		return s;

	}, [ same, same ] );
	run( 'instanced', () => new M.MeshBasicNodeMaterial(), ( m ) => new THREE.InstancedMesh( new THREE.BoxGeometry(), m, 2 ), [ same, same, ( e ) => { e.object.instanceMatrix.needsUpdate = true; }, same, ( e ) => { e.object.setColorAt( 0, new THREE.Color( 1, 0, 0 ) ); }, same ] );
	run( 'instanced_dynamic', () => new M.MeshBasicNodeMaterial(), ( m ) => {

		const i = new THREE.InstancedMesh( new THREE.BoxGeometry(), m, 2 );
		i.instanceMatrix.setUsage( THREE.DynamicDrawUsage );
		return i;

	}, [ same, same ] );
	run( 'morph', () => new M.MeshBasicNodeMaterial(), ( m ) => {

		const g = new THREE.BoxGeometry();
		g.morphAttributes.position = [ g.attributes.position.clone() ];
		const o = new THREE.Mesh( g, m );
		o.updateMorphTargets();
		return o;

	}, [ same, same, ( e ) => { e.object.morphTargetInfluences[ 0 ] = 0.5; }, same ] );
	run( 'sprite_center', () => new M.SpriteNodeMaterial(), ( m ) => new THREE.Sprite( m ), [ same, same, ( e ) => { e.object.center.set( 0, 0 ); }, same ] );
	run( 'static_object', () => new M.MeshBasicNodeMaterial(), mesh, [ same, ( e ) => { e.object.static = true; e.material.opacity = 0.5; }, same, ( e ) => { e.renderer._renderTarget = new THREE.RenderTarget( 2, 2 ); }, same ] );
	run( 'environment', () => new M.MeshStandardNodeMaterial(), mesh, [ ( e ) => { e.scene.environment = new THREE.Texture(); }, same, ( e ) => { e.scene.environmentIntensity = 2; }, same, ( e ) => { e.scene.environmentRotation.y = 1; }, same, ( e ) => { e.scene.environment.dispatchEvent( { type: 'dispose' } ); }, same ] );
	run( 'line_dashed', () => new M.LineDashedNodeMaterial(), ( m ) => new THREE.Line( new THREE.BufferGeometry().setFromPoints( [ new THREE.Vector3(), new THREE.Vector3( 1, 0, 0 ) ] ), m ), [ same, same, ( e ) => { e.material.dashOffset = 2; }, same, ( e ) => { e.material.linewidth = 3; }, same ] );
	run( 'volume_steps', () => new M.VolumeNodeMaterial(), mesh, [ same, same, ( e ) => { e.material.steps = 10; }, same ] );
	run( 'physical', () => new M.MeshPhysicalNodeMaterial(), mesh, [ same, same, ( e ) => { e.material.clearcoat = 1; }, same, ( e ) => { e.material.sheenColor.setHex( 0xff0000 ); }, same, ( e ) => { e.material.clearcoatMap = new THREE.Texture(); }, same ] );
	run( 'lights', () => new M.MeshStandardNodeMaterial(), mesh, [ ( e ) => {

		const s = new THREE.SpotLight();
		s.map = new THREE.Texture();
		const d = new THREE.DirectionalLight();
		d.castShadow = true;
		e.lightsNode.setLights( [ s, d ] );
		e.spot = s; e.dir = d;

	}, same, ( e ) => { e.spot.map.version ++; }, same, ( e ) => { e.dir.shadow.mapSize.set( 1024, 1024 ); }, same, same ] );

	return records;

}
