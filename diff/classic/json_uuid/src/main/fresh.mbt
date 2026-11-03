// Freshly built objects of every kind, for the seeded Math.random comparison in
// run.mjs: which uuid every object (and every object it creates) draws, the order of
// the id counters, and `toJSON()` where the class has one.

///|
struct Base {
  o : Int
  g : Int
  m : Int
  t : Int
  s : Int
}

///|
fn base() -> Base {
  {
    o: @core.Object3D::new().id + 1,
    g: @core.BufferGeometry::new().id + 1,
    m: @core.Material::new().id + 1,
    t: @core.Texture::new().id + 1,
    s: @core.TextureSource::new().id + 1,
  }
}

///|
fn entry(path : String, uuid : String, id : Int) -> Json {
  [Json::string(path), Json::string(uuid), Json::number(id.to_double())]
}

///|
fn probe_geometry(
  g : @core.BufferGeometry,
  path : String,
  b : Base,
  out : Array[Json],
) -> Unit {
  out.push(entry(path, g.uuid, g.id - b.g))
}

///|
fn probe_material(
  m : @core.Material,
  path : String,
  b : Base,
  out : Array[Json],
) -> Unit {
  out.push(entry(path, m.uuid, m.id - b.m))
}

///|
fn probe_slot(
  slot : @core.MaterialSlot,
  path : String,
  b : Base,
  out : Array[Json],
) -> Unit {
  match slot {
    Single(m) => probe_material(m, path, b, out)
    Multiple(ms) =>
      for i, m in ms {
        probe_material(m, "\{path}[\{i}]", b, out)
      }
  }
}

///|
fn probe_texture(
  t : @core.Texture,
  path : String,
  b : Base,
  out : Array[Json],
) -> Unit {
  out.push(entry(path, t.uuid, t.id - b.t))
  out.push(entry(path + ".source", t.source.uuid, t.source.id - b.s))
}

///|
fn probe_object(
  o : @core.Object3D,
  path : String,
  b : Base,
  out : Array[Json],
) -> Unit {
  out.push(entry(path, o.uuid, o.id - b.o))
  match o.kind {
    Mesh(mesh) => {
      probe_geometry(mesh.geometry, path + ".geometry", b, out)
      probe_slot(mesh.material, path + ".material", b, out)
    }
    Line(line) => {
      probe_geometry(line.geometry, path + ".geometry", b, out)
      probe_slot(line.material, path + ".material", b, out)
    }
    Points(points) => {
      probe_geometry(points.geometry, path + ".geometry", b, out)
      probe_slot(points.material, path + ".material", b, out)
    }
    Sprite(sprite) => {
      probe_geometry(sprite.geometry, path + ".geometry", b, out)
      probe_material(sprite.material, path + ".material", b, out)
    }
    Light(light) => {
      match light.kind {
        DirectionalLight(d) => probe_object(d.target, path + ".target", b, out)
        SpotLight(s) => probe_object(s.target, path + ".target", b, out)
        _ => ()
      }
      if light.shadow is Some(shadow) {
        probe_object(shadow.camera, path + ".shadow.camera", b, out)
      }
    }
    _ => ()
  }
  for i, child in o.children {
    probe_object(child, "\{path}.children[\{i}]", b, out)
  }
}

///|
fn probe_render_target(
  rt : @core.RenderTarget,
  path : String,
  b : Base,
  out : Array[Json],
) -> Unit {
  for i, t in rt.textures {
    probe_texture(t, "\{path}.textures[\{i}]", b, out)
  }
  if rt.depth_texture() is Some(t) {
    probe_texture(t, path + ".depthTexture", b, out)
  }
}

///|
enum Fresh {
  O(@core.Object3D)
  G(@core.BufferGeometry)
  M(@core.Material)
  T(@core.Texture)
  RT(@core.RenderTarget)
  Stereo(@core.StereoCamera)
  Skel(@core.Skeleton)
  IB(@core.InterleavedBuffer)
  Shape(@extras.Shape)
  Clip(@animation.AnimationClip)
}

///|
fn build(name : String) -> Fresh {
  match name {
    // objects
    "Object3D" => O(@core.Object3D::new())
    "Group" => O(@core.Group::new())
    "Bone" => O(@core.Bone::new())
    "Scene" => O(@core.Scene::new())
    "LOD" => O(@core.LOD::new())
    "ClippingGroup" => O(@core.ClippingGroup::new())
    "Mesh" => O(@core.Mesh::new())
    "Line" => O(@core.Line::new())
    "LineSegments" => O(@core.LineSegments::new())
    "LineLoop" => O(@core.LineLoop::new())
    "Points" => O(@core.Points::new())
    "Sprite" => O(@core.Sprite::new())
    "Sprite2" => O(@core.Sprite::new())
    "SkinnedMesh" => O(@core.SkinnedMesh::new())
    "InstancedMesh" => O(@core.InstancedMesh::new(2))
    "BatchedMesh" => O(@core.BatchedMesh::new(4, 10, max_index_count=20))
    // cameras
    "Camera" => O(@core.Camera::new())
    "PerspectiveCamera" => O(@core.PerspectiveCamera::new())
    "OrthographicCamera" => O(@core.OrthographicCamera::new())
    "ArrayCamera" => O(@core.ArrayCamera::new())
    "CubeCamera" => {
      let rt = @core.RenderTarget::new(width=4, height=4)
      O(@core.CubeCamera::new(near=0.1, far=2000.0, render_target=rt))
    }
    "StereoCamera" => Stereo(@core.StereoCamera::new())
    // lights
    "Light" => O(@core.Light::new())
    "AmbientLight" => O(@core.AmbientLight::new())
    "DirectionalLight" => O(@core.DirectionalLight::new())
    "HemisphereLight" => O(@core.HemisphereLight::new())
    "PointLight" => O(@core.PointLight::new())
    "SpotLight" => O(@core.SpotLight::new())
    "RectAreaLight" => O(@core.RectAreaLight::new())
    "LightProbe" => O(@core.LightProbe::new())
    "IESSpotLight" => O(@core.IESSpotLight::new())
    "ProjectorLight" => O(@core.ProjectorLight::new())
    // core
    "BufferGeometry" => G(@core.BufferGeometry::new())
    "InstancedBufferGeometry" => G(@core.InstancedBufferGeometry::new())
    "InterleavedBuffer" =>
      IB(@core.InterleavedBuffer::new(@core.TypedArray::float32(6), 3))
    "InstancedInterleavedBuffer" =>
      IB(@core.InstancedInterleavedBuffer::new(@core.TypedArray::float32(6), 3))
    "Skeleton" =>
      Skel(@core.Skeleton::new(bones=[@core.Bone::new(), @core.Bone::new()]))
    // materials
    "Material" => M(@core.Material::new())
    "LineBasicMaterial" => M(@core.LineBasicMaterial::new())
    "LineDashedMaterial" => M(@core.LineDashedMaterial::new())
    "MeshBasicMaterial" => M(@core.MeshBasicMaterial::new())
    "MeshDepthMaterial" => M(@core.MeshDepthMaterial::new())
    "MeshDistanceMaterial" => M(@core.MeshDistanceMaterial::new())
    "MeshLambertMaterial" => M(@core.MeshLambertMaterial::new())
    "MeshMatcapMaterial" => M(@core.MeshMatcapMaterial::new())
    "MeshNormalMaterial" => M(@core.MeshNormalMaterial::new())
    "MeshPhongMaterial" => M(@core.MeshPhongMaterial::new())
    "MeshPhysicalMaterial" => M(@core.MeshPhysicalMaterial::new())
    "MeshStandardMaterial" => M(@core.MeshStandardMaterial::new())
    "MeshToonMaterial" => M(@core.MeshToonMaterial::new())
    "PointsMaterial" => M(@core.PointsMaterial::new())
    "RawShaderMaterial" => M(@core.RawShaderMaterial::new())
    "ShaderMaterial" => M(@core.ShaderMaterial::new())
    "ShadowMaterial" => M(@core.ShadowMaterial::new())
    "SpriteMaterial" => M(@core.SpriteMaterial::new())
    // textures
    "Texture" => T(@core.Texture::new())
    "DataTexture" => T(@core.DataTexture::new())
    "Data3DTexture" => T(@core.Data3DTexture::new())
    "DataArrayTexture" => T(@core.DataArrayTexture::new())
    "CubeTexture" => T(@core.CubeTexture::new())
    "CompressedTexture" => T(@core.CompressedTexture::new())
    "CompressedArrayTexture" => T(@core.CompressedArrayTexture::new())
    "DepthTexture" => T(@core.DepthTexture::new(width=4, height=4))
    "CubeDepthTexture" => T(@core.CubeDepthTexture::new(size=4))
    "FramebufferTexture" => T(@core.FramebufferTexture::new(width=4, height=4))
    "CanvasTexture" => T(@core.CanvasTexture::new())
    "VideoFrameTexture" => T(@core.VideoFrameTexture::new())
    "ExternalTexture" => T(@core.ExternalTexture::new())
    "RenderTarget" => RT(@core.RenderTarget::new(width=4, height=4))
    "RenderTarget3D" =>
      RT(@core.RenderTarget3D::new(width=4, height=4, depth=2))
    // geometries
    "BoxGeometry" => G(@geometries.BoxGeometry::new())
    "CapsuleGeometry" => G(@geometries.CapsuleGeometry::new())
    "CircleGeometry" => G(@geometries.CircleGeometry::new())
    "ConeGeometry" => G(@geometries.ConeGeometry::new())
    "CylinderGeometry" => G(@geometries.CylinderGeometry::new())
    "DodecahedronGeometry" => G(@geometries.DodecahedronGeometry::new())
    "EdgesGeometry" => G(@geometries.EdgesGeometry::new())
    "ExtrudeGeometry" => G(@geometries.ExtrudeGeometry::new())
    "IcosahedronGeometry" => G(@geometries.IcosahedronGeometry::new())
    "LatheGeometry" => G(@geometries.LatheGeometry::new())
    "OctahedronGeometry" => G(@geometries.OctahedronGeometry::new())
    "PlaneGeometry" => G(@geometries.PlaneGeometry::new())
    "PolyhedronGeometry" => G(@geometries.PolyhedronGeometry::new())
    "RingGeometry" => G(@geometries.RingGeometry::new())
    "ShapeGeometry" => G(@geometries.ShapeGeometry::new())
    "SphereGeometry" => G(@geometries.SphereGeometry::new())
    "TetrahedronGeometry" => G(@geometries.TetrahedronGeometry::new())
    "TorusGeometry" => G(@geometries.TorusGeometry::new())
    "TorusKnotGeometry" => G(@geometries.TorusKnotGeometry::new())
    "TubeGeometry" => G(@geometries.TubeGeometry::new())
    "WireframeGeometry" => G(@geometries.WireframeGeometry::new())
    // extras, animation
    "Shape" => Shape(@extras.Shape::new())
    "AnimationClip" => Clip(@animation.AnimationClip::new(name="c"))
    _ => abort("unknown fresh scenario " + name)
  }
}

///|
/// `{ probes, json }` for a fresh `name`, with `Math.random` already reseeded by run.mjs
/// after `base()` ran.
pub fn fresh(name : String) -> String {
  let b = base()
  reseed_hook()
  let built = build(name)
  let out : Array[Json] = []
  let json : Json = match built {
    O(o) => {
      probe_object(o, "", b, out)
      o.to_json()
    }
    G(g) => {
      probe_geometry(g, "", b, out)
      g.to_json()
    }
    M(m) => {
      probe_material(m, "", b, out)
      m.to_json()
    }
    T(t) => {
      probe_texture(t, "", b, out)
      Json::null()
    }
    RT(rt) => {
      probe_render_target(rt, "", b, out)
      Json::null()
    }
    Stereo(s) => {
      probe_object(s.camera_l, ".cameraL", b, out)
      probe_object(s.camera_r, ".cameraR", b, out)
      Json::null()
    }
    Skel(s) => {
      out.push(entry("", s.uuid, 0))
      for i, bone in s.bones {
        probe_object(bone, "\{i}", b, out)
      }
      s.to_json()
    }
    IB(ib) => {
      out.push(entry("", ib.uuid, 0))
      Json::null()
    }
    Shape(s) => {
      out.push(entry("", s.uuid(), 0))
      s.to_json()
    }
    Clip(c) => {
      out.push(entry("", c.uuid, 0))
      c.to_json()
    }
  }
  ({ "probes": Json::array(out), "json": json } : Json).stringify()
}

///|
/// Reseeds `Math.random` through the hook run.mjs installs (`globalThis.__reseed`).
extern "js" fn reseed_hook() -> Unit = "() => globalThis.__reseed()"
