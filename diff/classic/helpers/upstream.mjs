// Upstream side of the helpers differential check. Every function mirrors main/main.mbt
// line by line; both sides log through globalThis.__note* (defined in run_diff.mjs).

const N = ( l, v ) => globalThis.__noteNum( l, v );
const S = ( l, v ) => globalThis.__noteStr( l, v );
const B = ( l, v ) => globalThis.__noteStr( l, String( v === true ) );
const T = ( l, a ) => globalThis.__noteTyped( l, a );

let THREE;

function vec( l, v ) {

	N( l + '.x', v.x ); N( l + '.y', v.y ); N( l + '.z', v.z );

}

function quat( l, q ) {

	N( l + '.x', q.x ); N( l + '.y', q.y ); N( l + '.z', q.z ); N( l + '.w', q.w );

}

function mat( l, m ) {

	for ( let i = 0; i < 16; i ++ ) N( l + '[' + i + ']', m.elements[ i ] );

}

function color( l, c ) {

	N( l + '.r', c.r ); N( l + '.g', c.g ); N( l + '.b', c.b );

}

function same( l, a, b ) {

	S( l, a === b ? 'same' : 'diff' );

}

function dumpAttribute( l, a ) {

	N( l + '.itemSize', a.itemSize );
	N( l + '.count', a.count );
	B( l + '.normalized', a.normalized );
	N( l + '.version', a.version );
	T( l + '.array', a.array );

}

function dumpGeometry( l, g ) {

	const names = Object.keys( g.attributes );
	S( l + '.attributes', names.join( ',' ) );
	for ( const name of names ) dumpAttribute( l + '.' + name, g.attributes[ name ] );
	if ( g.index !== null ) dumpAttribute( l + '.index', g.index ); else S( l + '.index', 'null' );
	if ( g.boundingSphere !== null ) {

		vec( l + '.boundingSphere.center', g.boundingSphere.center );
		N( l + '.boundingSphere.radius', g.boundingSphere.radius );

	} else S( l + '.boundingSphere', 'null' );

	if ( g.boundingBox !== null ) {

		vec( l + '.boundingBox.min', g.boundingBox.min );
		vec( l + '.boundingBox.max', g.boundingBox.max );

	} else S( l + '.boundingBox', 'null' );

	N( l + '.drawRange.start', g.drawRange.start );
	N( l + '.drawRange.count', g.drawRange.count );
	N( l + '.groups', g.groups.length );

}

function dumpMaterial( l, m ) {

	S( l + '.type', m.type );
	color( l + '.color', m.color );
	B( l + '.vertexColors', m.vertexColors );
	B( l + '.toneMapped', m.toneMapped );
	S( l + '.fog', String( m.fog ) );
	S( l + '.wireframe', String( m.wireframe ) );
	B( l + '.transparent', m.transparent );
	N( l + '.opacity', m.opacity );
	B( l + '.depthTest', m.depthTest );
	B( l + '.depthWrite', m.depthWrite );
	N( l + '.side', m.side );
	N( l + '.version', m.version );

}

function dumpObject( l, o ) {

	S( l + '.type', o.type );
	B( l + '.visible', o.visible );
	B( l + '.matrixAutoUpdate', o.matrixAutoUpdate );
	B( l + '.matrixWorldAutoUpdate', o.matrixWorldAutoUpdate );
	B( l + '.matrixWorldNeedsUpdate', o.matrixWorldNeedsUpdate );
	vec( l + '.position', o.position );
	quat( l + '.quaternion', o.quaternion );
	vec( l + '.rotation', o.rotation );
	S( l + '.rotation.order', o.rotation.order );
	vec( l + '.scale', o.scale );
	mat( l + '.matrix', o.matrix );
	mat( l + '.matrixWorld', o.matrixWorld );
	B( l + '.isMesh', o.isMesh );
	B( l + '.isLine', o.isLine );
	B( l + '.isLineSegments', o.isLineSegments );
	if ( o.isMesh || o.isLine ) {

		dumpGeometry( l + '.geometry', o.geometry );
		dumpMaterial( l + '.material', o.material );

	}

	N( l + '.children', o.children.length );
	for ( let i = 0; i < o.children.length; i ++ ) dumpObject( l + '.c' + i, o.children[ i ] );

}

function tracker( target ) {

	const counter = { n: 0 };
	target.addEventListener( 'dispose', () => counter.n ++ );
	return counter;

}

// Disposes `helper` and records how often each part fired `dispose`.
function disposeAll( l, helper ) {

	const parts = [];
	helper.traverse( ( o ) => {

		parts.push( tracker( o ) );
		if ( o.isMesh || o.isLine ) {

			parts.push( tracker( o.geometry ) );
			parts.push( tracker( o.material ) );

		}

	} );
	helper.dispose();
	S( l + '.disposed', parts.map( ( c ) => c.n ).join( ',' ) );

}

function v3( x, y, z ) {

	return new THREE.Vector3( x, y, z );

}

function axes() {

	const sizes = [ 1, 2.5, 0, - 3, 1e-7, 123456.789 ];
	for ( let i = 0; i < sizes.length; i ++ ) {

		const helper = new THREE.AxesHelper( sizes[ i ] );
		dumpObject( 'axes' + i, helper );
		helper.setColors( 0x123456, 0xabcdef, 0xff00ff );
		dumpGeometry( 'axes' + i + '.colored', helper.geometry );
		const copy = helper.clone();
		dumpObject( 'axes' + i + '.clone', copy );
		same( 'axes' + i + '.clone.geometry', copy.geometry, helper.geometry );
		disposeAll( 'axes' + i, helper );

	}

	dumpObject( 'axes.default', new THREE.AxesHelper() );

}

function grid() {

	const params = [
		[ 5, 3, 0x444444, 0x888888 ], [ 7.3, 7, 0xff0000, 0x00ff00 ], [ 1, 1, 0x444444, 0x888888 ],
		[ 4, 0, 0x444444, 0x888888 ], [ 3, 4.5, 0x123456, 0x654321 ], [ 6, 6, 0x444444, 0x888888 ],
		[ 0.7, 33, 0x444444, 0x888888 ], [ 10, 100, 0x444444, 0x888888 ], [ 9.1, 77, 0x444444, 0x888888 ],
	];
	dumpObject( 'grid.default', new THREE.GridHelper() );
	for ( let i = 0; i < params.length; i ++ ) {

		const p = params[ i ];
		const helper = new THREE.GridHelper( p[ 0 ], p[ 1 ], p[ 2 ], p[ 3 ] );
		dumpObject( 'grid' + i, helper );
		disposeAll( 'grid' + i, helper );

	}

}

function polarGrid() {

	const params = [
		[ 5, 1, 3, 8, 0x444444, 0x888888 ], [ 3, 7, 0, 5, 0x444444, 0x888888 ],
		[ 2, 3, 2, 3.5, 0x444444, 0x888888 ], [ 4, 2, 5, 12, 0x112233, 0x445566 ],
		[ 1, 0, 1, 1, 0x444444, 0x888888 ],
	];
	dumpObject( 'polar.default', new THREE.PolarGridHelper() );
	for ( let i = 0; i < params.length; i ++ ) {

		const p = params[ i ];
		const helper = new THREE.PolarGridHelper( p[ 0 ], p[ 1 ], p[ 2 ], p[ 3 ], p[ 4 ], p[ 5 ] );
		dumpObject( 'polar' + i, helper );
		disposeAll( 'polar' + i, helper );

	}

}

function arrow() {

	const first = new THREE.ArrowHelper();
	dumpObject( 'arrow.default', first );
	const cases = [
		[ v3( 0, 1, 0 ), v3( 0, 0, 0 ), 1, 0xffff00, undefined, undefined ],
		[ v3( 0, - 1, 0 ), v3( 0, 0, 0 ), 2, 0xffff00, undefined, undefined ],
		[ v3( 1, 1, 1 ).normalize(), v3( 1, 2, 3 ), 3, 0x00ff00, undefined, undefined ],
		[ v3( 0.3, - 0.2, 0.9 ).normalize(), v3( - 1, 0, 0.5 ), 0.1, 0xffff00, 0.5, undefined ],
		[ v3( - 1, 0, 0 ), v3( 0, 0, 0 ), 0, 0xff0000, 0.3, 0.1 ],
		[ v3( 0, 1, 1e-3 ).normalize(), v3( 0, 0, 0 ), 1, 0xffff00, undefined, undefined ],
		[ v3( 0, 0.99998, Math.sqrt( 1 - 0.99998 * 0.99998 ) ), v3( 0, 0, 0 ), 1, 0xffff00, undefined, undefined ],
		[ v3( 0, - 0.99998, - Math.sqrt( 1 - 0.99998 * 0.99998 ) ), v3( 2, 2, 2 ), 5, 0xffff00, 1, 0.5 ],
	];
	let last = first;
	for ( let i = 0; i < cases.length; i ++ ) {

		const c = cases[ i ];
		const helper = new THREE.ArrowHelper( c[ 0 ], c[ 1 ], c[ 2 ], c[ 3 ], c[ 4 ], c[ 5 ] );
		dumpObject( 'arrow' + i, helper );
		same( 'arrow' + i + '.lineGeometry', helper.line.geometry, first.line.geometry );
		same( 'arrow' + i + '.coneGeometry', helper.cone.geometry, first.cone.geometry );
		last = helper;

	}

	last.setDirection( v3( 1, 0, 1 ).normalize() );
	last.setLength( 4 );
	dumpObject( 'arrow.len4', last );
	last.setLength( 2, 0.5 );
	dumpObject( 'arrow.len2', last );
	last.setLength( 2, 0.5, 0.25 );
	last.setColor( 0x0000ff );
	last.position.set( 1, - 1, 2 );
	last.updateMatrixWorld();
	dumpObject( 'arrow.updated', last );
	const copy = last.clone();
	dumpObject( 'arrow.clone', copy );
	same( 'arrow.clone.lineMaterial', copy.line.material, last.line.material );
	same( 'arrow.clone.line', copy.line, last.line );
	const target = new THREE.ArrowHelper( v3( 0, 1, 0 ) );
	target.copy( last );
	dumpObject( 'arrow.copy', target );
	disposeAll( 'arrow', last );

}

function box3() {

	const boxes = [
		new THREE.Box3( v3( - 1, 0, 2 ), v3( 3, 4, 4 ) ),
		new THREE.Box3( v3( - 1, - 1, - 1 ), v3( 1, 1, 1 ) ),
		new THREE.Box3(),
		new THREE.Box3( v3( 0, 0, 0 ), v3( 2, 0, 2 ) ),
	];
	const colors = [ 0xffff00, 0x00ff00, 0xffff00, 0x123456 ];
	for ( let i = 0; i < boxes.length; i ++ ) {

		const parent = new THREE.Group();
		parent.position.set( 1, 2, 3 );
		parent.rotation.set( 0.1, 0.2, 0.3 );
		const helper = new THREE.Box3Helper( boxes[ i ], colors[ i ] );
		parent.add( helper );
		parent.updateMatrixWorld();
		dumpObject( 'box3_' + i, helper );
		boxes[ i ].expandByPoint( v3( - 5, 6, 0.5 ) );
		parent.updateMatrixWorld();
		dumpObject( 'box3_' + i + '.expanded', helper );
		same( 'box3_' + i + '.box', helper.box, boxes[ i ] );
		disposeAll( 'box3_' + i, helper );

	}

	const empty = new THREE.Box3Helper();
	dumpObject( 'box3.none', empty );
	disposeAll( 'box3.none', empty );

}

function boxHelper() {

	const none = new THREE.BoxHelper();
	dumpObject( 'box.none', none );
	const mesh = new THREE.Mesh( new THREE.BoxGeometry( 1, 2, 3 ), new THREE.MeshBasicMaterial() );
	mesh.position.set( 1, 2, 3 );
	mesh.rotation.set( 0.3, 0.5, 0.7 );
	mesh.scale.set( 1, 2, 0.5 );
	mesh.updateMatrixWorld();
	const meshHelper = new THREE.BoxHelper( mesh, 0xff0000 );
	dumpObject( 'box.mesh', meshHelper );
	const group = new THREE.Group();
	const sphere = new THREE.Mesh( new THREE.SphereGeometry( 0.5, 8, 6 ), new THREE.MeshBasicMaterial() );
	sphere.position.set( 2, 0, 0 );
	group.add( sphere );
	const cube = new THREE.Mesh( new THREE.BoxGeometry( 1, 1, 1 ), new THREE.MeshBasicMaterial() );
	cube.position.set( - 1, 1, 0 );
	group.add( cube );
	const line = new THREE.Line( new THREE.BufferGeometry().setFromPoints( [ v3( 0, 0, 0 ), v3( 0, 5, - 4 ) ] ), new THREE.LineBasicMaterial() );
	group.add( line );
	group.rotation.set( 0, 0.7, 0.2 );
	group.updateMatrixWorld();
	const groupHelper = new THREE.BoxHelper( group );
	dumpObject( 'box.group', groupHelper );
	// without an object, update reuses the box of the last update
	const stale = new THREE.BoxHelper();
	dumpObject( 'box.stale', stale );
	mesh.position.set( - 2, 0, 1 );
	mesh.updateMatrixWorld();
	meshHelper.update();
	dumpObject( 'box.moved', meshHelper );
	stale.setFromObject( cube );
	dumpObject( 'box.setFromObject', stale );
	same( 'box.setFromObject.object', stale.object, cube );
	const emptyHelper = new THREE.BoxHelper( new THREE.Object3D() );
	dumpObject( 'box.emptyObject', emptyHelper );
	const after = new THREE.BoxHelper();
	dumpObject( 'box.afterEmpty', after );
	const copy = groupHelper.clone();
	dumpObject( 'box.clone', copy );
	same( 'box.clone.object', copy.object, group );
	none.copy( meshHelper );
	dumpObject( 'box.copy', none );
	same( 'box.copy.object', none.object, mesh );
	disposeAll( 'box.mesh', meshHelper );

}

function cameraCase( l, camera ) {

	camera.position.set( 1, 2, 5 );
	camera.lookAt( 0, 0.5, 0 );
	camera.updateMatrixWorld();
	const helper = new THREE.CameraHelper( camera );
	dumpObject( l, helper );
	same( l + '.matrix', helper.matrix, camera.matrixWorld );
	camera.position.set( - 3, 1, 2 );
	camera.updateMatrixWorld();
	if ( camera.isPerspectiveCamera ) {

		camera.fov = 40;
		camera.near = 0.5;
		camera.updateProjectionMatrix();

	} else if ( camera.isOrthographicCamera ) {

		camera.left = - 3;
		camera.far = 30;
		camera.updateProjectionMatrix();

	}

	helper.update();
	dumpObject( l + '.updated', helper );
	const scene = new THREE.Scene();
	scene.add( helper );
	scene.updateMatrixWorld();
	mat( l + '.scene.matrixWorld', helper.matrixWorld );
	helper.setColors( new THREE.Color( 0x010203 ), new THREE.Color( 0x405060 ), new THREE.Color( 0x708090 ), new THREE.Color( 0xa0b0c0 ), new THREE.Color( 0xd0e0f0 ) );
	dumpGeometry( l + '.colored', helper.geometry );
	disposeAll( l, helper );

}

function cameraHelper() {

	const perspective = [
		[ 50, 1, 0.1, 2000 ], [ 75, 16 / 9, 1, 100 ], [ 30, 0.5, 0.01, 10 ], [ 120, 2, 5, 6 ],
	];
	for ( let i = 0; i < perspective.length; i ++ ) {

		const p = perspective[ i ];
		cameraCase( 'camera.p' + i, new THREE.PerspectiveCamera( p[ 0 ], p[ 1 ], p[ 2 ], p[ 3 ] ) );

	}

	const zoomed = new THREE.PerspectiveCamera( 60, 1.5, 0.3, 40 );
	zoomed.zoom = 2;
	zoomed.filmOffset = 3;
	cameraCase( 'camera.zoomed', zoomed );
	const offset = new THREE.PerspectiveCamera( 45, 1, 1, 20 );
	offset.setViewOffset( 400, 300, 100, 50, 200, 150 );
	cameraCase( 'camera.offset', offset );
	const orthographic = [
		[ - 1, 1, 1, - 1, 0.1, 2000 ], [ - 4, 2, 3, - 1, 0.5, 50 ],
	];
	for ( let i = 0; i < orthographic.length; i ++ ) {

		const p = orthographic[ i ];
		cameraCase( 'camera.o' + i, new THREE.OrthographicCamera( p[ 0 ], p[ 1 ], p[ 2 ], p[ 3 ], p[ 4 ], p[ 5 ] ) );

	}

	const orthoZoom = new THREE.OrthographicCamera( - 2, 2, 1, - 1, 1, 10 );
	orthoZoom.zoom = 0.5;
	cameraCase( 'camera.orthoZoom', orthoZoom );
	cameraCase( 'camera.base', new THREE.Camera() );
	const webgpu = new THREE.PerspectiveCamera( 50, 1.2, 0.5, 30 );
	webgpu.coordinateSystem = THREE.WebGPUCoordinateSystem;
	cameraCase( 'camera.webgpu', webgpu );
	const reversed = new THREE.PerspectiveCamera( 50, 1.2, 0.5, 30 );
	reversed._reversedDepth = true;
	cameraCase( 'camera.reversed', reversed );
	const orthoWebgpu = new THREE.OrthographicCamera( - 2, 2, 1, - 1, 1, 10 );
	orthoWebgpu.coordinateSystem = THREE.WebGPUCoordinateSystem;
	cameraCase( 'camera.orthoWebgpu', orthoWebgpu );
	const light = new THREE.DirectionalLight( 0xffffff, 1 );
	light.position.set( 2, 4, 2 );
	light.updateMatrixWorld();
	const shadowHelper = new THREE.CameraHelper( light.shadow.camera );
	dumpObject( 'camera.shadow', shadowHelper );

}

function directional() {

	const light = new THREE.DirectionalLight( 0xffffff, 1 );
	light.position.set( 1, 2, 3 );
	const helper = new THREE.DirectionalLightHelper( light );
	dumpObject( 'dir0', helper );
	same( 'dir0.matrix', helper.matrix, light.matrixWorld );
	same( 'dir0.material', helper.lightPlane.material, helper.targetLine.material );
	disposeAll( 'dir0', helper );
	const scene = new THREE.Scene();
	const light1 = new THREE.DirectionalLight( 0x00ff00, 2 );
	light1.position.set( 0, 5, 0 );
	light1.target.position.set( 1, 0, 1 );
	scene.add( light1 );
	scene.add( light1.target );
	const helper1 = new THREE.DirectionalLightHelper( light1, 2, 0xff0000 );
	scene.add( helper1 );
	scene.updateMatrixWorld();
	dumpObject( 'dir1', helper1 );
	const group = new THREE.Group();
	group.position.set( 3, - 1, 2 );
	group.rotation.set( 0.4, - 0.3, 0.2 );
	scene.add( group );
	const light2 = new THREE.DirectionalLight( 0x8080ff, 1 );
	light2.position.set( - 2, 3, 1 );
	group.add( light2 );
	const shared = new THREE.Color( 0x336699 );
	const helper2 = new THREE.DirectionalLightHelper( light2, 0.5, shared );
	dumpObject( 'dir2', helper2 );
	shared.setHex( 0x996633 );
	light2.position.set( 4, 4, - 4 );
	light2.target.position.set( 0, - 1, 0 );
	helper2.update();
	dumpObject( 'dir2.updated', helper2 );
	light1.color.setHex( 0x0000ff );
	light1.position.set( 2, 2, 2 );
	helper1.update();
	scene.updateMatrixWorld();
	dumpObject( 'dir1.updated', helper1 );
	const light3 = new THREE.DirectionalLight( 0xffffff, 1 );
	const helper3 = new THREE.DirectionalLightHelper( light3, 0 );
	dumpObject( 'dir3', helper3 );
	disposeAll( 'dir1', helper1 );

}

function hemisphere() {

	const light = new THREE.HemisphereLight( 0x88aaff, 0x553311, 1 );
	light.position.set( 0, 1, 0 );
	const helper = new THREE.HemisphereLightHelper( light );
	dumpObject( 'hemi0', helper );
	same( 'hemi0.material', helper.material, helper.children[ 0 ].material );
	same( 'hemi0.matrix', helper.matrix, light.matrixWorld );
	light.color.setHex( 0xff0000 );
	light.groundColor.setHex( 0x00ff00 );
	light.position.set( 1, 1, 1 );
	helper.update();
	dumpObject( 'hemi0.updated', helper );
	disposeAll( 'hemi0', helper );
	const group = new THREE.Group();
	group.position.set( 1, 2, 3 );
	group.rotation.set( 0.3, 0.2, 0.1 );
	const light1 = new THREE.HemisphereLight( 0x123456, 0x654321, 2 );
	light1.position.set( 3, 4, 5 );
	group.add( light1 );
	const helper1 = new THREE.HemisphereLightHelper( light1, 2, 0x123456 );
	dumpObject( 'hemi1', helper1 );
	group.updateMatrixWorld();
	helper1.update();
	dumpObject( 'hemi1.updated', helper1 );
	const light2 = new THREE.HemisphereLight( 0xffffff, 0x000000, 1 );
	light2.position.set( 0, 0, 0 );
	const helper2 = new THREE.HemisphereLightHelper( light2, 0.5 );
	dumpObject( 'hemi2', helper2 );

}

function point() {

	const light = new THREE.PointLight( 0xffffff, 1 );
	light.position.set( 1, 1, 1 );
	const helper = new THREE.PointLightHelper( light );
	dumpObject( 'point0', helper );
	same( 'point0.matrix', helper.matrix, light.matrixWorld );
	light.color.setHex( 0x00ffff );
	light.position.set( - 1, 2, 0 );
	helper.update();
	dumpObject( 'point0.updated', helper );
	disposeAll( 'point0', helper );
	const group = new THREE.Group();
	group.position.set( 0, 3, 0 );
	group.scale.set( 2, 2, 2 );
	const light1 = new THREE.PointLight( 0xff0000, 2 );
	light1.position.set( 1, 0, 0 );
	group.add( light1 );
	const helper1 = new THREE.PointLightHelper( light1, 0.5, 0xff8800 );
	dumpObject( 'point1', helper1 );
	const scene = new THREE.Scene();
	scene.add( group );
	scene.add( helper1 );
	scene.updateMatrixWorld();
	dumpObject( 'point1.scene', helper1 );
	const helper2 = new THREE.PointLightHelper( light1, 2 );
	dumpObject( 'point2', helper2 );

}

function spot() {

	const light = new THREE.SpotLight( 0xffffff );
	light.position.set( 0, 3, 0 );
	const helper = new THREE.SpotLightHelper( light );
	dumpObject( 'spot0', helper );
	const parent = new THREE.Group();
	parent.position.set( 1, 2, 3 );
	parent.rotation.set( 0.5, 0.1, - 0.2 );
	parent.add( helper );
	helper.update();
	dumpObject( 'spot0.parented', helper );
	disposeAll( 'spot0', helper );
	const scene = new THREE.Scene();
	const light1 = new THREE.SpotLight( 0x00ff00, 1, 5, 0.2 );
	light1.position.set( 1, 2, 3 );
	light1.target.position.set( 0, 0, - 1 );
	scene.add( light1 );
	scene.add( light1.target );
	const helper1 = new THREE.SpotLightHelper( light1, 0xff0000 );
	scene.add( helper1 );
	scene.updateMatrixWorld();
	dumpObject( 'spot1', helper1 );
	light1.distance = NaN;
	light1.angle = 1.2;
	helper1.update();
	dumpObject( 'spot1.nan', helper1 );
	const shared = new THREE.Color( 0x445566 );
	const light2 = new THREE.SpotLight( 0x0000ff, 1, 12, Math.PI / 6 );
	light2.position.set( - 2, 5, 1 );
	const helper2 = new THREE.SpotLightHelper( light2, shared );
	shared.setHex( 0x665544 );
	helper2.update();
	dumpObject( 'spot2', helper2 );

}

function plane() {

	const planes = [
		new THREE.Plane( v3( 0, 1, 0 ), 0 ),
		new THREE.Plane( v3( 1, 1, 0 ).normalize(), 2 ),
		new THREE.Plane( v3( 0, 0, - 1 ), - 1.5 ),
		new THREE.Plane( v3( 0.2, 0.9, - 0.4 ).normalize(), 0.7 ),
	];
	const sizes = [ 1, 3, 1, 0.25 ];
	const colors = [ 0xffff00, 0x00ffff, 0xffff00, 0xff00ff ];
	for ( let i = 0; i < planes.length; i ++ ) {

		const group = new THREE.Group();
		group.position.set( 0.5, - 1, 2 );
		group.rotation.set( 0.2, 0.4, 0.6 );
		const helper = new THREE.PlaneHelper( planes[ i ], sizes[ i ], colors[ i ] );
		group.add( helper );
		group.updateMatrixWorld();
		dumpObject( 'plane' + i, helper );
		planes[ i ].constant += 1.25;
		planes[ i ].normal.set( 0.6, 0, 0.8 );
		helper.size = 2.5;
		group.updateMatrixWorld();
		dumpObject( 'plane' + i + '.mutated', helper );
		disposeAll( 'plane' + i, helper );

	}

	const none = new THREE.PlaneHelper();
	dumpObject( 'plane.none', none );
	const source = new THREE.PlaneHelper( new THREE.Plane( v3( 0, 0, 1 ), 1 ), 2 );
	source.updateMatrixWorld();
	const copy = source.clone();
	dumpObject( 'plane.clone', copy );
	same( 'plane.clone.material', copy.material, source.material );
	disposeAll( 'plane.none', none );

}

function skeleton() {

	const scene = new THREE.Scene();
	const armature = new THREE.Group();
	armature.position.set( 1, 0, 0 );
	armature.rotation.set( 0, 0.3, 0 );
	const root = new THREE.Bone();
	const bone1 = new THREE.Bone();
	bone1.position.set( 0, 1, 0 );
	const bone2 = new THREE.Bone();
	bone2.position.set( 0, 1, 0 );
	bone2.rotation.set( 0, 0, 0.5 );
	const holder = new THREE.Object3D();
	holder.position.set( 0.5, 0.5, 0 );
	const bone3 = new THREE.Bone();
	bone3.position.set( 1, 0, 0 );
	const bone4 = new THREE.Bone();
	bone4.position.set( 0, 0, 2 );
	armature.add( root );
	root.add( bone1 );
	bone1.add( bone2 );
	bone2.add( holder );
	holder.add( bone3 );
	bone3.add( bone4 );
	root.add( new THREE.Bone() );
	scene.add( armature );
	const helper = new THREE.SkeletonHelper( armature );
	scene.add( helper );
	scene.updateMatrixWorld();
	dumpObject( 'skel0', helper );
	same( 'skel0.matrix', helper.matrix, armature.matrixWorld );
	N( 'skel0.bones', helper.bones.length );
	B( 'skel0.flag', helper.isSkeletonHelper );
	bone1.rotation.set( 0.2, 0.4, 0 );
	armature.position.set( - 1, 2, 0 );
	scene.updateMatrixWorld();
	dumpObject( 'skel0.moved', helper );
	helper.setColors( new THREE.Color( 0xff0000 ), new THREE.Color( 0x00ffff ) );
	dumpGeometry( 'skel0.colored', helper.geometry );
	const boneHelper = new THREE.SkeletonHelper( bone1 );
	scene.add( boneHelper );
	scene.updateMatrixWorld();
	dumpObject( 'skel1', boneHelper );
	const skinned = new THREE.SkinnedMesh( new THREE.BoxGeometry( 1, 1, 1 ), new THREE.MeshBasicMaterial() );
	const sroot = new THREE.Bone();
	const stip = new THREE.Bone();
	stip.position.set( 0, 2, 0 );
	sroot.add( stip );
	skinned.add( sroot );
	skinned.bind( new THREE.Skeleton( [ sroot, stip ] ) );
	skinned.position.set( 0, - 1, 1 );
	stip.rotation.set( 0.3, 0, 0 );
	scene.add( skinned );
	const skinnedHelper = new THREE.SkeletonHelper( skinned );
	scene.add( skinnedHelper );
	scene.updateMatrixWorld();
	dumpObject( 'skel2', skinnedHelper );
	disposeAll( 'skel0', helper );

}

export function runUpstream( three ) {

	THREE = three;
	axes();
	grid();
	polarGrid();
	arrow();
	box3();
	boxHelper();
	cameraHelper();
	directional();
	hemisphere();
	point();
	spot();
	plane();
	skeleton();

}
