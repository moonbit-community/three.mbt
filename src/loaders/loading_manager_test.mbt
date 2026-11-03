///|
test "LoadingManager addHandler/getHandler/removeHandler" {
  let loading_manager = @loaders.LoadingManager::new()
  let loader = @loaders.Loader::new()
  let regex1 = @loaders.RegExp::new("\\.jpg$", flags="i")
  let regex2 = @loaders.RegExp::new("\\.jpg$", flags="gi")
  fn is_loader(handler : &@loaders.LoaderLike?) -> Bool {
    handler is Some(handler) && physical_equal(handler.loader(), loader)
  }

  loading_manager.add_handler(regex1, loader) |> ignore
  assert_true(is_loader(loading_manager.get_handler("foo.jpg")))
  // the correct file extension is not at the end of the file name
  assert_true(loading_manager.get_handler("foo.jpg.png") is None)
  // the file extension is wrong
  assert_true(loading_manager.get_handler("foo.jpeg") is None)
  loading_manager.remove_handler(regex1) |> ignore
  assert_true(loading_manager.get_handler("foo.jpg") is None)
  loading_manager.add_handler(regex2, loader) |> ignore
  assert_true(is_loader(loading_manager.get_handler("foo.jpg")))
  // test twice, see #17920
  assert_true(is_loader(loading_manager.get_handler("foo.jpg")))
}

///|
test "LoadingManager abortController - lazy instantiation" {
  let loading_manager = @loaders.LoadingManager::new()
  assert_true(loading_manager._abort_controller is None)
  let controller = loading_manager.abort_controller()
  assert_true(
    loading_manager._abort_controller is Some(c) && c.same(controller),
  )
  let controller2 = loading_manager.abort_controller()
  assert_true(controller.same(controller2))
}

///|
test "LoadingManager abort() - aborts controller and resets" {
  let loading_manager = @loaders.LoadingManager::new()
  let controller = loading_manager.abort_controller()
  assert_false(controller.aborted())
  loading_manager.abort() |> ignore
  assert_true(controller.aborted())
  assert_true(loading_manager._abort_controller is None)
}

///|
test "LoadingManager abortController - recreation after abort" {
  let loading_manager = @loaders.LoadingManager::new()
  let controller1 = loading_manager.abort_controller()
  loading_manager.abort() |> ignore
  assert_true(controller1.aborted())
  assert_true(loading_manager._abort_controller is None)
  let controller2 = loading_manager.abort_controller()
  assert_false(controller1.same(controller2))
  assert_false(controller2.aborted())
}

///|
test "LoadingManager item callbacks" {
  let events = []
  let manager = @loaders.LoadingManager::new(
    on_load=() => events.push("load"),
    on_progress=(url, loaded, total) => {
      events.push("progress \{url} \{loaded}/\{total}")
    },
    on_error=url => events.push("error \{url}"),
  )
  manager.on_start = Some((url, loaded, total) => {
    events.push("start \{url} \{loaded}/\{total}")
  })
  manager.item_start("a")
  manager.item_start("b")
  manager.item_end("a")
  manager.item_error("b")
  manager.item_end("b")
  manager.item_start("c")
  manager.item_end("c")
  assert_eq(events, [
    "start a 0/1", "progress a 1/2", "error b", "progress b 2/2", "load", "start c 2/3",
    "progress c 3/3", "load",
  ])
}

///|
test "LoadingManager resolveURL" {
  let manager = @loaders.LoadingManager::new()
  // NFC normalization
  assert_eq(manager.resolve_url("e\u{301}"), "\u{e9}")
  manager.set_url_modifier(Some(url => "blob:" + url)) |> ignore
  assert_eq(manager.resolve_url("a.png"), "blob:a.png")
  manager.set_url_modifier(None) |> ignore
  assert_eq(manager.resolve_url("a.png"), "a.png")
}
