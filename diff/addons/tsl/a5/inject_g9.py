#!/usr/bin/env python3
"""A5 bug injection on the mock-GPU paths (render / updateBefore code the shader harness
never runs): each bug is applied to the real src/addons/tsl file, the MoonBit side
(diff/core/g9/mbt_a5) is rebuilt, the listed scenarios are compared
(diff/core/g9/harness/run_a5.mjs), and the file is restored (diff/lib/inject.py).
    python3 inject_g9.py [index ...]
    INJECT_DRY_RUN=1 python3 inject_g9.py   # only check that every pattern still occurs
"""
import subprocess, sys, pathlib
sys.path.insert(0, str(next(p for p in pathlib.Path(__file__).resolve().parents if (p / 'lib/env.py').exists())))
from lib.env import DIFF, REPO  # noqa: E402
from lib.inject import patched, DRY_RUN  # noqa: E402

T = 'src/addons/tsl/'
G9 = DIFF / 'core/g9'
BUGS = [
  ('display_bloom_node.mbt', 'let _bloom_node_blur_direction_x : @math.Vector2 = @math.Vector2::new(1.0, 0.0)', 'let _bloom_node_blur_direction_x : @math.Vector2 = @math.Vector2::new(1.0, 1.0)', ['a5_bloom'], 'horizontal blur direction (1,0) -> (1,1)'),
  ('display_bloom_node.mbt', 'resx = (resx / 2.0).floor()', 'resx = (resx / 2.0).ceil()', ['a5_bloom', 'a5_bloom_nodes'], 'mip chain width floor -> ceil'),
  ('display_after_image_node.mbt', '  self._comp_rt = temp\n', '', ['a5_after_image'], 'history swap drops the second assignment'),
  ('display_traa_node.mbt', 'offset_x + jitter_offset.0 - 0.5,', 'offset_x + jitter_offset.1 - 0.5,', ['a5_traa'], 'jitter x uses the y Halton offset'),
  ('display_traa_node.mbt', '  self._jitter_index += 1\n', '', ['a5_traa'], 'jitter index never advances'),
  ('display_taau_node.mbt', '    quad_mesh.set_material(self._seed_material)\n', '', ['a5_taau'], 'seed pass renders with the previous material'),
  ('display_outline_node.mbt', '''    _outline_node_blur_direction_y,
  )
  |> ignore
  renderer.set_render_target(Some(self._render_target_edge_buffer1))''', '''    _outline_node_blur_direction_x,
  )
  |> ignore
  renderer.set_render_target(Some(self._render_target_edge_buffer1))''', ['a5_outline'], 'vertical half-resolution blur keeps the x direction'),
  ('display_stereo_composite_pass_node.mbt', 'renderer.render(scene, stereo.camera_r)', 'renderer.render(scene, stereo.camera_l)', ['a5_parallax_barrier'], 'right eye rendered with the left camera'),
  ('display_oit_pass_node.mbt', '        material.depth_write = current_depth_write\n', '', ['a5_oit'], 'depthWrite not restored after the OIT pass'),
  ('lighting_clustered_lights_node.mbt', '  renderer.compute(self._compute.unwrap())\n  None\n}', '  None\n}', ['a5_clustered_lights'], 'cluster compute never dispatched'),
  ('shadows_tile_shadow_node.mbt', 'let tile_left = ls_min.x + tile.x.0 * full_width', 'let tile_left = ls_min.x + tile.x.0 * full_height', ['a5_tile_shadow'], 'tile left edge scaled by the height'),
  ('display_smaa_node.mbt', '''  renderer.set_render_target(Some(self._render_target_weights))
  quad_mesh.set_material(self._material_weights)''', '''  renderer.set_render_target(Some(self._render_target_edges))
  quad_mesh.set_material(self._material_weights)''', ['a5_smaa'], 'weights pass renders into the edges target'),
  ('display_temporal_reproject_node.mbt', '    renderer.copy_texture_to_texture(current_depth, history_depth)\n', '', ['a5_temporal_reproject'], 'history depth never copied'),
  ('display_after_image_node.mbt', 'self._old_rt = self._comp_rt', 'self._old_rt = temp', ['a5_after_image'], 'old target not swapped in'),
  ('display_taau_node.mbt', 'quad_mesh.object.name = "TAAU.seed"', 'quad_mesh.object.name = "TAAU.seeds"', ['a5_taau'], 'pass name (no GPU effect; expected to be missed)'),
  ('lighting_dynamic_lights_node.mbt', '    if dynamic_lights_node_can_batch_light(light) == false {', '    if dynamic_lights_node_can_batch_light(light) == true {', ['a5_dynamic_lights'], 'batching test inverted'),
]
only = [int(a) for a in sys.argv[1:]]
for i, (f, old, new, scen, desc) in enumerate(BUGS):
    if only and i not in only:
        continue
    src = (REPO / T / f).read_text()
    if src.count(old) != 1:
        print(f'[{i}] SKIP {f}: pattern found {src.count(old)} times')
        continue
    with patched(T + f, old, new):
        if DRY_RUN:
            print(f'[{i}] pattern found: {desc}')
            continue
        b = subprocess.run(['moon', 'build', '--target', 'js'], cwd=G9 / 'mbt_a5', capture_output=True, text=True)
        if b.returncode != 0:
            print(f'[{i}] BUILD FAILED {f}: {desc}\n' + b.stdout[-800:])
            continue
        r = subprocess.run(['node', 'run_a5.mjs', '--quiet'] + scen, cwd=G9 / 'harness', capture_output=True, text=True)
    last = r.stdout.strip().split('\n')[-1]
    print(f'[{i}] {"CAUGHT" if r.returncode != 0 else "MISSED"} {f}: {desc} -> {last}', flush=True)
if not DRY_RUN:
    subprocess.run(['moon', 'build', '--target', 'js'], cwd=G9 / 'mbt_a5', capture_output=True)
