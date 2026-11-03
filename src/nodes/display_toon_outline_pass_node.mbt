// nodes/display/ToonOutlinePassNode.js

///|
/// A pass that draws toon outlines: toon materials are drawn a second time with a
/// back-faced, inflated outline material.
pub(all) struct ToonOutlinePassNode {
  pass : PassNode
  mut color_node : Node
  mut thickness_node : Node
  mut alpha_node : Node
  mut _outline_material : @core.Material
  /// `_materialCache`: original material -> outline material, in insertion order.
  _material_cache : Array[(@core.Material, @core.Material)]
  mut _on_material_dispose : (@core.Event) -> Unit
}

///|
pub impl NodeClass for ToonOutlinePassNode with fn class_name(_) {
  "ToonOutlinePassNode"
}

///|
pub impl NodeClass for ToonOutlinePassNode with fn parent(self) {
  Some(self.pass)
}

///|
pub impl NodeClass for ToonOutlinePassNode with fn children(self, node, out) {
  self.pass.children(node, out)
  push_child(out, "colorNode", Some(self.color_node))
  push_child(out, "thicknessNode", Some(self.thickness_node))
  push_child(out, "alphaNode", Some(self.alpha_node))
}

///|
pub impl NodeClass for ToonOutlinePassNode with fn update_before(
  self,
  node,
  frame,
) {
  let renderer = frame.renderer.unwrap()
  let current_render_object_function = renderer.get_render_object_function()
  renderer.set_render_object_function(
    Some({
      f: fn(
        object,
        scene,
        camera,
        geometry,
        material,
        group,
        lights_node,
        clipping_context,
        _,
      ) {
        // only render outline for supported materials
        if material.material_type is MeshToonMaterial ||
          material.has_extension_flag("isMeshToonNodeMaterial") {
          if material.wireframe != Some(true) {
            let outline_material = self.get_outline_material(material)
            renderer_render_object(
              renderer, object, scene, camera, geometry, outline_material, group,
              lights_node, clipping_context,
            )
          }
        }
        // default
        renderer_render_object(
          renderer, object, scene, camera, geometry, material, group, lights_node,
          clipping_context,
        )
      },
    }),
  )
  PassNode::update_before_base(node, frame)
  renderer.set_render_object_function(current_render_object_function)
  None
}

///|
pub impl NodeClass for ToonOutlinePassNode with fn dispose(self, node) {
  self.pass.dispose(node)
  self._outline_material.dispose()
  for entry in self._material_cache {
    let (original_material, outline_material) = entry
    original_material.dispatcher.remove_event_listener(
      "dispose",
      self._on_material_dispose,
    )
    outline_material.dispose()
  }
  self._material_cache.clear()
}

///|
pub impl PassNodeClass for ToonOutlinePassNode with fn set_size(
  _,
  node,
  width,
  height,
) {
  PassNode::set_size_base(node, width, height)
}

///|
/// `_createMaterial()`: the outline material.
fn ToonOutlinePassNode::create_material(
  self : ToonOutlinePassNode,
) -> @core.Material {
  let material = NodeMaterial::new()
  material.name = "Toon_Outline"
  material.side = @core.BackSide
  let node_material = NodeMaterial::of(material).unwrap()
  // vertex node
  let outline_normal = normal_local.negate()
  let mvp = camera_projection_matrix.mul(model_view_matrix)
  let ratio = float(1.0) // TODO: support outline thickness ratio for each vertex
  let pos = mvp.mul(vec4_of([position_local, 1.0]))
  let pos2 = mvp.mul(vec4_of([position_local.add(outline_normal), 1.0]))
  let norm = normalize(pos.sub(pos2)) // NOTE: subtract pos2 from pos because BackSide objectNormal is negative
  node_material.vertex_node = Some(
    pos.add(norm.mul(self.thickness_node).mul(pos.w()).mul(ratio)),
  )
  // color node
  node_material.color_node = Some(vec4_of([self.color_node, self.alpha_node]))
  material
}

///|
/// `_getOutlineMaterial( originalMaterial )`: the outline material for a material,
/// one per material with a `positionNode`.
fn ToonOutlinePassNode::get_outline_material(
  self : ToonOutlinePassNode,
  original_material : @core.Material,
) -> @core.Material {
  let position_node = match NodeMaterial::of(original_material) {
    Some(m) => m.position_node
    None => None
  }
  if position_node is None {
    return self._outline_material // early out if there are no node modifications
  }
  let mut force = false
  let outline_material = match
    self._material_cache.search_by(fn(e) {
      physical_equal(e.0, original_material)
    }) {
    Some(i) => self._material_cache[i].1
    None => {
      // create
      let m = self.create_material()
      self._material_cache.push((original_material, m))
      original_material.dispatcher.add_event_listener(
        "dispose",
        self._on_material_dispose,
      )
      force = true
      m
    }
  }
  // update
  if outline_material.version != original_material.version || force == true {
    NodeMaterial::of(outline_material).unwrap().position_node = position_node
    outline_material.version = original_material.version
  }
  outline_material
}

///|
/// `new ToonOutlinePassNode( scene, camera, colorNode, thicknessNode, alphaNode )`.
pub fn ToonOutlinePassNode::new(
  scene : @core.Object3D,
  camera : @core.Object3D,
  color_node : Node,
  thickness_node : Node,
  alpha_node : Node,
) -> Node {
  let node = Node::alloc(node_type="vec4")
  let pass = PassNode::construct(
    node,
    PassNode::color(),
    scene,
    camera,
    PassNodeOptions::default(),
  )
  let t = ToonOutlinePassNode::{
    pass,
    color_node,
    thickness_node,
    alpha_node,
    _outline_material: @core.Material::new(),
    _material_cache: [],
    _on_material_dispose: fn(_) {  },
  }
  t._outline_material = t.create_material()
  t._on_material_dispose = fn(event) {
    guard event.target is Some(Material(original_material)) else { return }
    original_material.dispatcher.remove_event_listener(
      "dispose",
      t._on_material_dispose,
    )
    match
      t._material_cache.search_by(fn(e) {
        physical_equal(e.0, original_material)
      }) {
      Some(i) => {
        t._material_cache[i].1.dispose()
        t._material_cache.remove(i) |> ignore
      }
      None => ()
    }
  }
  node.name = Some("Outline Pass")
  pass.pass_class = t
  node.set_class(t)
}

///|
pub fn ToonOutlinePassNode::of(node : Node) -> ToonOutlinePassNode? {
  match node.class_payload("ToonOutlinePassNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `toonOutlinePass( scene, camera, color = new Color( 0, 0, 0 ), thickness = 0.003,
/// alpha = 1 )`.
pub fn toon_outline_pass(
  scene : @core.Object3D,
  camera : @core.Object3D,
  color? : &IntoTsl,
  thickness? : &IntoTsl,
  alpha? : &IntoTsl,
) -> Node {
  let color = match color {
    Some(c) => node_object(c.to_tsl())
    None => node_object(Color(@math.Color::new(0.0, 0.0, 0.0)))
  }
  let thickness = match thickness {
    Some(t) => node_object(t.to_tsl())
    None => node_object(Number(0.003))
  }
  let alpha = match alpha {
    Some(a) => node_object(a.to_tsl())
    None => node_object(Number(1.0))
  }
  ToonOutlinePassNode::new(scene, camera, color, thickness, alpha)
}

///|
/// `renderer.renderObject( ... )`, which group G6 has not declared yet; it becomes the
/// `Renderer` method once it exists.
fn renderer_render_object(
  renderer : Renderer,
  object : @core.Object3D,
  scene : @core.Object3D,
  camera : @core.Object3D,
  geometry : @core.BufferGeometry,
  material : @core.Material,
  group : @core.GeometryGroup?,
  lights_node : Node,
  clipping_context : ClippingContext?,
) -> Unit {
  renderer.render_object(
    object,
    scene,
    camera,
    geometry,
    material,
    group,
    lights_node,
    clipping_context,
    None,
  )
}
