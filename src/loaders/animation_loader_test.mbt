///|
test "AnimationLoader parse" {
  let json = @json.parse(
    (
      #|[{"name":"a","duration":1,"tracks":[{"name":".position[x]","times":[0,1],"values":[0,2],"type":"number"}],"uuid":"clip-a","blendMode":2500},
      #| {"name":"b","duration":-1,"tracks":[],"uuid":"clip-b","blendMode":2501}]
    ),
  )
  let clips = @loaders.AnimationLoader::new().parse(json)
  assert_eq(clips.length(), 2)
  assert_eq(clips[0].name, "a")
  assert_eq(clips[0].uuid, "clip-a")
  assert_eq(clips[0].tracks.length(), 1)
  assert_eq(clips[1].uuid, "clip-b")
}

///|
test "ObjectLoader attaches parsed animations" {
  let json = @json.parse(
    (
      #|{"metadata":{"type":"Object"},
      #| "animations":[{"name":"walk","duration":2,"tracks":[],"uuid":"clip-w","blendMode":2500}],
      #| "object":{"uuid":"o","type":"Group","animations":["clip-w","missing"]}}
    ),
  )
  let object = @loaders.ObjectLoader::new().parse(json)
  assert_eq(object.animations.length(), 1)
  assert_eq(object.animations[0].uuid(), "clip-w")
}
