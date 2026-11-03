// The WebGPU surface three.js r187 uses, as a binding spec. gen_gpu_bindings.mjs turns it
// into src/renderers/gpu, gen_gpu_mock.mjs into the recording mock, and
// check_gpu_coverage.mjs checks it against gpu_usage.mjs.
//
// Names: `camelCase` -> `snake_case` with digits kept attached (`maxTextureDimension2D` ->
// `max_texture_dimension2d`), MoonBit keywords get `_` (`type_`, `module_`).
//
// Types (MoonBit side): Int, Double, Bool, String, JsValue (@core.JsValue), ArrayBuffer
// (@core.ArrayBuffer), U32 (an Int passed as `v >>> 0`, for u32 masks such as 0xFFFFFFFF),
// Source (any GPUBufferSource: core TypedArray, ArrayBuffer, JsValue), handle types,
// dictionaries, unions, Array[T], T? (nullable). A string-enum value is `String<GPUEnum>`:
// String in MoonBit, checked against `enums` by the mock.
//
// Methods: 'jsName(=moon_name)?(param:Type, opt?:Type) -> Ret'. Parameters the IDL marks
// optional are `name?:Type`: labelled optional arguments, `None` passes `undefined`.
// `-> Promise<T>` generates the callback form `name(..., on_done : (T) -> Unit, ...,
// on_error? : (@core.JsValue) -> Unit)` and the raw `name_promise(...) -> @core.JsValue`.
//
// Properties: 'jsName:Type' (read-only), 'jsName:Type rw', 'jsName:Fn(T) w' (an event
// handler setter), 'jsName:Promise<T>' (callback getter + `_promise`).
//
// Dictionaries: fields 'jsName:Type' (required, plain field) or 'jsName?:Type' (Option field;
// `None` leaves the key out). `to_js` emits the keys in field order, which is upstream's
// order (constructor order for the descriptor classes, literal / assignment order
// elsewhere). `cls` marks the reusable classes of renderers/webgpu/descriptors: they get
// `X::default()` (upstream's `new X()`), `reset()` and `copy()` (`Object.assign( {}, x )`),
// with the defaults written as upstream's JS initializers (`= ''`, `= null`, ...; checked
// against the class sources). Every dictionary gets `X::new(...)`: labelled arguments, one
// per field, like an object literal.

export const handles = [
	[ 'GPU', '`navigator.gpu`.' ],
	[ 'WGSLLanguageFeatures', '`navigator.gpu.wgslLanguageFeatures`.' ],
	[ 'GPUAdapter', '`GPUAdapter`.' ],
	[ 'GPUAdapterInfo', '`GPUAdapterInfo`.' ],
	[ 'GPUSupportedFeatures', '`adapter.features` / `device.features`.' ],
	[ 'GPUSupportedLimits', '`adapter.limits` / `device.limits`.' ],
	[ 'GPUDevice', '`GPUDevice`.' ],
	[ 'GPUQueue', '`device.queue`.' ],
	[ 'GPUBuffer', '`GPUBuffer`.' ],
	[ 'GPUTexture', '`GPUTexture`.' ],
	[ 'GPUTextureView', '`GPUTextureView`.' ],
	[ 'GPUSampler', '`GPUSampler`.' ],
	[ 'GPUExternalTexture', '`GPUExternalTexture`, from `importExternalTexture`.' ],
	[ 'GPUBindGroupLayout', '`GPUBindGroupLayout`.' ],
	[ 'GPUBindGroup', '`GPUBindGroup`.' ],
	[ 'GPUPipelineLayout', '`GPUPipelineLayout`.' ],
	[ 'GPUShaderModule', '`GPUShaderModule`.' ],
	[ 'GPUCompilationInfo', '`GPUCompilationInfo`, from `getCompilationInfo`.' ],
	[ 'GPUCompilationMessage', 'An entry of `GPUCompilationInfo.messages`.' ],
	[ 'GPURenderPipeline', '`GPURenderPipeline`.' ],
	[ 'GPUComputePipeline', '`GPUComputePipeline`.' ],
	[ 'GPUCommandEncoder', '`GPUCommandEncoder`.' ],
	[ 'GPURenderPassEncoder', '`GPURenderPassEncoder`.' ],
	[ 'GPUComputePassEncoder', '`GPUComputePassEncoder`.' ],
	[ 'GPURenderBundleEncoder', '`GPURenderBundleEncoder`.' ],
	[ 'GPURenderBundle', '`GPURenderBundle`.' ],
	[ 'GPUCommandBuffer', '`GPUCommandBuffer`.' ],
	[ 'GPUQuerySet', '`GPUQuerySet`.' ],
	[ 'GPUCanvasContext', 'The `webgpu` context of a canvas.' ],
	[ 'GPUDeviceLostInfo', 'What `device.lost` resolves with.' ],
	[ 'GPUError', '`GPUError` (validation, out-of-memory or internal).' ],
	[ 'GPUUncapturedErrorEvent', 'The event `device.onuncapturederror` receives.' ],
];

// Shared by GPURenderPassEncoder and GPURenderBundleEncoder (GPURenderCommandsMixin).
const renderCommands = [
	'setPipeline(pipeline:GPURenderPipeline)',
	'setBindGroup(index:Int, bind_group:GPUBindGroup)',
	'setIndexBuffer(buffer:GPUBuffer, index_format:String<GPUIndexFormat>, offset?:Int, size?:Int)',
	'setVertexBuffer(slot:Int, buffer:GPUBuffer, offset?:Int, size?:Int)',
	'draw(vertex_count:Int, instance_count?:Int, first_vertex?:Int, first_instance?:Int)',
	'drawIndexed(index_count:Int, instance_count?:Int, first_index?:Int, base_vertex?:Int, first_instance?:Int)',
	'drawIndirect(indirect_buffer:GPUBuffer, indirect_offset:Int)',
	'drawIndexedIndirect(indirect_buffer:GPUBuffer, indirect_offset:Int)',
];

// Default limits of the WebGPU specification (what an adapter must at least support).
export const limits = {
	maxTextureDimension1D: 8192,
	maxTextureDimension2D: 8192,
	maxTextureDimension3D: 2048,
	maxTextureArrayLayers: 256,
	maxBindGroups: 4,
	maxBindGroupsPlusVertexBuffers: 24,
	maxBindingsPerBindGroup: 1000,
	maxDynamicUniformBuffersPerPipelineLayout: 8,
	maxDynamicStorageBuffersPerPipelineLayout: 4,
	maxSampledTexturesPerShaderStage: 16,
	maxSamplersPerShaderStage: 16,
	maxStorageBuffersPerShaderStage: 8,
	maxStorageTexturesPerShaderStage: 4,
	maxUniformBuffersPerShaderStage: 12,
	maxUniformBufferBindingSize: 65536,
	maxStorageBufferBindingSize: 134217728,
	minUniformBufferOffsetAlignment: 256,
	minStorageBufferOffsetAlignment: 256,
	maxVertexBuffers: 8,
	maxBufferSize: 268435456,
	maxVertexAttributes: 16,
	maxVertexBufferArrayStride: 2048,
	maxInterStageShaderVariables: 16,
	maxColorAttachments: 8,
	maxColorAttachmentBytesPerSample: 32,
	maxComputeWorkgroupStorageSize: 16384,
	maxComputeInvocationsPerWorkgroup: 256,
	maxComputeWorkgroupSizeX: 256,
	maxComputeWorkgroupSizeY: 256,
	maxComputeWorkgroupSizeZ: 64,
	maxComputeWorkgroupsPerDimension: 65535,
};

export const interfaces = {
	GPU: {
		methods: [
			'requestAdapter(options?:GPURequestAdapterOptions) -> Promise<GPUAdapter?>',
			'getPreferredCanvasFormat() -> String<GPUTextureFormat>',
		],
		// undefined in browsers that predate WGSL language extensions
		props: [ 'wgslLanguageFeatures:WGSLLanguageFeatures?' ],
	},
	WGSLLanguageFeatures: { methods: [ 'has(name:String) -> Bool' ], props: [] },
	GPUAdapter: {
		methods: [ 'requestDevice(descriptor?:GPUDeviceDescriptor) -> Promise<GPUDevice>' ],
		props: [ 'features:GPUSupportedFeatures', 'limits:GPUSupportedLimits', 'info:GPUAdapterInfo' ],
	},
	GPUAdapterInfo: {
		methods: [],
		props: [ 'vendor:String', 'architecture:String', 'device:String', 'description:String' ],
	},
	GPUSupportedFeatures: { methods: [ 'has(name:String<GPUFeatureName>) -> Bool' ], props: [] },
	// Limits are Double: maxBufferSize and maxStorageBufferBindingSize exceed 2^31 on real GPUs.
	GPUSupportedLimits: { methods: [], props: Object.keys( limits ).map( ( k ) => `${ k }:Double` ) },
	GPUDevice: {
		methods: [
			'destroy()',
			'createBuffer(descriptor:GPUBufferDescriptor) -> GPUBuffer',
			'createTexture(descriptor:GPUTextureDescriptor) -> GPUTexture',
			'createSampler(descriptor?:GPUSamplerDescriptor) -> GPUSampler',
			'importExternalTexture(descriptor:GPUExternalTextureDescriptor) -> GPUExternalTexture',
			'createBindGroupLayout(descriptor:GPUBindGroupLayoutDescriptor) -> GPUBindGroupLayout',
			'createPipelineLayout(descriptor:GPUPipelineLayoutDescriptor) -> GPUPipelineLayout',
			'createBindGroup(descriptor:GPUBindGroupDescriptor) -> GPUBindGroup',
			'createShaderModule(descriptor:GPUShaderModuleDescriptor) -> GPUShaderModule',
			'createComputePipeline(descriptor:GPUComputePipelineDescriptor) -> GPUComputePipeline',
			'createRenderPipeline(descriptor:GPURenderPipelineDescriptor) -> GPURenderPipeline',
			'createComputePipelineAsync(descriptor:GPUComputePipelineDescriptor) -> Promise<GPUComputePipeline>',
			'createRenderPipelineAsync(descriptor:GPURenderPipelineDescriptor) -> Promise<GPURenderPipeline>',
			'createCommandEncoder(descriptor?:GPUCommandEncoderDescriptor) -> GPUCommandEncoder',
			'createRenderBundleEncoder(descriptor:GPURenderBundleEncoderDescriptor) -> GPURenderBundleEncoder',
			'createQuerySet(descriptor:GPUQuerySetDescriptor) -> GPUQuerySet',
			'pushErrorScope(filter:String<GPUErrorFilter>)',
			'popErrorScope() -> Promise<GPUError?>',
		],
		props: [
			'features:GPUSupportedFeatures', 'limits:GPUSupportedLimits', 'queue:GPUQueue',
			'lost:Promise<GPUDeviceLostInfo>', 'onuncapturederror:Fn(GPUUncapturedErrorEvent) w',
			'label:String rw',
		],
	},
	GPUQueue: {
		methods: [
			'submit(command_buffers:Array[GPUCommandBuffer])',
			'onSubmittedWorkDone() -> Promise<Unit>',
			'writeBuffer(buffer:GPUBuffer, buffer_offset:Int, data:Source, data_offset?:Int, size?:Int)',
			'writeTexture(destination:GPUTexelCopyTextureInfo, data:Source, data_layout:GPUTexelCopyBufferLayout, size:GPUExtent3D)',
			'copyExternalImageToTexture(source:GPUCopyExternalImageSourceInfo, destination:GPUCopyExternalImageDestInfo, copy_size:GPUExtent3D)',
		],
		props: [],
	},
	GPUBuffer: {
		methods: [
			'mapAsync(mode:Int, offset?:Int, size?:Int) -> Promise<Unit>',
			'getMappedRange(offset?:Int, size?:Int) -> ArrayBuffer',
			'unmap()',
			'destroy()',
		],
		props: [ 'size:Int', 'usage:Int', 'mapState:String<GPUBufferMapState>', 'label:String rw' ],
	},
	GPUTexture: {
		methods: [
			'createView(descriptor?:GPUTextureViewDescriptor) -> GPUTextureView',
			// XR view descriptors come from the XR runtime as plain objects
			'createView=create_view_js(descriptor:JsValue) -> GPUTextureView',
			'destroy()',
		],
		props: [
			'width:Int', 'height:Int', 'depthOrArrayLayers:Int', 'mipLevelCount:Int', 'sampleCount:Int',
			'dimension:String<GPUTextureDimension>', 'format:String<GPUTextureFormat>', 'usage:Int',
			// compatibility mode only; undefined elsewhere
			'textureBindingViewDimension:String?', 'label:String rw',
		],
	},
	GPUShaderModule: { methods: [ 'getCompilationInfo() -> Promise<GPUCompilationInfo>' ], props: [] },
	GPUCompilationInfo: { methods: [], props: [ 'messages:Array[GPUCompilationMessage]' ] },
	GPUCompilationMessage: {
		methods: [],
		props: [ 'message:String', 'type:String<GPUCompilationMessageType>', 'lineNum:Int', 'linePos:Int', 'offset:Int', 'length:Int' ],
	},
	GPURenderPipeline: { methods: [ 'getBindGroupLayout(index:Int) -> GPUBindGroupLayout' ], props: [] },
	GPUComputePipeline: { methods: [ 'getBindGroupLayout(index:Int) -> GPUBindGroupLayout' ], props: [] },
	GPUCommandEncoder: {
		methods: [
			'beginRenderPass(descriptor:GPURenderPassDescriptor) -> GPURenderPassEncoder',
			'beginComputePass(descriptor?:GPUComputePassDescriptor) -> GPUComputePassEncoder',
			'copyBufferToBuffer(source:GPUBuffer, source_offset:Int, destination:GPUBuffer, destination_offset:Int, size:Int)',
			'copyBufferToTexture(source:GPUTexelCopyBufferInfo, destination:GPUTexelCopyTextureInfo, copy_size:GPUExtent3D)',
			'copyTextureToBuffer(source:GPUTexelCopyTextureInfo, destination:GPUTexelCopyBufferInfo, copy_size:GPUExtent3D)',
			'copyTextureToTexture(source:GPUTexelCopyTextureInfo, destination:GPUTexelCopyTextureInfo, copy_size:GPUExtent3D)',
			'clearBuffer(buffer:GPUBuffer, offset?:Int, size?:Int)',
			'resolveQuerySet(query_set:GPUQuerySet, first_query:Int, query_count:Int, destination:GPUBuffer, destination_offset:Int)',
			'finish(descriptor?:GPUCommandBufferDescriptor) -> GPUCommandBuffer',
		],
		props: [],
	},
	GPURenderPassEncoder: {
		methods: [
			'setViewport(x:Double, y:Double, width:Double, height:Double, min_depth:Double, max_depth:Double)',
			'setScissorRect(x:Int, y:Int, width:Int, height:Int)',
			'setBlendConstant(color:GPUColor)',
			'setStencilReference(reference:U32)',
			'beginOcclusionQuery(query_index:Int)',
			'endOcclusionQuery()',
			'executeBundles(bundles:Array[GPURenderBundle])',
			'end()',
			...renderCommands,
		],
		props: [],
	},
	GPUComputePassEncoder: {
		methods: [
			'setPipeline(pipeline:GPUComputePipeline)',
			'setBindGroup(index:Int, bind_group:GPUBindGroup)',
			'dispatchWorkgroups(workgroup_count_x:Int, workgroup_count_y?:Int, workgroup_count_z?:Int)',
			'dispatchWorkgroupsIndirect(indirect_buffer:GPUBuffer, indirect_offset:Int)',
			'end()',
		],
		props: [],
	},
	GPURenderBundleEncoder: {
		methods: [ ...renderCommands, 'finish(descriptor?:GPURenderBundleDescriptor) -> GPURenderBundle' ],
		props: [],
	},
	GPUQuerySet: { methods: [ 'destroy()' ], props: [ 'type:String<GPUQueryType>', 'count:Int' ] },
	GPUCanvasContext: {
		methods: [
			'configure(configuration:GPUCanvasConfiguration)',
			'unconfigure()',
			'getCurrentTexture() -> GPUTexture',
		],
		props: [ 'canvas:JsValue' ],
	},
	GPUDeviceLostInfo: { methods: [], props: [ 'reason:String<GPUDeviceLostReason>', 'message:String' ] },
	GPUError: { methods: [], props: [ 'message:String' ] },
	GPUUncapturedErrorEvent: { methods: [], props: [ 'error:GPUError' ] },
};

// Upstream's reusable classes in renderers/webgpu/descriptors (plus GPUMultisampleState,
// defined inside GPURenderPipelineDescriptor.js) and the dictionaries built inline.
export const dictionaries = {
	GPURequestAdapterOptions: { fields: [
		'powerPreference?:String<GPUPowerPreference>', 'featureLevel?:String', 'xrCompatible?:Bool',
		'forceFallbackAdapter?:Bool' ] },
	GPUDeviceDescriptor: { fields: [
		'requiredFeatures?:Array[String<GPUFeatureName>]', 'requiredLimits?:JsValue', 'label?:String' ] },
	GPUCanvasConfiguration: { fields: [
		'device:GPUDevice', 'format:String<GPUTextureFormat>', 'usage?:Int',
		'alphaMode?:String<GPUCanvasAlphaMode>', 'toneMapping?:GPUCanvasToneMapping',
		'viewFormats?:Array[String<GPUTextureFormat>]', 'colorSpace?:String<PredefinedColorSpace>' ] },
	GPUCanvasToneMapping: { fields: [ 'mode?:String<GPUCanvasToneMappingMode>' ] },
	GPUBufferDescriptor: { cls: true, fields: [
		'label?:String = \'\'', 'size:Int = 0', 'usage:Int = 0', 'mappedAtCreation?:Bool = false' ] },
	GPUExtent3D: { cls: true, fields: [
		'width:Int = 0', 'height?:Int = 1', 'depthOrArrayLayers?:Int = 1' ] },
	GPUOrigin3D: { fields: [ 'x?:Int', 'y?:Int', 'z?:Int' ] },
	GPUOrigin2D: { fields: [ 'x?:Int', 'y?:Int' ] },
	// GPUColorDict; upstream never passes the array form
	GPUColor: { fields: [ 'r:Double', 'g:Double', 'b:Double', 'a:Double' ] },
	GPUTextureDescriptor: { cls: true, fields: [
		'label?:String = \'\'',
		'size:GPUExtent3D = { width: 0, height: 1, depthOrArrayLayers: 1 }',
		'mipLevelCount?:Int = 1', 'sampleCount?:Int = 1',
		'dimension?:String<GPUTextureDimension> = \'2d\'',
		'format?:String<GPUTextureFormat> = undefined', 'usage?:Int = undefined',
		'viewFormats?:Array[String<GPUTextureFormat>] = []',
		'textureBindingViewDimension?:String<GPUTextureViewDimension> = undefined' ] },
	GPUTextureViewDescriptor: { cls: true, fields: [
		'label?:String = \'\'', 'format?:String<GPUTextureFormat> = undefined',
		'dimension?:String<GPUTextureViewDimension> = undefined', 'usage?:Int = 0',
		'aspect?:String<GPUTextureAspect> = \'all\'', 'baseMipLevel?:Int = 0', 'mipLevelCount?:Int = undefined',
		'baseArrayLayer?:Int = 0', 'arrayLayerCount?:Int = undefined', 'swizzle?:String = \'rgba\'' ] },
	GPUSamplerDescriptor: { cls: true, fields: [
		'label?:String = \'\'',
		'addressModeU?:String<GPUAddressMode> = \'clamp-to-edge\'',
		'addressModeV?:String<GPUAddressMode> = \'clamp-to-edge\'',
		'addressModeW?:String<GPUAddressMode> = \'clamp-to-edge\'',
		'magFilter?:String<GPUFilterMode> = \'nearest\'', 'minFilter?:String<GPUFilterMode> = \'nearest\'',
		'mipmapFilter?:String<GPUMipmapFilterMode> = \'nearest\'',
		'lodMinClamp?:Double = 0', 'lodMaxClamp?:Double = 32',
		'compare?:String<GPUCompareFunction> = undefined', 'maxAnisotropy?:Int = 1' ] },
	GPUExternalTextureDescriptor: { fields: [
		'source:JsValue', 'label?:String', 'colorSpace?:String<PredefinedColorSpace>' ] },
	GPUBindGroupLayoutDescriptor: { fields: [ 'entries:Array[GPUBindGroupLayoutEntry]', 'label?:String' ] },
	GPUBindGroupLayoutEntry: { fields: [
		'binding:Int', 'visibility:Int', 'buffer?:GPUBufferBindingLayout',
		'storageTexture?:GPUStorageTextureBindingLayout', 'texture?:GPUTextureBindingLayout',
		'sampler?:GPUSamplerBindingLayout', 'externalTexture?:GPUExternalTextureBindingLayout' ] },
	GPUBufferBindingLayout: { fields: [
		'type?:String<GPUBufferBindingType>', 'hasDynamicOffset?:Bool', 'minBindingSize?:Int' ] },
	// built from `{}`: every field optional, `format` included
	GPUStorageTextureBindingLayout: { fields: [
		'format?:String<GPUTextureFormat>', 'access?:String<GPUStorageTextureAccess>',
		'viewDimension?:String<GPUTextureViewDimension>' ] },
	GPUTextureBindingLayout: { fields: [
		'multisampled?:Bool', 'sampleType?:String<GPUTextureSampleType>',
		'viewDimension?:String<GPUTextureViewDimension>' ] },
	GPUSamplerBindingLayout: { fields: [ 'type?:String<GPUSamplerBindingType>' ] },
	GPUExternalTextureBindingLayout: { fields: [] },
	GPUBindGroupDescriptor: { cls: true, fields: [
		'label?:String = \'\'', 'layout?:GPUBindGroupLayout = null', 'entries:Array[GPUBindGroupEntry] = []' ] },
	GPUBindGroupEntry: { fields: [ 'binding:Int', 'resource:GPUBindingResource' ] },
	GPUBufferBinding: { fields: [ 'buffer:GPUBuffer', 'offset?:Int', 'size?:Int' ] },
	GPUPipelineLayoutDescriptor: { cls: true, fields: [
		'label?:String = \'\'', 'bindGroupLayouts?:Array[GPUBindGroupLayout] = null' ] },
	GPUShaderModuleDescriptor: { cls: true, fields: [
		'label?:String = \'\'', 'code:String = \'\'', 'compilationHints?:Array[JsValue] = []' ] },
	GPUProgrammableStage: { fields: [ 'module:GPUShaderModule', 'entryPoint?:String', 'constants?:JsValue' ] },
	GPUVertexState: { fields: [
		'module:GPUShaderModule', 'entryPoint?:String', 'constants?:JsValue', 'buffers?:Array[GPUVertexBufferLayout]' ] },
	GPUVertexBufferLayout: { fields: [
		'arrayStride:Int', 'attributes:Array[GPUVertexAttribute]', 'stepMode?:String<GPUVertexStepMode>' ] },
	GPUVertexAttribute: { fields: [ 'shaderLocation:Int', 'offset:Int', 'format:String<GPUVertexFormat>' ] },
	GPUFragmentState: { fields: [
		'module:GPUShaderModule', 'entryPoint?:String', 'constants?:JsValue', 'targets:Array[GPUColorTargetState]' ] },
	GPUColorTargetState: { fields: [ 'format:String<GPUTextureFormat>', 'blend?:GPUBlendState', 'writeMask?:U32' ] },
	GPUBlendState: { fields: [ 'color:GPUBlendComponent', 'alpha:GPUBlendComponent' ] },
	GPUBlendComponent: { fields: [
		'srcFactor?:String<GPUBlendFactor>', 'dstFactor?:String<GPUBlendFactor>', 'operation?:String<GPUBlendOperation>' ] },
	GPUPrimitiveState: { fields: [
		'topology?:String<GPUPrimitiveTopology>', 'stripIndexFormat?:String<GPUIndexFormat>',
		'frontFace?:String<GPUFrontFace>', 'cullMode?:String<GPUCullMode>', 'unclippedDepth?:Bool' ] },
	// built from `{}` by property assignment, in this order
	GPUDepthStencilState: { fields: [
		'format?:String<GPUTextureFormat>', 'depthWriteEnabled?:Bool', 'depthCompare?:String<GPUCompareFunction>',
		'stencilFront?:GPUStencilFaceState', 'stencilBack?:GPUStencilFaceState', 'stencilReadMask?:U32',
		'stencilWriteMask?:U32', 'depthBias?:Int', 'depthBiasSlopeScale?:Double', 'depthBiasClamp?:Double' ] },
	GPUStencilFaceState: { fields: [
		'compare?:String<GPUCompareFunction>', 'failOp?:String<GPUStencilOperation>',
		'depthFailOp?:String<GPUStencilOperation>', 'passOp?:String<GPUStencilOperation>' ] },
	GPUMultisampleState: { cls: true, fields: [
		'count?:Int = 1', 'mask?:U32 = 0xFFFFFFFF', 'alphaToCoverageEnabled?:Bool = false' ] },
	GPURenderPipelineDescriptor: { cls: true, fields: [
		'label?:String = \'\'', 'layout?:GPUPipelineLayoutOrAuto = null', 'vertex?:GPUVertexState = null',
		'primitive?:GPUPrimitiveState = {}', 'depthStencil?:GPUDepthStencilState = undefined',
		'multisample?:GPUMultisampleState = new GPUMultisampleState()', 'fragment?:GPUFragmentState = null' ] },
	GPUComputePipelineDescriptor: { cls: true, fields: [
		'label?:String = \'\'', 'layout?:GPUPipelineLayoutOrAuto = null', 'compute?:GPUProgrammableStage = null' ] },
	GPUCommandEncoderDescriptor: { cls: true, fields: [ 'label?:String = \'\'' ] },
	GPUCommandBufferDescriptor: { fields: [ 'label?:String' ] },
	GPURenderBundleDescriptor: { fields: [ 'label?:String' ] },
	// also the compute pass's timestampWrites: upstream uses this one class for both
	GPURenderPassTimestampWrites: { cls: true, fields: [
		'querySet?:GPUQuerySet = null', 'beginningOfPassWriteIndex?:Int = undefined', 'endOfPassWriteIndex?:Int = undefined' ] },
	GPUComputePassDescriptor: { cls: true, fields: [
		'label?:String = \'\'', 'timestampWrites?:GPURenderPassTimestampWrites = undefined' ] },
	GPURenderPassDescriptor: { cls: true, fields: [
		'label?:String = \'\'', 'colorAttachments:Array[GPURenderPassColorAttachment] = []',
		'depthStencilAttachment?:GPURenderPassDepthStencilAttachment = undefined',
		'occlusionQuerySet?:GPUQuerySet = undefined', 'timestampWrites?:GPURenderPassTimestampWrites = undefined',
		'maxDrawCount?:Int = 50000000' ] },
	GPURenderPassColorAttachment: { cls: true, fields: [
		'view?:GPUTextureView = null', 'depthSlice?:Int = undefined', 'resolveTarget?:GPUTextureView = undefined',
		'clearValue?:GPUColor = undefined', 'loadOp?:String<GPULoadOp> = undefined', 'storeOp?:String<GPUStoreOp> = undefined' ] },
	GPURenderPassDepthStencilAttachment: { cls: true, fields: [
		'view?:GPUTextureView = null', 'depthLoadOp?:String<GPULoadOp> = undefined',
		'depthStoreOp?:String<GPUStoreOp> = undefined', 'depthClearValue?:Double = undefined',
		'depthReadOnly?:Bool = false', 'stencilLoadOp?:String<GPULoadOp> = undefined',
		'stencilStoreOp?:String<GPUStoreOp> = undefined', 'stencilClearValue?:U32 = 0', 'stencilReadOnly?:Bool = false' ] },
	GPURenderBundleEncoderDescriptor: { cls: true, fields: [
		'label?:String = \'\'', 'colorFormats?:Array[String<GPUTextureFormat>] = null',
		'depthStencilFormat?:String<GPUTextureFormat> = undefined', 'sampleCount?:Int = 1',
		'depthReadOnly?:Bool = false', 'stencilReadOnly?:Bool = false' ] },
	GPUQuerySetDescriptor: { cls: true, fields: [
		'label?:String = \'\'', 'type?:String<GPUQueryType> = undefined', 'count:Int = 0' ] },
	GPUTexelCopyBufferLayout: { cls: true, fields: [
		'offset?:Int = 0', 'bytesPerRow?:Int = undefined', 'rowsPerImage?:Int = undefined' ] },
	GPUTexelCopyBufferInfo: { cls: true, fields: [
		'buffer?:GPUBuffer = null', 'offset?:Int = 0', 'bytesPerRow?:Int = undefined', 'rowsPerImage?:Int = undefined' ] },
	GPUTexelCopyTextureInfo: { cls: true, fields: [
		'texture?:GPUTexture = null', 'mipLevel?:Int = 0', 'origin?:GPUOrigin3D = { x: 0, y: 0, z: 0 }',
		'aspect?:String<GPUTextureAspect> = \'all\'' ] },
	GPUCopyExternalImageSourceInfo: { cls: true, fields: [
		'source?:JsValue = null', 'origin?:GPUOrigin2D = { x: 0, y: 0 }', 'flipY?:Bool = false' ] },
	// extends GPUTexelCopyTextureInfo: the superclass fields come first
	GPUCopyExternalImageDestInfo: { cls: true, extends: 'GPUTexelCopyTextureInfo', fields: [
		'texture?:GPUTexture = null', 'mipLevel?:Int = 0', 'origin?:GPUOrigin3D = { x: 0, y: 0, z: 0 }',
		'aspect?:String<GPUTextureAspect> = \'all\'',
		'colorSpace?:String<PredefinedColorSpace> = \'srgb\'', 'premultipliedAlpha?:Bool = false' ] },
};

// Union-typed dictionary members: one MoonBit enum each. A variant is [ name, type ];
// a type in double quotes is a string constant.
export const unions = {
	GPUBindingResource: [
		[ 'Sampler', 'GPUSampler' ], [ 'TextureView', 'GPUTextureView' ], [ 'BufferBinding', 'GPUBufferBinding' ],
		[ 'ExternalTexture', 'GPUExternalTexture' ], [ 'Texture', 'GPUTexture' ], [ 'Buffer', 'GPUBuffer' ] ],
	// `layout: pipelineLayout` or `layout: 'auto'`
	GPUPipelineLayoutOrAuto: [ [ 'Layout', 'GPUPipelineLayout' ], [ 'Auto', '"auto"' ] ],
};

// Flag namespaces; values from the WebGPU specification. `gpu_constants.mbt` has
// `GPU_BUFFER_USAGE_MAP_READ` for `GPUBufferUsage.MAP_READ`, and so on.
export const namespaces = {
	GPUBufferUsage: { MAP_READ: 0x0001, MAP_WRITE: 0x0002, COPY_SRC: 0x0004, COPY_DST: 0x0008, INDEX: 0x0010,
		VERTEX: 0x0020, UNIFORM: 0x0040, STORAGE: 0x0080, INDIRECT: 0x0100, QUERY_RESOLVE: 0x0200 },
	GPUTextureUsage: { COPY_SRC: 0x01, COPY_DST: 0x02, TEXTURE_BINDING: 0x04, STORAGE_BINDING: 0x08,
		RENDER_ATTACHMENT: 0x10, TRANSIENT_ATTACHMENT: 0x20 },
	GPUShaderStage: { VERTEX: 0x1, FRAGMENT: 0x2, COMPUTE: 0x4 },
	GPUMapMode: { READ: 0x0001, WRITE: 0x0002 },
	GPUColorWrite: { RED: 0x1, GREEN: 0x2, BLUE: 0x4, ALPHA: 0x8, ALL: 0xF },
};

// String enums of the WebGPU specification (plus the newer values upstream uses). Bound as
// String; the mock rejects a value outside its enum as browsers do (TypeError).
export const enums = {
	GPUPowerPreference: [ 'low-power', 'high-performance' ],
	GPUFeatureName: [ 'core-features-and-limits', 'depth-clip-control', 'depth32float-stencil8',
		'texture-compression-bc', 'texture-compression-bc-sliced-3d', 'texture-compression-etc2',
		'texture-compression-astc', 'texture-compression-astc-sliced-3d', 'timestamp-query',
		'indirect-first-instance', 'shader-f16', 'rg11b10ufloat-renderable', 'bgra8unorm-storage',
		'float32-filterable', 'float32-blendable', 'clip-distances', 'dual-source-blending', 'subgroups',
		'texture-formats-tier1', 'texture-formats-tier2', 'primitive-index', 'texture-component-swizzle' ],
	GPUBufferMapState: [ 'unmapped', 'pending', 'mapped' ],
	GPUTextureDimension: [ '1d', '2d', '3d' ],
	GPUTextureViewDimension: [ '1d', '2d', '2d-array', 'cube', 'cube-array', '3d' ],
	GPUTextureAspect: [ 'all', 'stencil-only', 'depth-only' ],
	GPUTextureFormat: [ 'r8unorm', 'r8snorm', 'r8uint', 'r8sint', 'r16unorm', 'r16snorm', 'r16uint', 'r16sint',
		'r16float', 'rg8unorm', 'rg8snorm', 'rg8uint', 'rg8sint', 'r32uint', 'r32sint', 'r32float', 'rg16unorm',
		'rg16snorm', 'rg16uint', 'rg16sint', 'rg16float', 'rgba8unorm', 'rgba8unorm-srgb', 'rgba8snorm',
		'rgba8uint', 'rgba8sint', 'bgra8unorm', 'bgra8unorm-srgb', 'rgb9e5ufloat', 'rgb10a2uint', 'rgb10a2unorm',
		'rg11b10ufloat', 'rg32uint', 'rg32sint', 'rg32float', 'rgba16unorm', 'rgba16snorm', 'rgba16uint',
		'rgba16sint', 'rgba16float', 'rgba32uint', 'rgba32sint', 'rgba32float', 'stencil8', 'depth16unorm',
		'depth24plus', 'depth24plus-stencil8', 'depth32float', 'depth32float-stencil8', 'bc1-rgba-unorm',
		'bc1-rgba-unorm-srgb', 'bc2-rgba-unorm', 'bc2-rgba-unorm-srgb', 'bc3-rgba-unorm', 'bc3-rgba-unorm-srgb',
		'bc4-r-unorm', 'bc4-r-snorm', 'bc5-rg-unorm', 'bc5-rg-snorm', 'bc6h-rgb-ufloat', 'bc6h-rgb-float',
		'bc7-rgba-unorm', 'bc7-rgba-unorm-srgb', 'etc2-rgb8unorm', 'etc2-rgb8unorm-srgb', 'etc2-rgb8a1unorm',
		'etc2-rgb8a1unorm-srgb', 'etc2-rgba8unorm', 'etc2-rgba8unorm-srgb', 'eac-r11unorm', 'eac-r11snorm',
		'eac-rg11unorm', 'eac-rg11snorm', 'astc-4x4-unorm', 'astc-4x4-unorm-srgb', 'astc-5x4-unorm',
		'astc-5x4-unorm-srgb', 'astc-5x5-unorm', 'astc-5x5-unorm-srgb', 'astc-6x5-unorm', 'astc-6x5-unorm-srgb',
		'astc-6x6-unorm', 'astc-6x6-unorm-srgb', 'astc-8x5-unorm', 'astc-8x5-unorm-srgb', 'astc-8x6-unorm',
		'astc-8x6-unorm-srgb', 'astc-8x8-unorm', 'astc-8x8-unorm-srgb', 'astc-10x5-unorm', 'astc-10x5-unorm-srgb',
		'astc-10x6-unorm', 'astc-10x6-unorm-srgb', 'astc-10x8-unorm', 'astc-10x8-unorm-srgb', 'astc-10x10-unorm',
		'astc-10x10-unorm-srgb', 'astc-12x10-unorm', 'astc-12x10-unorm-srgb', 'astc-12x12-unorm',
		'astc-12x12-unorm-srgb' ],
	GPUAddressMode: [ 'clamp-to-edge', 'repeat', 'mirror-repeat' ],
	GPUFilterMode: [ 'nearest', 'linear' ],
	GPUMipmapFilterMode: [ 'nearest', 'linear' ],
	GPUCompareFunction: [ 'never', 'less', 'equal', 'less-equal', 'greater', 'not-equal', 'greater-equal', 'always' ],
	GPUBufferBindingType: [ 'uniform', 'storage', 'read-only-storage' ],
	GPUSamplerBindingType: [ 'filtering', 'non-filtering', 'comparison' ],
	GPUTextureSampleType: [ 'float', 'unfilterable-float', 'depth', 'sint', 'uint' ],
	GPUStorageTextureAccess: [ 'write-only', 'read-only', 'read-write' ],
	GPUCompilationMessageType: [ 'error', 'warning', 'info' ],
	GPUPrimitiveTopology: [ 'point-list', 'line-list', 'line-strip', 'triangle-list', 'triangle-strip' ],
	GPUFrontFace: [ 'ccw', 'cw' ],
	GPUCullMode: [ 'none', 'front', 'back' ],
	GPUBlendFactor: [ 'zero', 'one', 'src', 'one-minus-src', 'src-alpha', 'one-minus-src-alpha', 'dst',
		'one-minus-dst', 'dst-alpha', 'one-minus-dst-alpha', 'src-alpha-saturated', 'constant',
		'one-minus-constant', 'src1', 'one-minus-src1', 'src1-alpha', 'one-minus-src1-alpha' ],
	GPUBlendOperation: [ 'add', 'subtract', 'reverse-subtract', 'min', 'max' ],
	GPUStencilOperation: [ 'keep', 'zero', 'replace', 'invert', 'increment-clamp', 'decrement-clamp',
		'increment-wrap', 'decrement-wrap' ],
	GPUIndexFormat: [ 'uint16', 'uint32' ],
	GPUVertexFormat: [ 'uint8', 'uint8x2', 'uint8x4', 'sint8', 'sint8x2', 'sint8x4', 'unorm8', 'unorm8x2',
		'unorm8x4', 'snorm8', 'snorm8x2', 'snorm8x4', 'uint16', 'uint16x2', 'uint16x4', 'sint16', 'sint16x2',
		'sint16x4', 'unorm16', 'unorm16x2', 'unorm16x4', 'snorm16', 'snorm16x2', 'snorm16x4', 'float16',
		'float16x2', 'float16x4', 'float32', 'float32x2', 'float32x3', 'float32x4', 'uint32', 'uint32x2',
		'uint32x3', 'uint32x4', 'sint32', 'sint32x2', 'sint32x3', 'sint32x4', 'unorm10-10-10-2', 'unorm8x4-bgra' ],
	GPUVertexStepMode: [ 'vertex', 'instance' ],
	GPULoadOp: [ 'load', 'clear' ],
	GPUStoreOp: [ 'store', 'discard' ],
	GPUQueryType: [ 'occlusion', 'timestamp' ],
	GPUCanvasAlphaMode: [ 'opaque', 'premultiplied' ],
	GPUCanvasToneMappingMode: [ 'standard', 'extended' ],
	GPUDeviceLostReason: [ 'unknown', 'destroyed' ],
	GPUErrorFilter: [ 'validation', 'out-of-memory', 'internal' ],
	PredefinedColorSpace: [ 'srgb', 'display-p3' ],
};

// Upstream WebGPUConstants.js table -> the WebGPU enum its values belong to (checked by
// check_gpu_coverage.mjs). Numeric tables map to a flag namespace.
export const constantsTables = {
	GPUPrimitiveTopology: 'GPUPrimitiveTopology', GPUCompareFunction: 'GPUCompareFunction',
	GPUStoreOp: 'GPUStoreOp', GPULoadOp: 'GPULoadOp', GPUFrontFace: 'GPUFrontFace', GPUCullMode: 'GPUCullMode',
	GPUIndexFormat: 'GPUIndexFormat', GPUVertexFormat: 'GPUVertexFormat', GPUTextureFormat: 'GPUTextureFormat',
	GPUAddressMode: 'GPUAddressMode', GPUFilterMode: 'GPUFilterMode', GPUBlendFactor: 'GPUBlendFactor',
	GPUBlendOperation: 'GPUBlendOperation', GPUStencilOperation: 'GPUStencilOperation',
	GPUBufferBindingType: 'GPUBufferBindingType', GPUStorageTextureAccess: 'GPUStorageTextureAccess',
	GPUSamplerBindingType: 'GPUSamplerBindingType', GPUTextureSampleType: 'GPUTextureSampleType',
	GPUTextureDimension: 'GPUTextureDimension', GPUTextureViewDimension: 'GPUTextureViewDimension',
	GPUTextureAspect: 'GPUTextureAspect', GPUInputStepMode: 'GPUVertexStepMode', GPUFeatureName: 'GPUFeatureName',
	// keys are three's aliases, values real feature names
	GPUFeatureMap: 'GPUFeatureName',
	GPUShaderStage: 'namespace:GPUShaderStage', GPUColorWriteFlags: 'namespace:GPUColorWrite',
};

// Literal strings found by gpu_usage.mjs (key -> the enum the value must belong to;
// `null` = a DOMString, not an enum).
export const literalEnums = {
	type: [ 'GPUQueryType' ], loadOp: [ 'GPULoadOp' ], storeOp: [ 'GPUStoreOp' ], aspect: [ 'GPUTextureAspect' ],
	dimension: [ 'GPUTextureDimension', 'GPUTextureViewDimension' ], format: [ 'GPUTextureFormat' ],
	alphaMode: [ 'GPUCanvasAlphaMode' ], mode: [ 'GPUCanvasToneMappingMode' ], compare: [ 'GPUCompareFunction' ],
	minFilter: [ 'GPUFilterMode' ], magFilter: [ 'GPUFilterMode' ], mipmapFilter: [ 'GPUMipmapFilterMode' ],
	addressModeU: [ 'GPUAddressMode' ], addressModeV: [ 'GPUAddressMode' ], addressModeW: [ 'GPUAddressMode' ],
	colorSpace: [ 'PredefinedColorSpace' ], layout: [ 'GPUPipelineLayoutOrAuto' ], pushErrorScope: [ 'GPUErrorFilter' ],
	features: [ 'GPUFeatureName' ], mapState: [ 'GPUBufferMapState' ], reason: [ 'GPUDeviceLostReason' ],
	messageType: [ 'GPUCompilationMessageType' ],
	featureLevel: null, swizzle: null, getContext: null, wgslLanguageFeatures: null,
};

// Hand-written bindings in gpu_helpers.mbt for the uses gpu_usage.mjs lists under
// `special` (feature tests, instanceof, BigUint64Array reads, getContext).
export const special = {
	'GPUQueue.copyElementImageToTexture:typeof': 'GPUQueue::has_copy_element_image_to_texture',
	'GPUQueue.copyElementImageToTexture:length': 'GPUQueue::copy_element_image_to_texture_length',
	'GPURenderPassEncoder.setBlendConstant:defined': 'has_set_blend_constant',
	'instanceof:GPURenderBundleEncoder': 'is_render_bundle_encoder',
	'GPUTextureUsage.TRANSIENT_ATTACHMENT:defined': 'has_texture_usage_transient_attachment',
	'GPUError.constructor.name': 'GPUError::type_name',
	'HTMLCanvasElement.getContext:webgpu': 'get_webgpu_context',
	BigUint64Array: 'big_uint64_is_zero',
	'navigator.gpu:defined': 'gpu',
	'GPU.wgslLanguageFeatures:defined': 'GPU::wgsl_language_features',
	'createRenderPipelineAsync:reject': 'error_message',
};

// ---------------------------------------------------------------------------------------
// Spec parsing, shared by the generators and the checker.

const KEYWORDS = new Set( [ 'type', 'module', 'ref', 'method', 'loop', 'match', 'enum', 'struct', 'trait',
	'impl', 'test', 'fn', 'let', 'mut', 'pub', 'priv', 'extern', 'as', 'in', 'with', 'guard', 'try', 'catch',
	'raise', 'async', 'await', 'defer', 'move', 'static', 'super', 'use', 'where', 'virtual', 'yield' ] );

export function snake( name ) {

	return name
		.replace( /([a-z])([A-Z])/g, '$1_$2' )
		.replace( /([A-Z]+)([A-Z][a-z])/g, '$1_$2' )
		.toLowerCase();

}

export function moonIdent( jsName ) {

	const s = snake( jsName );
	return KEYWORDS.has( s ) ? s + '_' : s;

}

// 'String<GPUTextureFormat>' -> { base: 'String', enum: 'GPUTextureFormat', nullable, array }
export function parseType( t ) {

	t = t.trim();
	let nullable = false;
	if ( t.endsWith( '?' ) ) { nullable = true; t = t.slice( 0, - 1 ); }
	const arr = /^Array\[(.+)\]$/.exec( t );
	if ( arr ) return { kind: 'array', elem: parseType( arr[ 1 ] ), nullable, text: t };
	const prom = /^Promise<(.+)>$/.exec( t );
	if ( prom ) return { kind: 'promise', elem: parseType( prom[ 1 ] ), nullable, text: t };
	const fn = /^Fn\((.*)\)$/.exec( t );
	if ( fn ) return { kind: 'fn', arg: parseType( fn[ 1 ] ), nullable, text: t };
	const en = /^(\w+)<(\w+)>$/.exec( t );
	if ( en ) return { kind: 'name', name: en[ 1 ], enum: en[ 2 ], nullable, text: t };
	return { kind: 'name', name: t, nullable, text: t };

}

export function parseMethod( spec ) {

	const m = /^(\w+)(?:=(\w+))?\((.*)\)(?:\s*->\s*(.+))?$/.exec( spec );
	if ( ! m ) throw new Error( 'bad method spec ' + spec );
	const [ , js, moon, params, ret ] = m;
	return {
		js,
		moon: moon || moonIdent( js ),
		params: params.trim() === '' ? [] : params.split( /,\s*(?![^<\[]*[>\]])/ ).map( ( p ) => {

			const pm = /^(\w+)(\?)?:(.+)$/.exec( p.trim() );
			if ( ! pm ) throw new Error( 'bad param ' + p + ' in ' + spec );
			return { name: pm[ 1 ], optional: !! pm[ 2 ], type: parseType( pm[ 3 ] ) };

		} ),
		ret: parseType( ret ? ret.trim() : 'Unit' ),
	};

}

export function parseProp( spec ) {

	const m = /^(\w+)(?:=(\w+))?:(\S+)(?:\s+(rw|w))?$/.exec( spec );
	if ( ! m ) throw new Error( 'bad prop spec ' + spec );
	return { js: m[ 1 ], moon: m[ 2 ] || moonIdent( m[ 1 ] ), type: parseType( m[ 3 ] ), access: m[ 4 ] || 'r' };

}

export function parseField( spec ) {

	const m = /^(\w+)(\?)?:(\S+(?:<\w+>)?)(?:\s*=\s*(.+))?$/.exec( spec );
	if ( ! m ) throw new Error( 'bad field spec ' + spec );
	return { js: m[ 1 ], moon: moonIdent( m[ 1 ] ), optional: !! m[ 2 ], type: parseType( m[ 3 ] ), init: m[ 4 ]?.trim() };

}

export const handleNames = new Set( handles.map( ( [ h ] ) => h ) );

// Methods bound by hand in gpu_helpers.mbt instead of the generator: the HTML-in-canvas
// `copyElementImageToTexture` has two signatures that upstream picks between by the
// function's `length`, and the mock leaves it out (as browsers without the feature do).
export const handWritten = {
	'GPUQueue.copyElementImageToTexture': [ 'GPUQueue::copy_element_image_to_texture', 'GPUQueue::copy_element_image_to_texture_sized' ],
};
