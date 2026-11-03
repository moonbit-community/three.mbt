#!/usr/bin/env python3
"""Deliberate-bug check: applies each mutation to a temporary copy of src/loaders (a
module under $THREE_DIFF_OUT/classic_loaders/mut whose moon.work points at the repo, so
the repository itself is never modified), rebuilds the harness against it and runs
run.mjs, which must report a failure (or the copied unit tests must fail).

    python3 mutate.py [name ...]
    INJECT_DRY_RUN=1 python3 mutate.py    # only check that every pattern applies
"""
import os, shutil, subprocess, sys
from pathlib import Path

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, str(Path(HERE).parents[1]))  # diff/
from lib.env import REPO, out_dir  # noqa: E402

SRC = str(REPO / 'src/loaders')
MUT = str(out_dir('classic_loaders', 'mut'))
DRY_RUN = os.environ.get('INJECT_DRY_RUN') == '1'

# (name, file, old, new): `old` must occur exactly once.
MUTATIONS = [
    ('blurriness dropped', 'object_loader.mbt', 'scene.background_blurriness = value', 'ignore(value)'),
    ('wrapT from wrapS', 'object_loader.mbt', 'object_loader_parse_constant(wrap[1], object_loader_texture_wrapping)', 'object_loader_parse_constant(wrap[0], object_loader_texture_wrapping)'),
    ('light target never found', 'object_loader.mbt', '    match object.get_object_by_property("uuid", Json::string(uuid)) {', '    match object.get_object_by_property("uuid", Json::string(uuid + "x")) {'),
    ('pivot ignored in matrix', 'object_loader.mbt', '        object.position.copy(pivot).apply_matrix4(object.matrix).sub(pivot)\n        |> ignore', '        ignore(pivot)'),
    ('attribute usage dropped', 'buffer_geometry_loader.mbt', 'buffer_attribute.set_usage(usage) |> ignore', 'ignore(usage)'),
    ('morphTargetsRelative dropped', 'buffer_geometry_loader.mbt', 'geometry.morph_targets_relative = true', '()'),
    ('texture userData dropped', 'object_loader.mbt', 'texture.user_data = JsValue::from_json(user_data)', 'ignore(user_data)'),
    ('DataTexture becomes Texture', 'object_loader.mbt', '        let texture = if image is DataImage({ data: Some(_), .. }) {', '        let texture = if image is DataImage({ data: Some(_), .. }) && false {'),
    ('LOD hysteresis dropped', 'object_loader.mbt', 'hysteresis?=json_opt_number(level, "hysteresis"),', 'hysteresis?=None,'),
    ('instanceColor dropped', 'object_loader.mbt', '      if instance_color is Some(instance_color) {', '      if instance_color is Some(instance_color) && false {'),
    ('skeleton not bound', 'object_loader.mbt', 'child.bind(skeleton, bind_matrix=skinned.bind_matrix)', 'ignore((skeleton, skinned))'),
    ('animations not attached', 'object_loader.mbt', 'Some(animation) => object.animations.push(animation)', 'Some(_) => ()'),
    ('shadow camera kept', 'object_loader.mbt', '    if shadow_data.get("camera") is Some(camera) {', '    if shadow_data.get("camera") is Some(camera) && false {'),
    ('cube data faces: source first', 'object_loader.mbt',
     '''        let image_array : Array[@core.TextureImage] = []
        for current_url in urls {
          match deserialize_image(current_url) {''',
     '''        let image_array : Array[@core.TextureImage] = []
        ignore(@math.generate_uuid())
        for current_url in urls {
          match deserialize_image(current_url) {'''),
    ('scene fog name ignored', 'object_loader.mbt', '          (Some(name), Some(Fog(fog))) => fog.name = name', '          (Some(_), Some(Fog(_))) => ()'),
    ('camera view dropped', 'object_loader.mbt', '      if data.get("view") is Some(view) {\n        camera.view = Some(object_loader_camera_view(view))\n      }\n      object\n    }\n    "OrthographicCamera"', '      ignore(data.get("view"))\n      object\n    }\n    "OrthographicCamera"'),
    ('batched geometry info count', 'object_loader.mbt', '      count: info_int("count"),', '      count: info_int("count") + 1,'),
    ('material cache ignored', 'object_loader.mbt', '      if cache.get(uuid) is None {', '      if true {'),
    ('progress not accumulated', 'file_loader.mbt', 'loaded += js_byte_length(value)', 'loaded = js_byte_length(value)'),
    ('itemStart before fetch', 'file_loader.mbt', '  // start the fetch\n  js_fetch(req)', '  manager.item_start(url)\n  js_fetch(req)'),
    ('duplicate requests not shared', 'file_loader.mbt', '  if file_loader_loading.get(url) is Some(callbacks) {', '  if file_loader_loading.get(url) is Some(callbacks) && false {'),
    ('crossOrigin not set', 'image_loader.mbt', 'image.set("crossOrigin", js_from_string(base.cross_origin))', 'ignore(base)'),
    ('isLoading never reset', 'loading_manager.mbt', '    self.is_loading = false', '    ()'),
    ('cube colorSpace', 'cube_texture_loader.mbt', 'texture.color_space = @core.SRGBColorSpace', '()'),
    ('bitmap credentials', 'image_bitmap_loader.mbt', 'base.with_credentials || base.cross_origin != "anonymous"', 'base.with_credentials'),
    ('mipmapCount rule', 'data_texture_loader.mbt', '  if tex_data.mipmap_count == Some(1) {', '  if tex_data.mipmap_count == Some(2) {'),
    ('decode item not tracked', 'audio_loader.mbt', '        manager.item_start(decode_url) // prevent loading manager from completing too early, see #33378', '        ignore(decode_url)'),
    ('json loader error not reported to manager', 'buffer_geometry_loader.mbt', '        base.manager.item_error(url)\n      }\n    },', '        ()\n      }\n    },'),
    ('relative image url', 'object_loader.mbt', '    self.base.resource_path + url', '    url'),
    ('resolveURL NFC skipped', 'loading_manager.mbt', '  let url = js_normalize_nfc(url)', '  let url = url'),
]


def setup():
    os.makedirs(os.path.join(MUT, 'src', 'loaders'), exist_ok=True)
    os.makedirs(os.path.join(MUT, 'src', 'harness'), exist_ok=True)
    with open(os.path.join(MUT, 'moon.mod'), 'w') as f:
        f.write('name = "loadersdev/mut"\n\nversion = "0.1.0"\n\nimport {\n  "moonbit-community/three@0.1.0",\n}\n\nsource = "src"\n\npreferred_target = "js"\n')
    with open(os.path.join(MUT, 'moon.work'), 'w') as f:
        f.write('members = [\n  ".",\n  "%s",\n]\n' % os.path.relpath(REPO, MUT))
    pkg = open(os.path.join(HERE, 'mbt', 'harness', 'moon.pkg')).read()
    with open(os.path.join(MUT, 'src', 'harness', 'moon.pkg'), 'w') as f:
        f.write(pkg.replace('"moonbit-community/three/loaders" @loaders', '"loadersdev/mut/loaders" @loaders'))
    for name in ('harness.mbt', 'scenarios.mbt'):
        shutil.copy(os.path.join(HERE, 'mbt', 'harness', name), os.path.join(MUT, 'src', 'harness', name))


def copy_sources():
    dst = os.path.join(MUT, 'src', 'loaders')
    for f in os.listdir(dst):
        os.remove(os.path.join(dst, f))
    for f in os.listdir(SRC):
        if f.endswith('.mbt') or f == 'moon.pkg':
            shutil.copy(os.path.join(SRC, f), os.path.join(dst, f))


def run(label):
    env = dict(os.environ, LOADERS_MODULE_DIR=MUT, LOADERS_HARNESS='loadersdev/mut/harness/harness.js')
    r = subprocess.run(['node', 'run.mjs'], cwd=HERE, env=env, capture_output=True, text=True)
    out = r.stdout + r.stderr
    summary = [l for l in out.splitlines() if 'passed' in l and 'failed' in l]
    lines = out.splitlines()
    first = [l for i, l in enumerate(lines) if l.startswith(('MISMATCH', 'ERROR', 'BUILD FAILED')) and not (i > 0 and lines[i - 1].startswith('KNOWN'))]
    code = r.returncode
    if code == 0:
        # the unit tests of src/loaders, on the mutated copy
        t = subprocess.run(['moon', 'test', '--target', 'js', '-p', 'loadersdev/mut/loaders'], cwd=MUT, capture_output=True, text=True)
        tl = [l for l in (t.stdout + t.stderr).splitlines() if l.startswith('Total tests')]
        if t.returncode != 0:
            code = 1
            first = ['unit tests: ' + (tl[-1] if tl else 'failed to run')]
    return code, (summary[-1] if summary else 'no summary'), (first[0] if first else '')


def main():
    only = sys.argv[1:]
    if DRY_RUN:
        bad = [n for n, f, old, _ in MUTATIONS if old not in open(os.path.join(SRC, f)).read()]
        print(f'{len(MUTATIONS) - len(bad)}/{len(MUTATIONS)} patterns apply' + (f'; not found: {bad}' if bad else ''))
        sys.exit(1 if bad else 0)
    setup()
    copy_sources()
    code, summary, _ = run('baseline')
    print(f'baseline: exit {code}: {summary}')
    if code != 0:
        print('baseline must pass'); sys.exit(1)
    missed = []
    for name, file, old, new in MUTATIONS:
        if only and name not in only:
            continue
        copy_sources()
        path = os.path.join(MUT, 'src', 'loaders', file)
        text = open(path).read()
        if text.count(old) < 1:
            print(f'SKIP     {name}: pattern not found'); missed.append(name); continue
        # the first occurrence (the synchronous path where code is duplicated)
        open(path, 'w').write(text.replace(old, new, 1))
        code, summary, first = run(name)
        status = 'caught' if code != 0 else 'MISSED'
        if code == 0: missed.append(name)
        print(f'{status:8} {name}: {summary} | {first[:110]}')
    copy_sources()
    print(f'\n{len(missed)} missed: {missed}')
    sys.exit(1 if missed else 0)


if __name__ == '__main__':
    main()
