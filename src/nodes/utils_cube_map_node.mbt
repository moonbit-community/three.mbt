// nodes/utils/CubeMapNode.js: an environment as a cube texture, converting
// equirectangular maps to cube maps once (cached per texture) before rendering.

///|
/// `_cache`: equirectangular texture -> converted cube texture.
let _cube_map_node_cache : @webgl.WeakMap[@core.Texture, @core.Texture] = @webgl.WeakMap::new()

///|
pub(all) struct CubeMapNode {
  mut env_node : Node
  mut _cube_texture : @core.Texture?
  mut _cube_texture_node : Node
  _default_texture : @core.Texture
}

///|
pub impl NodeClass for CubeMapNode with fn class_name(_) {
  "CubeMapNode"
}

///|
pub impl NodeClass for CubeMapNode with fn children(self, _, out) {
  push_child(out, "envNode", Some(self.env_node))
}

///|
/// `isEquirectangularMapReady( image )`.
fn cube_map_node_is_equirectangular_map_ready(
  image : @core.TextureImage,
) -> Bool {
  match image {
    NoImage => false
    _ => image.height() > 0.0
  }
}

///|
/// `mapTextureMapping( texture, mapping )`.
fn cube_map_node_map_texture_mapping(
  texture : @core.Texture,
  mapping : Int32,
) -> Unit {
  if mapping == @core.EquirectangularReflectionMapping {
    texture.mapping = @core.CubeReflectionMapping
  } else if mapping == @core.EquirectangularRefractionMapping {
    texture.mapping = @core.CubeRefractionMapping
  }
}

///|
let _cube_map_node_dispose_listener : Ref[((@core.Event) -> Unit)?] = Ref(None)

///|
/// `onTextureDispose( event )`: drops the converted cube map of a disposed texture.
/// One listener value, so `removeEventListener` gets the one `addEventListener` got.
fn cube_map_node_on_texture_dispose() -> (@core.Event) -> Unit {
  match _cube_map_node_dispose_listener.val {
    Some(f) => f
    None => {
      let f = fn(event : @core.Event) {
        guard event.target is Some(Texture(texture)) else { return }
        texture.remove_event_listener(
          "dispose",
          cube_map_node_on_texture_dispose(),
        )
        match _cube_map_node_cache.get(texture) {
          Some(render_target_texture) => {
            _cube_map_node_cache.delete(texture)
            render_target_texture.dispose()
          }
          None => ()
        }
      }
      _cube_map_node_dispose_listener.val = Some(f)
      f
    }
  }
}

///|
/// `renderTarget.fromEquirectangularTexture( renderer, texture )` of
/// renderers/common/CubeRenderTarget.js, which the renderer group ports.
fn cube_map_node_from_equirectangular_texture(
  render_target : @core.RenderTarget,
  renderer : Renderer?,
  texture : @core.Texture,
) -> Unit {
  match renderer {
    Some(renderer) =>
      CubeRenderTarget::from_equirectangular_texture(
        render_target, renderer, texture,
      )
      |> ignore
    None =>
      abort("TypeError: Cannot read properties of null (reading 'getMRT')")
  }
}

///|
/// `updateBefore( frame )`, also run by `setup( builder )` with the builder's renderer
/// and material.
pub fn CubeMapNode::update_before_with(
  self : CubeMapNode,
  renderer : Renderer?,
  material : @core.Material?,
) -> Unit {
  let env_node = self.env_node
  let is_texture_node = env_node.has_flag("isTextureNode")
  if is_texture_node || env_node.has_flag("isMaterialReferenceNode") {
    let texture = if is_texture_node {
      utils_node_value(env_node)
    } else {
      match (material, ReferenceNode::of(env_node)) {
        (Some(m), Some(r)) => reference_material_value(m, r.property)
        (None, _) =>
          abort(
            "TypeError: Cannot read properties of null (reading '\{operator_node_str(ReferenceNode::of(env_node).map(fn(r) { r.property }))}')",
          )
        _ => Undefined
      }
    }
    if texture is Texture(texture) {
      let mapping = texture.mapping
      if mapping == @core.EquirectangularReflectionMapping ||
        mapping == @core.EquirectangularRefractionMapping {
        // check for converted cubemap map
        match _cube_map_node_cache.get(texture) {
          Some(cube_map) => {
            cube_map_node_map_texture_mapping(cube_map, texture.mapping)
            self._cube_texture = Some(cube_map)
          }
          None => {
            // create cube map from equirectangular map
            let image = texture.image()
            if cube_map_node_is_equirectangular_map_ready(image) {
              let render_target = CubeRenderTarget::new(
                size=image.height().to_int(),
              )
              cube_map_node_from_equirectangular_texture(
                render_target, renderer, texture,
              )
              cube_map_node_map_texture_mapping(
                render_target.texture(),
                texture.mapping,
              )
              self._cube_texture = Some(render_target.texture())
              _cube_map_node_cache.set(texture, render_target.texture())
              texture.add_event_listener(
                "dispose",
                cube_map_node_on_texture_dispose(),
              )
            } else {
              // default cube texture as fallback when equirectangular texture is
              // not yet loaded
              self._cube_texture = Some(self._default_texture)
            }
          }
        }
        TextureNode::set_value(self._cube_texture_node, self._cube_texture)
      } else {
        // envNode already refers to a cube map
        self._cube_texture_node = self.env_node
      }
    }
  }
}

///|
pub impl NodeClass for CubeMapNode with fn update_before(self, _, frame) {
  self.update_before_with(frame.renderer, frame.material)
  None
}

///|
pub impl NodeClass for CubeMapNode with fn setup(self, _, builder) {
  self.update_before_with(Some(builder.renderer), builder.material)
  Some(self._cube_texture_node)
}

///|
/// The constructor body: `super( 'vec3' )` has run in `Node::alloc`.
pub fn CubeMapNode::construct(node : Node, env_node : Node) -> CubeMapNode {
  let cube_texture_node = cube_texture(TslValue::Null)
  let default_texture = @core.CubeTexture::new()
  default_texture.is_render_target_texture = true
  node.update_before_type = NodeUpdateType::render()
  {
    env_node,
    _cube_texture: None,
    _cube_texture_node: cube_texture_node,
    _default_texture: default_texture,
  }
}

///|
/// `new CubeMapNode( envNode )`.
pub fn CubeMapNode::new(env_node : Node) -> Node {
  let node = Node::alloc(node_type="vec3")
  node.set_class(CubeMapNode::construct(node, env_node))
}

///|
pub fn CubeMapNode::of(node : Node) -> CubeMapNode? {
  match node.class_payload("CubeMapNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `cubeMapNode( envNode )` (`nodeProxy( CubeMapNode )`).
pub fn cube_map_node(env_node : &IntoTsl) -> Node {
  let p = tsl_verify_params("CubeMapNode", [env_node.to_tsl()], 1, 1)
  CubeMapNode::new(operator_node_required(tsl_proxy_arg(p[0])))
}

///|
/// `node.value`: a texture node's (possibly referenced) texture, else the input value.
fn utils_node_value(node : Node) -> TslValue {
  if node.has_flag("isTextureNode") {
    match TextureNode::get_value_opt(node) {
      Some(t) => Texture(t)
      None => Null
    }
  } else {
    InputNode::get_value(node)
  }
}
