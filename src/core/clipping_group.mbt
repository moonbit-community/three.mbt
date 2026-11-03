// Upstream src/objects/ClippingGroup.js. Its `type` stays `Group`, as upstream.

///|
pub fn ClippingGroup::new() -> Object3D {
  Object3D::new(
    kind=ClippingGroup({
      clipping_planes: [],
      enabled: true,
      clip_intersection: false,
      clip_shadows: false,
    }),
    type_="Group",
  )
}
