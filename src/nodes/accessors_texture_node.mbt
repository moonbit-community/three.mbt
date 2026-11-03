// nodes/accessors/TextureNode.js: the root of the texture node family (CubeTextureNode,
// Texture3DNode, StorageTextureNode and the display/utils subclasses). Its virtual
// methods (`getDefaultUV`, `setupUV`, `generateUV`, `generateSnippet`, the `value`
// accessor and `new this.constructor( ... )` of `clone`) dispatch through
// `TextureNodeClass`.

///|
/// `EmptyTexture`, the default `value`.
let _texture_node_empty_texture : @core.Texture = @core.Texture::new()

///|
/// `texture.image instanceof ImageBitmap`.
extern "js" fn _texture_node_is_image_bitmap(image : @core.JsValue) -> Bool = "(v) => typeof ImageBitmap !== 'undefined' && v instanceof ImageBitmap"

///|
/// Virtual methods of the `TextureNode` family; defaults walk to the parent payload,
/// ending at TextureNode's own body.
pub(open) trait TextureNodeClass {
  /// The superclass payload in the family, `None` for `TextureNode`.
  fn texture_parent(Self) -> &TextureNodeClass? = _
  /// `get value()`; `None` is `null`.
  fn get_value(Self, Node) -> @core.Texture? = _
  /// `set value( value )`.
  fn set_value(Self, Node, @core.Texture?) -> Unit = _
  /// `getDefaultUV()`.
  fn get_default_uv(Self, Node) -> Node = _
  /// `getTransformedUV( uvNode )`.
  fn get_transformed_uv(Self, Node, Node) -> Node = _
  /// `setUpdateMatrix( value )`.
  fn set_update_matrix(Self, Node, Bool) -> Unit = _
  /// `setupUV( builder, uvNode )`.
  fn setup_uv(Self, Node, NodeBuilder, Node) -> Node = _
  /// `generateUV( builder, uvNode )`.
  fn generate_uv(Self, Node, NodeBuilder, Node) -> String = _
  /// `generateOffset( builder, offsetNode )`.
  fn generate_offset(Self, Node, NodeBuilder, Node) -> String = _
  /// `generateSnippet( builder, textureProperty, uvSnippet, levelSnippet, biasSnippet,
  /// depthSnippet, compareSnippet, gradSnippet, gatherSnippet, offsetSnippet,
  /// flipYSnippet )`.
  fn generate_snippet(
    Self,
    Node,
    NodeBuilder,
    String,
    String,
    String?,
    String?,
    String?,
    String?,
    Array[String]?,
    String?,
    String?,
    String?,
  ) -> String = _
  /// `new this.constructor( value, uvNode, levelNode, biasNode )`.
  fn construct_like(Self, @core.Texture?, Node?, Node?, Node?) -> Node = _
  /// `clone()`.
  fn clone(Self, Node) -> Node = _
}

///|
impl TextureNodeClass with fn texture_parent(_) {
  None
}

///|
impl TextureNodeClass with fn get_value(self, node) {
  match self.texture_parent() {
    Some(p) => p.get_value(node)
    None => TextureNode::get_value_base(node)
  }
}

///|
impl TextureNodeClass with fn set_value(self, node, value) {
  match self.texture_parent() {
    Some(p) => p.set_value(node, value)
    None => TextureNode::set_value_base(node, value)
  }
}

///|
impl TextureNodeClass with fn get_default_uv(self, node) {
  match self.texture_parent() {
    Some(p) => p.get_default_uv(node)
    None => uv(index=TextureNode::get_value(node).channel)
  }
}

///|
impl TextureNodeClass with fn get_transformed_uv(self, node, uv_node) {
  match self.texture_parent() {
    Some(p) => p.get_transformed_uv(node, uv_node)
    None =>
      TextureNode::_get_matrix_uniform(node).mul(vec3_of([uv_node, 1])).xy()
  }
}

///|
impl TextureNodeClass with fn set_update_matrix(self, node, value) {
  match self.texture_parent() {
    Some(p) => p.set_update_matrix(node, value)
    None => texture_node_payload(node).update_matrix = value
  }
}

///|
impl TextureNodeClass with fn setup_uv(self, node, builder, uv_node) {
  match self.texture_parent() {
    Some(p) => p.setup_uv(node, builder, uv_node)
    None => TextureNode::setup_uv_base(node, builder, uv_node)
  }
}

///|
impl TextureNodeClass with fn generate_uv(self, node, builder, uv_node) {
  match self.texture_parent() {
    Some(p) => p.generate_uv(node, builder, uv_node)
    None =>
      uv_node.build(
        builder,
        output=if texture_node_payload(node).sampler { "vec2" } else { "ivec2" },
      )
  }
}

///|
impl TextureNodeClass with fn generate_offset(self, node, builder, offset_node) {
  match self.texture_parent() {
    Some(p) => p.generate_offset(node, builder, offset_node)
    None => offset_node.build(builder, output="ivec2")
  }
}

///|
impl TextureNodeClass with fn generate_snippet(
  self,
  node,
  builder,
  texture_property,
  uv_snippet,
  level_snippet,
  bias_snippet,
  depth_snippet,
  compare_snippet,
  grad_snippet,
  gather_snippet,
  offset_snippet,
  flip_y_snippet,
) {
  match self.texture_parent() {
    Some(p) =>
      p.generate_snippet(
        node, builder, texture_property, uv_snippet, level_snippet, bias_snippet,
        depth_snippet, compare_snippet, grad_snippet, gather_snippet, offset_snippet,
        flip_y_snippet,
      )
    None =>
      TextureNode::generate_snippet_base(
        node, builder, texture_property, uv_snippet, level_snippet, bias_snippet,
        depth_snippet, compare_snippet, grad_snippet, gather_snippet, offset_snippet,
        flip_y_snippet,
      )
  }
}

///|
impl TextureNodeClass with fn construct_like(
  self,
  value,
  uv_node,
  level_node,
  bias_node,
) {
  match self.texture_parent() {
    Some(p) => p.construct_like(value, uv_node, level_node, bias_node)
    None => TextureNode::new(value~, uv_node?, level_node?, bias_node?)
  }
}

///|
impl TextureNodeClass with fn clone(self, node) {
  match self.texture_parent() {
    Some(p) => p.clone(node)
    None => TextureNode::clone_base(node)
  }
}

///|
pub(all) struct TextureNode {
  uniform : UniformNode
  mut uv_node : Node?
  mut level_node : Node?
  mut bias_node : Node?
  mut compare_node : Node?
  mut depth_node : Node?
  /// `[ gradNodeX, gradNodeY ]`.
  mut grad_node : Array[Node]?
  mut gather_node : Node?
  mut offset_node : Node?
  mut sampler : Bool
  mut update_matrix : Bool
  /// The texture node this one was derived from (`sample()`, `level()`, ...).
  mut reference_node : Node?
  mut _mergeable : Bool
  mut _value : @core.Texture?
  mut _matrix_uniform : Node?
  mut _flip_y_uniform : Node?
  mut _sampler_comparison : Bool
  /// The most derived payload of the family, set at the end of construction.
  mut class_ : &TextureNodeClass
}

///|
priv struct TextureNodeUnset {}

///|
impl TextureNodeClass for TextureNodeUnset

///|
pub impl TextureNodeClass for TextureNode

///|
pub impl NodeClass for TextureNode with fn class_name(_) {
  "TextureNode"
}

///|
pub impl NodeClass for TextureNode with fn parent(self) {
  Some(self.uniform)
}

///|
pub impl NodeClass for TextureNode with fn has_flag(self, flag) {
  flag == "isTextureNode" || self.uniform.has_flag(flag)
}

///|
pub impl NodeClass for TextureNode with fn children(self, node, out) {
  self.uniform.children(node, out)
  push_child(out, "uvNode", self.uv_node)
  push_child(out, "levelNode", self.level_node)
  push_child(out, "biasNode", self.bias_node)
  push_child(out, "compareNode", self.compare_node)
  push_child(out, "depthNode", self.depth_node)
  match self.grad_node {
    Some(g) => push_children(out, "gradNode", g.map(fn(n) { Some(n) }))
    None => ()
  }
  push_child(out, "gatherNode", self.gather_node)
  push_child(out, "offsetNode", self.offset_node)
  push_child(out, "referenceNode", self.reference_node)
}

///|
pub impl NodeClass for TextureNode with fn custom_cache_key(_, node) {
  let texture = TextureNode::get_value(node)
  hash([
    node.id.to_double(),
    texture.type_.to_double(),
    texture.min_filter.to_double(),
    texture.mag_filter.to_double(),
  ])
}

///|
pub impl NodeClass for TextureNode with fn generate_node_type(self, node, _, _) {
  if self.gather_node is Some(_) {
    return Some("vec4")
  }
  Some(get_texture_type(TextureNode::get_value(node)))
}

///|
pub impl NodeClass for TextureNode with fn update_reference(self, node, _) {
  match self.class_.get_value(node) {
    Some(t) => @core.JsValue::of(t)
    None => @core.JsValue::null()
  }
}

///|
pub impl NodeClass for TextureNode with fn setup(self, node, builder) {
  let properties = builder.get_node_properties(node)
  properties.set_node_or_null("referenceNode", self.reference_node)
  let texture = match self.class_.get_value(node) {
    Some(t) => t
    None =>
      abort(
        "THREE.TSL: `texture( value )` function expects a valid instance of THREE.Texture().",
      )
  }
  let uv_node = fn_(fn(_, _) {
    let mut uv_node = self.uv_node
    if uv_node is None ||
      builder.context.get_bool("forceUVContext") == Some(true) {
      match builder.context.get_uv() {
        Some(get_uv) => uv_node = Some((get_uv.f)(node, builder))
        None => ()
      }
    }
    let mut uv_node = match uv_node {
      Some(n) => n
      None => self.class_.get_default_uv(node)
    }
    if self.update_matrix {
      uv_node = self.class_.get_transformed_uv(node, uv_node)
    }
    uv_node = self.class_.setup_uv(node, builder, uv_node)
    Some(uv_node)
  }).call([])
  let mut level_node = self.level_node
  if level_node is None {
    match builder.context.get_texture_level() {
      Some(get_texture_level) => level_node = Some((get_texture_level.f)(node))
      None => ()
    }
  }
  let mut compare_node : Node? = None
  let mut compare_step_node : Node? = None
  if self.compare_node is Some(this_compare_node) {
    if texture_node_has_compatibility(
        builder.renderer,
        @core.Compatibility_TEXTURE_COMPARE,
      ) {
      compare_node = Some(this_compare_node)
    } else {
      let compare_function = texture.compare_function
      if compare_function is None ||
        compare_function == Some(@core.LessCompare) ||
        compare_function == Some(@core.LessEqualCompare) ||
        compare_function == Some(@core.GreaterCompare) ||
        compare_function == Some(@core.GreaterEqualCompare) {
        compare_step_node = Some(this_compare_node)
      } else {
        compare_node = Some(this_compare_node)
        @core.warn_once(
          "TSL: Only \"LessCompare\", \"LessEqualCompare\", \"GreaterCompare\" and \"GreaterEqualCompare\" are supported for depth texture comparison fallback.",
        )
      }
    }
  }
  // the context can provide analytic gradients of the default uv
  let mut grad_node = self.grad_node
  if grad_node is None &&
    self.uv_node is None &&
    level_node is None &&
    self.bias_node is None &&
    self.sampler {
    match builder.context.get_texture_gradient() {
      Some(get_texture_gradient) =>
        match (get_texture_gradient.f)(node, builder) {
          Some(gradient) =>
            grad_node = Some(
              if self.update_matrix {
                gradient.map(fn(n) {
                  TextureNode::_get_transformed_gradient(node, n)
                })
              } else {
                gradient
              },
            )
          None => ()
        }
      None => ()
    }
  }
  properties.set_node("uvNode", uv_node)
  properties.set_node_or_null("levelNode", level_node)
  properties.set_node_or_null("biasNode", self.bias_node)
  properties.set_node_or_null("compareNode", compare_node)
  properties.set_node_or_null("compareStepNode", compare_step_node)
  match grad_node {
    Some(g) => properties.set("gradNode", Nodes(g))
    None => properties.set("gradNode", Null)
  }
  properties.set_node_or_null("gatherNode", self.gather_node)
  properties.set_node_or_null("depthNode", self.depth_node)
  properties.set_node_or_null("offsetNode", self.offset_node)
  None
}

///|
pub impl NodeClass for TextureNode with fn generate(self, node, builder, output) {
  let texture = TextureNode::get_value(node)
  let properties = builder.get_node_properties(node)
  let texture_property = self.uniform
    .generate(node, builder, Some("property"))
    .unwrap_or("")
  if output == Some("samplerComparison") ||
    properties.get_node("compareNode") is Some(_) {
    // make sure the texture node creates a binding with a comparison sampler
    texture_node_payload(UniformNode::get_shared_node(node, builder))._sampler_comparison
    = true
  }
  if output is Some(o) && o.has_prefix("sampler") {
    return Some(texture_property + "_sampler")
  } else if builder.is_reference(output) {
    return Some(texture_property)
  }
  let node_data = builder.get_data_from_node(node)
  let node_type = node.get_node_type(builder)
  let property_name = match node_data.property_name {
    Some(p) => p
    None => {
      let uv_node = properties.get_node("uvNode").unwrap()
      let level_node = properties.get_node("levelNode")
      let bias_node = properties.get_node("biasNode")
      let compare_node = properties.get_node("compareNode")
      let compare_step_node = properties.get_node("compareStepNode")
      let depth_node = properties.get_node("depthNode")
      let grad_node = match properties.get("gradNode") {
        Some(Nodes(g)) => Some(g)
        _ => None
      }
      let gather_node = properties.get_node("gatherNode")
      let offset_node = properties.get_node("offsetNode")
      let uv_snippet = self.class_.generate_uv(node, builder, uv_node)
      let level_snippet = level_node.map(fn(n) {
        n.build(builder, output="float")
      })
      let bias_snippet = bias_node.map(fn(n) {
        n.build(builder, output="float")
      })
      let depth_snippet = depth_node.map(fn(n) {
        n.build(builder, output="int")
      })
      let compare_snippet = compare_node.map(fn(n) {
        n.build(builder, output="float")
      })
      let compare_step_snippet = compare_step_node.map(fn(n) {
        n.build(builder, output="float")
      })
      let grad_snippet = grad_node.map(fn(g) {
        [g[0].build(builder, output="vec2"), g[1].build(builder, output="vec2")]
      })
      let gather_snippet = gather_node.map(fn(n) {
        n.build(builder, output="int")
      })
      let offset_snippet = offset_node.map(fn(n) {
        self.class_.generate_offset(node, builder, n)
      })
      let flip_y_uniform = texture_node_payload(TextureNode::get_base(node))._flip_y_uniform
      let flip_y_snippet = flip_y_uniform.map(fn(n) {
        n.build(builder, output="bool")
      })
      let mut final_depth_snippet = depth_snippet
      if final_depth_snippet is None &&
        texture.is_array_texture &&
        !node.has_flag("isTexture3DNode") {
        final_depth_snippet = Some("0")
      }
      let node_var = builder.get_var_from_node(
        node,
        None,
        None,
        None,
        false,
        false,
        "variable",
      )
      let property_name = builder.get_property_name(Var(node_var))
      let mut snippet = self.class_.generate_snippet(
        node, builder, texture_property, uv_snippet, level_snippet, bias_snippet,
        final_depth_snippet, compare_snippet, grad_snippet, gather_snippet, offset_snippet,
        flip_y_snippet,
      )
      let snippet_type = if texture.is_depth_texture() && gather_snippet is None {
        "float"
      } else if texture.type_ == @core.UnsignedIntType {
        "uvec4"
      } else if texture.type_ == @core.IntType {
        "ivec4"
      } else {
        "vec4"
      }
      snippet = builder.format(snippet, Some(snippet_type), node_type)
      if compare_step_snippet is Some(compare_step_snippet) {
        let compare_function = texture.compare_function
        let node_type_str = node_type.unwrap_or("null")
        snippet = if compare_function == Some(@core.GreaterCompare) ||
          compare_function == Some(@core.GreaterEqualCompare) {
          step(
            expression(snippet, node_type=node_type_str),
            expression(compare_step_snippet, node_type="float"),
          ).build(builder, output?=node_type)
        } else {
          step(
            expression(compare_step_snippet, node_type="float"),
            expression(snippet, node_type=node_type_str),
          ).build(builder, output?=node_type)
        }
      }
      builder.add_line_flow_code("\{property_name} = \{snippet}", node~)
      |> ignore
      node_data.snippet = Some(snippet)
      node_data.property_name = Some(property_name)
      property_name
    }
  }
  let mut snippet = property_name
  if builder.needs_to_working_color_space(texture) {
    snippet = color_space_to_working(
        expression(snippet, node_type=node_type.unwrap_or("null")),
        texture.color_space,
      )
      .setup(builder)
      .unwrap()
      .build(builder, output?=node_type)
  }
  Some(builder.format(snippet, node_type, output))
}

///|
pub impl NodeClass for TextureNode with fn serialize(self, node, data) {
  self.uniform.serialize(node, data)
  // `this.value.toJSON( data.meta ).uuid`: the texture's uuid.
  data.set("value", @core.JsValue::of(TextureNode::get_value(node).uuid))
  data.set("sampler", @core.JsValue::of(self.sampler))
  data.set("updateMatrix", @core.JsValue::of(self.update_matrix))
}

///|
pub impl NodeClass for TextureNode with fn deserialize(self, node, data) {
  self.uniform.deserialize(node, data)
  let textures = data.get("meta").get("textures")
  let value = textures.get(data.get("value").cast())
  if !value.is_undefined() && !value.is_null() {
    self.class_.set_value(node, Some(value.cast()))
  }
  self.sampler = data.get("sampler").cast()
  self.update_matrix = data.get("updateMatrix").cast()
}

///|
pub impl InputNodeClass for TextureNode with fn input_parent(self) {
  Some(self.uniform)
}

///|
pub impl InputNodeClass for TextureNode with fn get_input_type(_, _, _) {
  Some("texture")
}

///|
pub impl InputNodeClass for TextureNode with fn get_uniform_hash(
  self,
  node,
  builder,
) {
  match self.reference_node {
    Some(r) if !TextureNode::get_mergeable(r) => return r.get_hash(builder)
    _ => ()
  }
  if !self._mergeable {
    return node.get_hash(builder)
  }
  TextureNode::get_value(node).uuid
}

///|
/// The constructor body: `super( value )` has run in `Node::alloc`.
pub fn TextureNode::construct(
  node : Node,
  value : @core.Texture?,
  uv_node : Node?,
  level_node : Node?,
  bias_node : Node?,
) -> TextureNode {
  let uniform = UniformNode::construct(node, texture_node_tsl_value(value))
  {
    uniform,
    uv_node,
    level_node,
    bias_node,
    compare_node: None,
    depth_node: None,
    grad_node: None,
    gather_node: None,
    offset_node: None,
    sampler: true,
    // `this.setUpdateMatrix( uvNode === null )`; the subclasses that ignore
    // `setUpdateMatrix` reset it after this constructor.
    update_matrix: uv_node is None,
    reference_node: None,
    _mergeable: true,
    _value: value,
    _matrix_uniform: None,
    _flip_y_uniform: None,
    _sampler_comparison: false,
    class_: TextureNodeUnset::{ },
  }
}

///|
/// Installs `payload` as the most derived class of the texture node family.
pub fn TextureNode::install(
  self : TextureNode,
  node : Node,
  payload : &TextureNodeClass,
  class_ : &NodeClass,
  input_class : &InputNodeClass,
) -> Node {
  self.class_ = payload
  self.uniform.input.class_ = input_class
  node.set_class(class_)
}

///|
/// `new TextureNode( value = EmptyTexture, uvNode = null, levelNode = null,
/// biasNode = null )`; `value=None` is `null`.
pub fn TextureNode::new(
  value~ : @core.Texture? = Some(_texture_node_empty_texture),
  uv_node? : Node,
  level_node? : Node,
  bias_node? : Node,
) -> Node {
  let node = Node::alloc()
  let t = TextureNode::construct(node, value, uv_node, level_node, bias_node)
  t.install(node, t, t, t)
}

///|
pub fn TextureNode::of(node : Node) -> TextureNode? {
  match node.class_payload("TextureNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn texture_node_payload(node : Node) -> TextureNode {
  match TextureNode::of(node) {
    Some(t) => t
    None => abort("TypeError: \{node.type_()} is not a TextureNode")
  }
}

///|
fn texture_node_tsl_value(value : @core.Texture?) -> TslValue {
  match value {
    Some(t) => Texture(t)
    None => Null
  }
}

///|
/// `get mergeable()`.
pub fn TextureNode::get_mergeable(node : Node) -> Bool {
  let t = texture_node_payload(node)
  match t.reference_node {
    Some(r) => TextureNode::get_mergeable(r)
    None => t._mergeable
  }
}

///|
/// `set mergeable( value )`.
pub fn TextureNode::set_mergeable(node : Node, value : Bool) -> Unit {
  let t = texture_node_payload(node)
  match t.reference_node {
    Some(r) => TextureNode::set_mergeable(r, value)
    None => t._mergeable = value
  }
}

///|
/// `textureNode.value`; aborts like upstream's `TypeError` when it is `null`.
pub fn TextureNode::get_value(node : Node) -> @core.Texture {
  match TextureNode::get_value_opt(node) {
    Some(t) => t
    None =>
      abort("TypeError: Cannot read properties of null (texture node value)")
  }
}

///|
/// `textureNode.value`, `None` for `null`.
pub fn TextureNode::get_value_opt(node : Node) -> @core.Texture? {
  texture_node_payload(node).class_.get_value(node)
}

///|
/// `textureNode.value = value`.
pub fn TextureNode::set_value(node : Node, value : @core.Texture?) -> Unit {
  texture_node_payload(node).class_.set_value(node, value)
}

///|
/// TextureNode's `get value()`.
pub fn TextureNode::get_value_base(node : Node) -> @core.Texture? {
  let t = texture_node_payload(node)
  match t.reference_node {
    Some(r) => TextureNode::get_value_opt(r)
    None => t._value
  }
}

///|
/// TextureNode's `set value( value )`.
pub fn TextureNode::set_value_base(node : Node, value : @core.Texture?) -> Unit {
  let t = texture_node_payload(node)
  match t.reference_node {
    Some(r) => TextureNode::set_value(r, value)
    None => {
      t._value = value
      t.uniform.input.value = texture_node_tsl_value(value)
    }
  }
}

///|
/// `getDefaultUV()`, dispatched to the most derived class.
pub fn TextureNode::get_default_uv(node : Node) -> Node {
  texture_node_payload(node).class_.get_default_uv(node)
}

///|
/// `getTransformedUV( uvNode )`, dispatched.
pub fn TextureNode::get_transformed_uv(node : Node, uv_node : Node) -> Node {
  texture_node_payload(node).class_.get_transformed_uv(node, uv_node)
}

///|
/// `_getTransformedGradient( gradientNode )`.
fn TextureNode::_get_transformed_gradient(
  node : Node,
  gradient_node : Node,
) -> Node {
  TextureNode::_get_matrix_uniform(node).mul(vec3_of([gradient_node, 0])).xy()
}

///|
/// `_getMatrixUniform()`: the texture-matrix uniform of the base node.
pub fn TextureNode::_get_matrix_uniform(node : Node) -> Node {
  let base_node = TextureNode::get_base(node)
  let base = texture_node_payload(base_node)
  match base._matrix_uniform {
    Some(u) => u
    None => {
      let u = uniform(TextureNode::get_value(base_node).matrix).on_object_update(fn(
          self_,
          _,
        ) {
          let texture = TextureNode::get_value(base_node)
          if texture.matrix_auto_update {
            texture.update_matrix()
          }
          InputNode::set_value(self_, Matrix3(texture.matrix))
          None
        },
      )
      base._matrix_uniform = Some(u)
      u
    }
  }
}

///|
/// `setUpdateMatrix( value )`, chained.
pub fn Node::set_update_matrix(self : Node, value : Bool) -> Node {
  texture_node_payload(self).class_.set_update_matrix(self, value)
  self
}

///|
/// TextureNode's `setupUV( builder, uvNode )`.
pub fn TextureNode::setup_uv_base(
  node : Node,
  builder : NodeBuilder,
  uv_node : Node,
) -> Node {
  let mut uv_node = uv_node
  if builder.is_flip_y() {
    let base_node = TextureNode::get_base(node)
    let base = texture_node_payload(base_node)
    let flip_y_uniform = match base._flip_y_uniform {
      Some(u) => u
      None => {
        let u = uniform(false).on_object_update(fn(self_, _) {
          let texture = TextureNode::get_value(base_node)
          let is_image_bitmap = match texture.image() {
            DomImage(image) => _texture_node_is_image_bitmap(image)
            _ => false
          }
          InputNode::set_value(
            self_,
            Bool(
              (is_image_bitmap && texture.flip_y) ||
              texture.is_render_target_texture ||
              texture.texture_type is FramebufferTexture ||
              texture.is_depth_texture(),
            ),
          )
          None
        })
        base._flip_y_uniform = Some(u)
        u
      }
    }
    uv_node = uv_node.to_var()
    let t = texture_node_payload(node)
    uv_node = if t.sampler {
      flip_y_uniform.select(uv_node.flip_y(), else_node=uv_node)
    } else {
      flip_y_uniform.select(
        uv_node.set_y(
          int(
            (match t.level_node {
              Some(l) => texture_size(node, level_node=l)
              None => texture_size(node)
            }).y(),
          )
          .sub(int(uv_node.y()))
          .sub(1),
        ),
        else_node=uv_node,
      )
    }
  }
  uv_node
}

///|
/// TextureNode's `generateSnippet( ... )`.
pub fn TextureNode::generate_snippet_base(
  node : Node,
  builder : NodeBuilder,
  texture_property : String,
  uv_snippet : String,
  level_snippet : String?,
  bias_snippet : String?,
  depth_snippet : String?,
  compare_snippet : String?,
  grad_snippet : Array[String]?,
  gather_snippet : String?,
  offset_snippet : String?,
  flip_y_snippet : String?,
) -> String {
  let texture = TextureNode::get_value(node)
  if texture_node_truthy(bias_snippet) {
    builder.generate_texture_bias(
      texture,
      texture_property,
      uv_snippet,
      bias_snippet.unwrap(),
      depth_snippet,
      offset_snippet,
    )
  } else if grad_snippet is Some(grad_snippet) {
    builder.generate_texture_grad(
      texture, texture_property, uv_snippet, grad_snippet, depth_snippet, offset_snippet,
    )
  } else if texture_node_truthy(gather_snippet) {
    if texture_node_truthy(compare_snippet) {
      builder.generate_texture_gather_compare(
        texture,
        texture_property,
        uv_snippet,
        compare_snippet.unwrap(),
        depth_snippet,
        offset_snippet,
        flip_y_snippet?,
      )
    } else {
      builder.generate_texture_gather(
        texture,
        texture_property,
        uv_snippet,
        gather_snippet,
        depth_snippet,
        offset_snippet,
        flip_y_snippet?,
      )
    }
  } else if texture_node_truthy(compare_snippet) {
    builder.generate_texture_compare(
      texture,
      texture_property,
      uv_snippet,
      compare_snippet.unwrap(),
      depth_snippet,
      offset_snippet,
    )
  } else if !texture_node_payload(node).sampler {
    builder.generate_texture_load(
      texture, texture_property, uv_snippet, level_snippet, depth_snippet, offset_snippet,
    )
  } else if texture_node_truthy(level_snippet) {
    builder.generate_texture_level(
      texture,
      texture_property,
      uv_snippet,
      level_snippet.unwrap(),
      depth_snippet,
      offset_snippet,
    )
  } else {
    builder.generate_texture(
      texture,
      texture_property,
      uv_snippet,
      depth_snippet?,
      offset_snippet?,
    )
  }
}

///|
/// `renderer.hasCompatibility( name )`. Pending: the renderer group's
/// `Renderer::has_compatibility` (upstream throws before `init()` as well).
fn texture_node_has_compatibility(renderer : Renderer, name : String) -> Bool {
  renderer.has_compatibility(name)
}

///|
/// A snippet's JS truthiness: `null` and `''` are false.
fn texture_node_truthy(snippet : String?) -> Bool {
  match snippet {
    Some(s) => s != ""
    None => false
  }
}

///|
/// `setSampler( value )`, chained.
pub fn Node::set_sampler(self : Node, value : Bool) -> Node {
  texture_node_payload(self).sampler = value
  self
}

///|
/// `getSampler()`.
pub fn Node::get_sampler(self : Node) -> Bool {
  texture_node_payload(self).sampler
}

///|
/// `clone()`, dispatched to the most derived class.
pub fn TextureNode::clone(node : Node) -> Node {
  texture_node_payload(node).class_.clone(node)
}

///|
/// TextureNode's `clone()`.
pub fn TextureNode::clone_base(node : Node) -> Node {
  let t = texture_node_payload(node)
  let new_node = t.class_.construct_like(
    TextureNode::get_value_opt(node),
    t.uv_node,
    t.level_node,
    t.bias_node,
  )
  let n = texture_node_payload(new_node)
  n.sampler = t.sampler
  n.depth_node = t.depth_node
  n.compare_node = t.compare_node
  n.grad_node = t.grad_node
  n.gather_node = t.gather_node
  n.offset_node = t.offset_node
  new_node
}

///|
/// A clone of `self` whose `referenceNode` is the base node, for the chained forms.
fn texture_node_derive(node : Node) -> (Node, TextureNode) {
  let texture_node = TextureNode::clone(node)
  let t = texture_node_payload(texture_node)
  t.reference_node = Some(TextureNode::get_base(node))
  (texture_node, t)
}

///|
/// `sample( uvNode )`, on a TextureNode or a SampleNode.
pub fn Node::sample(self : Node, uv_node : &IntoTsl) -> Node {
  if SampleNode::of(self) is Some(s) {
    return s.sample(node_object(uv_node.to_tsl()))
  }
  let texture_node = TextureNode::clone(self)
  let t = texture_node_payload(texture_node)
  t.uv_node = Some(node_object(uv_node.to_tsl()))
  t.reference_node = Some(TextureNode::get_base(self))
  texture_node
}

///|
/// `load( uvNode )`.
pub fn Node::load(self : Node, uv_node : &IntoTsl) -> Node {
  self.sample(uv_node).set_sampler(false)
}

///|
/// `blur( amountNode )`.
pub fn Node::blur(self : Node, amount_node : &IntoTsl) -> Node {
  let texture_node = TextureNode::clone(self)
  let t = texture_node_payload(texture_node)
  t.bias_node = Some(
    node_object(amount_node.to_tsl()).mul(max_mip_level(texture_node)),
  )
  t.reference_node = Some(TextureNode::get_base(self))
  // Upstream then warns when `textureNode.generateMipmaps === false`, a property no
  // texture node has, so that branch never runs.
  texture_node
}

///|
/// `level( levelNode )`.
pub fn Node::level(self : Node, level_node : &IntoTsl) -> Node {
  let (texture_node, t) = texture_node_derive(self)
  t.level_node = Some(node_object(level_node.to_tsl()))
  texture_node
}

///|
/// `size( levelNode )`.
pub fn Node::size(self : Node, level_node? : &IntoTsl) -> Node {
  texture_size(self, level_node?)
}

///|
/// `bias( biasNode )`.
pub fn Node::bias(self : Node, bias_node : &IntoTsl) -> Node {
  let (texture_node, t) = texture_node_derive(self)
  t.bias_node = Some(node_object(bias_node.to_tsl()))
  texture_node
}

///|
/// `getBase()`: the node the derived texture nodes refer to.
pub fn TextureNode::get_base(node : Node) -> Node {
  match texture_node_payload(node).reference_node {
    Some(r) => TextureNode::get_base(r)
    None => node
  }
}

///|
/// `getBase()`, chained.
pub fn Node::get_base(self : Node) -> Node {
  TextureNode::get_base(self)
}

///|
/// `compare( compareNode )`.
pub fn Node::compare(self : Node, compare_node : &IntoTsl) -> Node {
  let (texture_node, t) = texture_node_derive(self)
  t.compare_node = Some(node_object(compare_node.to_tsl()))
  texture_node
}

///|
/// `grad( gradNodeX, gradNodeY )`.
pub fn Node::grad(
  self : Node,
  grad_node_x : &IntoTsl,
  grad_node_y : &IntoTsl,
) -> Node {
  let (texture_node, t) = texture_node_derive(self)
  t.grad_node = Some([
    node_object(grad_node_x.to_tsl()),
    node_object(grad_node_y.to_tsl()),
  ])
  texture_node
}

///|
/// `gather( gatherNode = 0 )`.
pub fn Node::gather(self : Node, gather_node? : &IntoTsl) -> Node {
  let (texture_node, t) = texture_node_derive(self)
  t.gather_node = Some(
    match gather_node {
      Some(g) => node_object(g.to_tsl())
      None => node_object(Number(0.0))
    },
  )
  texture_node
}

///|
/// `isSampleCompare()`.
pub fn TextureNode::is_sample_compare(node : Node) -> Bool {
  let t = texture_node_payload(node)
  t.compare_node is Some(_) || t._sampler_comparison
}

///|
/// `depth( depthNode )`.
pub fn Node::depth(self : Node, depth_node : &IntoTsl) -> Node {
  let (texture_node, t) = texture_node_derive(self)
  t.depth_node = Some(node_object(depth_node.to_tsl()))
  texture_node
}

///|
/// `offset( offsetNode )`.
pub fn Node::offset(self : Node, offset_node : &IntoTsl) -> Node {
  let (texture_node, t) = texture_node_derive(self)
  t.offset_node = Some(node_object(offset_node.to_tsl()))
  texture_node
}

///|
/// `textureBase( value, uvNode, levelNode, biasNode )` (`nodeProxy( TextureNode )`):
/// the arguments pass through `nodeObject`.
fn texture_node_base(
  value : TslValue,
  uv_node : TslValue,
  level_node : TslValue,
  bias_node : TslValue,
) -> Node {
  TextureNode::new(
    value=texture_node_texture_arg(value),
    uv_node?=texture_node_node_arg(uv_node),
    level_node?=texture_node_node_arg(level_node),
    bias_node?=texture_node_node_arg(bias_node),
  )
}

///|
/// A `value` argument: a texture, or `null` (a `TextureNode` is handled by callers).
fn texture_node_texture_arg(value : TslValue) -> @core.Texture? {
  match value {
    Texture(t) => Some(t)
    Undefined => Some(_texture_node_empty_texture)
    Null => None
    Js(v) => Some(v.cast())
    _ => abort("TSL: texture( value ) expects a Texture")
  }
}

///|
/// A node argument after `nodeObject`: `null` stays `null`.
fn texture_node_node_arg(value : TslValue) -> Node? {
  match value {
    Undefined | Null => None
    v => Some(node_object(v))
  }
}

///|
/// `texture( value = EmptyTexture, uvNode = null, levelNode = null, biasNode = null )`.
/// `value` is a `Texture`, a texture node (cloned) or `null`.
pub fn texture(
  value : &IntoTsl,
  uv_node? : &IntoTsl,
  level_node? : &IntoTsl,
  bias_node? : &IntoTsl,
) -> Node {
  let value = value.to_tsl()
  let uv_node = texture_node_opt_arg(uv_node)
  let level_node = texture_node_opt_arg(level_node)
  let bias_node = texture_node_opt_arg(bias_node)
  match value {
    Node(v) if v.has_flag("isTextureNode") => {
      let texture_node = TextureNode::clone(v)
      let t = texture_node_payload(texture_node)
      // Ensure the reference is set to the original node
      t.reference_node = Some(TextureNode::get_base(v))
      if !(uv_node is Null) {
        t.uv_node = Some(node_object(uv_node))
      }
      if !(level_node is Null) {
        t.level_node = Some(node_object(level_node))
      }
      if !(bias_node is Null) {
        t.bias_node = Some(node_object(bias_node))
      }
      texture_node
    }
    _ => texture_node_base(value, uv_node, level_node, bias_node)
  }
}

///|
/// A labelled TSL argument: omitted is the default `null`.
fn texture_node_opt_arg(value : &IntoTsl?) -> TslValue {
  match value {
    Some(v) => v.to_tsl()
    None => Null
  }
}

///|
/// `texture()` with the default `EmptyTexture`.
pub fn texture_empty() -> Node {
  texture(_texture_node_empty_texture)
}

///|
/// `uniformTexture( value = EmptyTexture )`.
pub fn uniform_texture(value? : @core.Texture) -> Node {
  let texture_node = texture(value.unwrap_or(_texture_node_empty_texture))
  TextureNode::set_mergeable(texture_node, false)
  texture_node
}

///|
/// `textureLoad( ...params )`.
pub fn texture_load(
  value : &IntoTsl,
  uv_node? : &IntoTsl,
  level_node? : &IntoTsl,
  bias_node? : &IntoTsl,
) -> Node {
  texture(value, uv_node?, level_node?, bias_node?).set_sampler(false)
}

///|
/// `textureLevel( value, uv, level )`.
pub fn texture_level(
  value : &IntoTsl,
  uv_node : &IntoTsl,
  level_node : &IntoTsl,
) -> Node {
  texture(value, uv_node~).level(level_node)
}

///|
/// `sampler( value )`.
pub fn sampler(value : &IntoTsl) -> Node {
  let node = match value.to_tsl() {
    Node(n) => n
    _ => texture(value)
  }
  node.convert("sampler")
}

///|
/// `samplerComparison( value )`.
pub fn sampler_comparison(value : &IntoTsl) -> Node {
  let node = match value.to_tsl() {
    Node(n) => n
    _ => texture(value)
  }
  node.convert("samplerComparison")
}

///|
/// `builder.context.getTextureLevel( textureNode )`.
pub(all) struct ContextGetTextureLevel {
  f : (Node) -> Node
}

///|
/// `builder.context.getTextureLevel`, if set.
pub fn NodeContext::get_texture_level(
  self : NodeContext,
) -> ContextGetTextureLevel? {
  match self.get("getTextureLevel") {
    Other(_) as v => v.cast()
    _ => None
  }
}

///|
/// `builder.context.getTextureGradient( textureNode, builder )`: `[ dx, dy ]` or
/// `null`.
pub(all) struct ContextGetTextureGradient {
  f : (Node, NodeBuilder) -> Array[Node]?
}

///|
/// `builder.context.getTextureGradient`, if set.
pub fn NodeContext::get_texture_gradient(
  self : NodeContext,
) -> ContextGetTextureGradient? {
  match self.get("getTextureGradient") {
    Other(_) as v => v.cast()
    _ => None
  }
}
