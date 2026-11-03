// materials/nodes/NodeMaterialInstance.js: a material sharing the node setup of a node
// material while keeping its own configuration (color, opacity, userData, ...). The
// node slots read through to the node material (`NodeMaterial::of` of an instance is
// the node material's payload).

///|
/// `instance -> nodeMaterial` for `NodeMaterialInstance`s.
let node_material_instances : @webgl.WeakMap[@core.Material, @core.Material] = @webgl.WeakMap::new()

///|
/// The node material of a `NodeMaterialInstance`; `None` for other materials.
fn node_material_instance_of(material : @core.Material) -> @core.Material? {
  node_material_instances.get(material)
}

///|
pub(all) struct NodeMaterialInstance {
  /// The node material whose setup the instance shares.
  node_material : @core.Material
}

///|
pub impl @core.MaterialExtension for NodeMaterialInstance with fn type_name(_) {
  "NodeMaterialInstance"
}

///|
/// `new this.constructor( this.nodeMaterial )` (used by `clone`).
pub impl @core.MaterialExtension for NodeMaterialInstance with fn construct(
  self,
) {
  NodeMaterialInstance::new(self.node_material)
}

///|
/// The node material's `NodeMaterial` payload: the node properties are read-only
/// accessors of the node material.
pub impl @core.MaterialExtension for NodeMaterialInstance with fn payload(self) {
  match self.node_material.extension {
    Some(extension) => extension.payload()
    None => abort("unreachable: NodeMaterialInstance of a plain material")
  }
}

///|
/// `isNodeMaterialInstance`, and the `is*` flags copied from the node material.
pub impl @core.MaterialExtension for NodeMaterialInstance with fn has_flag(
  self,
  flag,
) {
  flag == "isNodeMaterialInstance" ||
  (flag.has_prefix("is") && self.node_material.has_extension_flag(flag))
}

///|
/// `copy( source )`: `copyProperties( this, source )` and a copy of `userData`.
pub impl @core.MaterialExtension for NodeMaterialInstance with fn copy_from(
  _,
  material,
  source,
) {
  node_material_instance_copy_properties(material, source)
  material.user_data = node_material_instance_clone_user_data(source.user_data)
}

///|
pub impl @core.MaterialExtension for NodeMaterialInstance with fn custom_program_cache_key(
  self,
  _,
) {
  Some(self.node_material.uuid + "," + self.node_material.version.to_string())
}

///|
/// `copyProperties( target, source )`: every own property except `uuid`, `version` and
/// the listeners (and the identity fields here: `id`, `type`, the class). Node
/// properties are not copied: they read through to the node material.
extern "js" fn node_material_instance_copy_properties(
  target : @core.Material,
  source : @core.Material,
) -> Unit =
  #|(t, s) => {
  #|  for ( const k of Object.keys( s ) ) {
  #|    if ( k === 'id' || k === 'dispatcher' || k === 'extension' || k === 'type_' || k === 'material_type' || k === 'uuid' || k === 'version' ) continue;
  #|    t[ k ] = s[ k ];
  #|  }
  #|}

///|
/// `cloneUserData( userData )`: copies the first level, cloning values such as colors
/// and sharing textures.
extern "js" fn node_material_instance_clone_user_data(
  user_data : @core.JsValue,
) -> @core.JsValue =
  #|(userData) => {
  #|  const result = {};
  #|  for ( const key in userData ) {
  #|    const value = userData[ key ];
  #|    result[ key ] = value?.clone !== undefined && value.isTexture !== true ? value.clone() : value;
  #|  }
  #|  return result;
  #|}

///|
/// `new NodeMaterialInstance( nodeMaterial )`.
pub fn NodeMaterialInstance::new(
  node_material : @core.Material,
) -> @core.Material {
  let material = @core.Material::new()
  if node_material.is_node_material() != true {
    abort(
      "TypeError: THREE.NodeMaterialInstance: The parameter must be a NodeMaterial.",
    )
  }
  node_material_instance_copy_properties(material, node_material)
  // Instance values often live in `userData`, so each instance starts with its own
  // copy.
  material.user_data = node_material_instance_clone_user_data(
    node_material.user_data,
  )
  material.set_extension(NodeMaterialInstance::{ node_material, }) |> ignore
  node_material_instances.set(material, node_material)
  material
}

///|
/// The `NodeMaterialInstance` payload; `None` for other materials.
pub fn NodeMaterialInstance::of(
  material : @core.Material,
) -> NodeMaterialInstance? {
  match node_material_instance_of(material) {
    Some(node_material) => Some({ node_material, })
    None => None
  }
}
