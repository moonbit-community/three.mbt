// Upstream src/core/Layers.js. The bit operations are the upstream JS expressions: they
// mix signed and unsigned results, which `mask` keeps as a Double.

///|
extern "js" fn layers_set_mask(layer : Int32) -> Double = "(l) => ( 1 << l | 0 ) >>> 0"

///|
extern "js" fn layers_enable_mask(mask : Double, layer : Int32) -> Double = "(m, l) => m | ( 1 << l | 0 )"

///|
extern "js" fn layers_toggle_mask(mask : Double, layer : Int32) -> Double = "(m, l) => m ^ ( 1 << l | 0 )"

///|
extern "js" fn layers_disable_mask(mask : Double, layer : Int32) -> Double = "(m, l) => m & ~ ( 1 << l | 0 )"

///|
extern "js" fn layers_masks_overlap(a : Double, b : Double) -> Bool = "(a, b) => ( a & b ) !== 0"

///|
pub fn Layers::new() -> Layers {
  { mask: 1, }
}

///|
pub fn Layers::set(self : Layers, layer : Int32) -> Unit {
  self.mask = layers_set_mask(layer)
}

///|
pub fn Layers::enable(self : Layers, layer : Int32) -> Unit {
  self.mask = layers_enable_mask(self.mask, layer)
}

///|
pub fn Layers::enable_all(self : Layers) -> Unit {
  self.mask = -1
}

///|
pub fn Layers::toggle(self : Layers, layer : Int32) -> Unit {
  self.mask = layers_toggle_mask(self.mask, layer)
}

///|
pub fn Layers::disable(self : Layers, layer : Int32) -> Unit {
  self.mask = layers_disable_mask(self.mask, layer)
}

///|
pub fn Layers::disable_all(self : Layers) -> Unit {
  self.mask = 0
}

///|
/// Upstream `test`, which is a keyword here.
pub fn Layers::test_(self : Layers, layers : Layers) -> Bool {
  layers_masks_overlap(self.mask, layers.mask)
}

///|
pub fn Layers::is_enabled(self : Layers, layer : Int32) -> Bool {
  layers_masks_overlap(self.mask, layers_enable_mask(0, layer))
}
