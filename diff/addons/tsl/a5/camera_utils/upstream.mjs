// Upstream side of src/addons/utils/camera_utils_test.mbt (same cases, same line format).
import { upstreamURL } from '../../../../lib/env.mjs';
const THREE = await import( upstreamURL( 'src/Three.js' ) );
const { frameCorners } = await import( upstreamURL( 'examples/jsm/utils/CameraUtils.js' ) );
const out = [];
const one = ( camera, c, estimate ) => {
	frameCorners( camera, new THREE.Vector3( c[ 0 ], c[ 1 ], c[ 2 ] ), new THREE.Vector3( c[ 3 ], c[ 4 ], c[ 5 ] ), new THREE.Vector3( c[ 6 ], c[ 7 ], c[ 8 ] ), estimate );
	const q = camera.quaternion;
	const v = [ q.x, q.y, q.z, q.w, ...camera.projectionMatrix.elements, ...camera.projectionMatrixInverse.elements, camera.isPerspectiveCamera ? camera.fov : - 1 ];
	out.push( JSON.stringify( v ) );
};
const cornerSets = [
	[ - 1, - 1, - 2, 1, - 1, - 2, - 1, 1, - 2 ],
	[ - 0.5, - 0.3, - 3, 0.7, - 0.2, - 3.1, - 0.4, 0.9, - 2.8 ],
	[ 2, 0, 1, 2, 0, - 1, 2, 1.5, 1 ],
	[ - 3, - 1, 4, - 1, - 1, 5, - 3, 2, 4.5 ],
];
const positions = [ [ 0, 0, 0 ], [ 0.3, - 0.2, 0.5 ], [ - 1, 2, 3 ] ];
for ( const c of cornerSets ) {
	for ( const p of positions ) {
		for ( const estimate of [ false, true ] ) {
			for ( const aspect of [ 0.5, 1, 1.7777777777777777 ] ) {
				const camera = new THREE.PerspectiveCamera( 60, aspect, 0.1, 50 );
				camera.position.set( ...p );
				one( camera, c, estimate );
			}
		}
		const ortho = new THREE.OrthographicCamera( - 1, 1, 1, - 1, 0.5, 20 );
		ortho.position.set( ...p );
		one( ortho, c, true );
	}
}
console.log( out.join( '\n' ) );
