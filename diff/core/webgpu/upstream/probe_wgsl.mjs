// Probe: upstream WGSL + GLSL generation in Node without a GPU (node upstream/probe_wgsl.mjs).
import { upstreamURL } from '../../../lib/env.mjs';
const SRC = upstreamURL( 'src' );
const THREE = await import( SRC + '/Three.WebGPU.js' );
const { WGSLNodeBuilder, GLSLNodeBuilder, Mesh, BoxGeometry, MeshBasicNodeMaterial, PerspectiveCamera, Scene, WebGPURenderer, TSL } = THREE;
const canvas = { style: {}, width: 300, height: 150, addEventListener() {}, removeEventListener() {}, getContext() { return null; } };
const renderer = new WebGPURenderer( { canvas } );
renderer._bindings = undefined;
const mesh = new Mesh( new BoxGeometry(), new MeshBasicNodeMaterial() );
mesh.material.colorNode = TSL.vec3( 1, 0, 0 ).mul( TSL.uv().x );
const scene = new Scene(); scene.add( mesh );
const camera = new PerspectiveCamera();
for ( const B of [ WGSLNodeBuilder, GLSLNodeBuilder ] ) {
	const builder = new B( mesh, renderer );
	builder.scene = scene; builder.camera = camera; builder.material = mesh.material;
	builder.lightsNode = renderer.lighting.getNode( scene, camera );
	try { builder.build(); console.log( builder.vertexShader.length, builder.fragmentShader.length ); console.log( builder.fragmentShader.slice( 0, 4000 ) ); }
	catch ( e ) { console.log( B.name, 'failed:', e.stack.split( '\n' ).slice( 0, 6 ).join( '\n' ) ); }
}
