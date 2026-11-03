// node --import ./register.mjs upstream.mjs [name ...]: the upstream side of the
// WebGLNodesHandler scenarios, printed as `@@WEBGL_LOG <name> <json>` lines. Mirrors
// src/addons/tsl/a5_webgl_nodes_handler_test.mbt step for step.
import { createRequire } from 'node:module';
import { upstreamURL } from '../../../../lib/env.mjs';
const SRC = upstreamURL( 'src' );
if ( typeof globalThis.ImageBitmap === 'undefined' ) globalThis.ImageBitmap = class ImageBitmap {};
const TSL = await import( SRC + '/Three.TSL.js' );
const THREE = await import( SRC + '/Three.WebGPU.js' );
const { WebGLRenderer } = await import( SRC + '/Three.js' );
const { default: Node } = await import( SRC + '/nodes/core/Node.js' );
const { WebGLNodesHandler } = await import( upstreamURL( 'examples/jsm/tsl/WebGLNodesHandler.js' ) );
const require = createRequire( import.meta.url );
const { createGL, createMockCanvas } = require( './wnh_mock.cjs' );

const tick = () => new Promise( ( r ) => setTimeout( r, 0 ) );

function setup( k, { width = 64, height = 32, antialias = false } = {} ) {

	const gl = createGL( { canvas: { width, height } } );
	const canvas = createMockCanvas( gl, width, height );
	const renderer = new WebGLRenderer( { canvas, context: gl, antialias, outputBufferType: THREE.UnsignedByteType } );
	renderer.setNodesHandler( new WebGLNodesHandler() );
	align( k );
	gl.__note( 'setup', 'done' );
	return { gl, renderer };

}

function align( k ) {

	const advance = ( name, target, f ) => {

		let id = f();
		if ( id >= target ) throw new Error( `counter ${name} already at ${id}` );
		while ( id < target - 1 ) id = f();

	};

	advance( 'fn', 3000 + k * 1000, () => Number( TSL.Fn( () => {}, { return: 'float' } ).shaderNode.layout.name.slice( 2 ) ) );
	advance( 'node', 300000 + k * 100000, () => new Node().id );
	advance( 'object3d', 10000 + k * 5000, () => new THREE.Object3D().id );
	advance( 'material', 10000 + k * 5000, () => new THREE.Material().id );
	advance( 'texture', 10000 + k * 5000, () => new THREE.Texture().id );
	advance( 'attribute', 10000 + k * 5000, () => new THREE.BufferAttribute( new Float32Array( 1 ), 1 ).id );
	advance( 'geometry', 10000 + k * 5000, () => new THREE.BufferGeometry().id );

}

const scenarios = {};

scenarios.wnh_basic = async ( k ) => {

	const { gl, renderer } = setup( k );
	const scene = new THREE.Scene();
	const camera = new THREE.PerspectiveCamera( 45, 2, 0.5, 50 );
	camera.position.set( 0, 1, 6 );
	camera.lookAt( 0, 0, 0 );
	const tint = TSL.uniform( new THREE.Color( 0xff8800 ) );
	const material = new THREE.MeshBasicNodeMaterial();
	material.colorNode = tint;
	const mesh = new THREE.Mesh( new THREE.BoxGeometry( 1, 1, 1 ), material );
	scene.add( mesh );
	// a second mesh sharing the material (its object uniforms are uploaded per draw)
	const twin = new THREE.Mesh( new THREE.PlaneGeometry( 1, 1 ), material );
	twin.position.x = 1.5;
	scene.add( twin );
	renderer.render( scene, camera );
	await tick();
	gl.__note( 'frame', 1 );
	tint.value.setHex( 0x0088ff );
	mesh.rotation.y = 0.5;
	renderer.render( scene, camera );
	await tick();
	return gl.__log;

};

const camera = () => {

	const c = new THREE.PerspectiveCamera( 45, 2, 0.5, 50 );
	c.position.set( 0, 1, 6 );
	c.lookAt( 0, 0, 0 );
	return c;

};

// webgl_tsl_clearcoat: standard / physical node materials under ambient, directional and
// point lights with fog and tone mapping; uniform and light updates over frames; a fog
// change picked up after material.dispose(); a material swap.
scenarios.wnh_lit = async ( k ) => {

	const { gl, renderer } = setup( k );
	renderer.toneMapping = THREE.ACESFilmicToneMapping;
	renderer.toneMappingExposure = 1.25;
	const scene = new THREE.Scene();
	scene.fog = new THREE.Fog( 0x222244, 2, 30 );
	const cam = camera();
	scene.add( new THREE.AmbientLight( 0x404040, 2 ) );
	const sun = new THREE.DirectionalLight( 0xffffff, 3 );
	sun.position.set( 3, 5, 2 );
	scene.add( sun );
	const point = new THREE.PointLight( 0xff8844, 30, 20, 2 );
	point.position.set( - 2, 1, 2 );
	scene.add( point );
	const geometry = new THREE.SphereGeometry( 0.8, 8, 6 );
	const tint = TSL.uniform( new THREE.Color( 0x3366cc ) );
	const rough = TSL.uniform( 0.4 );
	const standard = new THREE.MeshStandardNodeMaterial( { metalness: 0.2 } );
	standard.colorNode = tint;
	standard.roughnessNode = rough;
	const a = new THREE.Mesh( geometry, standard );
	a.position.x = - 1;
	scene.add( a );
	const physical = new THREE.MeshPhysicalNodeMaterial( { clearcoat: 1.0, clearcoatRoughness: 0.1, metalness: 0.9, roughness: 0.5, color: 0x0000ff } );
	const b = new THREE.Mesh( geometry, physical );
	b.position.x = 1;
	scene.add( b );
	renderer.render( scene, cam );
	await tick();
	gl.__note( 'frame', 1 );
	tint.value.setHex( 0xcc6633 );
	rough.value = 0.8;
	point.position.set( 2, 2, 1 );
	sun.intensity = 1.5;
	renderer.render( scene, cam );
	await tick();
	gl.__note( 'frame', 2 );
	scene.fog = new THREE.FogExp2( 0x101010, 0.05 );
	standard.dispose();
	physical.clearcoatRoughness = 0.3;
	renderer.render( scene, cam );
	await tick();
	gl.__note( 'frame', 3 );
	b.material = new THREE.MeshBasicNodeMaterial( { color: 0x00ff00 } );
	renderer.toneMapping = THREE.NoToneMapping;
	renderer.render( scene, cam );
	await tick();
	return gl.__log;

};

// scene.environment: an equirectangular float DataTexture, prefiltered by the WebGL
// PMREMGenerator the builder gives the PMREMNode (a nested render during the build).
scenarios.wnh_env = async ( k ) => {

	const { gl, renderer } = setup( k );
	const scene = new THREE.Scene();
	const cam = camera();
	const data = new Float32Array( 8 * 4 * 4 );
	for ( let i = 0; i < data.length; i ++ ) data[ i ] = ( i % 7 ) / 6;
	const env = new THREE.DataTexture( data, 8, 4, THREE.RGBAFormat, THREE.FloatType );
	env.mapping = THREE.EquirectangularReflectionMapping;
	env.needsUpdate = true;
	scene.environment = env;
	scene.background = new THREE.Color( 0x112233 );
	const material = new THREE.MeshStandardNodeMaterial( { roughness: 0.3, metalness: 1.0 } );
	const mesh = new THREE.Mesh( new THREE.SphereGeometry( 1, 8, 6 ), material );
	scene.add( mesh );
	renderer.render( scene, cam );
	await tick();
	gl.__note( 'frame', 1 );
	material.roughness = 0.7;
	scene.environmentIntensity = 0.5;
	renderer.render( scene, cam );
	await tick();
	return gl.__log;

};

// webgl_tsl_instancing: an InstancedMesh with a phong node material whose colorNode
// reads positionWorld and a uniform; instance matrix / color updates over frames.
scenarios.wnh_instancing = async ( k ) => {

	const { gl, renderer } = setup( k );
	const scene = new THREE.Scene();
	scene.background = new THREE.Color( 0xffffff );
	const cam = camera();
	scene.add( new THREE.AmbientLight( 0xffffff, 2 ) );
	const sun = new THREE.DirectionalLight( 0xffffff, 1 );
	sun.position.set( 1, 2, 3 );
	scene.add( sun );
	const t = TSL.uniform( 0 );
	const posY = TSL.positionWorld;
	const material = new THREE.MeshPhongNodeMaterial();
	material.colorNode = TSL.vec3(
		TSL.sin( posY.mul( 0.1 ).add( t ) ).mul( 0.5 ).add( 0.5 ).x,
		TSL.sin( posY.mul( 0.1 ).add( t.mul( 0.5 ).add( 2 ) ) ).mul( 0.5 ).add( 0.5 ).y,
		TSL.sin( posY.mul( 0.1 ).add( t.mul( 1.5 ).add( 4 ) ) ).mul( 0.5 ).add( 0.5 ).z,
	);
	const geometry = new THREE.BoxGeometry( 0.3, 0.3, 0.3 );
	const mesh = new THREE.InstancedMesh( geometry, material, 4 );
	const matrix = new THREE.Matrix4();
	for ( let i = 0; i < 4; i ++ ) {

		matrix.makeTranslation( i - 1.5, ( i % 2 ) * 0.5, 0 );
		mesh.setMatrixAt( i, matrix );
		mesh.setColorAt( i, new THREE.Color( i / 4, 1 - i / 4, 0.5 ) );

	}

	scene.add( mesh );
	renderer.render( scene, cam );
	await tick();
	gl.__note( 'frame', 1 );
	t.value = 0.75;
	matrix.makeTranslation( 0, 1, 0 );
	mesh.setMatrixAt( 2, matrix );
	mesh.instanceMatrix.needsUpdate = true;
	renderer.render( scene, cam );
	await tick();
	gl.__note( 'frame', 2 );
	t.value = 1.5;
	renderer.render( scene, cam );
	await tick();
	return gl.__log;

};

// webgl_tsl_skinning: a SkinnedMesh with a standard node material; bone updates.
scenarios.wnh_skinning = async ( k ) => {

	const { gl, renderer } = setup( k );
	const scene = new THREE.Scene();
	const cam = camera();
	scene.add( new THREE.HemisphereLight( 0x8888ff, 0x442200, 2 ) );
	const sun = new THREE.DirectionalLight( 0xffffff, 2 );
	sun.position.set( 1, 3, 2 );
	scene.add( sun );
	const geometry = new THREE.BoxGeometry( 0.4, 2, 0.4, 1, 4, 1 );
	const position = geometry.attributes.position;
	const skinIndex = [];
	const skinWeight = [];
	for ( let i = 0; i < position.count; i ++ ) {

		const y = position.getY( i ) + 1;
		const w = y / 2;
		skinIndex.push( 0, 1, 0, 0 );
		skinWeight.push( 1 - w, w, 0, 0 );

	}

	geometry.setAttribute( 'skinIndex', new THREE.Uint16BufferAttribute( skinIndex, 4 ) );
	geometry.setAttribute( 'skinWeight', new THREE.Float32BufferAttribute( skinWeight, 4 ) );
	const material = new THREE.MeshStandardNodeMaterial( { color: 0xaa6633, roughness: 0.6 } );
	const mesh = new THREE.SkinnedMesh( geometry, material );
	const root = new THREE.Bone();
	root.position.y = - 1;
	const tip = new THREE.Bone();
	tip.position.y = 2;
	root.add( tip );
	mesh.add( root );
	mesh.bind( new THREE.Skeleton( [ root, tip ] ) );
	scene.add( mesh );
	renderer.render( scene, cam );
	await tick();
	gl.__note( 'frame', 1 );
	tip.rotation.z = 0.5;
	root.rotation.x = 0.2;
	renderer.render( scene, cam );
	await tick();
	gl.__note( 'frame', 2 );
	tip.rotation.z = - 0.3;
	renderer.render( scene, cam );
	await tick();
	return gl.__log;

};

// webgl_tsl_shadowmap: directional and spot light shadows (WebGLRenderer's shadow maps
// read by the node shadows), a maskNode material clone, receiveShadow changes forcing
// program updates, fog.
scenarios.wnh_shadow = async ( k ) => {

	const { gl, renderer } = setup( k );
	renderer.shadowMap.enabled = true;
	const scene = new THREE.Scene();
	scene.fog = new THREE.Fog( 0x222244, 5, 40 );
	const cam = camera();
	scene.add( new THREE.AmbientLight( 0x444444, 2 ) );
	const spot = new THREE.SpotLight( 0xff8888, 40 );
	spot.angle = Math.PI / 5;
	spot.penumbra = 0.3;
	spot.position.set( 3, 5, 2 );
	spot.castShadow = true;
	spot.shadow.camera.near = 1;
	spot.shadow.camera.far = 20;
	spot.shadow.mapSize.set( 32, 32 );
	scene.add( spot );
	const dir = new THREE.DirectionalLight( 0x8888ff, 3 );
	dir.position.set( 2, 6, 4 );
	dir.castShadow = true;
	dir.shadow.camera.left = - 4;
	dir.shadow.camera.right = 4;
	dir.shadow.camera.top = 4;
	dir.shadow.camera.bottom = - 4;
	dir.shadow.mapSize.set( 32, 32 );
	const group = new THREE.Group();
	group.add( dir );
	scene.add( group );
	const material = new THREE.MeshPhongNodeMaterial( { color: 0x999999, shininess: 0, specular: 0x222222 } );
	const masked = material.clone();
	masked.transparent = true;
	masked.maskNode = TSL.positionLocal.x.greaterThan( 0.0 );
	const knot = new THREE.Mesh( new THREE.TorusGeometry( 0.6, 0.2, 6, 8 ), masked );
	knot.position.y = 1;
	knot.castShadow = true;
	knot.receiveShadow = true;
	scene.add( knot );
	const pillar = new THREE.Mesh( new THREE.CylinderGeometry( 0.2, 0.2, 2, 6 ), material );
	pillar.position.set( 1.5, 1, 0 );
	pillar.castShadow = true;
	scene.add( pillar );
	const groundMaterial = new THREE.MeshPhongNodeMaterial();
	groundMaterial.color.setHex( 0x999999 );
	groundMaterial.shininess = 0;
	groundMaterial.colorNode = TSL.Fn( () => {

		return TSL.positionWorld.xz.mul( 0.1 ).sin().x.mul( 0.2 ).add( 0.5 );

	} )();
	const ground = new THREE.Mesh( new THREE.PlaneGeometry( 10, 10 ), groundMaterial );
	ground.rotation.x = - Math.PI / 2;
	ground.receiveShadow = true;
	scene.add( ground );
	renderer.render( scene, cam );
	await tick();
	gl.__note( 'frame', 1 );
	group.rotation.y = 0.4;
	knot.rotation.x = 0.3;
	renderer.render( scene, cam );
	await tick();
	gl.__note( 'frame', 2 );
	pillar.receiveShadow = true;
	renderer.render( scene, cam );
	await tick();
	gl.__note( 'frame', 3 );
	pillar.receiveShadow = false;
	renderer.render( scene, cam );
	await tick();
	return gl.__log;

};

// renderer.compile, then frames, then disposing materials, geometries and the renderer.
scenarios.wnh_compile_dispose = async ( k ) => {

	const { gl, renderer } = setup( k );
	const scene = new THREE.Scene();
	const cam = camera();
	scene.add( new THREE.PointLight( 0xffffff, 20 ) );
	const tint = TSL.uniform( new THREE.Color( 0x44aa88 ) );
	const lambert = new THREE.MeshLambertNodeMaterial();
	lambert.colorNode = tint;
	const a = new THREE.Mesh( new THREE.BoxGeometry(), lambert );
	a.position.set( - 1, 0, - 1 );
	scene.add( a );
	const basic = new THREE.MeshBasicNodeMaterial( { color: 0xff0000, transparent: true, opacity: 0.5 } );
	const b = new THREE.Mesh( new THREE.PlaneGeometry(), basic );
	b.position.set( 1, 0, 0 );
	scene.add( b );
	renderer.compile( scene, cam );
	await tick();
	gl.__note( 'compiled', 1 );
	renderer.render( scene, cam );
	await tick();
	gl.__note( 'frame', 1 );
	tint.value.setHex( 0x8844aa );
	basic.opacity = 0.25;
	renderer.render( scene, cam );
	await tick();
	gl.__note( 'frame', 2 );
	lambert.dispose();
	a.geometry.dispose();
	renderer.render( scene, cam );
	await tick();
	gl.__note( 'frame', 3 );
	basic.dispose();
	renderer.dispose();
	await tick();
	return gl.__log;

};

// Buffer uniforms (uniformArray: a UniformsGroup per buffer, named by the builder),
// int / uint uniforms in the groups, a texture node (a sampler uniform) whose value
// changes, a mesh shared by two scenes.
scenarios.wnh_arrays = async ( k ) => {

	const { gl, renderer } = setup( k );
	const scene = new THREE.Scene();
	const cam = camera();
	const palette = TSL.uniformArray( [ new THREE.Color( 0xff0000 ), new THREE.Color( 0x00ff00 ), new THREE.Color( 0x0000ff ) ] );
	const index = TSL.uniform( 1, 'int' );
	const count = TSL.uniform( 2, 'uint' );
	const weights = TSL.uniformArray( [ 0.25, 0.5, 0.75, 1 ], 'float' );
	const pixels = new Uint8Array( 4 * 4 * 4 );
	for ( let i = 0; i < pixels.length; i ++ ) pixels[ i ] = ( i * 37 ) % 256;
	const map = new THREE.DataTexture( pixels, 4, 4 );
	map.needsUpdate = true;
	const other = new THREE.DataTexture( new Uint8Array( 2 * 2 * 4 ).fill( 200 ), 2, 2 );
	other.needsUpdate = true;
	const sampled = TSL.texture( map );
	const material = new THREE.MeshBasicNodeMaterial();
	material.colorNode = palette.element( index ).mul( weights.element( count ) ).mul( sampled.rgb );
	const mesh = new THREE.Mesh( new THREE.PlaneGeometry( 2, 2 ), material );
	scene.add( mesh );
	renderer.render( scene, cam );
	await tick();
	gl.__note( 'frame', 1 );
	index.value = 2;
	count.value = 3;
	palette.array[ 2 ].setHex( 0xffff00 );
	weights.array[ 3 ] = 0.125;
	sampled.value = other;
	renderer.render( scene, cam );
	await tick();
	gl.__note( 'frame', 2 );
	const second = new THREE.Scene();
	second.add( new THREE.AmbientLight( 0xffffff, 1 ) );
	second.add( mesh );
	renderer.render( second, cam );
	await tick();
	return gl.__log;

};

// A cube texture environment (cubeTexture node, PMREM from a cube map), changed after
// dispose; MeshPhysicalNodeMaterial sheen / iridescence.
scenarios.wnh_cube_env = async ( k ) => {

	const { gl, renderer } = setup( k );
	const scene = new THREE.Scene();
	const cam = camera();
	const face = ( v ) => {

		const t = new THREE.DataTexture( new Float32Array( 4 * 4 * 4 ).fill( v ), 4, 4, THREE.RGBAFormat, THREE.FloatType );
		return t;

	};

	const env = new THREE.CubeTexture( [ face( 0.1 ), face( 0.2 ), face( 0.3 ), face( 0.4 ), face( 0.5 ), face( 0.6 ) ] );
	env.type = THREE.FloatType;
	env.format = THREE.RGBAFormat;
	env.needsUpdate = true;
	scene.environment = env;
	const material = new THREE.MeshPhysicalNodeMaterial( { roughness: 0.2, metalness: 0.5, sheen: 1, sheenRoughness: 0.4, iridescence: 0.5 } );
	const mesh = new THREE.Mesh( new THREE.SphereGeometry( 1, 8, 6 ), material );
	scene.add( mesh );
	renderer.render( scene, cam );
	await tick();
	gl.__note( 'frame', 1 );
	scene.environment = null;
	material.dispose();
	renderer.render( scene, cam );
	await tick();
	return gl.__log;

};

// A point light shadow (PointShadowNode reading WebGLRenderer's cube shadow map), soft
// shadows, renderer.compile with a target scene, a second camera.
scenarios.wnh_point_shadow = async ( k ) => {

	const { gl, renderer } = setup( k );
	renderer.shadowMap.enabled = true;
	renderer.shadowMap.type = THREE.PCFSoftShadowMap;
	const scene = new THREE.Scene();
	const cam = camera();
	const point = new THREE.PointLight( 0xffffff, 30 );
	point.position.set( 0, 2, 0 );
	point.castShadow = true;
	point.shadow.mapSize.set( 16, 16 );
	scene.add( point );
	const material = new THREE.MeshStandardNodeMaterial( { color: 0x8899aa } );
	const ball = new THREE.Mesh( new THREE.SphereGeometry( 0.5, 8, 6 ), material );
	ball.castShadow = true;
	ball.receiveShadow = true;
	scene.add( ball );
	const floor = new THREE.Mesh( new THREE.PlaneGeometry( 6, 6 ), new THREE.MeshLambertNodeMaterial() );
	floor.rotation.x = - Math.PI / 2;
	floor.position.y = - 1;
	floor.receiveShadow = true;
	const extra = new THREE.Scene();
	extra.add( floor );
	renderer.compile( extra, cam, scene );
	await tick();
	gl.__note( 'compiled', 1 );
	scene.add( floor );
	renderer.render( scene, cam );
	await tick();
	gl.__note( 'frame', 1 );
	const top = new THREE.OrthographicCamera( - 3, 3, 1.5, - 1.5, 0.1, 20 );
	top.position.set( 0, 8, 0 );
	top.lookAt( 0, 0, 0 );
	point.position.x = 1;
	renderer.render( scene, top );
	await tick();
	return gl.__log;

};

// every scenario runs (counters and module caches carry over, as in the MoonBit chain)
const only = process.argv.slice( 2 );
let k = 0;
for ( const name of Object.keys( scenarios ) ) {

	const log = await scenarios[ name ]( k ++ );
	if ( only.length && ! only.includes( name ) ) continue;
	console.log( '@@WEBGL_LOG ' + name + ' ' + JSON.stringify( log ) );

}
