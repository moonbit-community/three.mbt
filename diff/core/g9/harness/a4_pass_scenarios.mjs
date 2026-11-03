// A4 mock-GPU scenarios, group `pass` (the MoonBit side is ../mbt/a4/pass.mbt, step for
// step): a lit scene rendered through a RenderPipeline whose output is each PassNode
// subclass (PixelationPassNode, RetroPassNode, SSAAPassNode, StereoPassNode,
// AnaglyphPassNode), rendered twice.
const PIXELATION = [ 'tsl/display/PixelationPassNode.js' ];
const RETRO = [ 'tsl/display/RetroPassNode.js' ];
const SSAA = [ 'tsl/display/SSAAPassNode.js' ];
const STEREO = [ 'tsl/display/StereoPassNode.js' ];
const ANAGLYPH = [ 'tsl/display/AnaglyphPassNode.js' ];

function faceTexture( THREE, size, r, g, b ) {
	const data = new Uint8Array( size * size * 4 );
	for ( let i = 0; i < size * size; i ++ ) {
		data[ i * 4 ] = ( i % 2 === 0 ) ? r : Math.floor( r / 2 );
		data[ i * 4 + 1 ] = g;
		data[ i * 4 + 2 ] = b;
		data[ i * 4 + 3 ] = 255;
	}
	const texture = new THREE.DataTexture( data, size, size );
	texture.needsUpdate = true;
	return texture;
}

// a core MeshBasicMaterial box with a map, a core MeshStandardMaterial sphere with an
// envMap and a metalnessMap, and a MeshStandardNodeMaterial plane
function retroScene( THREE ) {
	const scene = new THREE.Scene();
	scene.add( new THREE.AmbientLight( 0x404040, 1 ) );
	const dl = new THREE.DirectionalLight( 0xffffff, 2 );
	dl.position.set( 1, 2, 3 );
	scene.add( dl );
	const basic = new THREE.MeshBasicMaterial();
	basic.color.setHex( 0x88cc44 );
	basic.map = faceTexture( THREE, 2, 255, 128, 64 );
	const box = new THREE.Mesh( new THREE.BoxGeometry(), basic );
	box.position.x = - 0.8;
	box.rotation.set( 0.4, 0.6, 0 );
	scene.add( box );
	const faces = [ 0, 1, 2, 3, 4, 5 ].map( ( i ) => faceTexture( THREE, 2, 40 * i, 255 - 40 * i, 128 ) );
	const cube = new THREE.CubeTexture( faces );
	cube.needsUpdate = true;
	const standard = new THREE.MeshStandardMaterial();
	standard.color.setHex( 0x3366cc );
	standard.metalness = 0.7;
	standard.envMap = cube;
	standard.metalnessMap = faceTexture( THREE, 2, 200, 200, 200 );
	const sphere = new THREE.Mesh( new THREE.SphereGeometry( 0.5, 8, 6 ), standard );
	sphere.position.x = 0.8;
	scene.add( sphere );
	const plane = new THREE.Mesh( new THREE.PlaneGeometry( 4, 4 ), new THREE.MeshStandardNodeMaterial() );
	plane.position.z = - 1;
	scene.add( plane );
	return { scene, basic, standard };
}

export function register( { scenario, renderer, camera, litScene } ) {

	const pipeline = async ( ctx, make ) => {
		const { THREE } = ctx;
		const r = renderer( ctx );
		await r.init();
		const pp = new THREE.RenderPipeline( r );
		pp.outputNode = make( r );
		pp.render();
		pp.render();
		return { r, pp };
	};

	scenario( 'a4_pass_pixelation', PIXELATION, async ( ctx, A ) => {
		await pipeline( ctx, () => A.pixelationPass( litScene( ctx ), camera( ctx ), 2, 0.3, 0.4 ) );
	} );

	scenario( 'a4_pass_pixelation_dispose', PIXELATION, async ( ctx, A ) => {
		const { pp } = await pipeline( ctx, () => A.pixelationPass( litScene( ctx ), camera( ctx ) ) );
		pp.outputNode.dispose();
	} );

	scenario( 'a4_pass_ssaa', SSAA, async ( ctx, A ) => {
		await pipeline( ctx, ( r ) => {
			r.setClearColor( 0x223344, 0.75 );
			const p = A.ssaaPass( litScene( ctx ), camera( ctx ) );
			p.sampleLevel = 2;
			return p;
		} );
	} );

	scenario( 'a4_pass_ssaa_biased_view', SSAA, async ( ctx, A ) => {
		await pipeline( ctx, () => {
			const cam = camera( ctx );
			cam.setViewOffset( 8, 8, 1, 2, 4, 4 );
			const p = A.ssaaPass( litScene( ctx ), cam );
			p.sampleLevel = 1;
			p.unbiased = false;
			return p;
		} );
	} );

	scenario( 'a4_pass_ssaa_mrt', SSAA, async ( ctx, A ) => {
		const { TSL } = ctx;
		await pipeline( ctx, () => {
			const p = A.ssaaPass( litScene( ctx ), camera( ctx ) );
			p.sampleLevel = 0;
			p.setMRT( TSL.mrt( { output: TSL.output, normal: TSL.normalView } ) );
			return p.add( p.getTextureNode( 'normal' ) );
		} );
	} );

	scenario( 'a4_pass_stereo', STEREO, async ( ctx, A ) => {
		await pipeline( ctx, () => A.stereoPass( litScene( ctx ), camera( ctx ) ) );
	} );

	scenario( 'a4_pass_anaglyph', ANAGLYPH, async ( ctx, A ) => {
		await pipeline( ctx, () => A.anaglyphPass( litScene( ctx ), camera( ctx ) ) );
	} );

	scenario( 'a4_pass_anaglyph_modes', ANAGLYPH, async ( ctx, A ) => {
		const { pp } = await pipeline( ctx, () => {
			const p = A.anaglyphPass( litScene( ctx ), camera( ctx ) );
			p.algorithm = A.AnaglyphAlgorithm.HALF_COLOUR;
			p.colorMode = A.AnaglyphColorMode.MAGENTA_CYAN;
			p.eyeSep = 0.1;
			p.planeDistance = 2;
			return p;
		} );
		const p = pp.outputNode;
		for ( const algorithm of [ 'TRUE', 'GREY', 'COLOUR', 'DUBOIS', 'OPTIMISED', 'COMPROMISE' ] ) {
			for ( const mode of [ 'RED_CYAN', 'MAGENTA_GREEN' ] ) {
				p.algorithm = A.AnaglyphAlgorithm[ algorithm ];
				p.colorMode = A.AnaglyphColorMode[ mode ];
				pp.render();
			}
		}
		p.dispose();
	} );

	scenario( 'a4_pass_retro', RETRO, async ( ctx, A ) => {
		const { THREE } = ctx;
		const r = renderer( ctx );
		await r.init();
		const { scene, basic, standard } = retroScene( THREE );
		const pp = new THREE.RenderPipeline( r );
		const p = A.retroPass( scene, camera( ctx ) );
		pp.outputNode = p;
		pp.render();
		pp.render();
		// a new material version replaces (and disposes) the retro material
		basic.needsUpdate = true;
		standard.metalness = 0.2;
		pp.render();
		p.dispose();
	} );

	scenario( 'a4_pass_retro_options', RETRO, async ( ctx, A ) => {
		const { THREE, TSL } = ctx;
		const r = renderer( ctx );
		await r.init();
		const { scene, standard } = retroScene( THREE );
		scene.environment = standard.envMap;
		standard.envMap = null;
		const pp = new THREE.RenderPipeline( r );
		pp.outputNode = A.retroPass( scene, camera( ctx ), { affineDistortion: TSL.uniform( 0.5 ), filterTextures: true } );
		pp.render();
		pp.render();
	} );

}
