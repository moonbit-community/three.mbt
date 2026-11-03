// Calls the bindings against the recording mock (gpu_mock_gpu_test.mbt, generated from the
// same spec) and checks the logged WebGPU calls. The mock's Promises are synchronous
// thenables, so callbacks have run when the binding returns.

///|
extern "js" fn mock_install(mock : @core.JsValue) -> Unit = "(m) => { m.install(globalThis); }"

///|
extern "js" fn mock_log_text(mock : @core.JsValue) -> String = "(m) => m.logText()"

///|
extern "js" fn mock_clear_log(mock : @core.JsValue) -> Unit = "(m) => { m.log.length = 0; }"

///|
extern "js" fn mock_canvas(mock : @core.JsValue) -> @core.JsValue = "(m) => m.createCanvas({ width: 8, height: 8 })"

///|
/// A fresh mock installed as `navigator.gpu`, and a device from it.
fn setup() -> (@core.JsValue, @gpu.GPUDevice) {
  let mock = ffi_mock_gpu_create(@core.JsValue::object())
  mock_install(mock)
  let device : Ref[@gpu.GPUDevice?] = { val: None, }
  guard @gpu.gpu() is Some(gpu) else { abort("no navigator.gpu") }
  gpu.request_adapter(
    fn(adapter) {
      guard adapter is Some(adapter) else { abort("no adapter") }
      adapter.request_device(
        fn(d) { device.val = Some(d) },
        descriptor=@gpu.GPUDeviceDescriptor::new(
          required_features=["core-features-and-limits", "timestamp-query"],
          required_limits=@core.JsValue::object(),
        ),
      )
    },
    options=@gpu.GPURequestAdapterOptions::new(
      feature_level="compatibility",
      xr_compatible=false,
    ),
  )
  guard device.val is Some(device) else { abort("no device") }
  (mock, device)
}

///|
test "adapter and device come through the callbacks" {
  let (mock, device) = setup()
  inspect(device.features().has("core-features-and-limits"), content="true")
  inspect(device.features().has("timestamp-query"), content="false")
  inspect(
    device.limits().max_compute_workgroups_per_dimension(),
    content="65535",
  )
  inspect(device.limits().max_texture_dimension2d(), content="8192")
  inspect(
    mock_log_text(mock),
    content=(
      #|["GPU#1","requestAdapter",[{"featureLevel":"compatibility","xrCompatible":false}],{"ret":"GPUAdapter#3"}]
      #|["GPUAdapter#3","requestDevice",[{"requiredFeatures":["core-features-and-limits","timestamp-query"],"requiredLimits":{}}],{"ret":"GPUDevice#7"}]
      #|["GPUSupportedFeatures#9","has",["core-features-and-limits"]]
      #|["GPUSupportedFeatures#9","has",["timestamp-query"]]
    ),
  )
}

///|
test "buffers, textures and a render pass are logged with their descriptors" {
  let (mock, device) = setup()
  mock_clear_log(mock)
  // the reusable descriptor, as upstream's `_bufferDescriptor`
  let desc = @gpu.GPUBufferDescriptor::default()
  desc.label = Some("positions")
  desc.size = 16
  desc.usage = @gpu.GPU_BUFFER_USAGE_VERTEX | @gpu.GPU_BUFFER_USAGE_COPY_DST
  desc.mapped_at_creation = Some(true)
  let buffer = device.create_buffer(desc)
  desc.reset()
  let mapped = buffer.get_mapped_range()
  @core.TypedArray::view_by_name("Float32Array", mapped).set_from([
    1.0, 2.0, 3.0, 4.0,
  ])
  buffer.unmap()
  device
  .queue()
  .write_buffer(buffer, 0, @core.TypedArray::float32([5.0, 6.0]), data_offset=0)
  let texture_desc = @gpu.GPUTextureDescriptor::default()
  texture_desc.label = Some("color")
  texture_desc.size.width = 4
  texture_desc.size.height = Some(4)
  texture_desc.format = Some("rgba8unorm")
  texture_desc.usage = Some(
    @gpu.GPU_TEXTURE_USAGE_RENDER_ATTACHMENT | @gpu.GPU_TEXTURE_USAGE_COPY_SRC,
  )
  let texture = device.create_texture(texture_desc)
  inspect(texture.width(), content="4")
  inspect(texture.format(), content="rgba8unorm")
  inspect(texture.texture_binding_view_dimension() is None, content="true")
  let view = texture.create_view(
    descriptor=@gpu.GPUTextureViewDescriptor::new(
      dimension="2d",
      base_array_layer=0,
      array_layer_count=1,
    ),
  )
  let encoder = device.create_command_encoder(
    descriptor=@gpu.GPUCommandEncoderDescriptor::new(label="frame"),
  )
  let attachment = @gpu.GPURenderPassColorAttachment::default()
  attachment.view = Some(view)
  attachment.clear_value = Some(@gpu.GPUColor::new(r=0.0, g=0.0, b=0.0, a=1.0))
  attachment.load_op = Some("clear")
  attachment.store_op = Some("store")
  let pass_desc = @gpu.GPURenderPassDescriptor::default()
  pass_desc.color_attachments.push(attachment)
  let pass = encoder.begin_render_pass(pass_desc)
  pass.set_viewport(0.0, 0.0, 4.0, 4.0, 0.0, 1.0)
  pass.set_vertex_buffer(0, buffer)
  pass.draw(3, instance_count=1, first_vertex=0, first_instance=0)
  pass.end()
  device.queue().submit([encoder.finish()])
  inspect(
    mock_log_text(mock),
    content=(
      #|["GPUDevice#7","createBuffer",[{"label":"positions","size":16,"usage":40,"mappedAtCreation":true}],{"ret":"GPUBuffer#11"}]
      #|["GPUBuffer#11","getMappedRange",[]]
      #|["GPUBuffer#11","unmap",[],{"data":[{"offset":0,"bytes":{"$typed":"ArrayBuffer","values":[0,0,128,63,0,0,0,64,0,0,64,64,0,0,128,64]}}]}]
      #|["GPUQueue#8","writeBuffer",["<GPUBuffer#11>",0,{"$typed":"Float32Array","values":[5,6]},0]]
      #|["GPUDevice#7","createTexture",[{"label":"color","size":{"width":4,"height":4,"depthOrArrayLayers":1},"mipLevelCount":1,"sampleCount":1,"dimension":"2d","format":"rgba8unorm","usage":17,"viewFormats":[]}],{"ret":"GPUTexture#12"}]
      #|["GPUTexture#12","createView",[{"dimension":"2d","baseArrayLayer":0,"arrayLayerCount":1}],{"ret":"GPUTextureView#13"}]
      #|["GPUDevice#7","createCommandEncoder",[{"label":"frame"}],{"ret":"GPUCommandEncoder#14"}]
      #|["GPUCommandEncoder#14","beginRenderPass",[{"label":"","colorAttachments":[{"view":"<GPUTextureView#13>","clearValue":{"r":0,"g":0,"b":0,"a":1},"loadOp":"clear","storeOp":"store"}],"maxDrawCount":50000000}],{"ret":"GPURenderPassEncoder#15"}]
      #|["GPURenderPassEncoder#15","setViewport",[0,0,4,4,0,1]]
      #|["GPURenderPassEncoder#15","setVertexBuffer",[0,"<GPUBuffer#11>"]]
      #|["GPURenderPassEncoder#15","draw",[3,1,0,0]]
      #|["GPURenderPassEncoder#15","end",[]]
      #|["GPUCommandEncoder#14","finish",[],{"ret":"GPUCommandBuffer#16"}]
      #|["GPUQueue#8","submit",[["<GPUCommandBuffer#16>"]]]
    ),
  )
}

///|
test "descriptor defaults match upstream's classes" {
  // JSON.stringify( new GPUXxx() ) of the upstream classes
  inspect(
    @gpu.json_stringify(@gpu.GPUTextureViewDescriptor::default().to_js()),
    content=(
      #|{"label":"","usage":0,"aspect":"all","baseMipLevel":0,"baseArrayLayer":0,"swizzle":"rgba"}
    ),
  )
  inspect(
    @gpu.json_stringify(@gpu.GPUSamplerDescriptor::default().to_js()),
    content=(
      #|{"label":"","addressModeU":"clamp-to-edge","addressModeV":"clamp-to-edge","addressModeW":"clamp-to-edge","magFilter":"nearest","minFilter":"nearest","mipmapFilter":"nearest","lodMinClamp":0,"lodMaxClamp":32,"maxAnisotropy":1}
    ),
  )
  inspect(
    @gpu.json_stringify(@gpu.GPURenderPipelineDescriptor::default().to_js()),
    content=(
      #|{"label":"","primitive":{},"multisample":{"count":1,"mask":4294967295,"alphaToCoverageEnabled":false}}
    ),
  )
  inspect(
    @gpu.json_stringify(@gpu.GPUTexelCopyTextureInfo::default().to_js()),
    content=(
      #|{"mipLevel":0,"origin":{"x":0,"y":0,"z":0},"aspect":"all"}
    ),
  )
  // reset() empties arrays in place, as `entries.length = 0`
  let bind_group = @gpu.GPUBindGroupDescriptor::default()
  let entries = bind_group.entries
  bind_group.label = Some("bindGroup_object")
  let copy = bind_group.copy()
  bind_group.reset()
  inspect(physical_equal(bind_group.entries, entries), content="true")
  inspect(copy.label.unwrap_or("none"), content="bindGroup_object")
}

///|
test "promise methods call back synchronously against the mock" {
  let (mock, device) = setup()
  mock_clear_log(mock)
  let events : Array[String] = []
  device.lost(fn(info) { events.push("lost: \{info.reason()}") })
  device.push_error_scope("validation")
  device.pop_error_scope(fn(err) {
    events.push(
      "error scope: \{err.map(fn(e) { e.message() }).unwrap_or("none")}",
    )
  })
  device.pop_error_scope(fn(_) { events.push("unexpected") }, on_error=fn(e) {
    events.push("rejected: \{@gpu.error_message(e).unwrap_or("?")}")
  })
  let read_desc = @gpu.GPUBufferDescriptor::default()
  read_desc.size = 8
  read_desc.usage = @gpu.GPU_BUFFER_USAGE_MAP_READ |
    @gpu.GPU_BUFFER_USAGE_COPY_DST
  let read_buffer = device.create_buffer(read_desc)
  read_buffer.map_async(
    @gpu.GPU_MAP_MODE_READ,
    fn() {
      events.push(
        "mapped: \{read_buffer.map_state()} \{read_buffer.get_mapped_range(offset=0, size=8).byte_length()}",
      )
    },
    offset=0,
    size=8,
  )
  let shader = device.create_shader_module(
    @gpu.GPUShaderModuleDescriptor::new(
      label="vertex",
      code="@vertex fn main() {}",
    ),
  )
  shader.get_compilation_info(fn(info) {
    events.push("messages: \{info.messages().length()}")
  })
  let pipeline_desc = @gpu.GPURenderPipelineDescriptor::default()
  pipeline_desc.layout = Some(@gpu.GPUPipelineLayoutOrAuto::Auto)
  pipeline_desc.vertex = Some(
    @gpu.GPUVertexState::new(module_=shader, entry_point="main"),
  )
  device.create_render_pipeline_async(pipeline_desc, fn(pipeline) {
    let layout = pipeline.get_bind_group_layout(0)
    ignore(layout)
    events.push("pipeline")
  })
  device.queue().on_submitted_work_done(fn() { events.push("work done") })
  device.destroy()
  inspect(
    events.join("\n"),
    content=(
      #|error scope: none
      #|rejected: OperationError: popErrorScope with an empty error scope stack
      #|mapped: mapped 8
      #|messages: 0
      #|pipeline
      #|work done
      #|lost: destroyed
    ),
  )
  inspect(
    mock_log_text(mock),
    content=(
      #|["GPUDevice#7","pushErrorScope",["validation"]]
      #|["GPUDevice#7","popErrorScope",[]]
      #|["GPUDevice#7","popErrorScope",[]]
      #|["GPUDevice#7","createBuffer",[{"label":"","size":8,"usage":9,"mappedAtCreation":false}],{"ret":"GPUBuffer#11"}]
      #|["GPUBuffer#11","mapAsync",[1,0,8]]
      #|["GPUBuffer#11","getMappedRange",[0,8]]
      #|["GPUDevice#7","createShaderModule",[{"label":"vertex","code":"@vertex fn main() {}"}],{"ret":"GPUShaderModule#12"}]
      #|["GPUShaderModule#12","getCompilationInfo",[],{"ret":"GPUCompilationInfo#13"}]
      #|["GPUDevice#7","createRenderPipelineAsync",[{"label":"","layout":"auto","vertex":{"module":"<GPUShaderModule#12>","entryPoint":"main"},"primitive":{},"multisample":{"count":1,"mask":4294967295,"alphaToCoverageEnabled":false}}],{"ret":"GPURenderPipeline#14"}]
      #|["GPURenderPipeline#14","getBindGroupLayout",[0],{"ret":"GPUBindGroupLayout#15"}]
      #|["GPUQueue#8","onSubmittedWorkDone",[]]
      #|["GPUDevice#7","destroy",[]]
    ),
  )
}

///|
test "canvas context, bind groups and feature tests" {
  let (mock, device) = setup()
  mock_clear_log(mock)
  guard @gpu.get_webgpu_context(mock_canvas(mock)) is Some(context) else {
    abort("no context")
  }
  guard @gpu.gpu() is Some(gpu) else { abort("no gpu") }
  context.configure(
    @gpu.GPUCanvasConfiguration::new(
      device~,
      format=gpu.get_preferred_canvas_format(),
      usage=@gpu.GPU_TEXTURE_USAGE_RENDER_ATTACHMENT |
        @gpu.GPU_TEXTURE_USAGE_COPY_SRC,
      alpha_mode="premultiplied",
      tone_mapping=@gpu.GPUCanvasToneMapping::new(mode="standard"),
    ),
  )
  let current = context.get_current_texture()
  inspect(
    "\{current.width()}x\{current.height()} \{current.format()}",
    content="8x8 bgra8unorm",
  )
  let layout = device.create_bind_group_layout(
    @gpu.GPUBindGroupLayoutDescriptor::new(entries=[
      @gpu.GPUBindGroupLayoutEntry::new(
        binding=0,
        visibility=@gpu.GPU_SHADER_STAGE_VERTEX | @gpu.GPU_SHADER_STAGE_FRAGMENT,
        buffer=@gpu.GPUBufferBindingLayout::new(),
      ),
      @gpu.GPUBindGroupLayoutEntry::new(
        binding=1,
        visibility=@gpu.GPU_SHADER_STAGE_FRAGMENT,
        sampler=@gpu.GPUSamplerBindingLayout::new(type_="filtering"),
      ),
    ]),
  )
  let uniforms = device.create_buffer(
    @gpu.GPUBufferDescriptor::new(
      size=64,
      usage=@gpu.GPU_BUFFER_USAGE_UNIFORM | @gpu.GPU_BUFFER_USAGE_COPY_DST,
    ),
  )
  let sampler = device.create_sampler(
    descriptor=@gpu.GPUSamplerDescriptor::new(min_filter="linear"),
  )
  let group = @gpu.GPUBindGroupDescriptor::default()
  group.layout = Some(layout)
  group.entries.push(
    @gpu.GPUBindGroupEntry::new(
      binding=0,
      resource=BufferBinding(@gpu.GPUBufferBinding::new(buffer=uniforms)),
    ),
  )
  group.entries.push(
    @gpu.GPUBindGroupEntry::new(binding=1, resource=Sampler(sampler)),
  )
  let bind_group = device.create_bind_group(group)
  let bundle_encoder = device.create_render_bundle_encoder(
    @gpu.GPURenderBundleEncoderDescriptor::new(color_formats=["bgra8unorm"]),
  )
  bundle_encoder.set_bind_group(0, bind_group)
  let bundle = bundle_encoder.finish()
  ignore(bundle)
  inspect(
    @gpu.is_render_bundle_encoder(@core.JsValue::of(bundle_encoder)),
    content="true",
  )
  inspect(
    @gpu.has_set_blend_constant(@core.JsValue::of(bundle_encoder)),
    content="false",
  )
  inspect(@gpu.has_texture_usage_transient_attachment(), content="true")
  inspect(device.queue().has_copy_element_image_to_texture(), content="false")
  inspect(
    @gpu.same_handle(Some(context), @gpu.get_webgpu_context(mock_canvas(mock))),
    content="false",
  )
  inspect(
    mock_log_text(mock),
    content=(
      #|["HTMLCanvasElement#11","getContext",["webgpu"],{"ret":"GPUCanvasContext#12"}]
      #|["GPU#1","getPreferredCanvasFormat",[]]
      #|["GPUCanvasContext#12","configure",[{"device":"<GPUDevice#7>","format":"bgra8unorm","usage":17,"alphaMode":"premultiplied","toneMapping":{"mode":"standard"}}]]
      #|["GPUCanvasContext#12","getCurrentTexture",[],{"ret":"GPUTexture#13"}]
      #|["GPUDevice#7","createBindGroupLayout",[{"entries":[{"binding":0,"visibility":3,"buffer":{}},{"binding":1,"visibility":2,"sampler":{"type":"filtering"}}]}],{"ret":"GPUBindGroupLayout#14"}]
      #|["GPUDevice#7","createBuffer",[{"size":64,"usage":72}],{"ret":"GPUBuffer#15"}]
      #|["GPUDevice#7","createSampler",[{"minFilter":"linear"}],{"ret":"GPUSampler#16"}]
      #|["GPUDevice#7","createBindGroup",[{"label":"","layout":"<GPUBindGroupLayout#14>","entries":[{"binding":0,"resource":{"buffer":"<GPUBuffer#15>"}},{"binding":1,"resource":"<GPUSampler#16>"}]}],{"ret":"GPUBindGroup#17"}]
      #|["GPUDevice#7","createRenderBundleEncoder",[{"colorFormats":["bgra8unorm"]}],{"ret":"GPURenderBundleEncoder#18"}]
      #|["GPURenderBundleEncoder#18","setBindGroup",[0,"<GPUBindGroup#17>"]]
      #|["GPURenderBundleEncoder#18","finish",[],{"ret":"GPURenderBundle#19"}]
      #|["HTMLCanvasElement#20","getContext",["webgpu"],{"ret":"GPUCanvasContext#21"}]
    ),
  )
}
