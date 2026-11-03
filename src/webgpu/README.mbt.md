# bobzhang/three/webgpu

The entry points of three.js's WebGPU build in one package: upstream's `Three.WebGPU.js`
(`three/webgpu`), `Three.TSL.js` (`three/tsl`) and `Three.WebGPU.Nodes.js`. Import it once
and use it like the `THREE` namespace:

```text
import {
  "bobzhang/three/webgpu" @three,
}
```

- `@three.WebGPURenderer::new(...)`, the node materials (`@three.MeshStandardNodeMaterial::new()`),
  the node classes and the renderer classes;
- everything `Three.Core.js` exports: `@three.Scene::new()`, `@three.Mesh::new(...)`,
  `@three.BoxGeometry::new()`, `@three.Color::new(...)`, the constants (`@three.SRGBColorSpace`);
- the TSL functions and nodes: `@three.uv()`, `@three.fn_(...)`, `@three.position_local`
  (upstream's `TSL.uv()`; MoonBit has one namespace per package, so `THREE` and `TSL` are
  the same import here);
- namespaces as types with static methods: `@three.RendererUtils::save_renderer_state(...)`,
  `@three.MathUtils::clamp(...)`, `@three.NodeUtils::hash_string(...)`,
  `@three.AnimationUtils::subclip(...)`;
- the MoonBit types the signatures use in place of JS values (`JsValue`, `TypedArray`,
  `MaterialSlot`, `IntoTsl`, `TslValue`, ...).

MoonBit has no `export *`, so the files are `pub using @pkg { ... }` lists generated from
upstream's export lists by `node tools/check_webgpu_exports.mjs --write`; without `--write`
the tool checks every upstream export against the port and reports missing ones. Where two
upstream modules export the same name into one MoonBit namespace, TSL's wins: `log` is
TSL's `log`, utils.js's console `log` stays `@core.log`. `Three.WebGPU.Nodes.js`'s
`WebGPURenderer` (BasicNodeLibrary only) is `WebGPURendererNodes`.

## Example

A box with a node material whose `colorNode` is a TSL checker, under a directional light.
Rendering needs a browser with WebGPU (or WebGL 2), so this only builds the scene.

```mbt check
///|
test "a scene with a node material and a TSL colorNode" {
  let scene = @webgpu.Scene::new()
  let camera = @webgpu.PerspectiveCamera::new(
    fov=50.0,
    aspect=4.0 / 3.0,
    near=0.1,
    far=100.0,
  )
  camera.position.set(0.0, 0.0, 3.0) |> ignore
  // upstream: Fn( ( [ coord ] ) => { ... } ).setLayout( { name: 'checker', ... } )
  let scale = @webgpu.uniform(4)
  let checker = @webgpu.fn_(fn(inputs, _) {
    let coord = inputs.get(0).unwrap()
    let cell = coord.mul(scale).floor().to_var()
    let color = @webgpu.vec3(0.1).to_var()
    @webgpu.if_(cell.x().add(cell.y()).mod(2).equal(0), fn() {
      color.assign(@webgpu.vec3_of([1, 0.5, 0]))
    })
    |> ignore
    Some(color)
  }).set_layout(name="checker", type_="vec3", inputs=[("coord", "vec2")])
  let material = @webgpu.MeshStandardNodeMaterial::new()
  @webgpu.NodeMaterial::of(material).unwrap().color_node = Some(
    checker.call([@webgpu.uv()]),
  )
  let box = @webgpu.Mesh::new(
    geometry=@webgpu.BoxGeometry::new(),
    material=Single(material),
  )
  scene.add(box) |> ignore
  let light = @webgpu.DirectionalLight::new(intensity=2.0)
  light.position.set(1.0, 2.0, 3.0) |> ignore
  scene.add(light) |> ignore
  inspect(scene.children.length(), content="2")
  inspect(material.is_node_material(), content="true")
}
```
