// Differential harness, upstream side. Emits one line per observation.
import { upstreamURL } from '../../lib/env.mjs';
const SRC = upstreamURL( 'src' ) + '/';
const { PerspectiveCamera } = await import( SRC + 'cameras/PerspectiveCamera.js' );
const { OrthographicCamera } = await import( SRC + 'cameras/OrthographicCamera.js' );
const { Camera } = await import( SRC + 'cameras/Camera.js' );
const { ArrayCamera } = await import( SRC + 'cameras/ArrayCamera.js' );
const { StereoCamera } = await import( SRC + 'cameras/StereoCamera.js' );
const { CubeCamera } = await import( SRC + 'cameras/CubeCamera.js' );
const { Light } = await import( SRC + 'lights/Light.js' );
const { AmbientLight } = await import( SRC + 'lights/AmbientLight.js' );
const { DirectionalLight } = await import( SRC + 'lights/DirectionalLight.js' );
const { HemisphereLight } = await import( SRC + 'lights/HemisphereLight.js' );
const { LightProbe } = await import( SRC + 'lights/LightProbe.js' );
const { LightShadow } = await import( SRC + 'lights/LightShadow.js' );
const { PointLight } = await import( SRC + 'lights/PointLight.js' );
const { RectAreaLight } = await import( SRC + 'lights/RectAreaLight.js' );
const { SpotLight } = await import( SRC + 'lights/SpotLight.js' );
const { default: IESSpotLight } = await import( SRC + 'lights/webgpu/IESSpotLight.js' );
const { default: ProjectorLight } = await import( SRC + 'lights/webgpu/ProjectorLight.js' );
const { Fog } = await import( SRC + 'scenes/Fog.js' );
const { FogExp2 } = await import( SRC + 'scenes/FogExp2.js' );
const { Scene } = await import( SRC + 'scenes/Scene.js' );
const { Object3D } = await import( SRC + 'core/Object3D.js' );
const { RenderTarget } = await import( SRC + 'core/RenderTarget.js' );
const { Color } = await import( SRC + 'math/Color.js' );
const { Vector2 } = await import( SRC + 'math/Vector2.js' );
const { Vector3 } = await import( SRC + 'math/Vector3.js' );
const { Vector4 } = await import( SRC + 'math/Vector4.js' );
const { Euler } = await import( SRC + 'math/Euler.js' );
const { Matrix4 } = await import( SRC + 'math/Matrix4.js' );
const { Frustum } = await import( SRC + 'math/Frustum.js' );
const { Texture } = await import( SRC + 'textures/Texture.js' );
const { MeshBasicMaterial } = await import( SRC + 'materials/MeshBasicMaterial.js' );

const replacer = ( k, v ) => ( typeof v === 'number' && ( Object.is( v, - 0 ) || ! Number.isFinite( v ) ) ) ? 'num:' + ( Object.is( v, - 0 ) ? '-0' : String( v ) ) : v;
const emit = ( name, value ) => console.log( JSON.stringify( [ name, value ], replacer ) );
const emitNum = ( name, v ) => emit( name, [ v ] );
function emitJson( name, json ) {

	const ids = new Map();
	const text = JSON.stringify( json, ( k, v ) => {

		if ( typeof v === 'string' && /^[0-9a-f-]{36}$/.test( v ) ) {

			if ( ! ids.has( v ) ) ids.set( v, 'id' + ids.size );
			return ids.get( v );

		}

		return replacer( k, v );

	} );
	console.log( JSON.stringify( [ name, text ] ) );

}

let seed = 12345;
function rnd() {

	seed = seed * 16807;
	seed = seed - Math.floor( seed / 2147483647 ) * 2147483647;
	return seed / 2147483647;

}

const range = ( a, b ) => a + rnd() * ( b - a );

function matrices( name, camera ) {

	emit( name + ' projection', camera.projectionMatrix.elements );
	emit( name + ' projectionInverse', camera.projectionMatrixInverse.elements );

}

function transforms( name, object ) {

	emit( name + ' position', object.position.toArray() );
	emit( name + ' quaternion', object.quaternion.toArray() );
	emit( name + ' rotation', [ object.rotation.x, object.rotation.y, object.rotation.z ] );
	emit( name + ' matrix', object.matrix.elements );
	emit( name + ' matrixWorld', object.matrixWorld.elements );

}

function view( name, camera ) {

	transforms( name, camera );
	emit( name + ' matrixWorldInverse', camera.matrixWorldInverse.elements );

}

const perspectives = [
	[ 50, 1, 0.1, 2000 ], [ 75, 16 / 9, 0.1, 300 ], [ 35, 0.5, 1, 100 ], [ 90, 2.5, 0.01, 1e5 ],
	[ 1, 1, 1e-3, 1e7 ], [ - 90, 1, 0.1, 2000 ], [ 179, 0.1, 0.7, 7.3 ]
];
const orthographics = [
	[ - 1, 1, 1, - 1, 0.1, 2000 ], [ - 5, 5, 5, - 5, 0.5, 500 ], [ - 2, 3, 4, - 1, 1, 10 ],
	[ 100, 300, 700, 50, - 3, 17 ], [ - 0.25, 0.75, 0.125, - 0.625, 0.1, 0.2 ]
];
const views = [
	null, [ 1920, 1080, 100, 50, 800, 600 ], [ 100, 100, 0, 0, 100, 100 ], [ 4000, 3000, 1000, 1500, 800, 600 ],
	[ 300, 700, - 20, 33.5, 12.25, 9.75 ]
];
const coordinateSystems = [ 2000, 2001 ];
const reversed = [ false, true ];
const zooms = [ 1, 2, 0.37 ];

function cameraDetails( name, camera ) {

	const min = new Vector2(), max = new Vector2(), size = new Vector2();
	emit( name + ' film', [ camera.getFilmWidth(), camera.getFilmHeight(), camera.getFocalLength(), camera.getEffectiveFOV() ] );
	camera.getViewBounds( 1, min, max );
	emit( name + ' bounds1', [ min.x, min.y, max.x, max.y ] );
	camera.getViewBounds( 3.7, min, max );
	emit( name + ' bounds2', [ min.x, min.y, max.x, max.y ] );
	camera.getViewSize( 7.5, size );
	emit( name + ' size', [ size.x, size.y ] );

}

// projection matrices and view offsets
for ( const [ pi, p ] of perspectives.entries() ) for ( const zoom of zooms ) for ( const coord of coordinateSystems ) for ( const rev of reversed ) for ( const [ vi, v ] of views.entries() ) for ( const offset of [ 0, 3.5 ] ) {

	const name = `persp ${pi} ${zoom} ${coord} ${rev} ${vi} ${offset}`;
	const camera = new PerspectiveCamera( ...p );
	camera.zoom = zoom;
	camera.filmOffset = offset;
	camera.coordinateSystem = coord;
	camera._reversedDepth = rev;
	camera.updateProjectionMatrix();
	matrices( name + ' base', camera );
	if ( v !== null ) {

		camera.setViewOffset( ...v );
		matrices( name + ' view', camera );
		emit( name + ' aspect', [ camera.aspect ] );

	}

	cameraDetails( name, camera );
	const clone = camera.clone();
	matrices( name + ' clone', clone );
	clone.updateProjectionMatrix();
	matrices( name + ' cloneUpdated', clone );
	camera.clearViewOffset();
	matrices( name + ' cleared', camera );
	camera.setFocalLength( 42 );
	matrices( name + ' focal', camera );
	emit( name + ' fov', [ camera.fov ] );

}

for ( const [ pi, p ] of orthographics.entries() ) for ( const zoom of zooms ) for ( const coord of coordinateSystems ) for ( const rev of reversed ) for ( const [ vi, v ] of views.entries() ) {

	const name = `ortho ${pi} ${zoom} ${coord} ${rev} ${vi}`;
	const camera = new OrthographicCamera( ...p );
	camera.zoom = zoom;
	camera.coordinateSystem = coord;
	camera._reversedDepth = rev;
	camera.updateProjectionMatrix();
	matrices( name + ' base', camera );
	if ( v !== null ) {

		camera.setViewOffset( ...v );
		matrices( name + ' view', camera );

	}

	const clone = camera.clone();
	matrices( name + ' clone', clone );
	clone.updateProjectionMatrix();
	matrices( name + ' cloneUpdated', clone );
	camera.clearViewOffset();
	matrices( name + ' cleared', camera );

}

// lookAt and the scale-stripping hooks, on cameras and lights under random parents
function setRandomTransform( object, scaleMode ) {

	object.position.set( range( - 10, 10 ), range( - 10, 10 ), range( - 10, 10 ) );
	object.rotation.set( range( - 3, 3 ), range( - 3, 3 ), range( - 3, 3 ) );
	if ( scaleMode === 1 ) {

		const s = range( 0.5, 3 );
		object.scale.set( s, s, s );

	} else if ( scaleMode === 2 ) {

		object.scale.set( range( 0.5, 3 ), range( 0.5, 3 ), range( 0.5, 3 ) );

	} else if ( scaleMode === 3 ) {

		object.scale.set( - range( 0.5, 3 ), range( 0.5, 3 ), range( 0.5, 3 ) );

	}

}

const makers = [
	[ 'Camera', () => new Camera() ],
	[ 'Perspective', () => new PerspectiveCamera() ],
	[ 'Orthographic', () => new OrthographicCamera() ],
	[ 'Array', () => new ArrayCamera() ],
];
const lightMakers = [
	[ 'Directional', () => new DirectionalLight() ],
	[ 'Spot', () => new SpotLight() ],
	[ 'Point', () => new PointLight() ],
	[ 'Hemisphere', () => new HemisphereLight() ],
];

for ( let i = 0; i < 400; i ++ ) {

	for ( const [ kind, make ] of [ ...makers, ...lightMakers ] ) {

		const name = `look ${i} ${kind}`;
		const scaleMode = i % 4;
		const object = make();
		const parent = new Object3D();
		const grand = new Object3D();
		setRandomTransform( grand, scaleMode );
		setRandomTransform( parent, scaleMode === 2 ? 0 : scaleMode );
		setRandomTransform( object, i % 3 === 0 ? 0 : scaleMode );
		if ( i % 5 === 0 ) object.up.set( range( - 1, 1 ), range( - 1, 1 ), range( - 1, 1 ) ).normalize();
		if ( i % 7 !== 0 ) {

			grand.add( parent );
			parent.add( object );

		}

		const target = new Vector3( range( - 10, 10 ), range( - 10, 10 ), range( - 10, 10 ) );
		if ( i % 2 === 0 ) object.lookAt( target );
		else object.lookAt( target.x, target.y, target.z );
		emit( name + ' looked', object.quaternion.toArray() );
		if ( i % 3 === 1 ) {

			object.updateWorldMatrix( true, true );

		} else {

			grand.updateMatrixWorld( true );
			object.updateMatrixWorld();

		}

		const dir = new Vector3();
		emit( name + ' direction', object.getWorldDirection( dir ).toArray() );
		if ( object.isCamera ) view( name, object ); else transforms( name, object );

	}

}

// shadow updateMatrices
function shadowState( name, shadow ) {

	emit( name + ' matrix', shadow.matrix.elements );
	emit( name + ' camera', shadow.camera.matrixWorld.elements );
	emit( name + ' cameraInverse', shadow.camera.matrixWorldInverse.elements );
	emit( name + ' cameraProjection', shadow.camera.projectionMatrix.elements );
	const planes = [];
	for ( const plane of shadow.getFrustum().planes ) planes.push( plane.normal.x, plane.normal.y, plane.normal.z, plane.constant );
	emit( name + ' frustum', planes );

}

for ( let i = 0; i < 300; i ++ ) {

	const coord = coordinateSystems[ i % 2 ];
	const rev = i % 3 === 0;
	const scaleMode = i % 4;
	{

		const name = `dirShadow ${i}`;
		const light = new DirectionalLight();
		setRandomTransform( light, scaleMode );
		setRandomTransform( light.target, 0 );
		const shadow = light.shadow;
		shadow.camera.coordinateSystem = coord;
		shadow.camera._reversedDepth = rev;
		shadow.camera.left = range( - 20, - 1 );
		shadow.camera.right = range( 1, 20 );
		shadow.camera.updateProjectionMatrix();
		light.updateMatrixWorld();
		light.target.updateMatrixWorld();
		shadow.updateMatrices( light );
		shadowState( name, shadow );

	}

	{

		const name = `spotShadow ${i}`;
		const light = new SpotLight( undefined, undefined, i % 5 === 0 ? 0 : range( 1, 900 ), range( 0.1, 1.5 ), 0.2, 2 );
		setRandomTransform( light, scaleMode );
		setRandomTransform( light.target, 0 );
		const shadow = light.shadow;
		shadow.camera.coordinateSystem = coord;
		shadow.camera._reversedDepth = rev;
		shadow.focus = range( 0.2, 1 );
		shadow.aspect = range( 0.5, 2 );
		shadow.mapSize.set( 256 + i, 1024 - i );
		light.updateMatrixWorld();
		light.target.updateMatrixWorld();
		shadow.updateMatrices( light );
		shadowState( name, shadow );
		emit( name + ' cameraFields', [ shadow.camera.fov, shadow.camera.aspect, shadow.camera.far ] );
		shadow.updateMatrices( light );
		shadowState( name + ' again', shadow );

	}

	{

		const name = `viewportShadow ${i}`;
		const camera = new OrthographicCamera( - 3, 3, 2, - 2, 1, 50 );
		camera.coordinateSystem = coord;
		camera._reversedDepth = rev;
		camera.updateProjectionMatrix();
		setRandomTransform( camera, 0 );
		camera.updateMatrixWorld();
		const shadow = new LightShadow( camera );
		shadow._frameExtents.set( range( 1, 8 ), range( 1, 8 ) );
		const matrix = new Matrix4(), frustum = new Frustum();
		const viewport = new Vector4( range( 0, 4 ), range( 0, 4 ), range( 1, 3 ), range( 1, 3 ) );
		shadow._updateMatrix( camera, matrix, frustum, viewport );
		emit( name + ' matrix', matrix.elements );
		const planes = [];
		for ( const plane of frustum.planes ) planes.push( plane.normal.x, plane.normal.y, plane.normal.z, plane.constant );
		emit( name + ' frustum', planes );
		emit( name + ' viewport', shadow.getViewport( 0 ).toArray() );

	}

}

// toJSON
function jsonOf( name, object ) {

	emitJson( name, object.toJSON() );
	emitJson( name + ' clone', object.clone().toJSON() );

}

{

	const camera = new PerspectiveCamera( 60, 1.5, 0.2, 90 );
	jsonOf( 'json perspective', camera );
	camera.setViewOffset( 10, 5, 1, 2, 3, 4 );
	camera.name = 'cam';
	camera.position.set( 1, 2, 3 );
	camera.updateMatrix();
	camera.userData = { a: 1, b: [ 1, 2 ] };
	camera.add( new Object3D() );
	camera.layers.set( 3 );
	camera.renderOrder = 2.5;
	jsonOf( 'json perspective view', camera );
	camera.clearViewOffset();
	jsonOf( 'json perspective cleared', camera );
	const ortho = new OrthographicCamera( - 2, 3, 4, - 5, 0.5, 60 );
	jsonOf( 'json ortho', ortho );
	ortho.setViewOffset( 10, 5, 1, 2, 3, 4 );
	jsonOf( 'json ortho view', ortho );
	jsonOf( 'json camera', new Camera() );
	jsonOf( 'json array', new ArrayCamera( [ new PerspectiveCamera() ] ) );
	jsonOf( 'json cube', new CubeCamera( 1, 10, new RenderTarget( 4, 4 ) ) );

}

{

	const color = new Color( 0x123456 ), ground = new Color( 0xabc012 );
	jsonOf( 'json light', new Light( color, 0.5 ) );
	jsonOf( 'json ambient', new AmbientLight( color, 0.25 ) );
	jsonOf( 'json ambient default', new AmbientLight() );
	const directional = new DirectionalLight( color, 2 );
	directional.shadow.bias = 0.25;
	directional.shadow.normalBias = 0.75;
	directional.shadow.radius = 3;
	directional.shadow.blurSamples = 12;
	directional.shadow.intensity = 0.5;
	directional.shadow.mapSize.set( 1024, 2048 );
	directional.shadow.camera.left = - 7;
	jsonOf( 'json directional', directional );
	jsonOf( 'json hemisphere', new HemisphereLight( color, ground, 0.6 ) );
	const probe = new LightProbe( undefined, 0.5 );
	probe.sh.coefficients[ 2 ].set( 1, 2, 3 );
	jsonOf( 'json probe', probe );
	jsonOf( 'json point', new PointLight( color, 3, 10, 1.5 ) );
	jsonOf( 'json rect', new RectAreaLight( color, 3, 4, 5 ) );
	const spot = new SpotLight( color, 3, 10, 0.5, 0.25, 1.5 );
	spot.shadow.focus = 0.5;
	spot.shadow.aspect = 2;
	jsonOf( 'json spot', spot );
	jsonOf( 'json spot default', new SpotLight() );
	const mapped = new SpotLight();
	mapped.map = new Texture();
	jsonOf( 'json spot map', mapped );
	jsonOf( 'json ies', new IESSpotLight( color, 2 ) );
	jsonOf( 'json projector', new ProjectorLight( color, 2 ) );
	emit( 'power', [ new PointLight( color, 3 ).power, new SpotLight( color, 3 ).power, new RectAreaLight( color, 3, 4, 5 ).power ] );
	const powers = [ new PointLight(), new SpotLight(), new RectAreaLight( color, 1, 4, 5 ) ];
	for ( const light of powers ) light.power = 100;
	emit( 'set power', powers.map( ( l ) => l.intensity ) );

}

{

	emitJson( 'json fog', new Fog( new Color( 0xff0000 ), 2, 30 ).toJSON() );
	emitJson( 'json fogexp2', new FogExp2( new Color( 0x00ff00 ), 0.5 ).toJSON() );
	const named = new Fog();
	named.name = 'n';
	emitJson( 'json fog named', named.toJSON() );
	emitJson( 'json fog named clone', named.clone().toJSON() );
	const scene = new Scene();
	jsonOf( 'json scene', scene );
	scene.background = new Color( 0x336699 );
	scene.fog = new Fog( new Color( 0xff0000 ), 2, 30 );
	scene.backgroundBlurriness = 0.25;
	scene.backgroundIntensity = 2;
	scene.backgroundRotation.set( 1, 2, 3, 'ZYX' );
	scene.environmentIntensity = 3;
	scene.environmentRotation.set( 0.5, 0.25, 0.125, 'YXZ' );
	scene.add( new DirectionalLight() );
	scene.add( new PerspectiveCamera() );
	jsonOf( 'json scene full', scene );
	scene.fog = new FogExp2( new Color( 0xff0000 ), 0.125 );
	scene.background = new Texture();
	scene.environment = new Texture();
	scene.overrideMaterial = new MeshBasicMaterial();
	const mappedScene = new Scene();
	const mappedSpot = new SpotLight();
	mappedSpot.map = new Texture();
	mappedScene.add( mappedSpot );
	mappedScene.background = new Texture();
	emitJson( 'json scene spot map', mappedScene.toJSON() );
	const copy = new Scene().copy( scene );
	emit( 'scene copy', [ copy.children.length, copy.background.uuid === scene.background.uuid ? 1 : 0, copy.overrideMaterial.uuid === scene.overrideMaterial.uuid ? 1 : 0, copy.fog.density ] );

}

// stereo
for ( let i = 0; i < 100; i ++ ) {

	const stereo = new StereoCamera();
	const camera = new PerspectiveCamera( range( 10, 120 ), range( 0.5, 3 ), range( 0.01, 2 ), range( 10, 1000 ) );
	camera.focus = range( 1, 20 );
	camera.zoom = range( 0.5, 2 );
	stereo.aspect = i % 2 === 0 ? 1 : 0.5;
	stereo.eyeSep = range( 0.01, 0.2 );
	setRandomTransform( camera, i % 4 );
	camera.updateProjectionMatrix();
	camera.updateMatrixWorld();
	for ( let pass = 0; pass < 2; pass ++ ) {

		stereo.update( camera );
		emit( `stereo ${i} ${pass} l`, stereo.cameraL.projectionMatrix.elements );
		emit( `stereo ${i} ${pass} r`, stereo.cameraR.projectionMatrix.elements );
		emit( `stereo ${i} ${pass} lm`, stereo.cameraL.matrix.elements );
		emit( `stereo ${i} ${pass} rm`, stereo.cameraR.matrix.elements );
		camera.focus += pass;

	}

}

// cube camera
class MockRenderer {

	constructor( coordinateSystem, isWebGL, rev, autoClear ) {

		this.coordinateSystem = coordinateSystem;
		this.isWebGLRenderer = isWebGL;
		this.reversedDepthBuffer = rev;
		this.state = { buffers: { depth: { getReversed: () => rev } } };
		this.autoClear = autoClear;
		this.xr = { enabled: true };
		this.target = null;
		this.face = 3;
		this.level = 2;
		this.log = [];

	}

	getRenderTarget() { return this.target; }
	getActiveCubeFace() { return this.face; }
	getActiveMipmapLevel() { return this.level; }
	setRenderTarget( target, face, level ) { this.log.push( 1000 + face * 10 + level ); this.target = target; this.face = face; this.level = level; }
	clearDepth() { this.log.push( 2000 ); }
	render( scene, camera ) { this.log.push( 3000 + ( this.xr.enabled ? 1 : 0 ) ); this.log.push( ...camera.matrixWorld.elements ); this.log.push( ...camera.matrixWorldInverse.elements ); this.log.push( ...camera.projectionMatrix.elements ); }

}

for ( const coord of coordinateSystems ) for ( const rev of reversed ) for ( const autoClear of reversed ) for ( let i = 0; i < 4; i ++ ) {

	const name = `cube ${coord} ${rev} ${autoClear} ${i}`;
	const target = new RenderTarget( 8, 8 );
	const cube = new CubeCamera( 0.5, 40, target );
	cube.activeMipmapLevel = i;
	setRandomTransform( cube, i );
	const parent = new Object3D();
	if ( i > 1 ) {

		setRandomTransform( parent, 0 );
		parent.add( cube );
		parent.updateMatrixWorld();

	}

	const renderer = new MockRenderer( coord, i % 2 === 0, rev, autoClear );
	const scene = new Scene();
	cube.update( renderer, scene );
	emit( name + ' log', renderer.log );
	emit( name + ' restored', [ renderer.face, renderer.level, renderer.xr.enabled ? 1 : 0, renderer.target === null ? 1 : 0 ] );
	emit( name + ' texture', [ target.texture.pmremVersion, target.texture.mipmapsAutoUpdate ? 1 : 0 ] );
	for ( const [ c, camera ] of cube.children.entries() ) {

		emit( name + ' up ' + c, camera.up.toArray() );
		view( name + ' face ' + c, camera );

	}

	renderer.log.length = 0;
	cube.update( renderer, scene );
	emit( name + ' log2', renderer.log );

}

for ( const coord of coordinateSystems ) {

	const cube = new CubeCamera( 1, 10 );
	const clone = cube.clone();
	emit( 'cube clone ' + coord, [ clone.children.length, clone.children[ 0 ].far, clone.children[ 6 ].far ] );
	clone.coordinateSystem = coord;
	clone.updateCoordinateSystem();
	emit( 'cube clone updated ' + coord, clone.children.flatMap( ( c ) => c.quaternion.toArray() ) );

}

// copy keeps recursive as upstream does
{

	const results = [];
	for ( const make of [ () => new Light(), () => new AmbientLight(), () => new DirectionalLight(), () => new HemisphereLight(), () => new LightProbe(), () => new PointLight(), () => new RectAreaLight(), () => new SpotLight(), () => new IESSpotLight(), () => new ProjectorLight(), () => new Camera(), () => new PerspectiveCamera(), () => new OrthographicCamera(), () => new Scene() ] ) {

		const source = make();
		source.add( new Object3D() );
		results.push( make().copy( source, false ).children.length, make().copy( source, true ).children.length, make().copy( source ).children.length, source.clone().children.length );

	}

	emit( 'recursive', results );

}
