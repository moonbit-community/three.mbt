// Upstream side of the G5 whole-material WGSL scenarios (`g5_wgsl_*`): a node material
// built by upstream's real WGSLNodeBuilder (`build()`: prebuild -> NodeMaterial.build ->
// the three stages -> buildCode), on a renderer made like upstream_g8.mjs's renderer `a`.
// The MoonBit side is src/renderers/webgpu/g5_material_shader_diff_test.mbt.
export async function runUpstream( src ) {

	const T = await import( src + '/Three.TSL.js' );
	const THREE = await import( src + '/Three.WebGPU.js' );
	const { default: WGSLNodeBuilder } = await import( src + '/renderers/webgpu/nodes/WGSLNodeBuilder.js' );
	const N = await import( src + '/nodes/Nodes.js' );
	const { WebGPURenderer } = THREE;
	if ( typeof globalThis.ImageBitmap === 'undefined' ) globalThis.ImageBitmap = class ImageBitmap {};
	const canvas = { style: {}, width: 300, height: 150, addEventListener() {}, removeEventListener() {}, getContext() { return null; } };
	const makeRenderer = () => {

		const r = new WebGPURenderer( { canvas } );
		r._bindings = undefined;
		r._initialized = true;
		r.backend.device = { features: new Set() };
		r.backend.compatibilityMode = false;
		r.backend.renderer = r;
		return r;

	};

	const bindingsOf = ( builder ) => builder.getBindings().map( ( g ) => g.name + '[' + g.bindings.map( ( b ) => b.name + ':' + b.visibility ).join( ',' ) + ']' ).join( ' ' );
	const attr = ( n, itemSize ) => new THREE.BufferAttribute( new Float32Array( n * itemSize ), itemSize );
	const geometry = new THREE.BufferGeometry();
	for ( const [ name, itemSize ] of [ [ 'position', 3 ], [ 'normal', 3 ], [ 'uv', 2 ], [ 'color', 4 ] ] ) geometry.setAttribute( name, attr( 24, itemSize ) );
	const lineGeometry = new THREE.BufferGeometry();
	for ( const [ name, itemSize ] of [ [ 'position', 3 ], [ 'lineDistance', 1 ] ] ) lineGeometry.setAttribute( name, attr( 4, itemSize ) );
	const line2Geometry = new THREE.BufferGeometry();
	for ( const [ name, itemSize ] of [ [ 'position', 3 ], [ 'uv', 2 ], [ 'instanceStart', 3 ], [ 'instanceEnd', 3 ], [ 'instanceDistanceStart', 1 ], [ 'instanceDistanceEnd', 1 ] ] ) line2Geometry.setAttribute( name, attr( 8, itemSize ) );
	const tex = ( name ) => {

		const t = new THREE.Texture();
		t.name = name;
		return t;

	};

	const point = () => new THREE.PointLight( 0xff0000, 2, 10, 2 );
	const directional = () => new THREE.DirectionalLight( 0x00ff00, 3 );
	const M = THREE;
	const scenarios = [];
	const add = ( name, material, options = {} ) => scenarios.push( [ 'g5_wgsl_' + name, material, options ] );
	const set = ( make, f ) => () => {

		const m = make();
		f( m );
		return m;

	};

	const lit = { lights: () => [ point() ] };
	add( 'node_material', () => new M.NodeMaterial() );
	add( 'basic', () => new M.MeshBasicNodeMaterial() );
	add( 'basic_map_alpha_test', set( () => new M.MeshBasicNodeMaterial(), ( m ) => { m.map = tex( 'map' ); m.alphaTest = 0.5; } ) );
	add( 'basic_transparent_fog', set( () => new M.MeshBasicNodeMaterial(), ( m ) => { m.transparent = true; m.premultipliedAlpha = true; } ), { fog: true } );
	add( 'basic_vertex_colors_nodes', set( () => new M.MeshBasicNodeMaterial(), ( m ) => { m.vertexColors = true; m.colorNode = T.vec3( 1, 0.5, 0 ); m.positionNode = T.positionLocal.mul( 2 ); } ) );
	add( 'basic_log_depth', () => new M.MeshBasicNodeMaterial(), { logarithmic: true } );
	add( 'lambert', () => new M.MeshLambertNodeMaterial(), lit );
	add( 'phong', () => new M.MeshPhongNodeMaterial(), lit );
	add( 'standard', () => new M.MeshStandardNodeMaterial(), lit );
	add( 'standard_maps', set( () => new M.MeshStandardNodeMaterial(), ( m ) => { m.map = tex( 'map' ); m.roughnessMap = tex( 'rough' ); m.normalMap = tex( 'normal' ); } ), { lights: () => [ point(), directional() ] } );
	add( 'physical', () => new M.MeshPhysicalNodeMaterial(), lit );
	add( 'physical_clearcoat_sheen', set( () => new M.MeshPhysicalNodeMaterial(), ( m ) => { m.clearcoat = 1; m.sheen = 1; m.iridescence = 1; } ), lit );
	add( 'sss', set( () => new M.MeshSSSNodeMaterial(), ( m ) => { m.thicknessColorNode = T.vec3( 0.5, 0.1, 0.1 ); } ), lit );
	add( 'toon', () => new M.MeshToonNodeMaterial(), lit );
	add( 'matcap', () => new M.MeshMatcapNodeMaterial() );
	add( 'normal', () => new M.MeshNormalNodeMaterial() );
	add( 'shadow', () => new M.ShadowNodeMaterial(), { lights: () => [ directional() ] } );
	add( 'volume', () => new M.VolumeNodeMaterial(), lit );
	add( 'line_basic', () => new M.LineBasicNodeMaterial(), { object: ( m ) => new THREE.Line( lineGeometry, m ) } );
	add( 'line_dashed', () => new M.LineDashedNodeMaterial(), { object: ( m ) => new THREE.Line( lineGeometry, m ) } );
	add( 'line2', () => new M.Line2NodeMaterial(), { object: ( m ) => new THREE.Mesh( line2Geometry, m ) } );
	add( 'line2_dashed_world_units', set( () => new M.Line2NodeMaterial( { dashed: true } ), ( m ) => { m.worldUnits = true; } ), { object: ( m ) => new THREE.Mesh( line2Geometry, m ) } );
	add( 'points', () => new M.PointsNodeMaterial(), { object: ( m ) => new THREE.Points( lineGeometry, m ) } );
	add( 'points_sprite', () => new M.PointsNodeMaterial(), { object: ( m ) => new THREE.Mesh( geometry, m ) } );
	add( 'sprite', () => new M.SpriteNodeMaterial(), { object: ( m ) => new THREE.Sprite( m ) } );
	add( 'from_core_standard', () => new M.MeshStandardMaterial(), lit );

	const records = {};
	for ( const [ name, makeMaterial, options ] of scenarios ) {

		const material = makeMaterial();
		const object = options.object ? options.object( material ) : new THREE.Mesh( geometry, material );
		const renderer = makeRenderer();
		renderer.logarithmicDepthBuffer = options.logarithmic === true;
		const builder = new WGSLNodeBuilder( object, renderer );
		builder.scene = new THREE.Scene();
		builder.camera = new THREE.PerspectiveCamera();
		builder.lightsNode = new N.LightsNode().setLights( options.lights ? options.lights() : [] );
		if ( options.fog ) builder.fogNode = T.fog( T.color( 0x8899aa ), T.rangeFogFactor( 1, 10 ) );
		try {

			builder.build();

		} catch ( e ) {

			records[ name ] = { error: String( e && e.message ) };
			continue;

		}

		records[ name ] = { shader: builder.vertexShader + '\n@@@@\n' + builder.fragmentShader, bindings: bindingsOf( builder ) };

	}

	return records;

}
