// Group 2: the WebGLPrograms / WebGLProgram material grid (programs_grid.mjs), driven
// by the CASES of harness/scenarios/programs_common.cjs embedded below.

///|
/// CASES of harness/scenarios/programs_common.cjs, verbatim.
let programs_cases_json : String =
  #|[
  #|{"label":"basic","material":"MeshBasicMaterial"},
  #|{"label":"basic-maps","material":"MeshBasicMaterial","maps":{"map":{},"alphaMap":{},"aoMap":{},"lightMap":{"channel":1},"specularMap":{"channel":2}},"env":"cube"},
  #|{"label":"basic-env-refraction-mix","material":"MeshBasicMaterial","set":{"combine":1},"env":"cubeRefraction"},
  #|{"label":"basic-env-add","material":"MeshBasicMaterial","set":{"combine":2},"env":"cube","maps":{"map":{"channel":3}}},
  #|{"label":"basic-vertex-colors4","material":"MeshBasicMaterial","set":{"vertexColors":true},"geometry":{"attributes":["position","normal","uv","color4"]}},
  #|{"label":"basic-alpha","material":"MeshBasicMaterial","set":{"vertexColors":true,"alphaTest":0.5,"alphaHash":true,"alphaToCoverage":true,"transparent":true},"geometry":{"attributes":["position","normal","uv","color3"]}},
  #|{"label":"basic-fog","material":"MeshBasicMaterial","fog":"linear"},
  #|{"label":"basic-fog-exp2","material":"MeshBasicMaterial","fog":"exp2"},
  #|{"label":"basic-no-fog","material":"MeshBasicMaterial","set":{"fog":false},"fog":"exp2"},
  #|{"label":"basic-no-normals-morph-normals","material":"MeshBasicMaterial","geometry":{"attributes":["position"],"morph":["position","normal"],"morphCount":2}},
  #|{"label":"basic-morph-colors","material":"MeshBasicMaterial","geometry":{"attributes":["position","normal","uv"],"morph":["color"],"morphCount":3}},
  #|{"label":"basic-skinned","material":"MeshBasicMaterial","object":"skinned"},
  #|{"label":"basic-instanced","material":"MeshBasicMaterial","object":"instanced"},
  #|{"label":"basic-instanced-color-morph","material":"MeshBasicMaterial","object":"instancedColorMorph"},
  #|{"label":"basic-batched","material":"MeshBasicMaterial","object":"batched"},
  #|{"label":"basic-batched-color","material":"MeshBasicMaterial","object":"batchedColor"},
  #|{"label":"basic-sides","material":"MeshBasicMaterial","set":{"side":2,"premultipliedAlpha":true,"dithering":true}},
  #|{"label":"basic-back","material":"MeshBasicMaterial","set":{"side":1,"name":"named"}},
  #|{"label":"basic-tone-aces","material":"MeshBasicMaterial","renderer":{"toneMapping":4}},
  #|{"label":"basic-tone-agx-untoned","material":"MeshBasicMaterial","set":{"toneMapped":false},"renderer":{"toneMapping":6}},
  #|{"label":"basic-tone-custom","material":"MeshBasicMaterial","renderer":{"toneMapping":5}},
  #|{"label":"basic-tone-neutral","material":"MeshBasicMaterial","renderer":{"toneMapping":7}},
  #|{"label":"basic-tone-reinhard-cineon","material":"MeshBasicMaterial","renderer":{"toneMapping":2}},
  #|{"label":"basic-tone-cineon","material":"MeshBasicMaterial","renderer":{"toneMapping":3}},
  #|{"label":"basic-tone-linear","material":"MeshBasicMaterial","renderer":{"toneMapping":1}},
  #|{"label":"basic-linear-output","material":"MeshBasicMaterial","renderer":{"outputColorSpace":"srgb-linear","toneMapping":4}},
  #|{"label":"basic-render-target","material":"MeshBasicMaterial","renderer":{"renderTarget":true,"toneMapping":4}},
  #|{"label":"basic-lowp","material":"MeshBasicMaterial","set":{"precision":"lowp"}},
  #|{"label":"basic-mediump","material":"MeshBasicMaterial","set":{"precision":"mediump"}},
  #|{"label":"basic-video","material":"MeshBasicMaterial","maps":{"map":{"video":true,"colorSpace":"srgb"}}},
  #|{"label":"basic-video-linear","material":"MeshBasicMaterial","maps":{"map":{"video":true}}},
  #|{"label":"basic-reversed","material":"MeshBasicMaterial","renderer":{"reversed":true}},
  #|{"label":"basic-clipping","material":"MeshBasicMaterial","clipping":{"global":2}},
  #|{"label":"basic-clipping-local","material":"MeshBasicMaterial","clipping":{"global":1,"local":3,"intersection":true}},
  #|{"label":"basic-custom-key","material":"MeshBasicMaterial","customKey":"my-key"},
  #|{"label":"lambert","material":"MeshLambertMaterial","lights":{"directional":2,"point":1,"spot":2,"spotLightMap":1,"rectArea":1,"hemi":1,"directionalShadowMap":1,"pointShadowMap":1,"spotShadowMap":2,"numSpotLightShadowsWithMaps":1,"numLightProbes":1}},
  #|{"label":"lambert-no-normals","material":"MeshLambertMaterial","geometry":{"attributes":["position","uv"]}},
  #|{"label":"lambert-maps","material":"MeshLambertMaterial","maps":{"map":{},"emissiveMap":{"video":true,"colorSpace":"srgb"},"bumpMap":{},"normalMap":{},"displacementMap":{},"specularMap":{}},"env":"cube","fog":"linear"},
  #|{"label":"lambert-scene-env","material":"MeshLambertMaterial","sceneEnv":"cube"},
  #|{"label":"lambert-scene-pmrem","material":"MeshLambertMaterial","sceneEnv":"pmrem"},
  #|{"label":"lambert-flat","material":"MeshLambertMaterial","set":{"flatShading":true},"geometry":{"attributes":["position","normal","uv","tangent"],"morph":["normal"],"morphCount":1},"maps":{"normalMap":{}}},
  #|{"label":"phong","material":"MeshPhongMaterial","maps":{"specularMap":{},"normalMap":{}},"set":{"normalMapType":1},"lights":{"directional":2,"point":1,"spot":2,"spotLightMap":1,"rectArea":1,"hemi":1,"directionalShadowMap":1,"pointShadowMap":1,"spotShadowMap":2,"numSpotLightShadowsWithMaps":1,"numLightProbes":1},"shadows":2,"renderer":{"shadowMapEnabled":true,"shadowMapType":1}},
  #|{"label":"phong-vsm","material":"MeshPhongMaterial","lights":{"directional":1,"directionalShadowMap":1},"shadows":1,"renderer":{"shadowMapEnabled":true,"shadowMapType":3}},
  #|{"label":"phong-basic-shadow","material":"MeshPhongMaterial","lights":{"point":1,"pointShadowMap":1},"shadows":1,"renderer":{"shadowMapEnabled":true,"shadowMapType":0}},
  #|{"label":"phong-shadow-no-casters","material":"MeshPhongMaterial","lights":{"spot":1},"renderer":{"shadowMapEnabled":true,"shadowMapType":1}},
  #|{"label":"phong-env-pmrem-scene","material":"MeshPhongMaterial","sceneEnv":"pmrem","set":{"combine":1}},
  #|{"label":"toon","material":"MeshToonMaterial","maps":{"gradientMap":{},"map":{}},"lights":{"hemi":2}},
  #|{"label":"standard","material":"MeshStandardMaterial"},
  #|{"label":"standard-maps","material":"MeshStandardMaterial","maps":{"map":{},"roughnessMap":{},"metalnessMap":{"channel":1},"normalMap":{},"aoMap":{"channel":3},"lightMap":{},"emissiveMap":{},"displacementMap":{},"bumpMap":{},"alphaMap":{}},"geometry":{"attributes":["position","normal","uv","tangent"]}},
  #|{"label":"standard-packed-normal","material":"MeshStandardMaterial","maps":{"normalMap":{"format":1030}}},
  #|{"label":"standard-packed-normal-eac","material":"MeshStandardMaterial","maps":{"normalMap":{"format":37490}}},
  #|{"label":"standard-object-normal","material":"MeshStandardMaterial","maps":{"normalMap":{}},"set":{"normalMapType":1}},
  #|{"label":"standard-pmrem","material":"MeshStandardMaterial","env":"pmrem"},
  #|{"label":"standard-scene-pmrem","material":"MeshStandardMaterial","sceneEnv":"pmrem","lights":{"directional":2,"point":1,"spot":2,"spotLightMap":1,"rectArea":1,"hemi":1,"directionalShadowMap":1,"pointShadowMap":1,"spotShadowMap":2,"numSpotLightShadowsWithMaps":1,"numLightProbes":1}},
  #|{"label":"standard-cube-incomplete","material":"MeshStandardMaterial","env":"cube"},
  #|{"label":"standard-wireframe-bump","material":"MeshStandardMaterial","set":{"wireframe":true},"maps":{"bumpMap":{}},"geometry":{"attributes":["position","uv"]}},
  #|{"label":"standard-no-normals","material":"MeshStandardMaterial","geometry":{"attributes":["position","uv"]}},
  #|{"label":"standard-flat","material":"MeshStandardMaterial","set":{"flatShading":true}},
  #|{"label":"standard-defines","material":"MeshStandardMaterial","defines":{"1":"one","USE_THING":"","COUNT":3,"OFF":false,"ON":true}},
  #|{"label":"physical","material":"MeshPhysicalMaterial"},
  #|{"label":"physical-all","material":"MeshPhysicalMaterial","set":{"clearcoat":1,"iridescence":1,"sheen":1,"transmission":1,"anisotropy":0.5,"dispersion":1,"diffuseRoughness":0.5,"retroreflectivity":0.5,"transparent":true},"maps":{"map":{},"normalMap":{},"roughnessMap":{},"metalnessMap":{},"clearcoatMap":{},"clearcoatNormalMap":{},"clearcoatRoughnessMap":{"channel":1},"iridescenceMap":{},"iridescenceThicknessMap":{},"sheenColorMap":{},"sheenRoughnessMap":{"channel":2},"transmissionMap":{},"thicknessMap":{},"specularIntensityMap":{},"specularColorMap":{},"anisotropyMap":{},"diffuseRoughnessMap":{},"emissiveMap":{},"aoMap":{},"lightMap":{},"alphaMap":{}},"geometry":{"attributes":["position","normal","uv","tangent"]},"env":"pmrem","fog":"exp2","lights":{"directional":2,"point":1,"spot":2,"spotLightMap":1,"rectArea":1,"hemi":1,"directionalShadowMap":1,"pointShadowMap":1,"spotShadowMap":2,"numSpotLightShadowsWithMaps":1,"numLightProbes":1},"shadows":1,"renderer":{"shadowMapEnabled":true,"shadowMapType":1,"toneMapping":4}},
  #|{"label":"physical-maps-without-features","material":"MeshPhysicalMaterial","maps":{"map":{},"normalMap":{},"roughnessMap":{},"metalnessMap":{},"clearcoatMap":{},"clearcoatNormalMap":{},"clearcoatRoughnessMap":{"channel":1},"iridescenceMap":{},"iridescenceThicknessMap":{},"sheenColorMap":{},"sheenRoughnessMap":{"channel":2},"transmissionMap":{},"thicknessMap":{},"specularIntensityMap":{},"specularColorMap":{},"anisotropyMap":{},"diffuseRoughnessMap":{},"emissiveMap":{},"aoMap":{},"lightMap":{},"alphaMap":{}}},
  #|{"label":"physical-anisotropy-tangent-flat","material":"MeshPhysicalMaterial","set":{"anisotropy":1,"flatShading":true},"geometry":{"attributes":["position","normal","uv","tangent"]}},
  #|{"label":"matcap","material":"MeshMatcapMaterial","maps":{"matcap":{},"normalMap":{},"bumpMap":{}}},
  #|{"label":"matcap-plain","material":"MeshMatcapMaterial","fog":"linear"},
  #|{"label":"normal","material":"MeshNormalMaterial","maps":{"normalMap":{},"bumpMap":{},"displacementMap":{}},"set":{"flatShading":true}},
  #|{"label":"depth","material":"MeshDepthMaterial","set":{"depthPacking":3201},"maps":{"map":{},"alphaMap":{},"displacementMap":{}}},
  #|{"label":"depth-basic","material":"MeshDepthMaterial","set":{"depthPacking":3200}},
  #|{"label":"distance","material":"MeshDistanceMaterial","maps":{"alphaMap":{}}},
  #|{"label":"line","material":"LineBasicMaterial","set":{"vertexColors":true},"geometry":{"attributes":["position","color3"]},"object":"line","fog":"linear"},
  #|{"label":"line-dashed","material":"LineDashedMaterial","object":"line","maps":{"map":{}}},
  #|{"label":"points","material":"PointsMaterial","maps":{"map":{}},"object":"points","fog":"exp2"},
  #|{"label":"points-no-attenuation","material":"PointsMaterial","set":{"sizeAttenuation":false},"maps":{"alphaMap":{}},"geometry":{"attributes":["position"]},"object":"points"},
  #|{"label":"sprite","material":"SpriteMaterial","maps":{"map":{},"alphaMap":{}},"geometry":{"attributes":["position","uv"]},"fog":"linear"},
  #|{"label":"shadow","material":"ShadowMaterial","lights":{"directional":1,"directionalShadowMap":1},"shadows":1,"renderer":{"shadowMapEnabled":true,"shadowMapType":1},"fog":"linear"},
  #|{"label":"shader","material":"ShaderMaterial","shader":{"vertexShader":"#include <common>\nuniform float time;\nvarying vec2 vUv;\nvoid main() {\n\tvUv = uv;\n\tvec3 p = position;\n\t#pragma unroll_loop_start\n\tfor ( int i = 0; i < 3; i ++ ) {\n\t\tp.x += float( UNROLLED_LOOP_INDEX ) * offsets[ i ];\n\t}\n\t#pragma unroll_loop_end\n\tgl_Position = projectionMatrix * modelViewMatrix * vec4( p, 1.0 );\n}","fragmentShader":"#include <common>\n#include <clipping_planes_pars_fragment>\nvarying vec2 vUv;\nvoid main() {\n\t#include <clipping_planes_fragment>\n\tgl_FragColor = vec4( vUv, float( NUM_DIR_LIGHTS ), 1.0 );\n}","uniforms":["time","offsets"]},"defines":{"2":"x","A":1,"B":false,"C":"","D":1.5},"lights":{"directional":2,"point":1,"spot":2,"spotLightMap":1,"rectArea":1,"hemi":1,"directionalShadowMap":1,"pointShadowMap":1,"spotShadowMap":2,"numSpotLightShadowsWithMaps":1,"numLightProbes":1},"clipping":{"global":2}},
  #|{"label":"shader-glsl3-ext","material":"ShaderMaterial","shader":{"vertexShader":"#include <common>\nuniform float time;\nvarying vec2 vUv;\nvoid main() {\n\tvUv = uv;\n\tvec3 p = position;\n\t#pragma unroll_loop_start\n\tfor ( int i = 0; i < 3; i ++ ) {\n\t\tp.x += float( UNROLLED_LOOP_INDEX ) * offsets[ i ];\n\t}\n\t#pragma unroll_loop_end\n\tgl_Position = projectionMatrix * modelViewMatrix * vec4( p, 1.0 );\n}","fragmentShader":"#include <common>\n#include <clipping_planes_pars_fragment>\nvarying vec2 vUv;\nvoid main() {\n\t#include <clipping_planes_fragment>\n\tgl_FragColor = vec4( vUv, float( NUM_DIR_LIGHTS ), 1.0 );\n}","glslVersion":"300 es","clipCullDistance":true,"multiDraw":true,"index0AttributeName":"uv"},"set":{"name":"MyShader","fog":true,"flatShading":true},"fog":"exp2","customKey":"k2"},
  #|{"label":"shader-same-source","material":"ShaderMaterial","shader":{"vertexShader":"#include <common>\nuniform float time;\nvarying vec2 vUv;\nvoid main() {\n\tvUv = uv;\n\tvec3 p = position;\n\t#pragma unroll_loop_start\n\tfor ( int i = 0; i < 3; i ++ ) {\n\t\tp.x += float( UNROLLED_LOOP_INDEX ) * offsets[ i ];\n\t}\n\t#pragma unroll_loop_end\n\tgl_Position = projectionMatrix * modelViewMatrix * vec4( p, 1.0 );\n}","fragmentShader":"#include <common>\n#include <clipping_planes_pars_fragment>\nvarying vec2 vUv;\nvoid main() {\n\t#include <clipping_planes_fragment>\n\tgl_FragColor = vec4( vUv, float( NUM_DIR_LIGHTS ), 1.0 );\n}","uniforms":["time"]},"defines":{"2":"x","A":1,"B":false,"C":"","D":1.5},"lights":{"directional":2,"point":1,"spot":2,"spotLightMap":1,"rectArea":1,"hemi":1,"directionalShadowMap":1,"pointShadowMap":1,"spotShadowMap":2,"numSpotLightShadowsWithMaps":1,"numLightProbes":1},"clipping":{"global":2}},
  #|{"label":"shader-default","material":"ShaderMaterial","object":"batched"},
  #|{"label":"raw","material":"RawShaderMaterial","shader":{"vertexShader":"precision highp float;\nattribute vec3 position;\nvoid main() { gl_Position = vec4( position, 1.0 ); }","fragmentShader":"precision highp float;\nvoid main() { gl_FragColor = vec4( 1.0 ); }"},"defines":{"X":2}},
  #|{"label":"raw-glsl3","material":"RawShaderMaterial","shader":{"vertexShader":"precision highp float;\nattribute vec3 position;\nvoid main() { gl_Position = vec4( position, 1.0 ); }","fragmentShader":"precision highp float;\nvoid main() { gl_FragColor = vec4( 1.0 ); }","glslVersion":"300 es"},"set":{"name":"raw"}},
  #|{"label":"grids","material":"MeshStandardMaterial","grids":[true,false,true]},
  #|{"label":"log2","material":"MeshStandardMaterial","r":2,"lights":{"directional":1}},
  #|{"label":"log2-basic","material":"MeshBasicMaterial","r":2,"set":{"precision":"highp"}}
  #|]

///|
extern "js" fn grid_json_parse(text : String) -> @core.JsValue = "(s) => JSON.parse(s)"

///|
/// The mock canvas of programs_common.cjs (`createCanvas`).
extern "js" fn grid_canvas(
  gl : @webgl.WebGL2RenderingContext,
  width : Int32,
  height : Int32,
) -> @webgl.HTMLCanvasElement =
  #|(gl, width, height) => ({
  #|  width, height, style: {},
  #|  setAttribute() {}, addEventListener() {}, removeEventListener() {},
  #|  getContext() { return gl; },
  #|})

///|
/// JS `a < b` on strings, for `Array.prototype.sort`'s default order.
extern "js" fn grid_js_compare(a : String, b : String) -> Double = "(a, b) => a < b ? -1 : a > b ? 1 : 0"

///|
extern "js" fn grid_js_string(value : @core.JsValue) -> String = "(v) => String(v)"

///|
/// `gl.__log` of another mock, noted as one value.
extern "js" fn grid_log_value(
  gl : @webgl.WebGL2RenderingContext,
) -> @core.JsValue = "(gl) => gl.__log.slice()"

///|
fn grid_get(spec : Json, key : String) -> Json? {
  match spec {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn grid_number(j : Json) -> Double {
  match j {
    Number(n, ..) => n
    _ => abort("grid: not a number")
  }
}

///|
fn grid_int(spec : Json, key : String, default : Int32) -> Int32 {
  match grid_get(spec, key) {
    Some(j) => grid_number(j).to_int()
    None => default
  }
}

///|
fn grid_bool(spec : Json, key : String) -> Bool {
  grid_get(spec, key) is Some(True)
}

///|
fn grid_string(j : Json) -> String {
  match j {
    String(s) => s
    _ => abort("grid: not a string")
  }
}

///|
fn grid_entries(spec : Json, key : String) -> Array[(String, Json)] {
  match grid_get(spec, key) {
    Some(Object(map)) => map.iter().collect()
    _ => []
  }
}

///|
struct GridSetup {
  gl : @webgl.WebGL2RenderingContext
  renderer : @webgl.WebGLRenderer
  clipping : @webgl.WebGLClipping
  programs : @webgl.WebGLPrograms
}

///|
fn grid_setup(
  gl : @webgl.WebGL2RenderingContext,
  logarithmic~ : Bool = false,
  precision? : String,
) -> GridSetup {
  let renderer = @webgl.WebGLRenderer::new(
    canvas=grid_canvas(gl, 64, 32),
    context=gl,
    logarithmic_depth_buffer=logarithmic,
    precision?,
  )
  let binding_states = @webgl.WebGLBindingStates::new(
    gl,
    @webgl.WebGLAttributes::new(gl),
  )
  let environments = @webgl.WebGLEnvironments::new(renderer)
  let clipping = @webgl.WebGLClipping::new(renderer.properties)
  let programs = @webgl.WebGLPrograms::new(
    renderer,
    environments,
    renderer.extensions,
    renderer.capabilities,
    binding_states,
    clipping,
  )
  { gl, renderer, clipping, programs, }
}

///|
fn grid_texture(spec : Json) -> @core.Texture {
  let t = if grid_bool(spec, "video") {
    @core.VideoTexture::new(@core.JsValue::object())
  } else {
    @core.Texture::new()
  }
  if grid_get(spec, "channel") is Some(c) {
    t.channel = grid_number(c).to_int()
  }
  if grid_get(spec, "format") is Some(f) {
    t.format = grid_number(f).to_int()
  }
  if grid_get(spec, "colorSpace") is Some(cs) {
    t.color_space = grid_string(cs)
  }
  t
}

///|
fn grid_env_texture(kind : String) -> @core.Texture {
  if kind == "pmrem" {
    let t = @core.Texture::new()
    t.is_pmrem_texture = true
    for i in 0..<9 {
      t.mipmaps.push(
        DataImage({
          data: None,
          width: 256 >> i,
          height: 256 >> i,
          depth: None,
          mipmaps: None,
        }),
      )
    }
    return t
  }
  let t = @core.CubeTexture::new()
  if kind == "cubeRefraction" {
    t.mapping = @core.CubeRefractionMapping
  }
  t
}

///|
fn grid_geometry(spec : Json) -> @core.BufferGeometry {
  let g = @core.BufferGeometry::new()
  let names = match grid_get(spec, "attributes") {
    Some(Array(names)) => names.map(grid_string)
    _ => ["position", "normal", "uv"]
  }
  for name in names {
    let size = match name {
      "position" | "normal" | "color3" => 3
      "uv" => 2
      _ => 4
    }
    let attribute_name = if name.has_prefix("color") { "color" } else { name }
    ignore(
      g.set_attribute(
        attribute_name,
        @core.Float32BufferAttribute::new(3 * size, size),
      ),
    )
  }
  if grid_get(spec, "morph") is Some(Array(morph)) {
    let count = grid_int(spec, "morphCount", 0)
    for name in morph {
      let list : Array[@core.GeometryAttribute] = []
      for _ in 0..<count {
        list.push(Buffer(@core.Float32BufferAttribute::new(9, 3)))
      }
      g.morph_attributes[grid_string(name)] = list
    }
  }
  g
}

///|
fn grid_object(
  kind : String,
  g : @core.BufferGeometry,
  material : @core.Material,
) -> @core.Object3D {
  match kind {
    "skinned" => @core.SkinnedMesh::new(geometry=g, material=Single(material))
    "instanced" =>
      @core.InstancedMesh::new(geometry=g, material=Single(material), 2)
    "instancedColorMorph" => {
      let o = @core.InstancedMesh::new(geometry=g, material=Single(material), 2)
      ignore(o.set_color_at(0, @math.Color::new(1.0, 0.0, 0.0)))
      guard o.kind is Mesh({ kind: InstancedMesh(im), .. }) else {
        abort("instanced")
      }
      im.morph_texture = Some(@core.DataTexture::new())
      o
    }
    "batched" =>
      @core.BatchedMesh::new(2, 6, max_index_count=6, material=Single(material))
    "batchedColor" => {
      let o = @core.BatchedMesh::new(
        2,
        6,
        max_index_count=6,
        material=Single(material),
      )
      guard o.kind is Mesh({ kind: BatchedMesh(bm), .. }) else {
        abort("batched")
      }
      bm._colors_texture = Some(@core.DataTexture::new())
      o
    }
    "points" => @core.Points::new(geometry=g, material=Single(material))
    "line" => @core.Line::new(geometry=g, material=Single(material))
    _ => @core.Mesh::new(geometry=g, material=Single(material))
  }
}

///|
fn grid_lights_state(
  extensions : @webgl.WebGLExtensions,
  spec : Json?,
) -> @webgl.WebGLLightsState {
  let s = @webgl.WebGLLights::new(extensions).state
  let spec = spec.unwrap_or(Json::null())
  let fill = fn(array : Array[@core.UniformValue], key : String) {
    array.clear()
    for _ in 0..<grid_int(spec, key, 0) {
      array.push(Null)
    }
  }
  fill(s.sun, "sun")
  fill(s.directional, "directional")
  fill(s.point, "point")
  fill(s.spot, "spot")
  fill(s.spot_light_map, "spotLightMap")
  fill(s.rect_area, "rectArea")
  fill(s.hemi, "hemi")
  fill(s.sun_shadow_map, "sunShadowMap")
  fill(s.directional_shadow_map, "directionalShadowMap")
  fill(s.point_shadow_map, "pointShadowMap")
  fill(s.spot_shadow_map, "spotShadowMap")
  s.num_spot_light_shadows_with_maps = grid_int(
    spec, "numSpotLightShadowsWithMaps", 0,
  )
  s.num_light_probes = grid_int(spec, "numLightProbes", 0)
  s
}

///|
fn grid_material(type_ : String) -> @core.Material {
  match type_ {
    "MeshBasicMaterial" => @core.MeshBasicMaterial::new()
    "MeshLambertMaterial" => @core.MeshLambertMaterial::new()
    "MeshPhongMaterial" => @core.MeshPhongMaterial::new()
    "MeshToonMaterial" => @core.MeshToonMaterial::new()
    "MeshStandardMaterial" => @core.MeshStandardMaterial::new()
    "MeshPhysicalMaterial" => @core.MeshPhysicalMaterial::new()
    "MeshMatcapMaterial" => @core.MeshMatcapMaterial::new()
    "MeshNormalMaterial" => @core.MeshNormalMaterial::new()
    "MeshDepthMaterial" => @core.MeshDepthMaterial::new()
    "MeshDistanceMaterial" => @core.MeshDistanceMaterial::new()
    "LineBasicMaterial" => @core.LineBasicMaterial::new()
    "LineDashedMaterial" => @core.LineDashedMaterial::new()
    "PointsMaterial" => @core.PointsMaterial::new()
    "SpriteMaterial" => @core.SpriteMaterial::new()
    "ShadowMaterial" => @core.ShadowMaterial::new()
    "ShaderMaterial" => @core.ShaderMaterial::new()
    "RawShaderMaterial" => @core.RawShaderMaterial::new()
    _ => abort("grid: unknown material " + type_)
  }
}

///|
/// `material[ k ] = v` for the scalar properties the grid sets.
fn grid_set(material : @core.Material, k : String, v : Json) -> Unit {
  let b = v is True
  match k {
    "name" => material.name = grid_string(v)
    "transparent" => material.transparent = b
    "alphaTest" => material.set_alpha_test(grid_number(v))
    "alphaHash" => material.alpha_hash = b
    "alphaToCoverage" => material.alpha_to_coverage = b
    "vertexColors" => material.vertex_colors = b
    "fog" => material.fog = Some(b)
    "side" => material.side = grid_number(v).to_int()
    "premultipliedAlpha" => material.premultiplied_alpha = b
    "dithering" => material.dithering = b
    "toneMapped" => material.tone_mapped = b
    "precision" => material.precision = Some(grid_string(v))
    "combine" => material.combine = Some(grid_number(v).to_int())
    "flatShading" => material.flat_shading = Some(b)
    "normalMapType" => material.normal_map_type = Some(grid_number(v).to_int())
    "wireframe" => material.wireframe = Some(b)
    "depthPacking" => material.depth_packing = Some(grid_number(v).to_int())
    "sizeAttenuation" => material.size_attenuation = Some(b)
    "clearcoat" => material.set_clearcoat(grid_number(v))
    "iridescence" => material.set_iridescence(grid_number(v))
    "sheen" => material.set_sheen(grid_number(v))
    "transmission" => material.set_transmission(grid_number(v))
    "anisotropy" => material.set_anisotropy(grid_number(v))
    "dispersion" => material.set_dispersion(grid_number(v))
    "diffuseRoughness" => material.set_diffuse_roughness(grid_number(v))
    "retroreflectivity" => material.set_retroreflectivity(grid_number(v))
    _ => abort("grid: unknown property " + k)
  }
}

///|
/// `material[ k ] = texture`.
fn grid_set_map(
  material : @core.Material,
  k : String,
  t : @core.Texture,
) -> Unit {
  let t = Some(t)
  match k {
    "map" => material.map = t
    "alphaMap" => material.alpha_map = t
    "aoMap" => material.ao_map = t
    "lightMap" => material.light_map = t
    "specularMap" => material.specular_map = t
    "emissiveMap" => material.emissive_map = t
    "bumpMap" => material.bump_map = t
    "normalMap" => material.normal_map = t
    "displacementMap" => material.displacement_map = t
    "gradientMap" => material.gradient_map = t
    "roughnessMap" => material.roughness_map = t
    "metalnessMap" => material.metalness_map = t
    "matcap" => material.matcap = t
    "clearcoatMap" => material.clearcoat_map = t
    "clearcoatNormalMap" => material.clearcoat_normal_map = t
    "clearcoatRoughnessMap" => material.clearcoat_roughness_map = t
    "iridescenceMap" => material.iridescence_map = t
    "iridescenceThicknessMap" => material.iridescence_thickness_map = t
    "sheenColorMap" => material.sheen_color_map = t
    "sheenRoughnessMap" => material.sheen_roughness_map = t
    "transmissionMap" => material.transmission_map = t
    "thicknessMap" => material.thickness_map = t
    "specularIntensityMap" => material.specular_intensity_map = t
    "specularColorMap" => material.specular_color_map = t
    "anisotropyMap" => material.anisotropy_map = t
    "diffuseRoughnessMap" => material.diffuse_roughness_map = t
    _ => abort("grid: unknown map " + k)
  }
}

///|
/// A registered `LightProbeGrid` stand-in: only `texture` is read.
struct GridProbe {
  texture : @core.Texture?
}

///|
impl @webgl.LightProbeGridSource for GridProbe with fn texture(self) {
  self.texture
}

///|
impl @webgl.LightProbeGridSource for GridProbe with fn bounding_box(_) {
  @math.Box3::new()
}

///|
impl @webgl.LightProbeGridSource for GridProbe with fn resolution(_) {
  @math.Vector3::new(1.0, 1.0, 1.0)
}

///|
impl @webgl.LightProbeGridSource for GridProbe with fn priority(_) {
  0.0
}

///|
fn grid_or_false(v : String?) -> String {
  v.unwrap_or("false")
}

///|
fn grid_opt_int(v : Int32?, none : String) -> String {
  match v {
    Some(n) => n.to_string()
    None => none
  }
}

///|
/// The keys of a plain object in JS order (array indices first), as `Object.keys`.
extern "js" fn grid_js_key_order(
  keys : FixedArray[String],
) -> FixedArray[String] =
  #|(keys) => { const o = {}; for (const k of keys) o[k] = 1; return Object.keys(o); }

///|
/// `digest( p )` of programs_grid.mjs.
fn grid_digest(p : @webgl.WebGLProgramParameters, stage_base : Int32) -> String {
  let entries : Array[(String, String)] = [
    ("shaderID", p.shader_id.unwrap_or("undefined")),
    ("shaderType", p.shader_type),
    ("shaderName", p.shader.name),
    (
      "defines",
      match p.defines {
        None => "undefined"
        Some(defines) => {
          let keys = grid_js_key_order(
            FixedArray::from_array(defines.keys().collect()),
          )
          "{" +
          keys
          .iter()
          .map(fn(n) {
            n + ":" + grid_js_string(@core.JsValue::from_json(defines[n]))
          })
          .collect()
          .join("|") +
          "}"
        }
      },
    ),
    (
      "customVertexShaderID",
      match p.custom_vertex_shader_id {
        Some(id) => (id - stage_base).to_string()
        None => "undefined"
      },
    ),
    (
      "customFragmentShaderID",
      match p.custom_fragment_shader_id {
        Some(id) => (id - stage_base).to_string()
        None => "undefined"
      },
    ),
    ("isRawShaderMaterial", p.is_raw_shader_material.to_string()),
    ("glslVersion", p.glsl_version.unwrap_or("none")),
    ("precision", p.precision),
    ("batching", p.batching.to_string()),
    ("batchingColor", p.batching_color.to_string()),
    ("instancing", p.instancing.to_string()),
    ("instancingColor", p.instancing_color.to_string()),
    ("instancingMorph", p.instancing_morph.to_string()),
    ("outputColorSpace", p.output_color_space),
    ("alphaToCoverage", p.alpha_to_coverage.to_string()),
    ("map", p.map.to_string()),
    ("matcap", p.matcap.to_string()),
    ("envMap", p.env_map.to_string()),
    ("envMapMode", grid_opt_int(p.env_map_mode, "false")),
    ("envMapPMREM", p.env_map_pmrem.to_string()),
    ("envMapMaxLod", grid_opt_int(p.env_map_max_lod, "null")),
    ("envMapSize", grid_opt_int(p.env_map_size, "null")),
    ("aoMap", p.ao_map.to_string()),
    ("lightMap", p.light_map.to_string()),
    ("bumpMap", p.bump_map.to_string()),
    ("normalMap", p.normal_map.to_string()),
    ("displacementMap", p.displacement_map.to_string()),
    ("emissiveMap", p.emissive_map.to_string()),
    ("normalMapObjectSpace", p.normal_map_object_space.to_string()),
    ("normalMapTangentSpace", p.normal_map_tangent_space.to_string()),
    ("packedNormalMap", p.packed_normal_map.to_string()),
    ("metalnessMap", p.metalness_map.to_string()),
    ("roughnessMap", p.roughness_map.to_string()),
    ("anisotropy", p.anisotropy.to_string()),
    ("anisotropyMap", p.anisotropy_map.to_string()),
    ("clearcoat", p.clearcoat.to_string()),
    ("clearcoatMap", p.clearcoat_map.to_string()),
    ("clearcoatNormalMap", p.clearcoat_normal_map.to_string()),
    ("clearcoatRoughnessMap", p.clearcoat_roughness_map.to_string()),
    ("diffuseRoughness", p.diffuse_roughness.to_string()),
    ("diffuseRoughnessMap", p.diffuse_roughness_map.to_string()),
    ("dispersion", p.dispersion.to_string()),
    ("retroreflection", p.retroreflection.to_string()),
    ("iridescence", p.iridescence.to_string()),
    ("iridescenceMap", p.iridescence_map.to_string()),
    ("iridescenceThicknessMap", p.iridescence_thickness_map.to_string()),
    ("sheen", p.sheen.to_string()),
    ("sheenColorMap", p.sheen_color_map.to_string()),
    ("sheenRoughnessMap", p.sheen_roughness_map.to_string()),
    ("specularMap", p.specular_map.to_string()),
    ("specularColorMap", p.specular_color_map.to_string()),
    ("specularIntensityMap", p.specular_intensity_map.to_string()),
    ("transmission", p.transmission.to_string()),
    ("transmissionMap", p.transmission_map.to_string()),
    ("thicknessMap", p.thickness_map.to_string()),
    ("gradientMap", p.gradient_map.to_string()),
    ("opaque", p.opaque_.to_string()),
    ("alphaMap", p.alpha_map.to_string()),
    ("alphaTest", p.alpha_test.to_string()),
    ("alphaHash", p.alpha_hash.to_string()),
    ("combine", grid_opt_int(p.combine, "undefined")),
    ("mapUv", grid_or_false(p.map_uv)),
    ("aoMapUv", grid_or_false(p.ao_map_uv)),
    ("lightMapUv", grid_or_false(p.light_map_uv)),
    ("bumpMapUv", grid_or_false(p.bump_map_uv)),
    ("normalMapUv", grid_or_false(p.normal_map_uv)),
    ("displacementMapUv", grid_or_false(p.displacement_map_uv)),
    ("emissiveMapUv", grid_or_false(p.emissive_map_uv)),
    ("metalnessMapUv", grid_or_false(p.metalness_map_uv)),
    ("roughnessMapUv", grid_or_false(p.roughness_map_uv)),
    ("anisotropyMapUv", grid_or_false(p.anisotropy_map_uv)),
    ("clearcoatMapUv", grid_or_false(p.clearcoat_map_uv)),
    ("clearcoatNormalMapUv", grid_or_false(p.clearcoat_normal_map_uv)),
    ("clearcoatRoughnessMapUv", grid_or_false(p.clearcoat_roughness_map_uv)),
    ("diffuseRoughnessMapUv", grid_or_false(p.diffuse_roughness_map_uv)),
    ("iridescenceMapUv", grid_or_false(p.iridescence_map_uv)),
    ("iridescenceThicknessMapUv", grid_or_false(p.iridescence_thickness_map_uv)),
    ("sheenColorMapUv", grid_or_false(p.sheen_color_map_uv)),
    ("sheenRoughnessMapUv", grid_or_false(p.sheen_roughness_map_uv)),
    ("specularMapUv", grid_or_false(p.specular_map_uv)),
    ("specularColorMapUv", grid_or_false(p.specular_color_map_uv)),
    ("specularIntensityMapUv", grid_or_false(p.specular_intensity_map_uv)),
    ("transmissionMapUv", grid_or_false(p.transmission_map_uv)),
    ("thicknessMapUv", grid_or_false(p.thickness_map_uv)),
    ("alphaMapUv", grid_or_false(p.alpha_map_uv)),
    ("vertexTangents", p.vertex_tangents.to_string()),
    ("vertexNormals", p.vertex_normals.to_string()),
    ("vertexColors", p.vertex_colors.to_string()),
    ("vertexAlphas", p.vertex_alphas.to_string()),
    ("pointsUvs", p.points_uvs.to_string()),
    ("fog", p.fog.to_string()),
    ("useFog", p.use_fog.to_string()),
    ("fogExp2", p.fog_exp2.to_string()),
    ("flatShading", p.flat_shading.to_string()),
    ("sizeAttenuation", p.size_attenuation.to_string()),
    ("logarithmicDepthBuffer", p.logarithmic_depth_buffer.to_string()),
    ("reversedDepthBuffer", p.reversed_depth_buffer.to_string()),
    ("skinning", p.skinning.to_string()),
    ("hasPositionAttribute", p.has_position_attribute.to_string()),
    ("morphTargets", p.morph_targets.to_string()),
    ("morphNormals", p.morph_normals.to_string()),
    ("morphColors", p.morph_colors.to_string()),
    ("morphTargetsCount", p.morph_targets_count.to_string()),
    ("morphTextureStride", p.morph_texture_stride.to_string()),
    ("numSunLights", p.num_sun_lights.to_string()),
    ("numDirLights", p.num_dir_lights.to_string()),
    ("numPointLights", p.num_point_lights.to_string()),
    ("numSpotLights", p.num_spot_lights.to_string()),
    ("numSpotLightMaps", p.num_spot_light_maps.to_string()),
    ("numRectAreaLights", p.num_rect_area_lights.to_string()),
    ("numHemiLights", p.num_hemi_lights.to_string()),
    ("numSunLightShadows", p.num_sun_light_shadows.to_string()),
    ("numDirLightShadows", p.num_dir_light_shadows.to_string()),
    ("numPointLightShadows", p.num_point_light_shadows.to_string()),
    ("numSpotLightShadows", p.num_spot_light_shadows.to_string()),
    (
      "numSpotLightShadowsWithMaps",
      p.num_spot_light_shadows_with_maps.to_string(),
    ),
    ("numLightProbes", p.num_light_probes.to_string()),
    ("numLightProbeGrids", p.num_light_probe_grids.to_string()),
    ("numClippingPlanes", p.num_clipping_planes.to_string()),
    ("numClipIntersection", p.num_clip_intersection.to_string()),
    ("dithering", p.dithering.to_string()),
    ("shadowMapEnabled", p.shadow_map_enabled.to_string()),
    ("shadowMapType", p.shadow_map_type.to_string()),
    ("toneMapping", p.tone_mapping.to_string()),
    ("decodeVideoTexture", p.decode_video_texture.to_string()),
    ("decodeVideoTextureEmissive", p.decode_video_texture_emissive.to_string()),
    ("premultipliedAlpha", p.premultiplied_alpha.to_string()),
    ("doubleSided", p.double_sided.to_string()),
    ("flipSided", p.flip_sided.to_string()),
    ("useDepthPacking", p.use_depth_packing.to_string()),
    ("depthPacking", p.depth_packing.to_string()),
    ("index0AttributeName", p.index0_attribute_name.unwrap_or("undefined")),
    ("extensionClipCullDistance", p.extension_clip_cull_distance.to_string()),
    ("extensionMultiDraw", p.extension_multi_draw.to_string()),
    (
      "rendererExtensionParallelShaderCompile",
      p.renderer_extension_parallel_shader_compile.to_string(),
    ),
    ("customProgramCacheKey", p.custom_program_cache_key),
    ("vertexUv1s", p.vertex_uv1s.to_string()),
    ("vertexUv2s", p.vertex_uv2s.to_string()),
    ("vertexUv3s", p.vertex_uv3s.to_string()),
  ]
  @webgl.stable_sort_by(entries, fn(a, b) { grid_js_compare(a.0, b.0) })
  entries.map(fn(e) { e.0 + "=" + e.1 }).join(";")
}

///|
/// `normalizeKey( key, p )` of programs_grid.mjs.
fn grid_normalize_key(
  key : String,
  p : @webgl.WebGLProgramParameters,
  stage_base : Int32,
) -> String {
  if p.shader_id is Some(_) {
    return key
  }
  let parts = key.split(",").map(fn(s) { s.to_owned() }).collect()
  parts[0] = (grid_js_number(parts[0]).to_int() - stage_base).to_string()
  parts[1] = (grid_js_number(parts[1]).to_int() - stage_base).to_string()
  parts.join(",")
}

///|
extern "js" fn grid_js_number(s : String) -> Double = "(s) => Number(s)"

///|
test "diff programs_grid" {
  let gl = mock_gl(
    options="{\"extensions\":[\"EXT_color_buffer_float\",\"WEBGL_multi_draw\",\"KHR_parallel_shader_compile\",\"EXT_clip_control\",\"WEBGL_clip_cull_distance\"],\"canvas\":{\"width\":64,\"height\":32}}",
  )
  let gl2 = mock_gl(
    options="{\"extensions\":[],\"canvas\":{\"width\":64,\"height\":32}}",
  )
  let r1 = grid_setup(gl)
  let r2 = grid_setup(gl2, logarithmic=true, precision="mediump")
  mock_clear(gl)
  mock_clear(gl2)
  let render_target = @webgl.WebGLRenderTarget::new(width=4, height=4)
  let camera = @core.PerspectiveCamera::new()
  let mut stage_base : Int32? = None
  let mut program_base : Int32? = None
  let cases = match grid_json_parse(programs_cases_json).to_json() {
    Array(cases) => cases
    _ => abort("cases")
  }
  let acquired : Array[(GridSetup, @webgl.WebGLProgram, @core.Material)] = []
  for c in cases {
    let r = if grid_int(c, "r", 1) == 2 { r2 } else { r1 }
    let g = r.gl
    let renderer = r.renderer
    let rs = grid_get(c, "renderer").unwrap_or(Json::null())
    renderer.tone_mapping = grid_int(rs, "toneMapping", 0)
    renderer.set_output_color_space(
      match grid_get(rs, "outputColorSpace") {
        Some(cs) => grid_string(cs)
        None => "srgb"
      },
    )
    renderer.shadow_map.enabled = grid_bool(rs, "shadowMapEnabled")
    renderer.shadow_map.type_ = grid_int(rs, "shadowMapType", 1)
    if grid_bool(rs, "renderTarget") {
      renderer.set_render_target(Some(render_target))
    }
    if grid_bool(rs, "reversed") {
      renderer.state.buffers.depth.set_reversed(true)
    }
    let material = grid_material(grid_string(grid_get(c, "material").unwrap()))
    for kv in grid_entries(c, "set") {
      grid_set(material, kv.0, kv.1)
    }
    for kv in grid_entries(c, "maps") {
      grid_set_map(material, kv.0, grid_texture(kv.1))
    }
    if grid_get(c, "env") is Some(env) {
      material.env_map = Some(grid_env_texture(grid_string(env)))
    }
    let defines = grid_entries(c, "defines")
    if defines.length() > 0 {
      let target = material.defines.unwrap_or(Map([]))
      for kv in defines {
        target[kv.0] = kv.1
      }
      material.defines = Some(target)
    }
    if grid_get(c, "customKey") is Some(key) {
      let key = grid_string(key)
      material.custom_program_cache_key = Some(fn() { key })
    }
    if grid_get(c, "shader") is Some(shader) {
      if grid_get(shader, "vertexShader") is Some(v) {
        material.vertex_shader = Some(grid_string(v))
      }
      if grid_get(shader, "fragmentShader") is Some(f) {
        material.fragment_shader = Some(grid_string(f))
      }
      if grid_get(shader, "glslVersion") is Some(v) {
        material.glsl_version = Some(grid_string(v))
      }
      if grid_bool(shader, "clipCullDistance") {
        material.extensions.unwrap().clip_cull_distance = true
      }
      if grid_bool(shader, "multiDraw") {
        material.extensions.unwrap().multi_draw = true
      }
      if grid_get(shader, "index0AttributeName") is Some(n) {
        material.index0_attribute_name = Some(grid_string(n))
      }
      if grid_get(shader, "uniforms") is Some(Array(names)) {
        let uniforms = material.uniforms.unwrap()
        for n in names {
          uniforms[grid_string(n)] = @core.Uniform::new(Number(0.0))
        }
      }
    }
    let scene = @core.Scene::new()
    guard scene.kind is Scene(scene_data) else { abort("scene") }
    match grid_get(c, "fog") {
      Some(String("linear")) =>
        scene_data.fog = Some(
          Fog(
            @core.Fog::new(
              color=@math.Color::new(1.0, 1.0, 1.0),
              near=1.0,
              far=10.0,
            ),
          ),
        )
      Some(String("exp2")) =>
        scene_data.fog = Some(
          FogExp2(
            @core.FogExp2::new(
              color=@math.Color::new(1.0, 1.0, 1.0),
              density=0.1,
            ),
          ),
        )
      _ => ()
    }
    if grid_get(c, "sceneEnv") is Some(env) {
      scene_data.environment = Some(grid_env_texture(grid_string(env)))
    }
    let obj = grid_object(
      match grid_get(c, "object") {
        Some(o) => grid_string(o)
        None => "mesh"
      },
      grid_geometry(grid_get(c, "geometry").unwrap_or(Json::null())),
      material,
    )
    let shadows = []
    for _ in 0..<grid_int(c, "shadows", 0) {
      shadows.push(@core.Object3D::new())
    }
    let grids = match grid_get(c, "grids") {
      Some(Array(list)) =>
        list.map(fn(has_texture) {
          let o = @core.Object3D::new()
          @webgl.register_light_probe_grid(o, GridProbe::{
            texture: if has_texture is True {
              Some(@core.Texture::new())
            } else {
              None
            },
          })
          o
        })
      _ => []
    }
    let clip = grid_get(c, "clipping").unwrap_or(Json::null())
    let global_planes = []
    for i in 0..<grid_int(clip, "global", 0) {
      global_planes.push(
        @math.Plane::new(
          normal=@math.Vector3::new(1.0, 0.0, 0.0),
          constant=i.to_double(),
        ),
      )
    }
    let local_count = grid_int(clip, "local", 0)
    if local_count > 0 {
      let planes = []
      for i in 0..<local_count {
        planes.push(
          @math.Plane::new(
            normal=@math.Vector3::new(0.0, 1.0, 0.0),
            constant=i.to_double(),
          ),
        )
      }
      material.clipping_planes = Some(planes)
      material.clip_intersection = grid_bool(clip, "intersection")
    }
    ignore(r.clipping.init(global_planes, local_count > 0))
    r.clipping.set_global_state(global_planes, camera)
    r.clipping.set_state(material, camera, false)
    let params = r.programs.get_parameters(
      material,
      grid_lights_state(renderer.extensions, grid_get(c, "lights")),
      shadows,
      scene,
      obj,
      grids,
    )
    if stage_base is None && params.custom_vertex_shader_id is Some(id) {
      stage_base = Some(id)
    }
    let label = grid_string(grid_get(c, "label").unwrap())
    let base = stage_base.unwrap_or(0)
    note_str(g, label + " params", grid_digest(params, base))
    let key = r.programs.get_program_cache_key(params)
    note_str(g, label + " key", grid_normalize_key(key, params, base))
    params.shader.uniforms = r.programs.get_uniforms(material)
    note_str(
      g,
      label + " uniforms",
      grid_js_key_order(
        FixedArray::from_array(params.shader.uniforms.keys().collect()),
      )
      .iter()
      .collect()
      .join(" "),
    )
    let program = r.programs.acquire_program(params, key)
    if program_base is None {
      program_base = Some(program.id)
    }
    note_str(
      g,
      label + " program",
      [
        program.type_,
        program.name,
        program.used_times.to_string(),
        (program.id - program_base.unwrap()).to_string(),
        (program.cache_key == key).to_string(),
      ].join(" "),
    )
    acquired.push((r, program, material))
    if grid_bool(rs, "renderTarget") {
      renderer.set_render_target(None)
    }
    if grid_bool(rs, "reversed") {
      renderer.state.buffers.depth.set_reversed(false)
    }
  }
  // program bookkeeping
  note_int(gl, "programs", r1.programs.programs.length())
  note_int(gl2, "programs", r2.programs.programs.length())
  let first = acquired[0].1
  note_bool(gl, "ready", first.is_ready())
  note_bool(gl, "ready", first.is_ready())
  note_bool(gl2, "ready", acquired[acquired.length() - 1].1.is_ready())
  let attributes = first.get_attributes()
  note_str(gl, "attributes", attributes.keys().collect().join(" "))
  ignore(first.get_uniforms())
  note_str(
    gl,
    "diagnostics",
    if first.diagnostics is None {
      "undefined"
    } else {
      "set"
    },
  )
  r1.renderer.debug.check_shader_errors = false
  ignore(acquired[1].1.get_uniforms())
  r1.renderer.debug.check_shader_errors = true
  for item in acquired {
    let (r, program, material) = item
    r.programs.release_program(program)
    if material.is_shader_material() {
      r.programs.release_shader_cache(material)
    }
  }
  note_int(gl, "programs", r1.programs.programs.length())
  note_int(gl2, "programs", r2.programs.programs.length())
  r1.programs.dispose()
  r2.programs.dispose()
  mock_note(gl, "gl2", grid_log_value(gl2))
  let log = emit_log("programs_grid", gl)
  assert_true(log.length() > cases.length() * 4)
}

///|
/// `compile( R, material )` of programs_errors.mjs.
fn errors_compile(r : GridSetup, material : @core.Material) -> Unit {
  let g = r.gl
  let object = @core.Mesh::new(
    geometry=@core.BufferGeometry::new(),
    material=Single(material),
  )
  let params = r.programs.get_parameters(
    material,
    grid_lights_state(r.renderer.extensions, None),
    [],
    @core.Scene::new(),
    object,
    [],
  )
  let key = r.programs.get_program_cache_key(params)
  params.shader.uniforms = r.programs.get_uniforms(material)
  let program = r.programs.acquire_program(params, key)
  ignore(program.get_uniforms())
  match program.diagnostics {
    None => note_str(g, "diagnostics", "undefined")
    Some(d) => {
      note_str(
        g,
        "diagnostics",
        [
          d.runnable.to_string(),
          d.program_log,
          d.vertex_shader.log,
          d.fragment_shader.log,
        ].join("|"),
      )
      note_str(g, "vertex prefix", d.vertex_shader.prefix)
      note_str(g, "fragment prefix", d.fragment_shader.prefix)
    }
  }
}

///|
test "diff programs_errors" {
  let source = Array::makei(20, fn(i) { "line \{i + 1}" }).join("\n")
  let canvas = "\"canvas\":{\"width\":64,\"height\":32}"
  let gl_a = mock_gl(
    options="{\"linkStatus\":false,\"compileStatus\":false,\"shaderInfoLog\":\"  ERROR: 0:12: bad token\\n\",\"programInfoLog\":\" link failed \",\"shaderSource\":" +
      Json::string(source).stringify() +
      "," +
      canvas +
      "}",
  )
  let gl_b = mock_gl(
    options="{\"programInfoLog\":\"warning: unused\"," + canvas + "}",
  )
  let gl_c = mock_gl(options="{\"shaderInfoLog\":\"note\"," + canvas + "}")
  let a = grid_setup(gl_a)
  mock_clear(gl_a)
  let b = grid_setup(gl_b)
  mock_clear(gl_b)
  let c = grid_setup(gl_c)
  mock_clear(gl_c)
  errors_compile(a, @core.MeshBasicMaterial::new())
  a.renderer.debug.on_shader_error = Some(fn(g, program, vs, fs) {
    let handles : FixedArray[@core.JsValue] = [
      @core.JsValue::of(program),
      @core.JsValue::of(vs),
      @core.JsValue::of(fs),
    ]
    mock_note(g, "onShaderError", @core.JsValue::of(handles))
  })
  errors_compile(a, @core.MeshLambertMaterial::new())
  errors_compile(b, @core.MeshStandardMaterial::new())
  let raw = @core.RawShaderMaterial::new()
  raw.vertex_shader = Some("void main() {}")
  raw.fragment_shader = Some("void main() {}")
  raw.defines = Some(Map([("FOO", Json::number(1.0))]))
  errors_compile(b, raw)
  errors_compile(c, @core.MeshPhongMaterial::new())
  mock_note(gl_a, "B", grid_log_value(gl_b))
  mock_note(gl_a, "C", grid_log_value(gl_c))
  let log = emit_log("programs_errors", gl_a)
  assert_true(log.contains("getError()"))
}
