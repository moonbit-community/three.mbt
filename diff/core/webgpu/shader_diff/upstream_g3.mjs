// Upstream side of the G3 (nodes/lighting, nodes/functions, nodes/pmrem,
// nodes/materialx) shader scenarios. The MoonBit side is
// src/nodes/g3_shader_diff_test.mbt; scenario names start with `g3_`.
//
// Both sides build with `G3Builder`, a NodeBuilder subclass whose `buildFunctionCode`
// writes a layout function in a WGSL-like form (as G1Builder does), whose `getTernary`
// prints a `select`, and whose texture methods print their arguments (`-` for
// null/undefined), with the WebGPU renderer stub. Records add `codes` (the layout
// functions the build registered).

// @@G3 shared begin (copied verbatim into the MoonBit file, as G1 does)
const g3ParseFunction = ( source ) => {

	const m = /^fn (\w+)\( (.*?) \) -> (\w+) \{/.exec( source );
	const inputs = m[ 2 ] === '' ? [] : m[ 2 ].split( ', ' ).map( ( p ) => p.split( ' : ' ) );
	return [ m[ 1 ], m[ 3 ], inputs ];

};

const g3FunctionCode = ( source, name, newName ) => source.replace( 'fn ' + name + '(', 'fn ' + newName + '(' );
// @@G3 shared end

const fmt = ( v ) => v === null || v === undefined ? '-' : Array.isArray( v ) ? '[' + v.map( fmt ).join( ',' ) + ']' : String( v );

export async function runUpstream( src ) {

	const T = await import( src + '/Three.TSL.js' );
	const THREE = await import( src + '/Three.WebGPU.js' );
	const { default: NodeBuilder } = await import( src + '/nodes/core/NodeBuilder.js' );
	const { WebGPURenderer } = THREE;
	const { default: NodeFunction } = await import( src + '/nodes/core/NodeFunction.js' );
	const { default: NodeFunctionInput } = await import( src + '/nodes/core/NodeFunctionInput.js' );
	const { default: NodeParser } = await import( src + '/nodes/core/NodeParser.js' );

	class G3Function extends NodeFunction {

		constructor( source ) {

			const [ name, type, params ] = g3ParseFunction( source );
			super( type, params.map( ( [ n, t ] ) => new NodeFunctionInput( t, n ) ), name );
			this.source = source;

		}

		getCode( name = this.name ) {

			return g3FunctionCode( this.source, this.name, name );

		}

	}

	class G3Parser extends NodeParser {

		parseFunction( source ) {

			return new G3Function( source );

		}

	}
	const imp = async ( p ) => import( src + '/nodes/' + p );

	const { default: D_GGX } = await imp( 'functions/BSDF/D_GGX.js' );
	const { default: D_GGX_Anisotropic } = await imp( 'functions/BSDF/D_GGX_Anisotropic.js' );
	const { default: V_GGX_SmithCorrelated } = await imp( 'functions/BSDF/V_GGX_SmithCorrelated.js' );
	const { default: V_GGX_SmithCorrelated_Anisotropic } = await imp( 'functions/BSDF/V_GGX_SmithCorrelated_Anisotropic.js' );
	const { default: F_Schlick } = await imp( 'functions/BSDF/F_Schlick.js' );
	const { default: Schlick_to_F0 } = await imp( 'functions/BSDF/Schlick_to_F0.js' );
	const { default: BRDF_Lambert } = await imp( 'functions/BSDF/BRDF_Lambert.js' );
	const { LTC_Uv, LTC_Evaluate, LTC_Evaluate_Volume } = await imp( 'functions/BSDF/LTC.js' );
	const { getDistanceAttenuation } = await imp( 'lighting/LightUtils.js' );
	const { default: getAlphaHashThreshold } = await imp( 'functions/material/getAlphaHashThreshold.js' );
	const { default: getShIrradianceAt } = await imp( 'functions/material/getShIrradianceAt.js' );
	const MXN = await imp( 'materialx/MaterialXNoise.js' );
	const MXC = await imp( 'materialx/MaterialXColor.js' );
	const { mx_srgb_texture_to_lin_rec709 } = await imp( 'materialx/MaterialXColorTransform.js' );

	class G3Builder extends NodeBuilder {

		constructor( object, renderer ) {

			super( object, renderer, new G3Parser() );

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

		generateTextureCompare( texture, p, uv, compare, depth, offset ) {

			return `texCompare(${ p }, ${ uv }, ${ compare }, ${ fmt( depth ) }, ${ fmt( offset ) })`;

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

	}

	// A renderer per scenario: NodeBuilder caches layout functions per backend, which would
	// make the function code a scenario registers depend on the scenarios before it.
	const canvas = { style: {}, width: 300, height: 150, addEventListener() {}, removeEventListener() {}, getContext() { return null; } };
	const newRenderer = () => {

		const renderer = new WebGPURenderer( { canvas } );
		renderer._bindings = undefined;
		return renderer;

	};

	const { float, int, uint, vec2, vec3, vec4, mat3, array } = T;
	const fv = ( v ) => float( v ).toVar();
	const v2 = ( a, b ) => vec2( a, b ).toVar();
	const v3 = ( a, b, c ) => vec3( a, b, c ).toVar();

	// [ name, make ]
	const scenarios = [];
	const add = ( name, make ) => scenarios.push( [ 'g3_' + name, make ] );

	// --- BSDF
	add( 'd_ggx', () => D_GGX( { alpha: fv( 0.25 ), dotNH: fv( 0.75 ) } ) );
	add( 'd_ggx_anisotropic', () => D_GGX_Anisotropic( { alphaT: fv( 0.3 ), alphaB: fv( 0.2 ), dotNH: fv( 0.9 ), dotTH: fv( 0.1 ), dotBH: fv( 0.2 ) } ) );
	add( 'v_ggx_smith_correlated', () => V_GGX_SmithCorrelated( { alpha: fv( 0.25 ), dotNL: fv( 0.5 ), dotNV: fv( 0.6 ) } ) );
	add( 'v_ggx_smith_correlated_anisotropic', () => V_GGX_SmithCorrelated_Anisotropic( { alphaT: fv( 0.3 ), alphaB: fv( 0.2 ), dotTV: fv( 0.1 ), dotBV: fv( 0.2 ), dotTL: fv( 0.3 ), dotBL: fv( 0.4 ), dotNV: fv( 0.5 ), dotNL: fv( 0.6 ) } ) );
	add( 'f_schlick', () => F_Schlick( { f0: v3( 0.04, 0.04, 0.04 ), f90: fv( 1 ), dotVH: fv( 0.5 ) } ) );
	add( 'f_schlick_numbers', () => F_Schlick( { f0: vec3( 0.04 ), f90: 1.0, dotVH: fv( 0.5 ) } ) );
	add( 'schlick_to_f0', () => Schlick_to_F0( { f: v3( 0.1, 0.2, 0.3 ), f90: 1.0, dotVH: fv( 0.5 ) } ) );
	add( 'brdf_lambert', () => BRDF_Lambert( { diffuseColor: v3( 1, 0.5, 0.25 ) } ) );
	add( 'ltc_uv', () => LTC_Uv( { N: v3( 0, 0, 1 ), V: v3( 0, 1, 0 ), roughness: fv( 0.5 ) } ) );
	add( 'ltc_evaluate', () => LTC_Evaluate( { N: v3( 0, 0, 1 ), V: v3( 0, 1, 0 ), P: v3( 0, 0, 0 ), mInv: mat3( 1, 0, 0, 0, 1, 0, 0, 0, 1 ), p0: v3( 1, 1, 1 ), p1: v3( - 1, 1, 1 ), p2: v3( - 1, - 1, 1 ), p3: v3( 1, - 1, 1 ) } ) );
	add( 'ltc_evaluate_volume', () => LTC_Evaluate_Volume( { P: v3( 0, 0, 0 ), p0: v3( 1, 1, 1 ), p1: v3( - 1, 1, 1 ), p2: v3( - 1, - 1, 1 ), p3: v3( 1, - 1, 1 ) } ) );
	add( 'ltc_evaluate_twice', () => LTC_Evaluate( { N: v3( 0, 0, 1 ), V: v3( 0, 1, 0 ), P: v3( 0, 0, 0 ), mInv: mat3( 1, 0, 0, 0, 1, 0, 0, 0, 1 ), p0: v3( 1, 1, 1 ), p1: v3( - 1, 1, 1 ), p2: v3( - 1, - 1, 1 ), p3: v3( 1, - 1, 1 ) } ).add( LTC_Evaluate_Volume( { P: v3( 0, 0, 0 ), p0: v3( 1, 1, 1 ), p1: v3( - 1, 1, 1 ), p2: v3( - 1, - 1, 1 ), p3: v3( 1, - 1, 1 ) } ) ) );

	// --- LightUtils, functions/material
	add( 'distance_attenuation', () => getDistanceAttenuation( { lightDistance: fv( 3 ), cutoffDistance: fv( 10 ), decayExponent: fv( 2 ) } ) );
	add( 'alpha_hash_threshold', () => getAlphaHashThreshold( v3( 1, 2, 3 ) ) );
	add( 'sh_irradiance_at', () => getShIrradianceAt( v3( 0, 1, 0 ), array( [ vec3( 1 ), vec3( 2 ), vec3( 3 ), vec3( 4 ), vec3( 5 ), vec3( 6 ), vec3( 7 ), vec3( 8 ), vec3( 9 ) ] ).toVar() ) );

	// --- MaterialX
	add( 'mx_perlin_noise_float_2d', () => MXN.mx_perlin_noise_float( v2( 0.5, 0.25 ) ) );
	add( 'mx_perlin_noise_float_3d', () => MXN.mx_perlin_noise_float( v3( 0.5, 0.25, 0.125 ) ) );
	add( 'mx_perlin_noise_vec3_3d', () => MXN.mx_perlin_noise_vec3( v3( 0.5, 0.25, 0.125 ) ) );
	add( 'mx_cell_noise_float_2d', () => MXN.mx_cell_noise_float( v2( 0.5, 0.25 ) ) );
	add( 'mx_cell_noise_vec3_3d', () => MXN.mx_cell_noise_vec3( v3( 0.5, 0.25, 0.125 ) ) );
	add( 'mx_fractal_noise_float', () => MXN.mx_fractal_noise_float( v3( 0.5, 0.25, 0.125 ), int( 3 ).toVar(), fv( 2 ), fv( 0.5 ) ) );
	add( 'mx_fractal_noise_vec4', () => MXN.mx_fractal_noise_vec4( v3( 0.5, 0.25, 0.125 ), int( 3 ).toVar(), fv( 2 ), fv( 0.5 ) ) );
	add( 'mx_worley_noise_float_2d', () => MXN.mx_worley_noise_float( v2( 0.5, 0.25 ), fv( 1 ), int( 0 ).toVar() ) );
	add( 'mx_worley_noise_vec3_3d', () => MXN.mx_worley_noise_vec3( v3( 0.5, 0.25, 0.125 ), fv( 1 ), int( 0 ).toVar() ) );
	add( 'mx_unifiednoise2d', () => MXN.mx_unifiednoise2d( int( 1 ).toVar(), v2( 0.5, 0.25 ), v2( 1, 1 ), v2( 0, 0 ), fv( 1 ), fv( 0 ), fv( 1 ), fv( 0 ), int( 3 ).toVar(), fv( 2 ), fv( 0.5 ), int( 0 ).toVar() ) );
	add( 'mx_unifiednoise3d', () => MXN.mx_unifiednoise3d( int( 2 ).toVar(), v3( 0.5, 0.25, 0.125 ), v3( 1, 1, 1 ), v3( 0, 0, 0 ), fv( 1 ), fv( 0 ), fv( 1 ), fv( 0 ), int( 3 ).toVar(), fv( 2 ), fv( 0.5 ), int( 0 ).toVar() ) );
	add( 'mx_hsvtorgb', () => MXC.mx_hsvtorgb( v3( 0.5, 0.25, 0.75 ) ) );
	add( 'mx_rgbtohsv', () => MXC.mx_rgbtohsv( v3( 0.5, 0.25, 0.75 ) ) );
	add( 'mx_srgb_texture_to_lin_rec709', () => mx_srgb_texture_to_lin_rec709( v3( 0.5, 0.25, 0.75 ) ) );

	// --- Lights and lighting models. A `lit` scenario builds `lightingContext( lightsNode,
	// lightingModel, materialLightings )` as NodeMaterial.setupLights does, for a mesh with
	// every attribute, a perspective camera, the given material and the context callbacks
	// a node material sets (as G2's `materialContext`).
	const N = await imp( 'Nodes.js' );
	const { LightsNode, lightingContext } = { LightsNode: N.LightsNode, lightingContext: ( await imp( 'lighting/LightingContextNode.js' ) ).lightingContext };
	const { default: BasicLightingModel } = await imp( 'functions/BasicLightingModel.js' );
	const { default: PhongLightingModel } = await imp( 'functions/PhongLightingModel.js' );
	const { default: ToonLightingModel } = await imp( 'functions/ToonLightingModel.js' );
	const { default: PhysicalLightingModel } = await imp( 'functions/PhysicalLightingModel.js' );
	const { default: ShadowMaskModel } = await imp( 'functions/ShadowMaskModel.js' );

	const geometry = new THREE.BufferGeometry();
	for ( const [ name, itemSize ] of [ [ 'position', 3 ], [ 'normal', 3 ], [ 'uv', 2 ], [ 'uv1', 2 ], [ 'tangent', 4 ], [ 'color', 4 ] ] ) {

		geometry.setAttribute( name, new THREE.BufferAttribute( new Float32Array( 24 * itemSize ), itemSize ) );

	}

	const materialContext = ( builder ) => {

		builder.context.setupPositionView = () => T.modelViewMatrix.mul( T.positionLocal ).xyz;
		builder.context.setupModelViewProjection = () => T.cameraProjectionMatrix.mul( T.positionView );
		builder.context.setupNormal = () => T.subBuild( T.normalViewGeometry, 'NORMAL', 'vec3' );
		builder.context.setupClearcoatNormal = () => T.subBuild( T.normalViewGeometry, 'NORMAL', 'vec3' );
		builder.context.clipSpace = T.vec4( 1, 2, 3, 1 );

	};

	const tex = ( name ) => {

		const t = new THREE.Texture();
		t.name = name;
		return t;

	};

	N.RectAreaLightNode.setLTC( { LTC_FLOAT_1: tex( 'ltc_float_1' ), LTC_FLOAT_2: tex( 'ltc_float_2' ), LTC_HALF_1: tex( 'ltc_half_1' ), LTC_HALF_2: tex( 'ltc_half_2' ) } );

	const point = () => new THREE.PointLight( 0xff0000, 2, 10, 2 );
	const directional = () => new THREE.DirectionalLight( 0x00ff00, 3 );
	const spot = () => new THREE.SpotLight( 0x0000ff, 4, 20, Math.PI / 4, 0.5, 2 );
	const lit = [];
	const addLit = ( name, material, lights, model, { lightings = () => [], shadow = null } = {} ) => lit.push( [ 'g3_' + name, material, lights, model, lightings, shadow ] );
	const phong = () => new THREE.MeshPhongMaterial();
	const standard = () => new THREE.MeshStandardMaterial();

	addLit( 'lit_phong_point', phong, () => [ point() ], () => new PhongLightingModel() );
	addLit( 'lit_phong_directional_spot', phong, () => [ directional(), spot() ], () => new PhongLightingModel() );
	addLit( 'lit_lambert_directional', () => new THREE.MeshLambertMaterial(), () => [ directional() ], () => new PhongLightingModel( false ) );
	addLit( 'lit_basic_ambient', () => new THREE.MeshBasicMaterial(), () => [ new THREE.AmbientLight( 0x404040, 2 ) ], () => new BasicLightingModel() );
	addLit( 'lit_basic_none', () => new THREE.MeshBasicMaterial(), () => [], () => new BasicLightingModel() );
	addLit( 'lit_toon_point', () => new THREE.MeshToonMaterial(), () => [ point() ], () => new ToonLightingModel() );
	addLit( 'lit_toon_gradient', () => {

		const m = new THREE.MeshToonMaterial();
		m.gradientMap = tex( 'gradient' );
		return m;

	}, () => [ directional() ], () => new ToonLightingModel() );
	addLit( 'lit_physical_point', standard, () => [ point() ], () => new PhysicalLightingModel() );
	addLit( 'lit_physical_all_lights', standard, () => [ point(), directional(), spot(), new THREE.HemisphereLight( 0xffffff, 0x444444, 1 ), new THREE.AmbientLight( 0x404040, 1 ), new THREE.LightProbe() ], () => new PhysicalLightingModel() );
	addLit( 'lit_physical_counts', standard, () => [ point(), point(), point(), directional(), directional() ], () => new PhysicalLightingModel() );
	addLit( 'lit_physical_features', () => new THREE.MeshPhysicalMaterial(), () => [ directional() ], () => new PhysicalLightingModel( true, true, true, true ) );
	addLit( 'lit_physical_retro_eon', () => new THREE.MeshPhysicalMaterial(), () => [ point() ], () => new PhysicalLightingModel( false, false, false, false, false, false, true, true ) );
	addLit( 'lit_physical_rect_area', standard, () => [ new THREE.RectAreaLight( 0xffffff, 5, 4, 2 ) ], () => new PhysicalLightingModel() );
	addLit( 'lit_physical_rect_area_clearcoat', () => new THREE.MeshPhysicalMaterial(), () => [ new THREE.RectAreaLight( 0xffffff, 5, 4, 2 ) ], () => new PhysicalLightingModel( true ) );
	addLit( 'lit_hemisphere', phong, () => [ new THREE.HemisphereLight( 0xffffff, 0x444444, 1 ) ], () => new PhongLightingModel() );
	addLit( 'lit_light_probe', standard, () => [ new THREE.LightProbe() ], () => new PhysicalLightingModel() );
	addLit( 'lit_spot_map', standard, () => {

		const s = spot();
		s.map = tex( 'spot_map' );
		return [ s ];

	}, () => new PhysicalLightingModel() );
	addLit( 'lit_ies_spot', standard, () => {

		const s = new THREE.IESSpotLight( 0xffffff, 2, 10, 0.5 );
		s.iesMap = tex( 'ies' );
		return [ s ];

	}, () => new PhysicalLightingModel() );
	addLit( 'lit_projector', standard, () => [ new THREE.ProjectorLight( 0xffffff, 2, 10, 0.5 ) ], () => new PhysicalLightingModel() );
	addLit( 'lit_shadow_mask', standard, () => [ point(), directional() ], () => new ShadowMaskModel() );
	addLit( 'lit_material_lightings', phong, () => [ point() ], () => new PhongLightingModel(), { lightings: () => [ new N.AONode( float( 0.5 ).toVar() ), new N.IrradianceNode( vec3( 0.1, 0.2, 0.3 ).toVar() ) ] } );
	addLit( 'lit_basic_light_map', () => new THREE.MeshBasicMaterial(), () => [], () => new BasicLightingModel(), { lightings: () => [ new N.BasicLightMapNode( vec3( 0.5, 0.5, 0.5 ).toVar() ) ] } );


	// --- Shadows: the renderer has shadow maps enabled with `shadow.type` (and
	// `transmitted`), the lights cast shadows and the mesh receives them.
	const { BasicShadowFilter } = await imp( 'lighting/ShadowFilterNode.js' );
	const casting = ( make ) => () => make().map( ( l ) => {

		l.castShadow = true;
		return l;

	} );
	const BASIC = 0, PCF = 1, VSM = 3;
	addLit( 'shadow_directional_basic', phong, casting( () => [ directional() ] ), () => new PhongLightingModel(), { shadow: { type: BASIC } } );
	addLit( 'shadow_directional_pcf', phong, casting( () => [ directional() ] ), () => new PhongLightingModel(), { shadow: { type: PCF } } );
	addLit( 'shadow_directional_vsm', phong, casting( () => [ directional() ] ), () => new PhongLightingModel(), { shadow: { type: VSM } } );
	addLit( 'shadow_spot_pcf', standard, casting( () => [ spot() ] ), () => new PhysicalLightingModel(), { shadow: { type: PCF } } );
	addLit( 'shadow_point_basic', phong, casting( () => [ point() ] ), () => new PhongLightingModel(), { shadow: { type: BASIC } } );
	addLit( 'shadow_point_pcf', standard, casting( () => [ point() ] ), () => new PhysicalLightingModel(), { shadow: { type: PCF } } );
	addLit( 'shadow_point_vsm', phong, casting( () => [ point() ] ), () => new PhongLightingModel(), { shadow: { type: VSM } } );
	addLit( 'shadow_transmitted', phong, casting( () => [ directional() ] ), () => new PhongLightingModel(), { shadow: { type: PCF, transmitted: true } } );
	addLit( 'shadow_point_transmitted', phong, casting( () => [ point() ] ), () => new PhongLightingModel(), { shadow: { type: PCF, transmitted: true } } );
	addLit( 'shadow_bias_node', phong, casting( () => {

		const l = directional();
		l.shadow.biasNode = float( 0.001 ).toVar( 'customBias' );
		return [ l ];

	} ), () => new PhongLightingModel(), { shadow: { type: PCF } } );
	addLit( 'shadow_filter_node', phong, casting( () => {

		const l = spot();
		l.shadow.filterNode = BasicShadowFilter;
		return [ l ];

	} ), () => new PhongLightingModel(), { shadow: { type: PCF } } );
	addLit( 'shadow_custom_node', phong, casting( () => {

		const l = directional();
		l.shadow.shadowNode = float( 0.5 ).toVar( 'customShadow' );
		return [ l ];

	} ), () => new PhongLightingModel(), { shadow: { type: PCF } } );
	addLit( 'shadow_two_lights', standard, casting( () => [ directional(), point() ] ), () => new PhysicalLightingModel(), { shadow: { type: PCF } } );
	addLit( 'shadow_mask_shadowed', standard, casting( () => [ directional(), spot() ] ), () => new ShadowMaskModel(), { shadow: { type: PCF } } );
	addLit( 'shadow_disabled', phong, casting( () => [ directional() ] ), () => new PhongLightingModel() );


	// --- More lighting: volumetric, transmission, environments.
	const { default: VolumetricLightingModel } = await imp( 'functions/VolumetricLightingModel.js' );
	const cube = ( name, pmrem ) => {

		const t = new THREE.CubeTexture();
		t.name = name;
		if ( pmrem ) {

			t.isPMREMTexture = true;
			t.mipmaps = [ { width: 64, height: 64 } ];

		}

		return t;

	};

	const physical = () => new THREE.MeshPhysicalMaterial();
	addLit( 'lit_volumetric', () => new THREE.VolumeNodeMaterial(), () => [ point(), spot(), directional(), new THREE.RectAreaLight( 0xffffff, 5, 4, 2 ) ], () => new VolumetricLightingModel() );
	addLit( 'lit_physical_transmission', physical, () => [ point() ], () => new PhysicalLightingModel( false, false, false, false, true ) );
	addLit( 'lit_physical_dispersion', physical, () => [ point() ], () => new PhysicalLightingModel( false, false, false, false, true, true ) );
	addLit( 'lit_environment_pmrem', standard, () => [ point() ], () => new PhysicalLightingModel(), { lightings: () => [ new N.EnvironmentNode( T.cubeTexture( cube( 'env', true ) ) ) ] } );
	addLit( 'lit_environment_clearcoat', physical, () => [], () => new PhysicalLightingModel( true, true ), { lightings: () => [ new N.EnvironmentNode( T.cubeTexture( cube( 'env', true ) ) ) ] } );
	addLit( 'lit_environment_node', standard, () => [], () => new PhysicalLightingModel(), { lightings: () => [ new N.EnvironmentNode( vec3( 0.1, 0.2, 0.3 ).toVar() ) ] } );
	for ( const [ suffix, combine ] of [ [ 'multiply', THREE.MultiplyOperation ], [ 'mix', THREE.MixOperation ], [ 'add', THREE.AddOperation ] ] ) {

		addLit( 'lit_basic_environment_' + suffix, () => {

			const m = new THREE.MeshBasicMaterial();
			m.combine = combine;
			return m;

		}, () => [], () => new BasicLightingModel(), { lightings: () => [ new N.BasicEnvironmentNode( T.cubeTexture( cube( 'env' ) ) ) ] } );

	}

	// --- Functions that read accessors (built like the lit scenarios, without lights).
	const { default: BRDF_GGX } = await imp( 'functions/BSDF/BRDF_GGX.js' );
	const { default: BRDF_Sheen } = await imp( 'functions/BSDF/BRDF_Sheen.js' );
	const { default: BRDF_EON, EON_DirectionalAlbedo } = await imp( 'functions/BSDF/BRDF_EON.js' );
	const { default: EnvironmentBRDF } = await imp( 'functions/BSDF/EnvironmentBRDF.js' );
	const { default: DFGLUT } = await imp( 'functions/BSDF/DFGLUT.js' );
	const { default: getRoughness } = await imp( 'functions/material/getRoughness.js' );
	const { default: getGeometryRoughness } = await imp( 'functions/material/getGeometryRoughness.js' );
	const { default: getParallaxCorrectNormal } = await imp( 'functions/material/getParallaxCorrectNormal.js' );
	const PU = await imp( 'pmrem/PMREMUtils.js' );
	const MX = await imp( 'materialx/MaterialXNodes.js' );
	const geo = [];
	const addGeo = ( name, make ) => geo.push( [ 'g3_' + name, make ] );
	addGeo( 'brdf_ggx', () => BRDF_GGX( { lightDirection: v3( 0, 0, 1 ), f0: vec3( 0.04 ), f90: 1, roughness: fv( 0.5 ) } ) );
	addGeo( 'brdf_ggx_iridescence_anisotropy', () => BRDF_GGX( { lightDirection: v3( 0, 0, 1 ), f0: vec3( 0.04 ), f90: 1, roughness: fv( 0.5 ), f: v3( 0.1, 0.2, 0.3 ), USE_IRIDESCENCE: true, USE_ANISOTROPY: true } ) );
	addGeo( 'brdf_ggx_view_direction', () => BRDF_GGX( { lightDirection: v3( 0, 0, 1 ), viewDirection: v3( 0, 1, 0 ), normalView: v3( 1, 0, 0 ), f0: vec3( 0.04 ), f90: 1, roughness: fv( 0.5 ), USE_IRIDESCENCE: false } ) );
	addGeo( 'brdf_sheen', () => BRDF_Sheen( { lightDirection: v3( 0, 0, 1 ) } ) );
	addGeo( 'brdf_eon', () => BRDF_EON( { lightDirection: v3( 0, 0, 1 ), diffuseColor: v3( 1, 0.5, 0.25 ), roughness: fv( 0.5 ) } ) );
	addGeo( 'eon_directional_albedo', () => EON_DirectionalAlbedo( { diffuseColor: v3( 1, 0.5, 0.25 ), roughness: fv( 0.5 ), dotNV: fv( 0.7 ) } ) );
	addGeo( 'environment_brdf', () => EnvironmentBRDF( { dotNV: fv( 0.7 ), specularColor: v3( 0.04, 0.04, 0.04 ), specularF90: fv( 1 ), roughness: fv( 0.5 ) } ) );
	addGeo( 'dfglut', () => DFGLUT( { roughness: fv( 0.5 ), dotNV: fv( 0.7 ) } ) );
	addGeo( 'get_roughness', () => getRoughness( { roughness: fv( 0.3 ) } ) );
	addGeo( 'get_geometry_roughness', () => getGeometryRoughness() );
	addGeo( 'get_parallax_correct_normal', () => getParallaxCorrectNormal( v3( 0, 1, 0 ), v3( 10, 10, 10 ), v3( 0, 0, 0 ) ) );
	addGeo( 'pmrem_roughness_to_mip', () => PU.roughnessToMip( fv( 0.5 ), fv( 8 ) ) );
	addGeo( 'pmrem_spherical_gaussian_blur', () => PU.sphericalGaussianBlur( { SAMPLES: int( 20 ), sigma: fv( 0.2 ), direction: v3( 0, 0, 1 ), envMap: T.cubeTexture( cube( 'src' ) ) } ) );
	addGeo( 'pmrem_ggx_convolution', () => PU.ggxConvolution( { roughness: fv( 0.5 ), lodBias: fv( 1 ), envMap: T.cubeTexture( cube( 'src' ) ), direction: v3( 0, 0, 1 ), GGX_SAMPLES: uint( 64 ) } ) );
	addGeo( 'pmrem_ggx_integration', () => PU.ggxIntegration( { roughness: fv( 0.5 ), sourceLod: fv( 2 ), sourceSize: int( 8 ), envMap: T.cubeTexture( cube( 'src' ) ), direction: v3( 0, 0, 1 ) } ) );
	addGeo( 'pmrem_texture', () => N.PMREMNode ? T.pmremTexture( cube( 'env', true ), v3( 0, 0, 1 ), fv( 0.5 ) ) : null );
	addGeo( 'mx_noise_float', () => MX.mx_noise_float() );
	addGeo( 'mx_noise_vec3', () => MX.mx_noise_vec3( v2( 0.5, 0.25 ), 2, 0.5 ) );
	addGeo( 'mx_noise_vec4', () => MX.mx_noise_vec4() );
	addGeo( 'mx_cell_noise_float', () => MX.mx_cell_noise_float() );
	addGeo( 'mx_worley_noise_vec2', () => MX.mx_worley_noise_vec2() );
	addGeo( 'mx_worley_noise_vec3_style', () => MX.mx_worley_noise_vec3_style( v3( 0.5, 0.25, 0.125 ), 1, 1, 0 ) );
	addGeo( 'mx_fractal_noise_vec2', () => MX.mx_fractal_noise_vec2() );
	addGeo( 'mx_unifiednoise2d_defaults', () => MX.mx_unifiednoise2d( int( 2 ) ) );
	addGeo( 'mx_ramp4', () => MX.mx_ramp4( v3( 1, 0, 0 ), v3( 0, 1, 0 ), v3( 0, 0, 1 ), v3( 1, 1, 1 ) ) );
	addGeo( 'mx_splitlr', () => MX.mx_splitlr( fv( 0 ), fv( 1 ), fv( 0.5 ) ) );
	addGeo( 'mx_aastep', () => MX.mx_aastep( 0.5, fv( 0.25 ) ) );
	addGeo( 'mx_contrast_safepower', () => MX.mx_contrast( fv( 0.25 ), 2 ).add( MX.mx_safepower( fv( - 2 ), 3 ) ) );
	addGeo( 'mx_place2d', () => MX.mx_place2d( T.uv(), vec2( 0.5, 0.5 ), vec2( 2, 2 ), float( 45 ), vec2( 0.1, 0.2 ) ) );
	addGeo( 'mx_heighttonormal', () => MX.mx_heighttonormal( fv( 0.5 ) ) );
	addGeo( 'mx_math', () => MX.mx_modulo( fv( 5 ), fv( 2 ) ).add( MX.mx_atan2( fv( 1 ), fv( 2 ) ) ).add( MX.mx_ifgreater( fv( 1 ), fv( 2 ), fv( 3 ), fv( 4 ) ) ).add( MX.mx_invert( fv( 0.25 ) ) ) );
	addGeo( 'mx_transform_uv_smoothstep', () => MX.mx_transform_uv( 2, 0.5 ).x.add( MX.mx_smoothstep( fv( 0.25 ), 0, 1 ) ) );
	addGeo( 'mx_separate', () => MX.mx_separate( v3( 1, 2, 3 ), 'outy' ).add( MX.mx_separate( v3( 1, 2, 3 ), 2 ) ) );
	addGeo( 'mx_timer_frame', () => MX.mx_timer().add( MX.mx_frame() ) );
	const records = {};
	for ( const [ name, make ] of scenarios ) {

		const builder = new G3Builder( null, newRenderer() );
		builder.setShaderStage( 'fragment' );
		const flow = builder.flowStagesNode( make() );
		const uniforms = [];
		for ( const s of [ 'vertex', 'fragment', 'compute' ] ) {

			for ( const u of builder.uniforms[ s ] ) uniforms.push( `${s}:${u.name}:${u.type}` );

		}

		records[ name ] = { code: flow.code, result: typeof flow.result === 'string' ? flow.result : '', vars: flow.vars ?? '', uniforms, codes: builder.getCodes( 'fragment' ) };

	}

	for ( const [ name, make ] of geo ) {

		const object = new THREE.Mesh( geometry, new THREE.MeshStandardMaterial() );
		const builder = new G3Builder( object, newRenderer() );
		builder.camera = new THREE.PerspectiveCamera();
		materialContext( builder );
		builder.setShaderStage( 'fragment' );
		let flow;
		try {

			flow = builder.flowStagesNode( make() );

		} catch ( e ) {

			records[ name ] = { error: String( e ) };
			continue;

		}

		const uniforms = [];
		for ( const s of [ 'vertex', 'fragment', 'compute' ] ) {

			for ( const u of builder.uniforms[ s ] ) uniforms.push( `${s}:${u.name}:${u.type}` );

		}

		records[ name ] = { code: flow.code, result: typeof flow.result === 'string' ? flow.result : '', vars: flow.vars ?? '', uniforms, codes: builder.getCodes( 'fragment' ) };

	}

	for ( const [ name, makeMaterial, makeLights, makeModel, makeLightings, shadow ] of lit ) {

		const material = makeMaterial();
		const object = new THREE.Mesh( geometry, material );
		const renderer = newRenderer();
		if ( shadow !== null ) {

			renderer.shadowMap.enabled = true;
			renderer.shadowMap.type = shadow.type;
			renderer.shadowMap.transmitted = shadow.transmitted === true;
			renderer._initialized = true; // hasCompatibility() needs it
			object.receiveShadow = true;

		}

		const builder = new G3Builder( object, renderer );
		builder.camera = new THREE.PerspectiveCamera();
		materialContext( builder );
		builder.setShaderStage( 'fragment' );
		const lightsNode = new LightsNode().setLights( makeLights() );
		// as NodeMaterial.build does (VolumetricLightingModel starts the lights in a loop body,
		// built after LightsNode.setup has restored the builder's lights node)
		builder.lightsNode = lightsNode;
		let flow;
		try {

			flow = builder.flowStagesNode( lightingContext( lightsNode, makeModel(), makeLightings() ) );

		} catch ( e ) {

			records[ name ] = { error: String( e ) };
			continue;

		}

		const uniforms = [];
		for ( const s of [ 'vertex', 'fragment', 'compute' ] ) {

			for ( const u of builder.uniforms[ s ] ) uniforms.push( `${s}:${u.name}:${u.type}` );

		}

		records[ name ] = { code: flow.code, result: typeof flow.result === 'string' ? flow.result : '', vars: flow.vars ?? '', uniforms, codes: builder.getCodes( 'fragment' ) };

	}

	return records;

}
