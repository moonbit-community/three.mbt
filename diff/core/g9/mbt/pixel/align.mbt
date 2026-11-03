///|
/// Advances the id counters to the values harness/pixel_up.mjs aligns upstream's to.
pub fn align_counters() -> Unit {
  fn advance(name : String, target : Int32, f : () -> Int32) -> Unit {
    let mut id = f()
    if id >= target {
      abort("counter \{name} already at \{id}")
    }
    while id < target - 1 {
      id = f()
    }
  }

  advance("node", 20000, fn() { @three.Node::alloc().id })
  advance("object3d", 1000, fn() { @three.Object3D::new().id })
  advance("material", 1000, fn() { @three.Material::new().id })
  advance("texture", 1000, fn() { @three.Texture::new().id })
  advance("attribute", 1000, fn() {
    @three.BufferAttribute::new(@three.TypedArray::float32(1), 1).id
  })
  advance("geometry", 1000, fn() { @three.BufferGeometry::new().id })
}
