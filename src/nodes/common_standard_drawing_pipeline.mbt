// renderers/common/StandardDrawingPipeline.js: frustum culling and render list
// building. Custom drawing pipelines (a subclass in JS) override members through
// `DrawingPipelineClass`; each default is the standard body.

///|
let _standard_drawing_pipeline_vector4 : @math.Vector4 = @math.Vector4::new(
  0.0, 0.0, 0.0, 0.0,
)

///|
/// The overridable members of a drawing pipeline.
pub(open) trait DrawingPipelineClass {
  /// `prepareAsync( scene, camera )`: calls back when prepared (at once when there is
  /// nothing to prepare, as upstream's `undefined` result).
  fn prepare_async(
    Self,
    StandardDrawingPipeline,
    @core.Object3D,
    @core.Object3D,
    () -> Unit,
  ) -> Unit = _
  /// `dispose()`.
  fn dispose(Self, StandardDrawingPipeline) -> Unit = _
  /// `begin( camera, renderContext )`.
  fn begin(Self, StandardDrawingPipeline, @core.Object3D, RenderContext) -> Unit = _
  /// `beginRenderList( renderList )`.
  fn begin_render_list(Self, StandardDrawingPipeline, RenderList) -> Unit = _
  /// `finishRenderList( renderList )`.
  fn finish_render_list(Self, StandardDrawingPipeline, RenderList) -> Unit = _
  /// `isCulled( object, camera )`.
  fn is_culled(Self, StandardDrawingPipeline, @core.Object3D, @core.Object3D) -> Bool = _
  /// `pushRenderItem( renderList, object, geometry, material, groupOrder, z, group,
  /// clippingContext )`.
  fn push_render_item(
    Self,
    StandardDrawingPipeline,
    RenderList,
    @core.Object3D,
    @core.BufferGeometry,
    @core.Material,
    Int32,
    Double,
    @core.GeometryGroup?,
    ClippingContext?,
  ) -> Unit = _
  /// `project( object, camera, groupOrder, renderList, clippingContext )`.
  fn project(
    Self,
    StandardDrawingPipeline,
    @core.Object3D,
    @core.Object3D,
    Int32,
    RenderList,
    ClippingContext?,
  ) -> Unit = _
}

///|
impl DrawingPipelineClass with fn prepare_async(_, _, _, _, on_done) {
  on_done()
}

///|
impl DrawingPipelineClass with fn dispose(_, _) {

}

///|
impl DrawingPipelineClass with fn begin(_, pipeline, camera, render_context) {
  pipeline.begin_base(camera, render_context)
}

///|
impl DrawingPipelineClass with fn begin_render_list(_, _, render_list) {
  render_list.begin() |> ignore
}

///|
impl DrawingPipelineClass with fn finish_render_list(_, _, render_list) {
  render_list.finish()
}

///|
impl DrawingPipelineClass with fn is_culled(_, pipeline, object, camera) {
  pipeline.is_culled_base(object, camera)
}

///|
impl DrawingPipelineClass with fn push_render_item(
  _,
  _,
  render_list,
  object,
  geometry,
  material,
  group_order,
  z,
  group,
  clipping_context,
) {
  render_list.push(
    object, geometry, material, group_order, z, group, clipping_context,
  )
}

///|
impl DrawingPipelineClass with fn project(
  _,
  pipeline,
  object,
  camera,
  group_order,
  render_list,
  clipping_context,
) {
  pipeline.project_base(
    object, camera, group_order, render_list, clipping_context,
  )
}

///|
/// The class of a plain `new StandardDrawingPipeline()`.
priv struct BaseDrawingPipeline {}

///|
impl DrawingPipelineClass for BaseDrawingPipeline

///|
/// The renderer's drawing pipeline.
pub(all) struct StandardDrawingPipeline {
  mut class_ : &DrawingPipelineClass
  /// Set by `renderer.drawingPipeline = pipeline`.
  mut renderer : Renderer?
  _frustum : @math.Frustum
  mut _frustum_array : @math.FrustumArray?
  _proj_screen_matrix : @math.Matrix4
  mut _bundle_depth : Int32
}

///|
/// `new StandardDrawingPipeline()`; subclasses pass their class.
pub fn StandardDrawingPipeline::new(
  class_? : &DrawingPipelineClass,
) -> StandardDrawingPipeline {
  {
    class_: match class_ {
      Some(c) => c
      None => BaseDrawingPipeline::{ }
    },
    renderer: None,
    _frustum: @math.Frustum::new(),
    _frustum_array: None,
    _proj_screen_matrix: @math.Matrix4::new(),
    _bundle_depth: 0,
  }
}

///|
pub fn StandardDrawingPipeline::prepare_async(
  self : StandardDrawingPipeline,
  scene : @core.Object3D,
  camera : @core.Object3D,
  on_done : () -> Unit,
) -> Unit {
  self.class_.prepare_async(self, scene, camera, on_done)
}

///|
pub fn StandardDrawingPipeline::dispose(self : StandardDrawingPipeline) -> Unit {
  self.class_.dispose(self)
}

///|
pub fn StandardDrawingPipeline::begin(
  self : StandardDrawingPipeline,
  camera : @core.Object3D,
  render_context : RenderContext,
) -> Unit {
  self.class_.begin(self, camera, render_context)
}

///|
/// `StandardDrawingPipeline.prototype.begin`.
pub fn StandardDrawingPipeline::begin_base(
  self : StandardDrawingPipeline,
  camera : @core.Object3D,
  render_context : RenderContext,
) -> Unit {
  self._proj_screen_matrix.multiply_matrices(
    camera.projection_matrix(),
    camera.matrix_world_inverse(),
  )
  |> ignore
  if camera.is_array_camera() {
    // the frustums of the sub-cameras are kept per render context, the backends cull the draws of each sub-camera with them
    let frustum_array = match render_context.frustum_array {
      Some(f) => f
      None => {
        let f = @math.FrustumArray::new()
        render_context.frustum_array = Some(f)
        f
      }
    }
    @core.frustum_array_set_from_array_camera(frustum_array, camera) |> ignore
    self._frustum_array = Some(frustum_array)
  } else {
    let c = camera.as_camera()
    self._frustum.set_from_projection_matrix(
      self._proj_screen_matrix,
      coordinate_system=c.coordinate_system,
      reversed_depth=camera.reversed_depth(),
    )
    |> ignore
  }
}

///|
pub fn StandardDrawingPipeline::begin_render_list(
  self : StandardDrawingPipeline,
  render_list : RenderList,
) -> Unit {
  self.class_.begin_render_list(self, render_list)
}

///|
pub fn StandardDrawingPipeline::finish_render_list(
  self : StandardDrawingPipeline,
  render_list : RenderList,
) -> Unit {
  self.class_.finish_render_list(self, render_list)
}

///|
pub fn StandardDrawingPipeline::is_culled(
  self : StandardDrawingPipeline,
  object : @core.Object3D,
  camera : @core.Object3D,
) -> Bool {
  self.class_.is_culled(self, object, camera)
}

///|
/// `StandardDrawingPipeline.prototype.isCulled`.
pub fn StandardDrawingPipeline::is_culled_base(
  self : StandardDrawingPipeline,
  object : @core.Object3D,
  camera : @core.Object3D,
) -> Bool {
  if !object.frustum_culled || self._bundle_depth > 0 {
    return false
  }
  let frustum : @core.FrustumRef = if camera.is_array_camera() {
    match self._frustum_array {
      Some(f) => Array(f)
      None =>
        abort(
          "TypeError: Cannot read properties of null (reading 'intersectsObject')",
        )
    }
  } else {
    Single(self._frustum)
  }
  !object.intersects_frustum(frustum)
}

///|
pub fn StandardDrawingPipeline::push_render_item(
  self : StandardDrawingPipeline,
  render_list : RenderList,
  object : @core.Object3D,
  geometry : @core.BufferGeometry,
  material : @core.Material,
  group_order : Int32,
  z : Double,
  group : @core.GeometryGroup?,
  clipping_context : ClippingContext?,
) -> Unit {
  self.class_.push_render_item(
    self, render_list, object, geometry, material, group_order, z, group, clipping_context,
  )
}

///|
pub fn StandardDrawingPipeline::project(
  self : StandardDrawingPipeline,
  object : @core.Object3D,
  camera : @core.Object3D,
  group_order : Int32,
  render_list : RenderList,
  clipping_context : ClippingContext?,
) -> Unit {
  self.class_.project(
    self, object, camera, group_order, render_list, clipping_context,
  )
}

///|
/// `StandardDrawingPipeline.prototype.project`: walks the scene graph and fills the
/// render list.
pub fn StandardDrawingPipeline::project_base(
  self : StandardDrawingPipeline,
  object : @core.Object3D,
  camera : @core.Object3D,
  group_order : Int32,
  render_list : RenderList,
  clipping_context : ClippingContext?,
) -> Unit {
  if object.visible == false {
    return
  }
  let renderer = self.renderer.unwrap()
  let mut group_order = group_order
  let mut clipping_context = clipping_context
  let visible = object.layers.test_(camera.layers)
  if visible {
    if object.is_group() {
      // `renderOrder` is a number; a group order is an integer in practice
      group_order = object.render_order.to_int()
      match object.kind {
        ClippingGroup(g) if g.enabled =>
          clipping_context = Some(
            clipping_context.unwrap().get_group_context(object),
          )
        _ => ()
      }
    } else if object.is_lod() {
      match object.kind {
        LOD(lod) if lod.auto_update == true => object.update(camera)
        _ => ()
      }
    } else if object.is_light() {
      render_list.push_light(object)
    } else if object.is_sprite() {
      if self.is_culled(object, camera) == false {
        if renderer.sort_objects == true {
          _standard_drawing_pipeline_vector4
          .set_from_matrix_position(object.matrix_world)
          .apply_matrix4(self._proj_screen_matrix)
          |> ignore
        }
        let geometry = object.get_geometry().unwrap()
        match object.get_material() {
          Some(Single(material)) =>
            if material.visible {
              self.push_render_item(
                render_list,
                object,
                geometry,
                material,
                group_order,
                _standard_drawing_pipeline_vector4.z,
                None,
                clipping_context,
              )
            }
          _ => ()
        }
      }
    } else if object.is_line_loop() {
      @core.error(
        "Renderer: Objects of type THREE.LineLoop are not supported. Please use THREE.Line or THREE.LineSegments.",
      )
    } else if object.is_mesh() || object.is_line() || object.is_points() {
      if self.is_culled(object, camera) == false {
        let geometry = object.get_geometry().unwrap()
        if renderer.sort_objects == true {
          if geometry.bounding_sphere is None {
            geometry.compute_bounding_sphere()
          }
          _standard_drawing_pipeline_vector4.set(0.0, 0.0, 0.0, 1.0) |> ignore
          let center = geometry.bounding_sphere.unwrap().center
          _standard_drawing_pipeline_vector4.x = center.x
          _standard_drawing_pipeline_vector4.y = center.y
          _standard_drawing_pipeline_vector4.z = center.z
          _standard_drawing_pipeline_vector4
          .apply_matrix4(object.matrix_world)
          .apply_matrix4(self._proj_screen_matrix)
          |> ignore
        }
        match object.get_material() {
          Some(Multiple(materials)) => {
            let groups = geometry.groups
            for i in 0..<groups.length() {
              let group = groups[i]
              match materials.get(group.material_index) {
                Some(group_material) if group_material.visible =>
                  self.push_render_item(
                    render_list,
                    object,
                    geometry,
                    group_material,
                    group_order,
                    _standard_drawing_pipeline_vector4.z,
                    Some(group),
                    clipping_context,
                  )
                _ => ()
              }
            }
          }
          Some(Single(material)) =>
            if material.visible {
              self.push_render_item(
                render_list,
                object,
                geometry,
                material,
                group_order,
                _standard_drawing_pipeline_vector4.z,
                None,
                clipping_context,
              )
            }
          None => ()
        }
      }
    }
  }
  if BundleGroup::of(object) is Some(bundle_group) &&
    renderer.backend.has_bundles() {
    let base_render_list = render_list
    // replace render list
    let render_list = renderer
      ._render_lists()
      .get(object, camera, renderer.lighting)
    let render_bundle = renderer
      ._bundles()
      .get(object, camera, renderer._current_render_context.unwrap())
    let render_bundle_data = renderer.backend.get(
      @core.JsValue::of(render_bundle),
    )
    let render_bundle_needs_update = renderer._bundle_needs_update(
      bundle_group, render_bundle_data,
    )
    if render_bundle_needs_update {
      // update render list if necessary
      self.begin_render_list(render_list)
      if render_bundle_data.get("renderObjects").is_undefined() {
        render_bundle_data.set(
          "renderObjects",
          @core.JsValue::of(js_new_array()),
        )
      } else {
        js_array_clear(render_bundle_data.get("renderObjects"))
      }
      let children = object.children
      self._bundle_depth += 1
      for i in 0..<children.length() {
        self.project(
          children[i],
          camera,
          group_order,
          render_list,
          clipping_context,
        )
      }
      self._bundle_depth -= 1
      self.finish_render_list(render_list)
    }
    base_render_list.push_bundle({ bundle_group: object, camera, render_list, })
    return
  }
  //
  let children = object.children
  for i in 0..<children.length() {
    self.project(
      children[i],
      camera,
      group_order,
      render_list,
      clipping_context,
    )
  }
}

///|
extern "js" fn js_array_clear(array : @core.JsValue) -> Unit = "(a) => { a.length = 0; }"
