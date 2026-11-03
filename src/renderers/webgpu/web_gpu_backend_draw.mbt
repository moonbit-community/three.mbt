// WebGPUBackend.js, continued: compute passes, draws and the render pipeline cache keys.

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn begin_compute(
  self,
  backend,
  compute_group,
) {
  let group_gpu = self.get(compute_group.key())
  //
  let label = "computeGroup_" +
    (match compute_group {
      Node(n) => n.id.to_string()
      Nodes(_) => "undefined"
    })
  let cpd = _web_gpu_backend_compute_pass_descriptor
  let ced = _web_gpu_backend_command_encoder_descriptor
  cpd.label = Some(label)
  ced.label = Some(label)
  self.init_timestamp_query(
    @core.TimestampQuery_COMPUTE,
    backend.get_timestamp_uid(compute_group.key()),
    fn(t) { cpd.timestamp_writes = t },
  )
  let cmd_encoder = self.gpu_device().create_command_encoder(descriptor=ced)
  group_gpu.set("cmdEncoderGPU", @core.JsValue::of(cmd_encoder))
  group_gpu.set(
    "passEncoderGPU",
    @core.JsValue::of(cmd_encoder.begin_compute_pass(descriptor=cpd)),
  )
  group_gpu.set("currentPipeline", @core.JsValue::null())
  ced.reset()
  cpd.reset()
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn compute(
  self,
  _,
  compute_group,
  compute_node,
  bindings,
  pipeline,
  dispatch_size,
) {
  let compute_node_data = self.get(@core.JsValue::of(compute_node))
  let group_gpu = self.get(compute_group.key())
  let pass_encoder_gpu : @gpu.GPUComputePassEncoder = group_gpu
    .get("passEncoderGPU")
    .cast()
  // pipeline
  let pipeline_gpu_value = self.get(@core.JsValue::of(pipeline)).get("pipeline")
  if !group_gpu.get("currentPipeline").strict_equal(pipeline_gpu_value) {
    pass_encoder_gpu.set_pipeline(pipeline_gpu_value.cast())
    group_gpu.set("currentPipeline", pipeline_gpu_value)
  }
  // bind groups
  for i = 0; i < bindings.length(); i = i + 1 {
    let bind_group = bindings[i]
    let bindings_data = self.get(@core.JsValue::of(bind_group))
    pass_encoder_gpu.set_bind_group(i, bindings_data.get("group").cast())
  }
  let compute = @nodes.ComputeNode::of(compute_node).unwrap()
  let mut dispatch_size = dispatch_size
  if dispatch_size is None {
    dispatch_size = match compute.dispatch_size {
      Some(d) => Some(d)
      None => compute.count.map(fn(c) { @nodes.ComputeDispatchSize::Count(c) })
    }
  }
  let dispatch : Array[Int32] = match dispatch_size {
    // When the dispatchSize is set with a StorageBuffer from the GPU.
    Some(Indirect(attribute)) => {
      let dispatch_buffer = self.get(@core.JsValue::of(attribute)).get("buffer")
      pass_encoder_gpu.dispatch_workgroups_indirect(dispatch_buffer.cast(), 0)
      return
    }
    Some(Count(count)) => {
      // If a single number is given, we calculate the dispatch size based on the workgroup size
      if compute_node_data.get("dispatchSize").is_undefined() ||
        !compute_node_data.get("count").strict_equal(@core.JsValue::of(count)) {
        // cache dispatch size to avoid recalculating it every time
        compute_node_data.set("count", @core.JsValue::of(count))
        let workgroup_size = compute.workgroup_size
        let mut size = workgroup_size[0]
        for i = 1; i < workgroup_size.length(); i = i + 1 {
          size = size * workgroup_size[i]
        }
        let dispatch_count = wgpu_ceil_div(count, size)
        //
        let max_compute_workgroups_per_dimension = self
          .gpu_device()
          .limits()
          .max_compute_workgroups_per_dimension()
          .to_int()
        let ds = [dispatch_count, 1, 1]
        if dispatch_count > max_compute_workgroups_per_dimension {
          ds[0] = if dispatch_count < max_compute_workgroups_per_dimension {
            dispatch_count
          } else {
            max_compute_workgroups_per_dimension
          }
          ds[1] = wgpu_ceil_div(
            dispatch_count, max_compute_workgroups_per_dimension,
          )
        }
        compute_node_data.set("dispatchSize", @core.JsValue::of(ds))
      }
      compute_node_data.get("dispatchSize").cast()
    }
    Some(Size(size)) => size
    None =>
      abort("TypeError: Cannot read properties of undefined (reading '0')")
  }
  //
  pass_encoder_gpu.dispatch_workgroups(
    dispatch[0],
    workgroup_count_y=if dispatch.length() > 1 && dispatch[1] != 0 {
      dispatch[1]
    } else {
      1
    },
    workgroup_count_z=if dispatch.length() > 2 && dispatch[2] != 0 {
      dispatch[2]
    } else {
      1
    },
  )
}

///|
/// `Math.ceil( a / b )` of positive integers.
fn wgpu_ceil_div(a : Int32, b : Int32) -> Int32 {
  (a.to_double() / b.to_double()).ceil().to_int()
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn finish_compute(
  self,
  _,
  compute_group,
) {
  let group_data = self.get(compute_group.key())
  let pass : @gpu.GPUComputePassEncoder = group_data
    .get("passEncoderGPU")
    .cast()
  pass.end()
  let encoder : @gpu.GPUCommandEncoder = group_data.get("cmdEncoderGPU").cast()
  wgpu_submit(self.gpu_device(), encoder.finish())
}

///|
/// `_draw( renderObject, info, renderContextData, pipelineGPU, bindings, vertexBuffers,
/// drawParams, passEncoderGPU, currentSets, cameraIndexSlot = - 1 )`.
fn WebGPUBackend::_draw(
  self : WebGPUBackend,
  render_object : @nodes.RenderObject,
  info : @nodes.Info,
  render_context_data : @core.JsValue,
  pipeline_gpu : @gpu.GPURenderPipeline,
  bindings : Array[@nodes.BindGroup],
  vertex_buffers : Array[@nodes.AttributeBuffer],
  draw_params : @nodes.DrawParameters,
  pass_encoder_gpu : WebGPUPassEncoder,
  current_sets : WebGPUCurrentSets,
  camera_index_slot~ : Int32 = -1,
) -> Unit {
  let object = render_object.object
  let material = render_object.material
  let context = render_object.context
  let index = render_object.get_index()
  let has_index = index is Some(_)
  // pipeline
  if !@gpu.same_handle(current_sets.pipeline, Some(pipeline_gpu)) {
    pass_encoder_gpu.set_pipeline(pipeline_gpu)
    current_sets.pipeline = Some(pipeline_gpu)
  }
  // bind groups
  let current_binding_groups = current_sets.binding_groups
  for i = 0; i < bindings.length(); i = i + 1 {
    // the camera index slot is bound per sub-camera in draw()
    if i == camera_index_slot {
      continue
    }
    // compare native bind groups
    let bind_group = bindings[i]
    let bind_group_gpu : @gpu.GPUBindGroup = self
      .get(@core.JsValue::of(bind_group))
      .get("group")
      .cast()
    if !@gpu.same_handle(current_binding_groups.get(i), Some(bind_group_gpu)) {
      pass_encoder_gpu.set_bind_group(i, bind_group_gpu)
      current_binding_groups[i] = bind_group_gpu
    }
  }
  // attributes
  // index
  match index {
    Some(index) => {
      let key = wgpu_geometry_attribute_key(index)
      let same = match current_sets.index {
        Some(k) => k.strict_equal(key)
        None => false
      }
      if !same {
        let buffer : @gpu.GPUBuffer = self.get(key).get("buffer").cast()
        let index_format = if index.array().type_name() == "Uint16Array" {
          GPUIndexFormat_Uint16
        } else {
          GPUIndexFormat_Uint32
        }
        pass_encoder_gpu.set_index_buffer(buffer, index_format)
        current_sets.index = Some(key)
      }
    }
    None => ()
  }
  for i = 0; i < vertex_buffers.length(); i = i + 1 {
    let vertex_buffer = vertex_buffers[i]
    let same = match current_sets.attributes.get(i) {
      Some(b) => b.same(vertex_buffer)
      None => false
    }
    if !same {
      let buffer : @gpu.GPUBuffer = self
        .get(vertex_buffer.key())
        .get("buffer")
        .cast()
      pass_encoder_gpu.set_vertex_buffer(i, buffer)
      current_sets.attributes[i] = vertex_buffer
    }
  }
  // stencil
  if context.stencil == true &&
    material.stencil_write == true &&
    !render_context_data
    .get("currentStencilRef")
    .strict_equal(@core.JsValue::of(material.stencil_ref)) {
    match pass_encoder_gpu {
      Pass(p) => p.set_stencil_reference(material.stencil_ref)
      Bundle(_) =>
        abort("TypeError: passEncoderGPU.setStencilReference is not a function")
    }
    render_context_data.set(
      "currentStencilRef",
      @core.JsValue::of(material.stencil_ref),
    )
  }
  // blend constant
  match pass_encoder_gpu {
    Pass(p) if material.blending == @core.CustomBlending => {
      let blend_color = material.blend_color
      let blend_alpha = material.blend_alpha
      let current_blend_color : @math.Color = render_context_data
        .get("currentBlendColor")
        .cast()
      if blend_color.equals(current_blend_color) == false ||
        !render_context_data
        .get("currentBlendAlpha")
        .strict_equal(@core.JsValue::of(blend_alpha)) {
        _web_gpu_backend_blend_constant.r = blend_color.r
        _web_gpu_backend_blend_constant.g = blend_color.g
        _web_gpu_backend_blend_constant.b = blend_color.b
        _web_gpu_backend_blend_constant.a = blend_alpha
        p.set_blend_constant(_web_gpu_backend_blend_constant)
        current_blend_color.copy(blend_color) |> ignore
        render_context_data.set(
          "currentBlendAlpha",
          @core.JsValue::of(blend_alpha),
        )
      }
    }
    _ => ()
  }
  match object.kind {
    Mesh({ kind: BatchedMesh(batched), .. }) => {
      let starts = batched._merged_draw_starts
      let counts = batched._merged_draw_counts
      let instance_counts = batched._merged_draw_instance_counts
      let draw_count = batched._merged_draw_count
      let bytes_per_element = batched._multi_draw_bytes_per_element
      let mut first_instance = 0
      for i = 0; i < draw_count; i = i + 1 {
        let instance_count = instance_counts.get(i).to_int()
        let count = counts.get(i).to_int()
        if has_index == true {
          pass_encoder_gpu.draw_indexed(
            count,
            instance_count,
            (starts.get(i) / bytes_per_element.to_double()).to_int(),
            0,
            first_instance,
          )
        } else {
          pass_encoder_gpu.draw(
            count,
            instance_count,
            starts.get(i).to_int(),
            first_instance,
          )
        }
        info.update(object, count.to_double(), instance_count.to_double())
        first_instance += instance_count
      }
    }
    _ => {
      let vertex_count = draw_params.vertex_count
      let instance_count = draw_params.instance_count
      let first_vertex = draw_params.first_vertex
      match render_object.get_indirect() {
        Some(indirect) => {
          let buffer : @gpu.GPUBuffer = self
            .get(@core.JsValue::of(indirect))
            .get("buffer")
            .cast()
          let indirect_offsets = render_object.get_indirect_offset()
          for offset in indirect_offsets {
            if has_index == true {
              pass_encoder_gpu.draw_indexed_indirect(buffer, offset)
            } else {
              pass_encoder_gpu.draw_indirect(buffer, offset)
            }
          }
        }
        None =>
          if has_index == true {
            pass_encoder_gpu.draw_indexed(
              vertex_count,
              instance_count.to_int(),
              first_vertex,
              0,
              0,
            )
            info.update(object, vertex_count.to_double(), instance_count)
          } else {
            pass_encoder_gpu.draw(
              vertex_count,
              instance_count.to_int(),
              first_vertex,
              0,
            )
            info.update(object, vertex_count.to_double(), instance_count)
          }
      }
    }
  }
}

///|
/// The JS identity of a geometry attribute (`backend.get( index )`).
fn wgpu_geometry_attribute_key(
  attribute : @core.GeometryAttribute,
) -> @core.JsValue {
  match attribute {
    Buffer(a) => @core.JsValue::of(a)
    Interleaved(a) => @core.JsValue::of(a)
    GL(a) => @core.JsValue::of(a)
  }
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn draw(
  self,
  backend,
  render_object,
  info,
) {
  let object = render_object.object
  let context = render_object.context
  let pipeline = render_object.pipeline.unwrap()
  let render_context_data = self.render_context_data(context)
  let pipeline_data = self.get(@core.JsValue::of(pipeline))
  // Skip if pipeline has error
  if pipeline_data.get("error").strict_equal(@core.JsValue::of(true)) {
    return
  }
  let pipeline_gpu : @gpu.GPURenderPipeline = pipeline_data
    .get("pipeline")
    .cast()
  let draw_params = match render_object.get_draw_parameters() {
    Some(p) => p
    None => return
  }
  let bindings = render_object.get_bindings()
  // vertex buffers
  let vertex_buffers = render_object.get_vertex_buffers()
  let camera = render_object.camera
  let cameras = @nodes.camera_sub_cameras(camera)
  if camera.is_array_camera() && cameras.length() > 0 {
    let camera_data = self.get(@core.JsValue::of(camera))
    let camera_index = render_object.get_binding_group("cameraIndex")
    let indexes_gpu : Array[@gpu.GPUBindGroup]? = wgpu_opt(
      camera_data, "indexesGPU",
    )
    let needs_indexes = match indexes_gpu {
      None => true
      Some(a) => a.length() != cameras.length()
    }
    if needs_indexes {
      let bindings_data = self.get(@core.JsValue::of(camera_index.unwrap()))
      let indexes_gpu = []
      let data = @core.TypedArray::uint32([0, 0, 0, 0])
      for i = 0; i < cameras.length(); i = i + 1 {
        data.set(0, i.to_double())
        let layout : WebGPUBindGroupLayout = bindings_data.get("layout").cast()
        let bind_group_index = self.binding_utils.create_bind_group_index(
          data,
          layout.layout_gpu,
        )
        indexes_gpu.push(bind_group_index)
      }
      camera_data.set("indexesGPU", @core.JsValue::of(indexes_gpu)) // TODO: Create a global library for this
    }
    let render_target = context.render_target
    let pixel_ratio = match render_target {
      None => self.renderer().get_pixel_ratio()
      Some(rt) =>
        if @nodes.render_target_props(rt).is_post_processing_render_target ==
          Some(true) {
          self.renderer().get_pixel_ratio()
        } else {
          1.0
        }
    }
    let index_pos = match camera_index {
      Some(ci) => {
        let mut pos = -1
        for i = 0; i < bindings.length(); i = i + 1 {
          if physical_equal(bindings[i], ci) {
            pos = i
            break
          }
        }
        pos
      }
      None => -1
    }
    let frustum_array = context.frustum_array
    let per_camera_frustum_culled = match camera.kind {
      Camera({ kind: PerspectiveCamera({ array_camera: Some(a), .. }), .. }) =>
        a.per_camera_frustum_culled
      _ => true
    }
    for i = 0; i < cameras.length(); i = i + 1 {
      let sub_camera = cameras[i]
      let visible = object.layers.test_(sub_camera.layers) &&
        (
          per_camera_frustum_culled == false ||
          object.frustum_culled == false ||
          object.intersects_frustum(
            Single(frustum_array.unwrap().get_frustum(i).unwrap()),
          )
        )
      if visible {
        let vp = @webgl.camera_viewport(sub_camera)
        let mut pass = wgpu_current_pass(render_context_data)
        let mut sets = if render_context_data.get("currentSets").is_undefined() {
          WebGPUCurrentSets::new()
        } else {
          wgpu_current_sets(render_context_data)
        }
        let is_bundle_encoder = !render_context_data
          .get("bundleEncoders")
          .is_undefined()
        if is_bundle_encoder {
          let bundle_encoder = wgpu_bundle_encoders(render_context_data).unwrap()[i]
          let bundle_sets : Array[WebGPUCurrentSets] = render_context_data
            .get("bundleSets")
            .cast()
          pass = Some(Bundle(bundle_encoder))
          sets = bundle_sets[i]
        }
        // GPURenderBundleEncoder does not support setViewport, only GPURenderPassEncoder does
        match vp {
          Some(vp) if !is_bundle_encoder =>
            pass
            .unwrap()
            .pass("setViewport")
            .set_viewport(
              (vp.x * pixel_ratio).floor(),
              (vp.y * pixel_ratio).floor(),
              (vp.z * pixel_ratio).floor(),
              (vp.w * pixel_ratio).floor(),
              context.viewport_min_depth.unwrap_or(0.0),
              context.viewport_max_depth.unwrap_or(1.0),
            )
          _ => ()
        }
        // Set camera index binding for this layer
        if index_pos != -1 {
          match wgpu_opt(camera_data, "indexesGPU") {
            Some(indexes_gpu) => {
              let indexes_gpu : Array[@gpu.GPUBindGroup] = indexes_gpu
              let camera_index_gpu = indexes_gpu[i]
              if !@gpu.same_handle(
                  sets.binding_groups.get(index_pos),
                  Some(camera_index_gpu),
                ) {
                pass.unwrap().set_bind_group(index_pos, camera_index_gpu)
                sets.binding_groups[index_pos] = camera_index_gpu
              }
            }
            None => ()
          }
        }
        self._draw(
          render_object,
          info,
          render_context_data,
          pipeline_gpu,
          bindings,
          vertex_buffers,
          draw_params,
          pass.unwrap(),
          sets,
          camera_index_slot=index_pos,
        )
      }
    }
  } else {
    // Regular single camera rendering
    match wgpu_current_pass(render_context_data) {
      Some(current_pass) => {
        // Handle occlusion queries
        match current_pass {
          Bundle(_) =>
            if @nodes.occlusion_test(object) == true {
              @core.warn_once(
                "WebGPUBackend: Occlusion queries can not be recorded into render bundles.",
              )
            }
          Pass(pass) =>
            if context.occlusion_query_count > 0 {
              let occlusion_data = backend.get_occlusion_data(context)
              let last_object = occlusion_data.get("lastOcclusionObject")
              if !last_object.strict_equal(@core.JsValue::of(object)) {
                if !last_object.is_null() &&
                  @nodes.occlusion_test(last_object.cast()) == true {
                  pass.end_occlusion_query()
                  let index : Int32 = occlusion_data
                    .get("occlusionQueryIndex")
                    .cast()
                  occlusion_data.set(
                    "occlusionQueryIndex",
                    @core.JsValue::of(index + 1),
                  )
                }
                if @nodes.occlusion_test(object) == true {
                  let index : Int32 = occlusion_data
                    .get("occlusionQueryIndex")
                    .cast()
                  pass.begin_occlusion_query(index)
                  let objects : Array[@core.Object3D?] = occlusion_data
                    .get("occlusionQueryObjects")
                    .cast()
                  if index < objects.length() {
                    objects[index] = Some(object)
                  } else {
                    while objects.length() < index {
                      objects.push(None)
                    }
                    objects.push(Some(object))
                  }
                }
                occlusion_data.set(
                  "lastOcclusionObject",
                  @core.JsValue::of(object),
                )
              }
            }
        }
        self._draw(
          render_object,
          info,
          render_context_data,
          pipeline_gpu,
          bindings,
          vertex_buffers,
          draw_params,
          current_pass,
          wgpu_current_sets(render_context_data),
        )
      }
      None => ()
    }
  }
}

///|
/// A material value as JS sees it (`null` for an absent blend factor).
fn wgpu_opt_int(v : Int32?) -> @core.JsValue {
  match v {
    Some(x) => @core.JsValue::of(x)
    None => @core.JsValue::null()
  }
}

///|
/// An optional string as JS sees it (`undefined` when absent).
fn wgpu_opt_string(v : String?) -> @core.JsValue {
  match v {
    Some(x) => @core.JsValue::of(x)
    None => @core.JsValue::undefined()
  }
}

///|
/// `frontFaceCW` of `needsRenderUpdate` / `getRenderCacheKey`.
fn wgpu_front_face_cw(object : @core.Object3D) -> Bool {
  object.is_mesh() && object.matrix_world.determinant_affine() < 0.0
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn needs_render_update(
  self,
  _,
  render_object,
) {
  let data = self.get(@core.JsValue::of(render_object))
  let object = render_object.object
  let material = render_object.material
  let geometry = render_object.geometry
  let utils = self.utils
  let sample_count = utils.get_sample_count_render_context(
    render_object.context,
  )
  let color_space = utils.get_current_color_space(render_object.context)
  let color_format = utils.get_current_color_format(render_object.context)
  let depth_stencil_format = utils.get_current_depth_stencil_format(
    render_object.context,
  )
  let primitive_topology = utils.get_primitive_topology(object, material)
  let strip_index_format = utils.get_strip_index_format(object, geometry)
  let front_face_cw = wgpu_front_face_cw(object)
  let values : Array[(String, @core.JsValue)] = [
    ("material", @core.JsValue::of(material)),
    ("materialVersion", @core.JsValue::of(material.version)),
    ("transparent", @core.JsValue::of(material.transparent)),
    ("blending", @core.JsValue::of(material.blending)),
    ("premultipliedAlpha", @core.JsValue::of(material.premultiplied_alpha)),
    ("blendSrc", @core.JsValue::of(material.blend_src)),
    ("blendDst", @core.JsValue::of(material.blend_dst)),
    ("blendEquation", @core.JsValue::of(material.blend_equation)),
    ("blendSrcAlpha", wgpu_opt_int(material.blend_src_alpha)),
    ("blendDstAlpha", wgpu_opt_int(material.blend_dst_alpha)),
    ("blendEquationAlpha", wgpu_opt_int(material.blend_equation_alpha)),
    ("colorWrite", @core.JsValue::of(material.color_write)),
    ("depthWrite", @core.JsValue::of(material.depth_write)),
    ("depthTest", @core.JsValue::of(material.depth_test)),
    ("depthFunc", @core.JsValue::of(material.depth_func)),
    ("stencilWrite", @core.JsValue::of(material.stencil_write)),
    ("stencilFunc", @core.JsValue::of(material.stencil_func)),
    ("stencilFail", @core.JsValue::of(material.stencil_fail)),
    ("stencilZFail", @core.JsValue::of(material.stencil_z_fail)),
    ("stencilZPass", @core.JsValue::of(material.stencil_z_pass)),
    ("stencilFuncMask", @core.JsValue::of(material.stencil_func_mask)),
    ("stencilWriteMask", @core.JsValue::of(material.stencil_write_mask)),
    ("polygonOffset", @core.JsValue::of(material.polygon_offset)),
    ("polygonOffsetFactor", @core.JsValue::of(material.polygon_offset_factor)),
    ("polygonOffsetUnits", @core.JsValue::of(material.polygon_offset_units)),
    ("side", @core.JsValue::of(material.side)),
    ("alphaToCoverage", @core.JsValue::of(material.alpha_to_coverage)),
    ("sampleCount", @core.JsValue::of(sample_count)),
    ("colorSpace", wgpu_opt_string(color_space)),
    ("colorFormat", wgpu_opt_string(color_format)),
    ("depthStencilFormat", wgpu_opt_string(depth_stencil_format)),
    ("primitiveTopology", wgpu_opt_string(primitive_topology)),
    ("stripIndexFormat", wgpu_opt_string(strip_index_format)),
    ("frontFaceCW", @core.JsValue::of(front_face_cw)),
    ("geometryVersion", @core.JsValue::of(render_object.geometry_version)),
    (
      "clippingContextCacheKey",
      @core.JsValue::of(render_object.clipping_context_cache_key),
    ),
  ]
  let mut needs_update = false
  for entry in values {
    let (key, value) = entry
    if !data.get(key).strict_equal(value) {
      needs_update = true
      break
    }
  }
  if needs_update {
    for entry in values {
      let (key, value) = entry
      data.set(key, value)
    }
  }
  needs_update
}

///|
pub impl @nodes.BackendClass for WebGPUBackend with fn get_render_cache_key(
  self,
  _,
  render_object,
) {
  let object = render_object.object
  let material = render_object.material
  let geometry = render_object.geometry
  let utils = self.utils
  let render_context = render_object.context
  // meshes with negative scale have a different frontFace render pipeline
  // descriptor value so the following must be honored in the cache key
  let front_face_cw = wgpu_front_face_cw(object)
  wgpu_join([
    @core.JsValue::of(material.transparent),
    @core.JsValue::of(material.blending),
    @core.JsValue::of(material.premultiplied_alpha),
    @core.JsValue::of(material.blend_src),
    @core.JsValue::of(material.blend_dst),
    @core.JsValue::of(material.blend_equation),
    wgpu_opt_int(material.blend_src_alpha),
    wgpu_opt_int(material.blend_dst_alpha),
    wgpu_opt_int(material.blend_equation_alpha),
    @core.JsValue::of(material.color_write),
    @core.JsValue::of(material.depth_write),
    @core.JsValue::of(material.depth_test),
    @core.JsValue::of(material.depth_func),
    @core.JsValue::of(material.stencil_write),
    @core.JsValue::of(material.stencil_func),
    @core.JsValue::of(material.stencil_fail),
    @core.JsValue::of(material.stencil_z_fail),
    @core.JsValue::of(material.stencil_z_pass),
    @core.JsValue::of(material.stencil_func_mask),
    @core.JsValue::of(material.stencil_write_mask),
    @core.JsValue::of(material.polygon_offset),
    @core.JsValue::of(material.polygon_offset_factor),
    @core.JsValue::of(material.polygon_offset_units),
    @core.JsValue::of(material.side),
    @core.JsValue::of(material.alpha_to_coverage),
    @core.JsValue::of(front_face_cw),
    @core.JsValue::of(utils.get_sample_count_render_context(render_context)),
    wgpu_opt_string(utils.get_current_color_space(render_context)),
    wgpu_opt_string(utils.get_current_color_format(render_context)),
    wgpu_opt_string(utils.get_current_depth_stencil_format(render_context)),
    wgpu_opt_string(utils.get_primitive_topology(object, material)),
    wgpu_opt_string(utils.get_strip_index_format(object, geometry)),
    @core.JsValue::of(
      self.attribute_utils.get_vertex_buffer_layout_cache_key(render_object),
    ),
    @core.JsValue::of(render_object.clipping_context_cache_key),
  ])
}
