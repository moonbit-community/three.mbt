// Upstream side of the a6 objects mock-GPU scenarios: SkyMesh, WaterMesh (a reflector()
// rendered in its target's onBeforeRender), Water2Mesh (reflector + viewport shared
// texture, flow updated before each render) and LensflareMesh (framebuffer copies and
// renderObject calls in onBeforeRender), rendered by WebGPURenderer. MoonBit side:
// ../mbt/main/main.mbt.
export const scenarios = {};
const dataTexture = ( THREE, w, h, seed ) => {
	const data = new Uint8Array( w * h * 4 );
	for ( let i = 0; i < data.length; i ++ ) data[ i ] = ( i * seed + 3 ) % 256;
	const t = new THREE.DataTexture( data, w, h );
	t.needsUpdate = true;
	return t;
};
const camera = ( THREE, x, y, z ) => {
	const c = new THREE.PerspectiveCamera( 50, 2, 0.1, 1000 );
	c.position.set( x, y, z );
	c.lookAt( 0, 0, 0 );
	return c;
};
scenarios.sky_mesh = async ( ctx ) => {
	const { THREE, A } = ctx;
	const r = new THREE.WebGPURenderer( { canvas: ctx.canvas } );
	await r.init();
	r.toneMapping = THREE.ACESFilmicToneMapping;
	const scene = new THREE.Scene();
	const sky = new A.SkyMesh();
	sky.scale.setScalar( 450 );
	sky.turbidity.value = 8;
	sky.rayleigh.value = 1.5;
	sky.sunPosition.value.setFromSphericalCoords( 1, 1.2, 0.4 );
	sky.cloudCoverage.value = 0.6;
	scene.add( sky );
	ctx.note( 'sky', [ sky.type, sky.isSkyMesh === true, sky.material.side, sky.material.depthWrite, sky.material.fog ] );
	const cam = camera( THREE, 0, 1, 5 );
	r.render( scene, cam );
	sky.showSunDisc.value = 0;
	r.render( scene, cam );
};
scenarios.water_mesh = async ( ctx ) => {
	const { THREE, A } = ctx;
	const r = new THREE.WebGPURenderer( { canvas: ctx.canvas } );
	await r.init();
	const scene = new THREE.Scene();
	scene.background = new THREE.Color( 0x334455 );
	scene.add( new THREE.DirectionalLight( 0xffffff, 2 ) );
	const box = new THREE.Mesh( new THREE.BoxGeometry( 1, 1, 1 ), new THREE.MeshStandardNodeMaterial( { color: 0xcc6633 } ) );
	box.position.set( 0, 1, 0 );
	scene.add( box );
	const normals = dataTexture( THREE, 4, 4, 37 );
	normals.wrapS = normals.wrapT = THREE.RepeatWrapping;
	const water = new A.WaterMesh( new THREE.PlaneGeometry( 20, 20 ), { waterNormals: normals, sunDirection: new THREE.Vector3( 0.3, 0.9, 0.2 ).normalize(), sunColor: 0xffffff, waterColor: 0x001e0f, distortionScale: 3.7, resolutionScale: 0.5 } );
	water.rotation.x = - Math.PI / 2;
	scene.add( water );
	ctx.note( 'water', [ water.type, water.isWaterMesh === true, water.material.transparent, water.resolutionScale ] );
	const cam = camera( THREE, 2, 3, 8 );
	r.render( scene, cam );
	ctx.note( 'children', water.children.map( ( c ) => c.type ) );
	water.distortionScale.value = 1.5;
	r.render( scene, cam );
};
scenarios.water2_mesh = async ( ctx ) => {
	const { THREE, A } = ctx;
	const r = new THREE.WebGPURenderer( { canvas: ctx.canvas } );
	await r.init();
	const scene = new THREE.Scene();
	scene.background = new THREE.Color( 0x223344 );
	scene.add( new THREE.DirectionalLight( 0xffffff, 1 ) );
	const ground = new THREE.Mesh( new THREE.PlaneGeometry( 20, 20 ), new THREE.MeshStandardNodeMaterial( { color: 0x777777 } ) );
	ground.rotation.x = - Math.PI / 2;
	ground.position.y = - 1;
	scene.add( ground );
	const water = new A.Water2Mesh( new THREE.PlaneGeometry( 10, 10 ), { color: 0xaaccff, scale: 4, flowDirection: new THREE.Vector2( 1, 1 ), normalMap0: dataTexture( THREE, 2, 2, 3 ), normalMap1: dataTexture( THREE, 2, 2, 5 ) } );
	water.rotation.x = - Math.PI / 2;
	scene.add( water );
	const flowing = new A.Water2Mesh( new THREE.PlaneGeometry( 4, 4 ), { flowMap: dataTexture( THREE, 2, 2, 7 ), flowSpeed: 2.5, reflectivity: 0.3, normalMap0: dataTexture( THREE, 2, 2, 9 ), normalMap1: dataTexture( THREE, 2, 2, 13 ) } );
	flowing.rotation.x = - Math.PI / 2;
	flowing.position.set( 6, 0.5, 0 );
	scene.add( flowing );
	const cam = camera( THREE, - 4, 5, 8 );
	for ( let frame = 0; frame < 3; frame ++ ) {
		r.render( scene, cam );
		ctx.note( 'flow', [ water.material.colorNode.flowConfig.value.toArray(), flowing.material.colorNode.flowConfig.value.toArray() ] );
	}
};
scenarios.lensflare_mesh = async ( ctx ) => {
	const { THREE, A } = ctx;
	const r = new THREE.WebGPURenderer( { canvas: ctx.canvas } );
	await r.init();
	const scene = new THREE.Scene();
	scene.add( new THREE.DirectionalLight( 0xffffff, 1 ) );
	const box = new THREE.Mesh( new THREE.BoxGeometry( 1, 1, 1 ), new THREE.MeshStandardNodeMaterial( { color: 0x228822 } ) );
	box.position.set( 1, 0, 0 );
	scene.add( box );
	const light = new THREE.Object3D();
	light.position.set( - 0.5, 0.3, - 3 );
	scene.add( light );
	const flare = new A.LensflareMesh();
	flare.addElement( new A.LensflareElement( dataTexture( THREE, 2, 2, 3 ), 32, 0, new THREE.Color( 0xffccaa ) ) );
	flare.addElement( new A.LensflareElement( dataTexture( THREE, 2, 2, 5 ), 12, 0.6 ) );
	flare.addElement( new A.LensflareElement( dataTexture( THREE, 2, 2, 7 ), 20, 1.0, new THREE.Color( 0x3366ff ) ) );
	light.add( flare );
	ctx.note( 'lensflare', [ flare.type, flare.isLensflareMesh === true, flare.frustumCulled, flare.renderOrder, flare.material.opacity, flare.geometry === A.LensflareMesh.Geometry ] );
	const cam = camera( THREE, 0, 0, 5 );
	r.render( scene, cam );
	r.render( scene, cam );
	light.position.set( 0, 0, 8 );
	r.render( scene, cam );
	light.position.set( 0.2, - 0.1, - 2 );
	const target = new THREE.RenderTarget( 48, 24, { type: THREE.HalfFloatType } );
	r.setRenderTarget( target );
	r.render( scene, cam );
	r.setRenderTarget( null );
	r.render( scene, cam );
	flare.dispose();
};
