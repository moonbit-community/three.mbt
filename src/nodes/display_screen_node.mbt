// nodes/display/ScreenNode.js

///|
/// `_screenSizeVec`: the value of the `screenSize` uniform, written by `update`.
let _screen_node_screen_size_vec : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
/// `_viewportVec`: the value of the `viewport` uniform, written by `update`.
let _screen_node_viewport_vec : @math.Vector4 = @math.Vector4::new(
  0.0, 0.0, 0.0, 1.0,
)

///|
/// Screen and viewport values: the fragment coordinate, the screen size, the
/// viewport rectangle and the screen UV.
pub(all) struct ScreenNode {
  mut scope : String
}

///|
pub impl NodeClass for ScreenNode with fn class_name(_) {
  "ScreenNode"
}

///|
pub impl NodeClass for ScreenNode with fn has_flag(_, flag) {
  flag == "isViewportNode"
}

///|
pub impl NodeClass for ScreenNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for ScreenNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for ScreenNode with fn generate_node_type(self, _, _, _) {
  if self.scope == ScreenNode::viewport() {
    Some("vec4")
  } else {
    Some("vec2")
  }
}

///|
pub impl NodeClass for ScreenNode with fn update(self, _, frame) {
  let renderer = match frame.renderer {
    Some(r) => r
    None =>
      abort(
        "TypeError: Cannot read properties of null (reading 'getRenderTarget')",
      )
  }
  let render_target = renderer.get_render_target()
  if self.scope == ScreenNode::viewport() {
    match render_target {
      Some(rt) => _screen_node_viewport_vec.copy(rt.viewport) |> ignore
      None => {
        renderer_get_viewport(renderer, _screen_node_viewport_vec)
        _screen_node_viewport_vec.multiply_scalar(renderer.get_pixel_ratio())
        |> ignore
      }
    }
  } else {
    match render_target {
      Some(rt) => {
        _screen_node_screen_size_vec.x = rt.width.to_double()
        _screen_node_screen_size_vec.y = rt.height.to_double()
      }
      None =>
        renderer_get_drawing_buffer_size(renderer, _screen_node_screen_size_vec)
    }
  }
  None
}

///|
pub impl NodeClass for ScreenNode with fn setup(self, node, _) {
  let scope = self.scope
  let output = if scope == ScreenNode::size() {
    uniform(_screen_node_screen_size_vec).set_group(render_group)
  } else if scope == ScreenNode::viewport() {
    uniform(_screen_node_viewport_vec).set_group(render_group)
  } else {
    vec2(screen_coordinate.div(screen_size))
  }
  let mut update_type = NodeUpdateType::none()
  if self.scope == ScreenNode::size() || self.scope == ScreenNode::viewport() {
    update_type = NodeUpdateType::render()
  }
  node.update_type = update_type
  Some(output)
}

///|
pub impl NodeClass for ScreenNode with fn generate(self, node, builder, _) {
  if self.scope == ScreenNode::coordinate() {
    let mut coord = builder.get_frag_coord()
    if builder.is_flip_y() {
      // follow webgpu standards
      let size = match
        builder.get_node_properties(screen_size).get_node("outputNode") {
        Some(n) => n.build(builder)
        None =>
          abort("TypeError: Cannot read properties of null (reading 'build')")
      }
      coord = "\{builder.get_type("vec2")}( \{coord}.x, \{size}.y - \{coord}.y )"
    }
    return Some(coord)
  }
  node.generate_base(builder, None)
}

///|
/// `ScreenNode.COORDINATE`.
pub fn ScreenNode::coordinate() -> String {
  "coordinate"
}

///|
/// `ScreenNode.VIEWPORT`.
pub fn ScreenNode::viewport() -> String {
  "viewport"
}

///|
/// `ScreenNode.SIZE`.
pub fn ScreenNode::size() -> String {
  "size"
}

///|
/// `ScreenNode.UV`.
pub fn ScreenNode::uv() -> String {
  "uv"
}

///|
pub fn ScreenNode::construct(_node : Node, scope : String) -> ScreenNode {
  { scope, }
}

///|
/// `new ScreenNode( scope )`.
pub fn ScreenNode::new(scope : String) -> Node {
  let node = Node::alloc()
  node.set_class(ScreenNode::construct(node, scope))
}

///|
pub fn ScreenNode::of(node : Node) -> ScreenNode? {
  match node.class_payload("ScreenNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `screenDPR`: the renderer's pixel ratio.
pub let screen_dpr : Node = module_nodes(
  "nodes/display/ScreenNode.js:screenDPR",
  fn() {
    uniform(1)
    .set_group(render_group)
    .on_render_update(fn(n, frame) {
      match frame.renderer {
        Some(renderer) =>
          InputNode::set_value(n, Number(renderer.get_pixel_ratio()))
        None =>
          abort(
            "TypeError: Cannot read properties of null (reading 'getPixelRatio')",
          )
      }
      None
    })
  },
)

///|
/// `screenUV`: the fragment's position on the screen, 0 to 1.
pub let screen_uv : Node = module_nodes(
  "nodes/display/ScreenNode.js:screenUV",
  fn() { ScreenNode::new(ScreenNode::uv()) },
)

///|
/// `screenSize`: the screen size in physical pixels.
pub let screen_size : Node = module_nodes(
  "nodes/display/ScreenNode.js:screenSize",
  fn() { ScreenNode::new(ScreenNode::size()) },
)

///|
/// `screenCoordinate`: the fragment's position in physical pixels.
pub let screen_coordinate : Node = module_nodes(
  "nodes/display/ScreenNode.js:screenCoordinate",
  fn() { ScreenNode::new(ScreenNode::coordinate()) },
)

///|
/// `viewport`: the viewport rectangle `( x, y, width, height )` in physical pixels.
pub let viewport : Node = module_nodes("nodes/display/ScreenNode.js:viewport", fn() {
  ScreenNode::new(ScreenNode::viewport())
})

///|
/// `viewportSize`: the viewport size in physical pixels.
pub let viewport_size : Node = module_nodes(
  "nodes/display/ScreenNode.js:viewportSize",
  fn() { viewport.zw() },
)

///|
/// `viewportCoordinate`: the fragment's position relative to the viewport.
pub let viewport_coordinate : Node = module_nodes(
  "nodes/display/ScreenNode.js:viewportCoordinate",
  fn() { screen_coordinate.sub(viewport.xy()) },
)

///|
/// `viewportUV`: the fragment's position in the viewport, 0 to 1.
pub let viewport_uv : Node = module_nodes(
  "nodes/display/ScreenNode.js:viewportUV",
  fn() { viewport_coordinate.div(viewport_size) },
)

// Renderer members that group G6 has not declared yet; each becomes the `Renderer`
// method of the same name once it exists.

///|
/// `renderer.getViewport( target )`.
fn renderer_get_viewport(renderer : Renderer, target : @math.Vector4) -> Unit {
  renderer.get_viewport(target) |> ignore
}

///|
/// `renderer.getDrawingBufferSize( target )`.
fn renderer_get_drawing_buffer_size(
  renderer : Renderer,
  target : @math.Vector2,
) -> Unit {
  renderer.get_drawing_buffer_size(target) |> ignore
}
