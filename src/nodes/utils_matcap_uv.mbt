// nodes/utils/MatcapUV.js: the uv of a matcap texture from the view normal.

///|
/// `matcapUV`: computed once per build (in the `NORMAL` and `VERTEX` sub-builds).
pub let matcap_uv : Node = module_nodes("nodes/utils/MatcapUV.js:matcapUV", fn() {
  fn_(fn(_, _) {
    let x = vec3_of([
      position_view_direction.z(),
      0,
      position_view_direction.x().negate(),
    ]).normalize()
    let y = position_view_direction.cross(x)
    Some(
      vec2_of([x.dot(normal_view), y.dot(normal_view)]).mul(0.495).add(0.5), // 0.495 to remove artifacts caused by undersized matcap disks
    )
  })
  .once(sub_builds=["NORMAL", "VERTEX"])
  .call([])
  .to_var(name="matcapUV")
})
