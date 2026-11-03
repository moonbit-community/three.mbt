// materials/nodes/Line2NodeMaterial.js: the node material of `Line2`/`LineSegments2`
// (wide lines from instanced quads).

///|
let line2_node_material_defaults : @core.Material = @core.LineDashedMaterial::new()

///|
let line2_world_start : Node = module_nodes(
  "materials/nodes/Line2NodeMaterial.js:worldStart",
  fn() { varying_property("vec3", name="worldStart") },
)

///|
let line2_world_end : Node = module_nodes(
  "materials/nodes/Line2NodeMaterial.js:worldEnd",
  fn() { varying_property("vec3", name="worldEnd") },
)

///|
let line2_line_distance : Node = module_nodes(
  "materials/nodes/Line2NodeMaterial.js:lineDistance",
  fn() { varying_property("float", name="lineDistance") },
)

///|
let line2_world_pos : Node = module_nodes(
  "materials/nodes/Line2NodeMaterial.js:worldPos",
  fn() { varying_property("vec4", name="worldPos") },
)

///|
/// `trimSegmentAlpha( { start, end } )`.
let line2_trim_segment_alpha : Node = module_nodes(
  "materials/nodes/Line2NodeMaterial.js:trimSegmentAlpha",
  fn() {
    fn_(
      fn(inputs, _) {
        let start = inputs.named("start").unwrap()
        let end = inputs.named("end").unwrap()
        let a = camera_projection_matrix.element(2).element(2) // 3nd entry in 3th column
        let b = camera_projection_matrix.element(3).element(2) // 3nd entry in 4th column
        // we need different nearEstimate formula for reversed and default depth buffer
        // a is positive with a reversed depth buffer so it can be used for controlling the
        // code flow
        let near_estimate = a
          .greater_than(0)
          .select(b.negate().div(a.add(1)), else_node=b.mul(-0.5).div(a))
        Some(near_estimate.sub(start.z()).div(end.z().sub(start.z())))
      },
      layout=FnLayout::short(
        [("start", "vec4"), ("end", "vec4")],
        return_="float",
        upstream="materials/nodes/Line2NodeMaterial.js:trimSegmentAlpha",
      ),
    )
  },
)

///|
/// `closestLineToLine( { p1, p2, p3, p4 } )`.
let line2_closest_line_to_line : Node = module_nodes(
  "materials/nodes/Line2NodeMaterial.js:closestLineToLine",
  fn() {
    fn_(
      fn(inputs, _) {
        let p1 = inputs.named("p1").unwrap()
        let p2 = inputs.named("p2").unwrap()
        let p3 = inputs.named("p3").unwrap()
        let p4 = inputs.named("p4").unwrap()
        let p13 = p1.sub(p3)
        let p43 = p4.sub(p3)
        let p21 = p2.sub(p1)
        let d1343 = p13.dot(p43)
        let d4321 = p43.dot(p21)
        let d1321 = p13.dot(p21)
        let d4343 = p43.dot(p43)
        let d2121 = p21.dot(p21)
        let denom = d2121.mul(d4343).sub(d4321.mul(d4321))
        let numer = d1343.mul(d4321).sub(d1321.mul(d4343))
        let mua = numer.div(denom).clamp()
        let mub = d1343.add(d4321.mul(mua)).div(d4343).clamp()
        Some(vec2_of([mua, mub]))
      },
      layout=FnLayout::short(
        [("p1", "vec3"), ("p2", "vec3"), ("p3", "vec3"), ("p4", "vec3")],
        return_="vec2",
        upstream="materials/nodes/Line2NodeMaterial.js:closestLineToLine",
      ),
    )
  },
)

///|
/// The `Line2NodeMaterial` payload of `builder.material`.
fn line2_builder_payload(builder : NodeBuilder) -> Line2NodeMaterial {
  match Line2NodeMaterial::of(node_material_builder_material(builder)) {
    Some(p) => p
    None => abort("TypeError: builder.material is not a Line2NodeMaterial")
  }
}

///|
/// `mvpLine`: the clip-space position of a line vertex.
let line2_mvp_line : Node = module_nodes(
  "materials/nodes/Line2NodeMaterial.js:mvpLine",
  fn() {
    fn_(fn(_, builder) {
      let material = line2_builder_payload(builder)
      let use_dash = material._use_dash == Some(true)
      let use_world_units = material._use_world_units
      let instance_start = attribute("instanceStart")
      let instance_end = attribute("instanceEnd")
      // camera space
      let start = vec4(model_view_matrix.mul(vec4_of([instance_start, 1.0]))).to_var(
        name="start",
      )
      let end = vec4(model_view_matrix.mul(vec4_of([instance_end, 1.0]))).to_var(
        name="end",
      )
      let mut distance_start : Node? = None
      let mut distance_end : Node? = None
      if use_dash {
        distance_start = Some(
          float(attribute("instanceDistanceStart")).to_var(name="distanceStart"),
        )
        distance_end = Some(
          float(attribute("instanceDistanceEnd")).to_var(name="distanceEnd"),
        )
      }
      if use_world_units {
        line2_world_start.assign(start.xyz())
        line2_world_end.assign(end.xyz())
      }
      let aspect = viewport.z().div(viewport.w())
      // special case for perspective projection, and segments that terminate either in,
      // or behind, the camera plane
      let perspective = camera_projection_matrix
        .element(2)
        .element(3)
        .equal(-1.0) // 4th entry in the 3rd column
      if_(perspective, fn() {
        if_(start.z().less_than(0.0).and_(end.z().greater_than(0.0)), fn() {
          let alpha = line2_trim_segment_alpha.call_named({
            "start": start,
            "end": end,
          })
          end.assign(vec4_of([mix(start.xyz(), end.xyz(), alpha), end.w()]))
          if use_dash {
            distance_end
            .unwrap()
            .assign(mix(distance_start.unwrap(), distance_end.unwrap(), alpha))
          }
        }).else_if(
          end.z().less_than(0.0).and_(start.z().greater_than_equal(0.0)),
          fn() {
            let alpha = line2_trim_segment_alpha.call_named({
              "start": end,
              "end": start,
            })
            start.assign(
              vec4_of([mix(end.xyz(), start.xyz(), alpha), start.w()]),
            )
            if use_dash {
              distance_start
              .unwrap()
              .assign(
                mix(distance_end.unwrap(), distance_start.unwrap(), alpha),
              )
            }
          },
        )
        |> ignore
      })
      |> ignore
      if use_dash {
        let dash_scale_node = match material.dash_scale_node {
          Some(n) => float(n)
          None => material_line_scale
        }
        let offset_node = match material.offset_node {
          Some(n) => float(n)
          None => material_line_dash_offset
        }
        let mut line_dist = position_geometry
          .y()
          .less_than(0.5)
          .select(
            dash_scale_node.mul(distance_start.unwrap()),
            else_node=dash_scale_node.mul(distance_end.unwrap()),
          )
        line_dist = line_dist.add(offset_node)
        line2_line_distance.assign(line_dist)
      }
      // clip space
      let clip_start = camera_projection_matrix.mul(start)
      let clip_end = camera_projection_matrix.mul(end)
      // ndc space
      let ndc_start = clip_start.xyz().div(clip_start.w())
      let ndc_end = clip_end.xyz().div(clip_end.w())
      // direction
      let dir = ndc_end.xy().sub(ndc_start.xy()).to_var()
      // account for clip-space aspect ratio
      dir.x().assign(dir.x().mul(aspect))
      dir.assign(dir.normalize())
      let clip = vec4_of([]).to_var()
      if use_world_units {
        // get the offset direction as perpendicular to the view vector
        let world_dir = end.xyz().sub(start.xyz()).normalize()
        let tmp_fwd = perspective.select(
          mix(start.xyz(), end.xyz(), 0.5).normalize(),
          else_node=vec3_of([0.0, 0.0, -1.0]),
        )
        let world_up = world_dir.cross(tmp_fwd).normalize()
        let world_fwd = world_dir.cross(world_up)
        line2_world_pos.assign(
          position_geometry.y().less_than(0.5).select(start, else_node=end),
        )
        // height offset
        let hw = material_line_width.mul(0.5)
        line2_world_pos.add_assign(
          vec4_of([
            position_geometry
            .x()
            .less_than(0.0)
            .select(world_up.mul(hw), else_node=world_up.mul(hw).negate()),
            0,
          ]),
        )
        // don't extend the line if we're rendering dashes because we won't be rendering
        // the endcaps
        if !use_dash {
          // cap extension
          line2_world_pos.add_assign(
            vec4_of([
              position_geometry
              .y()
              .less_than(0.5)
              .select(world_dir.mul(hw).negate(), else_node=world_dir.mul(hw)),
              0,
            ]),
          )
          // add width to the box
          line2_world_pos.add_assign(vec4_of([world_fwd.mul(hw), 0]))
          // endcaps
          if_(
            position_geometry
            .y()
            .greater_than(1.0)
            .or(position_geometry.y().less_than(0.0)),
            fn() {
              line2_world_pos.sub_assign(
                vec4_of([world_fwd.mul(2.0).mul(hw), 0]),
              )
            },
          )
          |> ignore
        }
        // project the worldpos
        clip.assign(camera_projection_matrix.mul(line2_world_pos))
        // shift the depth of the projected points so the line segments overlap neatly
        let clip_pose = vec3_of([]).to_var()
        clip_pose.assign(
          position_geometry
          .y()
          .less_than(0.5)
          .select(ndc_start, else_node=ndc_end),
        )
        if_(clip.w().greater_than(0.0), fn() {
          // only shift the depth of vertices in front of the camera (#35137)
          clip.z().assign(clip_pose.z().mul(clip.w()))
        })
        |> ignore
      } else {
        let offset = vec2_of([dir.y(), dir.x().negate()]).to_var(name="offset")
        // undo aspect ratio adjustment
        dir.x().assign(dir.x().div(aspect))
        offset.x().assign(offset.x().div(aspect))
        // sign flip
        offset.assign(
          position_geometry
          .x()
          .less_than(0.0)
          .select(offset.negate(), else_node=offset),
        )
        // endcaps
        if_(position_geometry.y().less_than(0.0), fn() {
          offset.assign(offset.sub(dir))
        }).else_if(position_geometry.y().greater_than(1.0), fn() {
          offset.assign(offset.add(dir))
        })
        |> ignore
        // adjust for linewidth
        offset.assign(offset.mul(material_line_width))
        // adjust for clip-space to screen-space conversion // maybe resolution should be
        // based on viewport ...
        offset.assign(offset.div(viewport.w().div(screen_dpr)))
        // select end
        clip.assign(
          position_geometry
          .y()
          .less_than(0.5)
          .select(clip_start, else_node=clip_end),
        )
        // back to clip space
        offset.assign(offset.mul(clip.w()))
        clip.assign(clip.add(vec4_of([offset, 0, 0])))
      }
      Some(clip)
    }).call([])
  },
)

///|
/// `alphaLine`: the coverage of a line fragment (discarding outside the line).
let line2_alpha_line : Node = module_nodes(
  "materials/nodes/Line2NodeMaterial.js:alphaLine",
  fn() {
    fn_(fn(_, builder) {
      let material = line2_builder_payload(builder)
      let renderer = builder.renderer
      let use_alpha_to_coverage = node_material_builder_material(builder).alpha_to_coverage
      let use_dash = material._use_dash == Some(true)
      let use_world_units = material._use_world_units
      let v_uv = uv()
      if use_dash {
        let dash_size_node = match material.dash_size_node {
          Some(n) => float(n)
          None => material_line_dash_size
        }
        let gap_size_node = match material.gap_size_node {
          Some(n) => float(n)
          None => material_line_gap_size
        }
        dash_size.assign(dash_size_node)
        gap_size.assign(gap_size_node)
        v_uv.y().less_than(-1.0).or(v_uv.y().greater_than(1.0)).discard() // discard endcaps
        line2_line_distance
        .mod(dash_size.add(gap_size))
        .greater_than(dash_size)
        .discard() // todo - FIX
      }
      let alpha = float(1).to_var(name="alpha")
      if use_world_units {
        let len = float_of([]).to_var()
        let orthographic = camera_projection_matrix
          .element(2)
          .element(3)
          .not_equal(-1.0)
          .to_const()
        if_(orthographic, fn() {
          // View rays are parallel to the z axis so the distance reduces to camera-space
          // XY
          let line_dir = line2_world_end.xy().sub(line2_world_start.xy())
          let t = line2_world_pos
            .xy()
            .sub(line2_world_start.xy())
            .dot(line_dir)
            .div(line_dir.dot(line_dir))
            .clamp()
          len.assign(
            line2_world_start
            .xy()
            .add(line_dir.mul(t))
            .sub(line2_world_pos.xy())
            .length(),
          )
        }).else_(fn() {
          // Find the closest points on the view ray and the line segment
          let ray_end = line2_world_pos.xyz().normalize().mul(1.0e5)
          let line_dir = line2_world_end.sub(line2_world_start)
          let params = line2_closest_line_to_line.call_named({
            "p1": line2_world_start,
            "p2": line2_world_end,
            "p3": vec3_of([0.0, 0.0, 0.0]),
            "p4": ray_end,
          })
          let p1 = line2_world_start.add(line_dir.mul(params.x()))
          let p2 = ray_end.mul(params.y())
          let delta = p1.sub(p2)
          len.assign(delta.length())
        })
        let norm = len.div(material_line_width)
        if !use_dash {
          if use_alpha_to_coverage && renderer.current_samples() > 0 {
            let dnorm = norm.fwidth()
            alpha.assign(
              smoothstep(dnorm.negate().add(0.5), dnorm.add(0.5), norm).one_minus(),
            )
          } else {
            norm.greater_than(0.5).discard()
          }
        }
      } else if use_alpha_to_coverage && renderer.current_samples() > 0 {
        // round endcaps
        let a = v_uv.x()
        let b = v_uv
          .y()
          .greater_than(0.0)
          .select(v_uv.y().sub(1.0), else_node=v_uv.y().add(1.0))
        let len2 = a.mul(a).add(b.mul(b))
        let dlen = float(len2.fwidth()).to_var(name="dlen")
        if_(v_uv.y().abs().greater_than(1.0), fn() {
          alpha.assign(
            smoothstep(dlen.one_minus(), dlen.add(1), len2).one_minus(),
          )
        })
        |> ignore
      } else {
        if_(v_uv.y().abs().greater_than(1.0), fn() {
          let a = v_uv.x()
          let b = v_uv
            .y()
            .greater_than(0.0)
            .select(v_uv.y().sub(1.0), else_node=v_uv.y().add(1.0))
          let len2 = a.mul(a).add(b.mul(b))
          len2.greater_than(1.0).discard()
        })
        |> ignore
      }
      Some(alpha)
    }).call([])
  },
)

///|
/// `alphaToCoverage` is the core `alpha_to_coverage` field (upstream's
/// `_useAlphaToCoverage` behind the accessor).
pub(all) struct Line2NodeMaterial {
  /// The dash offset.
  mut dash_offset : Double
  mut offset_node : Node?
  mut dash_scale_node : Node?
  mut dash_size_node : Node?
  mut gap_size_node : Node?
  /// `_useDash` (`parameters.dashed`, `undefined` by default).
  mut _use_dash : Bool?
  /// `_useWorldUnits`.
  mut _use_world_units : Bool
}

///|
pub impl NodeMaterialClass for Line2NodeMaterial with fn class_name(_) {
  "Line2NodeMaterial"
}

///|
pub impl NodeMaterialClass for Line2NodeMaterial with fn parent(_) {
  Some(BaseNodeMaterial::{ })
}

///|
pub impl NodeMaterialClass for Line2NodeMaterial with fn has_flag(_, flag) {
  flag == "isLine2NodeMaterial" ||
  flag == "isLineDashedMaterial" ||
  flag == "isLineBasicMaterial"
}

///|
pub impl NodeMaterialClass for Line2NodeMaterial with fn construct(_) {
  Line2NodeMaterial::new()
}

///|
pub impl NodeMaterialClass for Line2NodeMaterial with fn node_slot(self, name) {
  match name {
    "offsetNode" => Some(self.offset_node)
    "dashScaleNode" => Some(self.dash_scale_node)
    "dashSizeNode" => Some(self.dash_size_node)
    "gapSizeNode" => Some(self.gap_size_node)
    _ => None
  }
}

///|
pub impl NodeMaterialClass for Line2NodeMaterial with fn own_node_slots(
  self,
  out,
) {
  out.push(("offsetNode", self.offset_node))
  out.push(("dashScaleNode", self.dash_scale_node))
  out.push(("dashSizeNode", self.dash_size_node))
  out.push(("gapSizeNode", self.gap_size_node))
}

///|
pub impl NodeMaterialClass for Line2NodeMaterial with fn set_node_slot(
  self,
  name,
  value,
) {
  match name {
    "offsetNode" => self.offset_node = value
    "dashScaleNode" => self.dash_scale_node = value
    "dashSizeNode" => self.dash_size_node = value
    "gapSizeNode" => self.gap_size_node = value
    _ => return false
  }
  true
}

///|
pub impl NodeMaterialClass for Line2NodeMaterial with fn get_property(
  self,
  material,
  name,
) {
  match name {
    "dashOffset" => Some(Number(self.dash_offset))
    // `this.vertexColors = parameters.vertexColors` leaves it `undefined` by default
    "vertexColors" if material.vertex_colors == false => Some(Undefined)
    "lineColorNode" =>
      Some(
        node_material_slot_value(NodeMaterial::payload_of(material).color_node),
      )
    "worldUnits" => Some(Bool(self._use_world_units))
    "dashed" =>
      match self._use_dash {
        Some(b) => Some(Bool(b))
        None => Some(Undefined)
      }
    "alphaToCoverage" => Some(Bool(material.alpha_to_coverage))
    _ =>
      match self.node_slot(name) {
        Some(slot) => Some(node_material_slot_value(slot))
        None => BaseNodeMaterial::{ }.get_property(material, name)
      }
  }
}

///|
pub impl NodeMaterialClass for Line2NodeMaterial with fn reference_value(
  self,
  _,
  key,
) {
  match key {
    "dashOffset" => Some(Number(self.dash_offset))
    _ => None
  }
}

///|
/// The accessors and members of `copy( source )` (`worldUnits` and `dashed` bump the
/// version when they change).
pub impl NodeMaterialClass for Line2NodeMaterial with fn copy_members(
  self,
  material,
  source,
) {
  match Line2NodeMaterial::of(source) {
    Some(s) => {
      Line2NodeMaterial::set_world_units(material, s._use_world_units)
      if s._use_dash is Some(dashed) {
        Line2NodeMaterial::set_dashed(material, dashed)
      }
      self.dash_offset = s.dash_offset
    }
    None => ()
  }
}

///|
pub impl NodeMaterialClass for Line2NodeMaterial with fn setup_diffuse_color(
  _,
  material,
  builder,
) {
  NodeMaterial::setup_diffuse_color_base(material, builder)
  diffuse_color.a().mul_assign(line2_alpha_line)
  if material.vertex_colors == true &&
    node_material_builder_geometry(builder).has_attribute("instanceColorStart") {
    let instance_color_start = attribute("instanceColorStart")
    let instance_color_end = attribute("instanceColorEnd")
    let instance_color = position_geometry
      .y()
      .less_than(0.5)
      .select(instance_color_start, else_node=instance_color_end)
    diffuse_color.rgb().mul_assign(instance_color)
  }
  if material.transparent {
    diffuse_color
    .rgb()
    .assign(
      diffuse_color
      .rgb()
      .mul(diffuse_color.a())
      .add(
        viewport_opaque_mip_texture().rgb().mul(diffuse_color.a().one_minus()),
      ),
    )
  }
}

///|
pub impl NodeMaterialClass for Line2NodeMaterial with fn setup_position(
  _,
  material,
  builder,
) {
  let local_position = model_world_matrix_inverse
    .mul(camera_world_matrix)
    .mul(camera_projection_matrix_inverse)
    .mul(line2_mvp_line)
  position_local.assign(local_position.xyz().div(local_position.w()))
  if builder.needs_previous_data() {
    position_previous.assign(position_local)
  }
  NodeMaterial::setup_position_base(material, builder)
}

///|
/// `set worldUnits( value )`: bumps the version when the value changes.
pub fn Line2NodeMaterial::set_world_units(
  material : @core.Material,
  value : Bool,
) -> Unit {
  let p = Line2NodeMaterial::of(material).unwrap()
  if p._use_world_units != value {
    p._use_world_units = value
    material.set_needs_update(true)
  }
}

///|
/// `get worldUnits()`.
pub fn Line2NodeMaterial::world_units(material : @core.Material) -> Bool {
  Line2NodeMaterial::of(material).unwrap()._use_world_units
}

///|
/// `set dashed( value )`: bumps the version when the value changes.
pub fn Line2NodeMaterial::set_dashed(
  material : @core.Material,
  value : Bool,
) -> Unit {
  let p = Line2NodeMaterial::of(material).unwrap()
  if p._use_dash != Some(value) {
    p._use_dash = Some(value)
    material.set_needs_update(true)
  }
}

///|
/// `get dashed()`; `None` is `undefined`.
pub fn Line2NodeMaterial::dashed(material : @core.Material) -> Bool? {
  Line2NodeMaterial::of(material).unwrap()._use_dash
}

///|
/// `set alphaToCoverage( value )`: bumps the version when the value changes.
pub fn Line2NodeMaterial::set_alpha_to_coverage(
  material : @core.Material,
  value : Bool,
) -> Unit {
  if material.alpha_to_coverage != value {
    material.alpha_to_coverage = value
    material.set_needs_update(true)
  }
}

///|
/// `new Line2NodeMaterial( parameters )`; `dashed` and `vertex_colors` are the
/// parameters the constructor reads itself.
pub fn Line2NodeMaterial::new(
  dashed? : Bool,
  vertex_colors? : Bool,
) -> @core.Material {
  let material = NodeMaterial::create(Line2NodeMaterial::{
    dash_offset: 0,
    offset_node: None,
    dash_scale_node: None,
    dash_size_node: None,
    gap_size_node: None,
    _use_dash: dashed,
    _use_world_units: false,
  })
  NodeMaterial::set_default_values(material, line2_node_material_defaults)
  material.vertex_colors = vertex_colors.unwrap_or(false)
  material.blending = @core.NoBlending
  material.alpha_to_coverage = true
  material
}

///|
pub fn Line2NodeMaterial::of(material : @core.Material) -> Line2NodeMaterial? {
  match NodeMaterial::class_payload(material, "Line2NodeMaterial") {
    Some(p) => Some(p.cast())
    None => None
  }
}
