// The MoonBit side of dump_up.mjs: the same canonical JSON, field by field.

///|
using @core {type JsValue}

///|
extern "js" fn obj() -> JsValue = "() => ({})"

///|
extern "js" fn put(o : JsValue, k : String, v : JsValue) -> Unit = "(o, k, v) => { o[k] = v; }"

///|
extern "js" fn null_() -> JsValue = "() => null"

///|
extern "js" fn stringify(v : JsValue) -> String = "(v) => JSON.stringify(v)"

///|
extern "js" fn hash_view(a : @core.TypedArray) -> JsValue =
  #|(a) => { const b = new Uint8Array(a.buffer, a.byteOffset, a.byteLength); let h = 0x811c9dc5; for (let i = 0; i < b.length; i++) { h ^= b[i]; h = Math.imul(h, 0x01000193) >>> 0; } return h.toString(16).padStart(8, '0'); }

///|
extern "js" fn array_from(a : Array[Double]) -> JsValue = "(a) => Array.from(a)"

///|
extern "js" fn sort_entries(a : JsValue) -> JsValue = "(a) => a.sort((x, y) => (x[0] < y[0] ? -1 : x[0] > y[0] ? 1 : 0))"

///|
#external
type IdMap

///|
extern "js" fn IdMap::new() -> IdMap = "() => new Map()"

///|
extern "js" fn IdMap::lookup(self : IdMap, k : JsValue) -> JsValue = "(m, k) => m.get(k)"

///|
extern "js" fn IdMap::add(self : IdMap, k : JsValue) -> Int = "(m, k) => { const i = m.size; m.set(k, i); return i; }"

///|
fn[T] js(v : T) -> JsValue {
  JsValue::of(v)
}

///|
fn num(v : Double) -> JsValue {
  JsValue::of(v)
}

///|
fn int(v : Int) -> JsValue {
  JsValue::of(v.to_double())
}

///|
fn arr(a : Array[JsValue]) -> JsValue {
  JsValue::of(a)
}

///|
fn opt_num(v : Double?) -> JsValue {
  match v {
    Some(v) => num(v)
    None => null_()
  }
}

///|
fn v2(v : @math.Vector2) -> JsValue {
  arr([num(v.x), num(v.y)])
}

///|
fn v3(v : @math.Vector3) -> JsValue {
  arr([num(v.x), num(v.y), num(v.z)])
}

///|
fn elements(e : Array[Double]) -> JsValue {
  arr(e.map(num))
}

///|
priv struct Ctx {
  ids : Map[String, IdMap]
  objects : Array[JsValue]
  geometries : Array[JsValue]
  materials : Array[JsValue]
  textures : Array[JsValue]
  skeletons : Array[JsValue]
  attributes : Array[JsValue]
  interleaved : Array[JsValue]
}

///|
fn Ctx::id(self : Ctx, kind : String, key : JsValue, f : (Int) -> Unit) -> Int {
  let m = self.ids[kind]
  let found = m.lookup(key)
  if !found.is_undefined() {
    return found.cast()
  }
  let i = m.add(key)
  f(i)
  i
}

///|
fn set_at(a : Array[JsValue], i : Int, v : JsValue) -> Unit {
  while a.length() <= i {
    a.push(null_())
  }
  a[i] = v
}

///|
fn Ctx::attr_key(attr : @core.GeometryAttribute) -> JsValue {
  match attr {
    Buffer(a) => js(a)
    Interleaved(a) => js(a)
    GL(a) => js(a)
  }
}

///|
fn Ctx::attr_id(self : Ctx, attr : @core.GeometryAttribute) -> Int {
  self.id("attr", Ctx::attr_key(attr), fn(i) {
    set_at(self.attributes, i, null_())
    set_at(self.attributes, i, self.attr_dump(attr))
  })
}

///|
fn Ctx::ib_id(self : Ctx, ib : @core.InterleavedBuffer) -> Int {
  self.id("ib", js(ib), fn(i) {
    let d = obj()
    put(d, "stride", int(ib.stride))
    put(d, "count", int(ib.count))
    put(d, "usage", int(ib.usage))
    put(d, "instanced", js(ib.is_instanced_interleaved_buffer))
    put(
      d,
      "meshPerAttribute",
      if ib.is_instanced_interleaved_buffer {
        int(ib.mesh_per_attribute)
      } else {
        null_()
      },
    )
    put(d, "type", js(ib.array.type_name()))
    put(d, "length", int(ib.array.length()))
    put(d, "hash", hash_view(ib.array))
    set_at(self.interleaved, i, d)
  })
}

///|
fn Ctx::attr_dump(self : Ctx, attr : @core.GeometryAttribute) -> JsValue {
  let d = obj()
  match attr {
    Interleaved(a) => {
      put(d, "kind", js("interleaved"))
      put(d, "name", js(a.name))
      put(d, "itemSize", int(a.item_size))
      put(d, "offset", int(a.offset))
      put(d, "normalized", js(a.normalized))
      put(d, "count", int(a.count()))
      put(d, "data", int(self.ib_id(a.data)))
    }
    Buffer(a) => {
      let instanced = a.is_instanced_buffer_attribute()
      put(
        d,
        "kind",
        js(
          if instanced {
            "instanced"
          } else {
            "buffer"
          },
        ),
      )
      put(d, "name", js(a.name))
      put(d, "itemSize", int(a.item_size))
      put(d, "normalized", js(a.normalized))
      put(d, "count", int(a.count))
      put(d, "usage", int(a.usage))
      put(d, "gpuType", int(a.gpu_type))
      put(
        d,
        "meshPerAttribute",
        if instanced {
          int(a.mesh_per_attribute)
        } else {
          null_()
        },
      )
      put(d, "type", js(a.array.type_name()))
      put(d, "length", int(a.array.length()))
      put(d, "hash", hash_view(a.array))
    }
    GL(_) => put(d, "kind", js("gl"))
  }
  d
}

///|
fn texture_class(t : @core.Texture) -> String {
  match t.texture_type {
    Texture => "Texture"
    CanvasTexture => "CanvasTexture"
    CompressedArrayTexture => "CompressedArrayTexture"
    CompressedCubeTexture => "CompressedCubeTexture"
    CompressedTexture => "CompressedTexture"
    CubeDepthTexture => "CubeDepthTexture"
    CubeTexture => "CubeTexture"
    Data3DTexture => "Data3DTexture"
    DataArrayTexture => "DataArrayTexture"
    DataTexture => "DataTexture"
    DepthTexture => "DepthTexture"
    ExternalTexture => "ExternalTexture"
    FramebufferTexture => "FramebufferTexture"
    HTMLTexture => "HTMLTexture"
    VideoFrameTexture => "VideoFrameTexture"
    VideoTexture => "VideoTexture"
  }
}

///|
fn tex_image(image : @core.TextureImage) -> JsValue {
  match image {
    NoImage => null_()
    DomImage(v) =>
      if v.get("__bitmap").is_undefined() {
        let d = obj()
        put(d, "kind", js("dom"))
        d
      } else {
        let d = obj()
        put(d, "kind", js("bitmap"))
        put(d, "width", v.get("width"))
        put(d, "height", v.get("height"))
        put(d, "hash", v.get("hash"))
        d
      }
    ImageArray(items) => {
      let d = obj()
      put(d, "kind", js("array"))
      put(d, "items", arr(items.map(tex_image)))
      d
    }
    TextureImage(_) => {
      let d = obj()
      put(d, "kind", js("texture"))
      d
    }
    DataImage(di) => {
      let d = obj()
      put(d, "kind", js("data"))
      put(d, "width", int(di.width))
      put(d, "height", int(di.height))
      put(
        d,
        "depth",
        match di.depth {
          Some(x) => int(x)
          None => null_()
        },
      )
      put(
        d,
        "data",
        match di.data {
          Some(a) => arr([js(a.type_name()), int(a.length()), hash_view(a)])
          None => null_()
        },
      )
      d
    }
  }
}

///|
fn Ctx::tex_id(self : Ctx, t : @core.Texture?) -> JsValue {
  match t {
    None => null_()
    Some(t) =>
      int(
        self.id("tex", js(t), fn(i) {
          set_at(self.textures, i, null_())
          set_at(self.textures, i, self.tex_dump(t))
        }),
      )
  }
}

///|
fn Ctx::tex_dump(self : Ctx, t : @core.Texture) -> JsValue {
  let d = obj()
  put(d, "class", js(texture_class(t)))
  put(d, "uuid", js(t.uuid))
  put(d, "name", js(t.name))
  put(d, "channel", int(t.channel))
  put(d, "mapping", int(t.mapping))
  put(d, "offset", v2(t.offset))
  put(d, "repeat", v2(t.repeat))
  put(d, "center", v2(t.center))
  put(d, "rotation", num(t.rotation))
  put(d, "matrixAutoUpdate", js(t.matrix_auto_update))
  put(d, "matrix", elements(t.matrix.elements))
  put(d, "wrapS", int(t.wrap_s))
  put(d, "wrapT", int(t.wrap_t))
  put(d, "magFilter", int(t.mag_filter))
  put(d, "minFilter", int(t.min_filter))
  put(d, "anisotropy", int(t.anisotropy))
  put(d, "format", int(t.format))
  put(d, "type", int(t.type_))
  put(
    d,
    "internalFormat",
    match t.internal_format {
      Some(s) => js(s)
      None => null_()
    },
  )
  put(d, "colorSpace", js(t.color_space))
  put(d, "flipY", js(t.flip_y))
  put(d, "generateMipmaps", js(t.generate_mipmaps))
  put(d, "premultiplyAlpha", js(t.premultiply_alpha))
  put(d, "unpackAlignment", int(t.unpack_alignment))
  put(d, "version", int(t.version))
  put(d, "userData", js(stringify(t.user_data)))
  put(d, "source", int(self.id("src", js(t.source), _ => ())))
  put(d, "sourceVersion", int(t.source.version))
  put(d, "image", tex_image(t.image()))
  put(d, "mipmaps", arr(t.mipmaps.map(tex_image)))
  d
}

///|
fn material_maps(m : @core.Material) -> Array[(String, @core.Texture?)] {
  [
    ("map", m.map),
    ("lightMap", m.light_map),
    ("aoMap", m.ao_map),
    ("emissiveMap", m.emissive_map),
    ("bumpMap", m.bump_map),
    ("normalMap", m.normal_map),
    ("displacementMap", m.displacement_map),
    ("roughnessMap", m.roughness_map),
    ("metalnessMap", m.metalness_map),
    ("alphaMap", m.alpha_map),
    ("envMap", m.env_map),
    ("clearcoatMap", m.clearcoat_map),
    ("clearcoatRoughnessMap", m.clearcoat_roughness_map),
    ("clearcoatNormalMap", m.clearcoat_normal_map),
    ("iridescenceMap", m.iridescence_map),
    ("iridescenceThicknessMap", m.iridescence_thickness_map),
    ("sheenColorMap", m.sheen_color_map),
    ("sheenRoughnessMap", m.sheen_roughness_map),
    ("transmissionMap", m.transmission_map),
    ("thicknessMap", m.thickness_map),
    ("specularIntensityMap", m.specular_intensity_map),
    ("specularColorMap", m.specular_color_map),
    ("anisotropyMap", m.anisotropy_map),
    ("diffuseRoughnessMap", m.diffuse_roughness_map),
    ("specularMap", m.specular_map),
  ]
}

///|
fn Ctx::mat_id(self : Ctx, m : @core.Material) -> Int {
  self.id("mat", js(m), fn(i) {
    set_at(self.materials, i, null_())
    set_at(self.materials, i, self.mat_dump(m))
  })
}

///|
fn Ctx::mat_dump(self : Ctx, m : @core.Material) -> JsValue {
  let maps = obj()
  for entry in material_maps(m) {
    if entry.1 is Some(_) {
      put(maps, entry.0, self.tex_id(entry.1))
    }
  }
  let json = m.to_json(meta=@core.ToJsonMeta::new()).stringify()
  let d = obj()
  put(d, "type", js(m.type_))
  put(d, "uuid", js(m.uuid))
  put(d, "name", js(m.name))
  put(d, "version", int(m.version))
  put(d, "maps", maps)
  put(d, "json", js(json))
  put(
    d,
    "normalScale",
    match m.normal_scale {
      Some(v) => v2(v)
      None => null_()
    },
  )
  put(
    d,
    "clearcoatNormalScale",
    match m.clearcoat_normal_scale {
      Some(v) => v2(v)
      None => null_()
    },
  )
  put(
    d,
    "flatShading",
    match m.flat_shading {
      Some(v) => js(v)
      None => null_()
    },
  )
  put(d, "vertexColors", js(m.vertex_colors))
  put(
    d,
    "sizeAttenuation",
    match m.size_attenuation {
      Some(v) => js(v)
      None => null_()
    },
  )
  put(d, "userData", js(stringify(m.user_data)))
  d
}

///|
fn Ctx::geo_id(self : Ctx, g : @core.BufferGeometry) -> Int {
  self.id("geo", js(g), fn(i) {
    set_at(self.geometries, i, null_())
    set_at(self.geometries, i, self.geo_dump(g))
  })
}

///|
fn Ctx::geo_dump(self : Ctx, g : @core.BufferGeometry) -> JsValue {
  let d = obj()
  let attributes = []
  for k, a in g.attributes {
    attributes.push(arr([js(k), int(self.attr_id(a))]))
  }
  let morph = []
  for k, list in g.morph_attributes {
    morph.push(
      arr([
        js(k),
        arr(
          list.map(a => if js(a).is_undefined() {
            null_()
          } else {
            int(self.attr_id(a))
          }),
        ),
      ]),
    )
  }
  put(d, "type", js(g.type_))
  put(d, "uuid", js(g.uuid))
  put(d, "name", js(g.name))
  put(d, "attributes", arr(attributes))
  put(
    d,
    "index",
    match g.index {
      Some(a) => int(self.attr_id(a))
      None => null_()
    },
  )
  put(d, "morph", arr(morph))
  put(d, "morphTargetsRelative", js(g.morph_targets_relative))
  put(
    d,
    "groups",
    arr(
      g.groups.map(x => arr([int(x.start), num(x.count), int(x.material_index)])),
    ),
  )
  put(d, "drawRange", arr([int(g.draw_range.start), num(g.draw_range.count)]))
  put(
    d,
    "boundingBox",
    match g.bounding_box {
      Some(b) =>
        arr([
          num(b.min.x),
          num(b.min.y),
          num(b.min.z),
          num(b.max.x),
          num(b.max.y),
          num(b.max.z),
        ])
      None => null_()
    },
  )
  put(
    d,
    "boundingSphere",
    match g.bounding_sphere {
      Some(s) =>
        arr([num(s.center.x), num(s.center.y), num(s.center.z), num(s.radius)])
      None => null_()
    },
  )
  put(d, "userData", js(stringify(g.user_data)))
  d
}

///|
fn Ctx::skel_id(self : Ctx, s : @core.Skeleton) -> Int {
  self.id("skel", js(s), fn(i) {
    set_at(self.skeletons, i, null_())
    let d = obj()
    put(d, "uuid", js(s.uuid))
    put(d, "bones", arr(s.bones.map(b => int(self.obj_id(b)))))
    put(d, "boneInverses", arr(s.bone_inverses.map(m => elements(m.elements))))
    set_at(self.skeletons, i, d)
  })
}

///|
fn Ctx::obj_id(self : Ctx, o : @core.Object3D) -> Int {
  self.id("obj", js(o), fn(i) {
    set_at(self.objects, i, null_())
    set_at(self.objects, i, self.obj_dump(o))
  })
}

///|
fn Ctx::obj_dump(self : Ctx, o : @core.Object3D) -> JsValue {
  let d = obj()
  put(d, "type", js(o.type_))
  put(d, "name", js(o.name))
  put(d, "uuid", js(o.uuid))
  put(d, "parent", null_())
  put(d, "children", arr([]))
  put(d, "position", v3(o.position))
  put(
    d,
    "quaternion",
    arr([
      num(o.quaternion.x),
      num(o.quaternion.y),
      num(o.quaternion.z),
      num(o.quaternion.w),
    ]),
  )
  put(d, "scale", v3(o.scale))
  put(
    d,
    "rotation",
    arr([
      num(o.rotation.x),
      num(o.rotation.y),
      num(o.rotation.z),
      js(o.rotation.order),
    ]),
  )
  put(d, "up", v3(o.up))
  put(d, "matrix", elements(o.matrix.elements))
  put(d, "matrixWorld", elements(o.matrix_world.elements))
  put(d, "matrixAutoUpdate", js(o.matrix_auto_update))
  put(d, "visible", js(o.visible))
  put(d, "castShadow", js(o.cast_shadow))
  put(d, "receiveShadow", js(o.receive_shadow))
  put(d, "frustumCulled", js(o.frustum_culled))
  put(d, "renderOrder", num(o.render_order))
  put(d, "layers", num(o.layers.mask))
  put(d, "userData", js(stringify(o.user_data)))
  put(
    d,
    "pivot",
    match o.pivot {
      Some(p) => v3(p)
      None => null_()
    },
  )
  if o.is_mesh() || o.is_line() || o.is_points() {
    put(d, "geometry", int(self.geo_id(o.get_geometry().unwrap())))
    put(
      d,
      "material",
      match o.get_material().unwrap() {
        Single(m) => int(self.mat_id(m))
        Multiple(ms) => arr(ms.map(m => int(self.mat_id(m))))
      },
    )
    let (dict, infl) = o.morph_targets()
    put(
      d,
      "morphTargetInfluences",
      match infl {
        Some(a) => array_from(a)
        None => null_()
      },
    )
    put(
      d,
      "morphTargetDictionary",
      match dict {
        Some(m) => {
          let entries = []
          for k, v in m {
            entries.push(arr([js(k), int(v)]))
          }
          sort_entries(arr(entries))
        }
        None => null_()
      },
    )
  }
  match o.kind {
    Mesh({ kind: SkinnedMesh(s), .. }) => {
      put(d, "bindMode", js(s.bind_mode))
      put(d, "bindMatrix", elements(s.bind_matrix.elements))
      put(d, "bindMatrixInverse", elements(s.bind_matrix_inverse.elements))
      put(
        d,
        "skeleton",
        match s.skeleton {
          Some(sk) => int(self.skel_id(sk))
          None => null_()
        },
      )
    }
    Mesh({ kind: InstancedMesh(im), count, .. }) => {
      put(d, "count", int(count))
      put(d, "instanceMatrix", int(self.attr_id(Buffer(im.instance_matrix))))
      put(
        d,
        "instanceColor",
        match im.instance_color {
          Some(c) => int(self.attr_id(Buffer(c)))
          None => null_()
        },
      )
    }
    Camera(c) =>
      match c.kind {
        PerspectiveCamera(p) =>
          put(
            d,
            "camera",
            arr([
              js("perspective"),
              num(p.fov),
              num(p.aspect),
              num(p.near),
              num(p.far),
              num(p.zoom),
              num(p.focus),
              num(p.film_gauge),
              num(p.film_offset),
              elements(c.projection_matrix.elements),
            ]),
          )
        OrthographicCamera(p) =>
          put(
            d,
            "camera",
            arr([
              js("orthographic"),
              num(p.left),
              num(p.right),
              num(p.top),
              num(p.bottom),
              num(p.near),
              num(p.far),
              num(p.zoom),
              elements(c.projection_matrix.elements),
            ]),
          )
        BaseCamera => ()
      }
    Light(l) => {
      let (distance, decay, angle, penumbra) = match l.kind {
        PointLight(p) => (Some(p.distance), Some(p.decay), None, None)
        SpotLight(s) =>
          (Some(s.distance), Some(s.decay), Some(s.angle), Some(s.penumbra))
        _ => (None, None, None, None)
      }
      put(
        d,
        "light",
        arr([
          arr([num(l.color.r), num(l.color.g), num(l.color.b)]),
          num(l.intensity),
          opt_num(distance),
          opt_num(decay),
          opt_num(angle),
          opt_num(penumbra),
        ]),
      )
    }
    _ => ()
  }
  d
}

///|
fn Ctx::visit(self : Ctx, o : @core.Object3D) -> Int {
  let i = self.obj_id(o)
  let d = self.objects[i]
  put(
    d,
    "parent",
    match o.parent {
      Some(p) => int(self.obj_id(p))
      None => null_()
    },
  )
  put(d, "children", arr(o.children.map(c => int(self.visit(c)))))
  match o.kind {
    Light({ kind: DirectionalLight(_) | SpotLight(_), .. }) =>
      put(d, "target", int(self.obj_id(o.light_target())))
    _ => ()
  }
  i
}

///|
fn track_dump(t : @animation.KeyframeTrack) -> JsValue {
  let interp = t.create_interpolant()
  let n = t.times.length()
  let times = t.times
  let ts = if n > 0 {
    [
      times[0] - 0.1,
      times[0],
      (times[0] + times[n - 1]) / 2.0,
      times[n / 3] * 0.75 + times[n - 1] * 0.25,
      times[n - 1],
      times[n - 1] + 1.0,
    ]
  } else {
    []
  }
  let values = t.values.numbers()
  let d = obj()
  put(d, "name", js(t.name))
  put(d, "valueTypeName", js(t.value_type_name))
  put(d, "times", arr([js(times.type_name()), int(n), hash_view(times)]))
  put(
    d,
    "values",
    arr([js(values.type_name()), int(values.length()), hash_view(values)]),
  )
  put(
    d,
    "interpolation",
    match t.get_interpolation() {
      Some(i) => int(i)
      None => null_()
    },
  )
  put(
    d,
    "cubic",
    js(
      match t.create_interpolant_factory {
        Some(f) => f.is_interpolant_factory_method_gltf_cubic_spline
        None => false
      },
    ),
  )
  put(d, "samples", arr(ts.map(x => array_from(interp.evaluate(x)))))
  d
}

///|
fn ref_dump(r : @gltf.GLTFReference?) -> JsValue {
  match r {
    None => null_()
    Some(r) => {
      let out = []
      let fields = [
        ("materials", r.materials),
        ("meshes", r.meshes),
        ("nodes", r.nodes),
        ("primitives", r.primitives),
        ("textures", r.textures),
      ]
      for f in fields {
        if f.1 is Some(v) {
          out.push(arr([js(f.0), int(v)]))
        }
      }
      arr(out)
    }
  }
}

///|
pub fn dump_result(gltf : @gltf.GLTFResult) -> JsValue {
  let ids = {}
  for k in ["obj", "geo", "mat", "tex", "attr", "ib", "skel", "src"] {
    ids[k] = IdMap::new()
  }
  let ctx = {
    ids,
    objects: [],
    geometries: [],
    materials: [],
    textures: [],
    skeletons: [],
    attributes: [],
    interleaved: [],
  }
  let result = obj()
  put(result, "scenes", arr(gltf.scenes.map(s => int(ctx.visit(s)))))
  put(
    result,
    "scene",
    match gltf.scene {
      Some(s) => int(ctx.obj_id(s))
      None => null_()
    },
  )
  put(
    result,
    "cameras",
    arr(
      gltf.cameras.map(c => match c {
        Some(c) => int(ctx.visit(c))
        None => null_()
      }),
    ),
  )
  put(
    result,
    "animations",
    arr(
      gltf.animations.map(clip => {
        let d = obj()
        put(d, "uuid", js(clip.uuid))
        put(d, "name", js(clip.name))
        put(d, "duration", num(clip.duration))
        put(d, "blendMode", int(clip.blend_mode))
        put(d, "userData", js(stringify(clip.user_data)))
        put(d, "tracks", arr(clip.tracks.map(track_dump)))
        d
      }),
    ),
  )
  let associations = []
  for entry in gltf.parser.associations.entries() {
    let (kind, kid) = match entry.0 {
      Material(m) => ("material", int(ctx.mat_id(m)))
      Texture(t) => ("texture", ctx.tex_id(Some(t)))
      Object3D(o) => ("object", int(ctx.obj_id(o)))
    }
    associations.push(arr([js(kind), kid, ref_dump(entry.1)]))
  }
  put(result, "associations", arr(associations))
  let used = gltf.parser.json.get("extensionsUsed")
  put(
    result,
    "extensionsUsed",
    if used.is_undefined() {
      null_()
    } else {
      used
    },
  )
  put(result, "userData", js(stringify(gltf.user_data)))
  put(result, "asset", js(stringify(gltf.asset)))
  put(result, "objects", arr(ctx.objects))
  put(result, "geometries", arr(ctx.geometries))
  put(result, "materials", arr(ctx.materials))
  put(result, "textures", arr(ctx.textures))
  put(result, "skeletons", arr(ctx.skeletons))
  put(result, "attributes", arr(ctx.attributes))
  put(result, "interleaved", arr(ctx.interleaved))
  result
}

///|
/// Loads `url` with a fresh GLTFLoader (+ Draco, KTX2, meshopt from `opts`), resolving
/// to the dump; rejects with the error.
pub fn load_model(url : String, opts : JsValue) -> JsValue {
  @utils.AddonPromise::new(fn(resolve, reject) {
    let draco = @gltf.DRACOLoader::new()
    draco.set_decoder_path(opts.get("dracoPath").cast()) |> ignore
    draco.set_worker_limit(1) |> ignore
    let ktx2 = @gltf.KTX2Loader::new()
    ktx2.set_transcoder_path(opts.get("basisPath").cast()) |> ignore
    ktx2.set_worker_limit(1) |> ignore
    ktx2.worker_config = Some({
      astc_supported: false,
      astc_hdr_supported: false,
      etc1_supported: false,
      etc2_supported: true,
      dxt_supported: true,
      bptc_supported: true,
      pvrtc_supported: false,
    })
    let loader = @gltf.GLTFLoader::new()
    if !opts.get("nodeps").cast() {
      loader.set_draco_loader(draco).set_ktx2_loader(ktx2) |> ignore
      loader.set_meshopt_decoder(opts.get("meshopt")) |> ignore
    }
    if opts.get("plugin").cast() {
      loader.register(test_plugin_callback) |> ignore
      loader.register(test_plugin_callback) |> ignore
    }
    loader.load(
      url,
      fn(gltf) {
        let d = dump_result(gltf)
        draco.dispose() |> ignore
        ktx2.dispose() |> ignore
        resolve(d)
      },
      on_error=fn(e) {
        draco.dispose() |> ignore
        ktx2.dispose() |> ignore
        reject(e)
      },
    )
  }).to_js()
}

///|
/// A user plugin, mirrored by `TestPlugin` in run.mjs.
struct TestPlugin {
  parser : @gltf.GLTFParser
}

///|
impl @gltf.GLTFPlugin for TestPlugin with name(_) {
  "TEST_plugin"
}

///|
impl @gltf.GLTFPlugin for TestPlugin with before_root(self) {
  self.parser.json.set("__beforeRoot", js(true))
  Some(@utils.AddonPromise::resolve_undefined())
}

///|
impl @gltf.GLTFPlugin for TestPlugin with after_root(_, result) {
  result.user_data.set("afterRoot", int(result.scenes.length()))
  Some(@utils.AddonPromise::resolve_undefined())
}

///|
impl @gltf.GLTFPlugin for TestPlugin with create_node_attachment(self, index) {
  let node_def : JsValue = node_at(self.parser.json.get("nodes"), index)
  if node_def.get("name").is_undefined() || node_def.get("name").cast() != "Cam" {
    return None
  }
  let o = @core.Object3D::new()
  o.name = "attach_" + index.to_string()
  Some(@utils.AddonPromise::resolve(o))
}

///|
impl @gltf.GLTFPlugin for TestPlugin with get_material_type(self, index) {
  let def = node_at(self.parser.json.get("materials"), index)
  if !def.get("name").is_undefined() && def.get("name").cast() == "mask_default" {
    Some(MeshBasicMaterial)
  } else {
    None
  }
}

///|
impl @gltf.GLTFPlugin for TestPlugin with extend_material_params(
  self,
  index,
  params,
) {
  let def = node_at(self.parser.json.get("materials"), index)
  if !def.get("name").is_undefined() && def.get("name").cast() == "mask_default" {
    params["opacity"] = Number(0.5)
    return Some(@utils.AddonPromise::resolve_undefined())
  }
  None
}

///|
extern "js" fn node_at(a : JsValue, i : Int) -> JsValue = "(a, i) => a[i]"

///|
fn test_plugin_callback(parser : @gltf.GLTFParser) -> &@gltf.GLTFPlugin {
  TestPlugin::{ parser, }
}
