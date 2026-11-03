// Upstream src/renderers/webgl/WebGLShaderCache.js.

///|
let webgl_shader_stage_id : Ref[Int32] = { val: 0, }

///|
/// `WebGLShaderStage`: one distinct shader source and how many materials use it.
pub(all) struct WebGLShaderStage {
  id : Int32
  code : String
  mut used_times : Int32
}

///|
/// `new WebGLShaderStage( code )`.
pub fn WebGLShaderStage::new(code : String) -> WebGLShaderStage {
  let id = webgl_shader_stage_id.val
  webgl_shader_stage_id.val += 1
  { id, code, used_times: 0, }
}

///|
pub struct WebGLShaderCache {
  /// code -> stage
  shader_cache : Map[String, WebGLShaderStage]
  /// material id -> the `Set` of stages it uses, keyed by stage id
  material_cache : Map[Int32, Map[Int32, WebGLShaderStage]]
}

///|
/// `new WebGLShaderCache()`.
pub fn WebGLShaderCache::new() -> WebGLShaderCache {
  { shader_cache: {}, material_cache: {}, }
}

///|
/// `cache.update( material, vertexShaderStage, fragmentShaderStage )`.
pub fn WebGLShaderCache::update(
  self : WebGLShaderCache,
  material : @core.Material,
  vertex_shader_stage : WebGLShaderStage,
  fragment_shader_stage : WebGLShaderStage,
) -> WebGLShaderCache {
  let material_shaders = self._get_shader_cache_for_material(material)
  if !material_shaders.contains(vertex_shader_stage.id) {
    material_shaders[vertex_shader_stage.id] = vertex_shader_stage
    vertex_shader_stage.used_times += 1
  }
  if !material_shaders.contains(fragment_shader_stage.id) {
    material_shaders[fragment_shader_stage.id] = fragment_shader_stage
    fragment_shader_stage.used_times += 1
  }
  self
}

///|
/// `cache.remove( material )`.
pub fn WebGLShaderCache::remove(
  self : WebGLShaderCache,
  material : @core.Material,
) -> WebGLShaderCache {
  guard self.material_cache.get(material.id) is Some(material_shaders) else {
    abort("WebGLShaderCache.remove: material has no shader stages")
  }
  for _, shader_stage in material_shaders {
    shader_stage.used_times -= 1
    if shader_stage.used_times == 0 {
      self.shader_cache.remove(shader_stage.code)
    }
  }
  self.material_cache.remove(material.id)
  self
}

///|
/// `cache.getVertexShaderStage( material )`.
pub fn WebGLShaderCache::get_vertex_shader_stage(
  self : WebGLShaderCache,
  material : @core.Material,
) -> WebGLShaderStage {
  self._get_shader_stage(material.vertex_shader.unwrap_or(""))
}

///|
/// `cache.getFragmentShaderStage( material )`.
pub fn WebGLShaderCache::get_fragment_shader_stage(
  self : WebGLShaderCache,
  material : @core.Material,
) -> WebGLShaderStage {
  self._get_shader_stage(material.fragment_shader.unwrap_or(""))
}

///|
/// `cache.dispose()`.
pub fn WebGLShaderCache::dispose(self : WebGLShaderCache) -> Unit {
  self.shader_cache.clear()
  self.material_cache.clear()
}

///|
fn WebGLShaderCache::_get_shader_cache_for_material(
  self : WebGLShaderCache,
  material : @core.Material,
) -> Map[Int32, WebGLShaderStage] {
  match self.material_cache.get(material.id) {
    Some(set) => set
    None => {
      let set = Map([])
      self.material_cache[material.id] = set
      set
    }
  }
}

///|
fn WebGLShaderCache::_get_shader_stage(
  self : WebGLShaderCache,
  code : String,
) -> WebGLShaderStage {
  match self.shader_cache.get(code) {
    Some(stage) => stage
    None => {
      let stage = WebGLShaderStage::new(code)
      self.shader_cache[code] = stage
      stage
    }
  }
}
