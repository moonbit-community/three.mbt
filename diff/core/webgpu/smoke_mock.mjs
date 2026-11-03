// Direct smoke test of the generated mock: a few WebGPU calls, the log printed.
// Usage: node diff/core/webgpu/smoke_mock.mjs
import { createRequire } from 'node:module';
const require = createRequire( import.meta.url );
const { createMockGPU } = require( './mock_gpu.cjs' );

const mock = createMockGPU( {} );
mock.install( globalThis );
const adapter = await navigator.gpu.requestAdapter( { powerPreference: undefined, featureLevel: 'compatibility' } );
const device = await adapter.requestDevice( { requiredFeatures: [ 'core-features-and-limits', 'timestamp-query' ], requiredLimits: {} } );
console.log( 'device features', [ ...device.features ], 'maxBindGroups', device.limits.maxBindGroups );
class Desc { constructor() { this.label = ''; this.size = 0; this.usage = 0; this.mappedAtCreation = false; this.extra = 1; } }
const d = new Desc(); d.size = 16; d.usage = GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST; d.mappedAtCreation = true;
const buffer = device.createBuffer( d );
new Float32Array( buffer.getMappedRange() ).set( [ 1, 2, 3, 4 ] );
buffer.unmap();
device.queue.writeBuffer( buffer, 0, new Float32Array( [ 5, 6 ] ), 0, undefined );
const texture = device.createTexture( { label: 't', size: { width: 4, height: 4, depthOrArrayLayers: 1 }, format: 'rgba8unorm', usage: GPUTextureUsage.RENDER_ATTACHMENT } );
const view = texture.createView( { dimension: '2d', baseArrayLayer: 0, arrayLayerCount: 1, notAMember: 3 } );
const encoder = device.createCommandEncoder( { label: 'e' } );
const color4 = { isColor: true, r: 0, g: 0, b: 0, a: 1 };
const pass = encoder.beginRenderPass( { colorAttachments: [ { view, depthSlice: undefined, clearValue: color4, loadOp: 'clear', storeOp: 'store' } ] } );
pass.setViewport( 0, 0, 4, 4, 0, 1 );
pass.end();
device.queue.submit( [ encoder.finish() ] );
let threw = null;
try { device.createSampler( { minFilter: 'bogus' } ); } catch ( e ) { threw = e.message; }
console.log( 'enum check:', threw );
const ctx = mock.createCanvas( { width: 8, height: 8 } ).getContext( 'webgpu' );
ctx.configure( { device, format: navigator.gpu.getPreferredCanvasFormat(), usage: 0x11, alphaMode: 'premultiplied', toneMapping: { mode: 'standard' } } );
const t1 = ctx.getCurrentTexture(); const t2 = ctx.getCurrentTexture();
console.log( 'same current texture before submit', t1 === t2, t1.width, t1.format );
device.pushErrorScope( 'validation' );
console.log( 'popErrorScope', await device.popErrorScope() );
const rb = device.createBuffer( { size: 8, usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST } );
await rb.mapAsync( GPUMapMode.READ, 0, 8 );
console.log( 'mapState', rb.mapState, rb.getMappedRange( 0, 8 ).byteLength );
console.log( 'instanceof', pass instanceof GPURenderPassEncoder, device.createRenderBundleEncoder( { colorFormats: [ 'bgra8unorm' ] } ) instanceof GPURenderBundleEncoder );
console.log( mock.logText() );
