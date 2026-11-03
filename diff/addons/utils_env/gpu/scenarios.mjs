// Upstream side of the a6 mock-GPU scenarios: RoomEnvironment through PMREM, and
// WebGPUTextureUtils.decompress. MoonBit side: ../mbt/main/main.mbt.
export const scenarios = {};
const describeTexture = ( t ) => [ t.isCanvasTexture === true, t.minFilter, t.magFilter, t.wrapS, t.wrapT, t.colorSpace, t.name, t.image.__id, t.image.width, t.image.height ];
scenarios.pmrem_room = async ( ctx ) => {
	const { THREE, A } = ctx;
	const r = new THREE.WebGPURenderer( { canvas: ctx.canvas } );
	await r.init();
	const pmrem = new THREE.PMREMGenerator( r );
	const room = new A.RoomEnvironment();
	const target = pmrem.fromScene( room, 0.04, 0.1, 100, { size: 32 } );
	ctx.note( 'target', [ target.width, target.height, target.texture.mapping, target.texture.type ] );
	const scene = new THREE.Scene();
	scene.environment = target.texture;
	const m = new THREE.MeshStandardNodeMaterial();
	m.roughness = 0.3;
	m.metalness = 1;
	scene.add( new THREE.Mesh( new THREE.SphereGeometry( 0.5, 8, 6 ), m ) );
	const cam = new THREE.PerspectiveCamera( 50, 1, 0.1, 10 );
	cam.position.set( 0, 0, 3 );
	r.render( scene, cam );
	room.dispose();
	pmrem.dispose();
};
scenarios.pmrem_color_debug = async ( ctx ) => {
	const { THREE, A } = ctx;
	const r = new THREE.WebGPURenderer( { canvas: ctx.canvas } );
	await r.init();
	const pmrem = new THREE.PMREMGenerator( r );
	const t1 = pmrem.fromScene( new A.ColorEnvironment( 0x8040c0 ), 0, 0.1, 100, { size: 16 } );
	const t2 = pmrem.fromScene( new A.DebugEnvironment(), 0.02, 0.1, 100, { size: 16 } );
	ctx.note( 'targets', [ t1.width, t2.width ] );
};
scenarios.decompress = async ( ctx ) => {
	const { THREE, A } = ctx;
	const data = new Uint8Array( 4 * 2 * 4 );
	for ( let i = 0; i < data.length; i ++ ) data[ i ] = ( i * 7 ) % 256;
	const tex = new THREE.DataTexture( data, 4, 2 );
	tex.colorSpace = THREE.SRGBColorSpace;
	tex.name = 'blit';
	tex.minFilter = THREE.NearestFilter;
	tex.wrapS = THREE.RepeatWrapping;
	tex.needsUpdate = true;
	const r = new THREE.WebGPURenderer( { canvas: ctx.canvas } );
	await r.init();
	try {
		await A.decompress( tex, Infinity, r );
		ctx.note( 'a', 'resolved' );
	} catch ( e ) {
		ctx.note( 'a', String( e.message ) );
	}
	const t = await A.decompress( tex );
	ctx.note( 'b', describeTexture( t ) );
	const t2 = await A.decompress( tex, 2, r );
	ctx.note( 'c', [ ...describeTexture( t2 ), r.outputColorSpace ] );
};
