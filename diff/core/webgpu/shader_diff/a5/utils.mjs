// Group `utils` (src/addons/tsl/a5_utils_shader_diff_test.mbt): tsl/utils and tsl/math.
export const modules = [
	'tsl/utils/SpecularHelpers.js', 'tsl/utils/TAAUtils.js', 'tsl/utils/GroundedSkybox.js', 'tsl/utils/Raymarching.js',
	'tsl/utils/SoftParticles.js', 'tsl/math/Bayer.js', 'tsl/math/curlNoise.js', 'tsl/math/voronoiNoise.js',
	'tsl/utils/RNoise.js',
];

export function scenarios( { T, THREE, A, flow, whole, depthTex } ) {

	const fv = ( v, name ) => T.float( v ).toVar( name );
	const v2 = ( name ) => T.vec2( 0.25, 0.5 ).toVar( name );
	const v3 = ( name ) => T.vec3( 0.1, 0.2, 0.3 ).toVar( name );
	const v4 = ( name ) => T.vec4( 0.1, 0.2, 0.3, 0.4 ).toVar( name );

	flow( 'specular_d_gtr', () => A.D_GTR( fv( 0.5, 'r' ), fv( 0.8, 'h' ), T.float( 2 ) ) );
	flow( 'specular_terms', () => A.F_Schlick( v3( 'f0' ), fv( 0.3, 't' ) )
		.mul( A.GeometryTerm( fv( 0.5, 'l' ), fv( 0.6, 'v' ), 0.4 ) )
		.add( A.F_Schlick( v3( 'f1' ), fv( 0.2, 't2' ), fv( 0.9, 'f90' ) ) )
		.mul( A.SmithG( fv( 0.5, 'x' ), 0.3 ) ), { glsl: true } );
	flow( 'specular_dominant', () => A.getSpecularDominantFactor( fv( 0.5, 'nov' ), fv( 0.3, 'rough' ) ) );
	flow( 'specular_ggx_sample', () => {

		const r = A.ggxReflectionSample( v3( 'n' ), v3( 'v' ), fv( 0.4, 'rough' ), fv( 0.2, 'metal' ), v3( 'albedo' ), v4( 'xi' ) );
		return T.vec4( r.get( 'reflectDir' ), r.get( 'pdf' ) );

	}, { glsl: true } );
	flow( 'specular_ggx_sample_f0', () => {

		const r = A.ggxReflectionSample( v3( 'n' ), v3( 'v' ), fv( 0.4, 'rough' ), fv( 0.2, 'metal' ), v3( 'albedo' ), v4( 'xi' ), v3( 'f0' ), 0.5 );
		return r.get( 'sampleWeight' );

	} );
	flow( 'specular_equirect', () => A.equirectUvToDir( v2( 'uv' ) ).mul( A.equirectDirPdf( v3( 'dir' ) ) ).mul( A.misPowerHeuristic( fv( 1, 'a' ), fv( 2, 'b' ) ) ) );
	flow( 'taa_clip_flicker', () => A.clipAABB( v4( 'c' ), v4( 'h' ), v4( 'mn' ), v4( 'mx' ) ).add( A.flickerReduction( v4( 'c2' ), v4( 'h2' ), fv( 0.1, 'w' ) ) ), { glsl: true } );
	flow( 'taa_sample_depth', () => {

		const r = A.sampleCurrentDepth( T.texture( depthTex( 'depth' ) ), T.vec2( 4, 4 ), T.uniform( new THREE.Vector2( 0.1, 100 ) ) );
		return T.vec4( r.get( 'closestDepth' ), r.get( 'closestPositionTexel' ), r.get( 'farthestDepth' ) );

	} );
	flow( 'taa_previous_depth', () => A.samplePreviousDepth( T.texture( depthTex( 'prev' ) ), T.uv(), T.uniform( new THREE.Matrix4() ), T.uniform( new THREE.Matrix4() ), T.uniform( new THREE.Matrix4() ), T.uniform( new THREE.Vector2( 0.1, 100 ) ), new THREE.PerspectiveCamera() ) );
	flow( 'taa_previous_depth_ortho', () => A.samplePreviousDepth( T.texture( depthTex( 'prev' ) ), T.uv(), T.uniform( new THREE.Matrix4() ), T.uniform( new THREE.Matrix4() ), T.uniform( new THREE.Matrix4() ), T.uniform( new THREE.Vector2( 0.1, 100 ) ), new THREE.OrthographicCamera() ) );
	flow( 'rnoise', () => A.bindAnalyticNoise( T.uniform( new THREE.Vector2( 64, 32 ) ), 3 )( T.uv(), T.int( 2 ) ), { glsl: true } );
	flow( 'rnoise_default_seed', () => A.bindAnalyticNoise( T.vec2( 8, 8 ) )( T.uv(), 1 ) );
	flow( 'grounded_skybox', () => A.getGroundProjectedNormal( T.float( 15 ), T.uniform( 3 ) ), { glsl: true } );
	whole( 'raymarching', () => {

		const m = new THREE.MeshBasicNodeMaterial();
		const color = T.vec4( 0 ).toVar( 'acc' );
		m.fragmentNode = T.Fn( () => {

			A.RaymarchingBox( 8, ( { positionRay, stepSize } ) => {

				color.addAssign( T.vec4( positionRay, stepSize ) );

			} );
			return color;

		} )();
		return m;

	}, { glsl: true } );
	whole( 'soft_particles', () => {

		const m = new THREE.MeshBasicNodeMaterial();
		m.opacityNode = A.softParticles( { distance: T.uniform( 2 ), contrast: 3 } );
		return m;

	} );
	whole( 'soft_particles_default', () => {

		const m = new THREE.MeshBasicNodeMaterial();
		m.opacityNode = A.softParticles( { opacity: T.uniform( 0.5 ) } );
		return m;

	} );
	flow( 'bayer', () => A.bayer16( T.screenCoordinate ).r.add( A.bayerDither( v3( 'c' ) ).x ).add( A.bayerDither( v3( 'c2' ), 8 ).y ), { glsl: true } );
	flow( 'curl_noise', () => A.curlNoise( v3( 'p' ) ), { glsl: true } );
	flow( 'snoise', () => A.snoise( v3( 'p' ) ).add( A.permute( v4( 'x' ) ).x ) );
	flow( 'voronoi', () => A.voronoi2d( v2( 'p' ), T.uniform( 1.5 ) ).add( A.voronoi3d( v3( 'q' ), T.uniform( 0.5 ) ) ).add( A.hash2d( v2( 'h' ) ).x ).add( A.hash3d( v3( 'h3' ) ).y ), { glsl: true } );

}
