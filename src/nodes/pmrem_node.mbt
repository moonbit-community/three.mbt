// nodes/pmrem/PMREMNode.js: samples the PMREM of an environment texture, generating it
// with a PMREMGenerator when the texture changes.

///|
let pmrem_node_cache : @webgl.WeakMap[
  Renderer,
  @webgl.WeakMap[@core.Texture, @core.RenderTarget],
] = @webgl.WeakMap::new()

///|
/// `_getCache( renderer )`.
fn pmrem_node_get_cache(
  renderer : Renderer,
) -> @webgl.WeakMap[@core.Texture, @core.RenderTarget] {
  match pmrem_node_cache.get(renderer) {
    Some(c) => c
    None => {
      let c = @webgl.WeakMap::new()
      pmrem_node_cache.set(renderer, c)
      c
    }
  }
}

///|
/// `isCubeMapReady( image )`: all six faces are set.
fn pmrem_node_is_cube_map_ready(image : @core.TextureImage) -> Bool {
  match image {
    NoImage => false
    ImageArray(faces) => {
      let mut count = 0
      for i in 0..<6 {
        if i < faces.length() && !(faces[i] is NoImage) {
          count += 1
        }
      }
      count == 6
    }
    _ => false
  }
}

///|
/// `isEquirectangularMapReady( image )`.
fn pmrem_node_is_equirectangular_map_ready(image : @core.TextureImage) -> Bool {
  match image {
    NoImage => false
    image => image.height() > 0.0
  }
}

///|
/// `_getPMREMFromTexture( texture, renderer, generator )`: the cached PMREM of a texture,
/// regenerated when its `pmremVersion` changes; `None` while the image is not ready.
fn pmrem_node_get_pmrem_from_texture(
  texture : @core.Texture,
  renderer : Renderer,
  generator : PMREMNodeGenerator,
) -> @core.Texture? {
  let cache = pmrem_node_get_cache(renderer)
  let mut render_target = cache.get(texture)
  let pmrem_version = match render_target {
    Some(rt) => rt.texture().pmrem_version
    None => -1
  }
  if pmrem_version != texture.pmrem_version {
    let image = texture.image()
    if texture.is_cube_texture() {
      if pmrem_node_is_cube_map_ready(image) {
        render_target = Some(generator.from_cubemap(texture, render_target?))
      } else {
        return None
      }
    } else if pmrem_node_is_equirectangular_map_ready(image) {
      render_target = Some(
        generator.from_equirectangular(texture, render_target?),
      )
    } else {
      return None
    }
    let rt = render_target.unwrap()
    rt.texture().pmrem_version = texture.pmrem_version
    if !cache.has(texture) {
      let on_dispose : Ref[(@core.Event) -> Unit] = Ref(fn(_) {  })
      on_dispose.val = fn(_) {
        texture.remove_event_listener("dispose", on_dispose.val)
        if cache.get(texture) is Some(pmrem) {
          pmrem.texture().pmrem_version = -1
          pmrem.dispose()
          cache.delete(texture)
        }
      }
      texture.add_event_listener("dispose", on_dispose.val)
    }
    cache.set(texture, rt)
  }
  Some(render_target.unwrap().texture())
}

///|
/// What `_generator` holds: this renderer's PMREMGenerator, or the WebGLRenderer one the
/// WebGLNodesHandler add-on assigns (upstream duck-types both).
priv enum PMREMNodeGenerator {
  Renderer(PMREMGenerator)
  WebGL(@webgl.PMREMGenerator)
}

///|
fn PMREMNodeGenerator::from_cubemap(
  self : PMREMNodeGenerator,
  texture : @core.Texture,
  render_target? : @core.RenderTarget,
) -> @core.RenderTarget {
  match self {
    Renderer(g) => g.from_cubemap(texture, render_target?)
    WebGL(g) => g.from_cubemap(texture, render_target?)
  }
}

///|
fn PMREMNodeGenerator::from_equirectangular(
  self : PMREMNodeGenerator,
  texture : @core.Texture,
  render_target? : @core.RenderTarget,
) -> @core.RenderTarget {
  match self {
    Renderer(g) => g.from_equirectangular(texture, render_target?)
    WebGL(g) => g.from_equirectangular(texture, render_target?)
  }
}

///|
pub(all) struct PMREMNode {
  mut _value : @core.Texture
  mut _pmrem : @core.Texture?
  mut uv_node : Node?
  mut level_node : Node?
  mut _generator : PMREMGenerator?
  /// `_generator` when it holds a WebGLRenderer `PMREMGenerator` (set by the
  /// WebGLNodesHandler add-on); at most one of the two is set.
  mut _webgl_generator : @webgl.PMREMGenerator?
  _texture : Node
  _max_lod : Node
  _size : Node
}

///|
pub impl NodeClass for PMREMNode with fn class_name(_) {
  "PMREMNode"
}

///|
pub impl NodeClass for PMREMNode with fn children(self, _, out) {
  push_child(out, "uvNode", self.uv_node)
  push_child(out, "levelNode", self.level_node)
}

///|
pub impl NodeClass for PMREMNode with fn update_before(self, _, frame) {
  self.update_before_state(frame.renderer.unwrap())
  None
}

///|
pub impl NodeClass for PMREMNode with fn setup(self, node, builder) {
  self.update_before_state(builder.renderer)
  let mut uv_node = self.uv_node
  if uv_node is None && builder.context.get_uv() is Some(get_uv) {
    uv_node = Some((get_uv.f)(node, builder))
  }
  let mut level_node = self.level_node
  if level_node is None &&
    builder.context.get_texture_level() is Some(get_texture_level) {
    level_node = Some((get_texture_level.f)(node))
  }
  Some(
    self._texture
    .sample(material_env_rotation.mul(physical_optional(uv_node)))
    .level(roughness_to_mip(physical_optional(level_node), self._max_lod))
    .rgb(),
  )
}

///|
pub impl NodeClass for PMREMNode with fn dispose(self, node) {
  node.dispose_base()
  if self._generator is Some(generator) {
    generator.dispose()
  }
  if self._webgl_generator is Some(generator) {
    generator.dispose()
  }
}

///|
/// `updateFromTexture( texture )`: points the cube texture node at the PMREM.
pub fn PMREMNode::update_from_texture(
  self : PMREMNode,
  texture : @core.Texture,
) -> Unit {
  let mipmaps = if texture.texture_type is CompressedCubeTexture {
    match texture.image() {
      ImageArray(faces) =>
        match faces[0] {
          DataImage({ mipmaps: Some(m), .. }) =>
            m.map(fn(d) { @core.TextureImage::DataImage(d) })
          _ => []
        }
      _ => []
    }
  } else {
    texture.mipmaps
  }
  TextureNode::set_value(self._texture, Some(texture))
  InputNode::set_value(
    self._max_lod,
    Number((mipmaps.length() - 1).to_double()),
  )
  InputNode::set_value(self._size, Number(mipmaps[0].width()))
}

///|
/// `updateBefore( frame )` (also called with the builder in `setup`): regenerates the
/// PMREM when the texture's `pmremVersion` changed.
fn PMREMNode::update_before_state(
  self : PMREMNode,
  renderer : Renderer,
) -> Unit {
  let mut pmrem = self._pmrem
  let pmrem_version = match pmrem {
    Some(p) => p.pmrem_version
    None => -1
  }
  let texture = self._value
  if pmrem_version != texture.pmrem_version {
    if texture.is_pmrem_texture == true {
      pmrem = Some(texture)
    } else {
      let generator = match (self._generator, self._webgl_generator) {
        (Some(g), _) => PMREMNodeGenerator::Renderer(g)
        (None, Some(g)) => PMREMNodeGenerator::WebGL(g)
        (None, None) => {
          let g = PMREMGenerator::new(renderer)
          self._generator = Some(g)
          PMREMNodeGenerator::Renderer(g)
        }
      }
      pmrem = pmrem_node_get_pmrem_from_texture(texture, renderer, generator)
    }
    if pmrem is Some(p) {
      self._pmrem = Some(p)
      self.update_from_texture(p)
    }
  }
}

///|
/// `new PMREMNode( value, uvNode = null, levelNode = null )`.
pub fn PMREMNode::new(
  value : @core.Texture,
  uv_node? : Node,
  level_node? : Node,
) -> Node {
  let node = Node::alloc(node_type="vec3")
  let default_texture = @core.CubeTexture::new()
  default_texture.is_render_target_texture = true
  let payload = PMREMNode::{
    _value: value,
    _pmrem: None,
    uv_node,
    level_node,
    _generator: None,
    _webgl_generator: None,
    _texture: cube_texture(default_texture),
    _max_lod: uniform(0),
    _size: uniform(0),
  }
  node.update_before_type = NodeUpdateType::render()
  node.set_class(payload)
}

///|
pub fn PMREMNode::of(node : Node) -> PMREMNode? {
  match node.class_payload("PMREMNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `pmremNode.value`.
pub fn PMREMNode::value(node : Node) -> @core.Texture {
  PMREMNode::of(node).unwrap()._value
}

///|
/// `pmremNode.value = value`: a new texture, whose PMREM is generated on update.
pub fn PMREMNode::set_value(node : Node, value : @core.Texture) -> Unit {
  let self = PMREMNode::of(node).unwrap()
  self._value = value
  self._pmrem = None
}

///|
/// `pmremTexture( value, uvNode, levelNode )`.
pub fn pmrem_texture(
  value : @core.Texture,
  uv_node? : &IntoTsl,
  level_node? : &IntoTsl,
) -> Node {
  PMREMNode::new(
    value,
    uv_node?=uv_node.map(fn(u) { node_object(u.to_tsl()) }),
    level_node?=level_node.map(fn(l) { node_object(l.to_tsl()) }),
  )
}
