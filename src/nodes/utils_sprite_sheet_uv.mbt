// nodes/utils/SpriteSheetUV.js: the uv of one frame of a sprite sheet.

///|
/// `spritesheetUV( countNode, uvNode = uv(), frameNode = float( 0 ) )`.
pub let spritesheet_uv : Node = module_nodes(
  "nodes/utils/SpriteSheetUV.js:spritesheetUV",
  fn() {
    fn_(fn(inputs, _) {
      let count_node = operator_node_input(inputs, 0)
      let uv_node = inputs.get(1).unwrap_or_else(fn() { uv() })
      let frame_node = inputs.get(2).unwrap_or_else(fn() { float(0) })
      let width = count_node.x()
      let height = count_node.y()
      let frame_num = frame_node.mod(width.mul(height)).floor()
      let column = frame_num.mod(width)
      let row = height.sub(frame_num.add(1).div(width).ceil())
      let scale = count_node.reciprocal()
      let uv_frame_offset = vec2_of([column, row])
      Some(uv_node.add(uv_frame_offset).mul(scale))
    })
  },
)
