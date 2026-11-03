#!/usr/bin/env python3
# Injects one bug at a time into src/addons/controls, rebuilds the harness, runs
# run.mjs and records whether some scenario diverged; always restores the file.
#   python3 inject.py [index ...]      (INJECT_DRY_RUN=1: only check the patterns apply)
# If a run is killed hard, `python3 diff/lib/inject.py --restore` restores the file.
import subprocess, sys, pathlib
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(next(p for p in HERE.parents if (p / 'lib/env.py').exists())))
from lib.inject import patched, run as run_cmd, DRY_RUN  # noqa: E402
from lib.env import REPO  # noqa: E402

SRC = 'src/addons/controls/'
BUGS = [
    ('orbit wheel LINE_MODE factor 16 -> 10', 'orbit_controls.mbt', 'delta_y *= 16.0', 'delta_y *= 10.0'),
    ('orbit pinch ignores interceptControlDown', 'orbit_controls.mbt', 'ev_bool(event, "ctrlKey") && !self._control_active', 'ev_bool(event, "ctrlKey") && self._control_active'),
    ('orbit rotate by clientWidth', 'orbit_controls.mbt', '''  self._rotate_left(
    _orbit_two_pi * self._rotate_delta.x / dom_num(element, "clientHeight"),
  ) // yes, height
  self._rotate_up(
    _orbit_two_pi * self._rotate_delta.y / dom_num(element, "clientHeight"),
  )
  ignore(self._rotate_start.copy(self._rotate_end))
  ignore(self.update())''', '''  self._rotate_left(
    _orbit_two_pi * self._rotate_delta.x / dom_num(element, "clientWidth"),
  ) // yes, height
  self._rotate_up(
    _orbit_two_pi * self._rotate_delta.y / dom_num(element, "clientHeight"),
  )
  ignore(self._rotate_start.copy(self._rotate_end))
  ignore(self.update())'''),
    ('orbit damping decay uses factor', 'orbit_controls.mbt', 'self._spherical_delta.theta *= 1.0 - self.damping_factor', 'self._spherical_delta.theta *= self.damping_factor'),
    ('orbit keydown interceptor without capture', 'orbit_controls.mbt', '''  dom_add_event_listener_passive_capture(
    dom_owner_document(element),
    "keydown",''', '''  dom_add_event_listener(
    dom_owner_document(element),
    "keydown",'''),
    ('orbit no pointer capture', 'orbit_controls.mbt', '''    dom_set_pointer_capture(element, ev_num(event, "pointerId"))
    dom_add_event_listener(''', '''    dom_add_event_listener('''),
    ('orbit pointer-up placeholder swaps x/y', 'orbit_controls.mbt', 'make_pointer_event(pointer_id, position.x, position.y)', 'make_pointer_event(pointer_id, position.y, position.x)'),
    ('orbit second pointer picks pointers[0]', 'orbit_controls.mbt', '''  let pointer_id = if ev_num(event, "pointerId") == self._pointers[0] {
    self._pointers[1]''', '''  let pointer_id = if ev_num(event, "pointerId") == self._pointers[0] {
    self._pointers[0]'''),
    ('map mouse y sign', 'map_controls.mbt', '''  _map_mouse.y = -((ev_num(event, "clientY") - ev_num(rect, "top")) /
    ev_num(rect, "height")) *
    2.0 +
    1.0
  _map_raycaster.set_from_camera(_map_mouse, controls.base.object)
  if''', '''  _map_mouse.y = ((ev_num(event, "clientY") - ev_num(rect, "top")) /
    ev_num(rect, "height")) *
    2.0 +
    1.0
  _map_raycaster.set_from_camera(_map_mouse, controls.base.object)
  if'''),
    ('trackball wheel line factor', 'trackball_controls.mbt', 'ev_num(event, "deltaY") * 0.01', 'ev_num(event, "deltaY") * 0.025'),
    ('trackball mouse-on-circle uses height', 'trackball_controls.mbt', '(self.screen.height + 2.0 * (self.screen.top - page_y)) / self.screen.width', '(self.screen.height + 2.0 * (self.screen.top - page_y)) / self.screen.height'),
    ('trackball roll ignores wrap', 'trackball_controls.mbt', 'angle -= 2.0 * js_pi', 'angle -= js_pi'),
    ('fly yaw sign', 'fly_controls.mbt', 'self._move_state.yaw_left = -(ev_num(event, "pageX") - left - half_width) /', 'self._move_state.yaw_left = (ev_num(event, "pageX") - left - half_width) /'),
    ('fly pointer cancel keeps back', 'fly_controls.mbt', '''    self._move_state.forward = 0.0
    self._move_state.back = 0.0
    self._update_movement_vector()''', '''    self._move_state.forward = 0.0
    self._update_movement_vector()'''),
    ('first person lat clamp 89', 'first_person_controls.mbt', 'js_max(-85.0, js_min(85.0, self._lat))', 'js_max(-89.0, js_min(89.0, self._lat))'),
    ('first person touch backward on 1 pointer', 'first_person_controls.mbt', 'self._pointer_backward = self._pointer_count >= 2', 'self._pointer_backward = self._pointer_count >= 1'),
    ('pointer lock clamp uses max', 'pointer_lock_controls.mbt', 'js_min(_pointer_lock_pi_2 - self.min_polar_angle, _pointer_lock_euler.x)', 'js_min(_pointer_lock_pi_2 - self.max_polar_angle, _pointer_lock_euler.x)'),
    ('drag rotate y sign', 'drag_controls.mbt', '-_drag_diff.y', '_drag_diff.y'),
    ('drag hoveroff cursor', 'drag_controls.mbt', '''        self.dispatch_event(drag_event("hoveroff", hovered))
        dom_set_style(dom_element, "cursor", "auto")
        _drag_hovered.val = None
      }
      if''', '''        self.dispatch_event(drag_event("hoveroff", hovered))
        dom_set_style(dom_element, "cursor", "default")
        _drag_hovered.val = None
      }
      if'''),
    ('transform local translate excludes XY', 'transform_controls.mbt', '''    if space == "local" && axis != "XYZ" {
      ignore(self._offset.apply_quaternion(self._world_quaternion_inv))''', '''    if space == "local" && axis != "XY" {
      ignore(self._offset.apply_quaternion(self._world_quaternion_inv))'''),
    ('transform axis setter fires on equal values', 'transform_controls.mbt', '''  if self.axis != value {
    self.axis = value''', '''  if true {
    self.axis = value'''),
    ('transform axis hide threshold 0.9', 'transform_controls.mbt', 'let axis_hide_threshold = 0.99', 'let axis_hide_threshold = 0.9'),
    ('transform plane XZ aligned to v1', 'transform_controls.mbt', '''        Some("XZ") => {
          ignore(_transform_align_vector.copy(_transform_v3))''', '''        Some("XZ") => {
          ignore(_transform_align_vector.copy(_transform_v1))'''),
    ('transform JS Math.round -> floor', 'transform_controls.mbt', 'js_round(value / snap) * snap', '(value / snap).floor() * snap'),
    ('transform scale snap zero fallback dropped', 'transform_controls.mbt', '''        if js_number_truthy(v) {
          v
        } else {
          snap
        }''', '''        v'''),
    ('arcball drag notches 10', 'arcball_controls.mbt', 'let screen_notches = 8.0', 'let screen_notches = 10.0'),
    ('arcball angular speed in ms', 'arcball_controls.mbt', 'let t = (t1 - t0) / 1000.0', 'let t = (t1 - t0) / 100.0'),
    ('arcball z-rotate angle sign', 'arcball_controls.mbt', '(self._start_finger_rotation - self._current_finger_rotation)', '(self._current_finger_rotation - self._start_finger_rotation)'),
    ('arcball focus easing', 'arcball_controls.mbt', '1.0 - js_pow(1.0 - t, 3.0)', '1.0 - js_pow(1.0 - t, 2.0)'),
    ('arcball pinch min distance ignores dpr', 'arcball_controls.mbt', 'min_distance * self._dev_px_ratio', 'min_distance'),
    ('arcball double tap interval strict', 'arcball_controls.mbt', 'movement <= self._pos_threshold', 'movement < 0.0'),
]

def run(cmd, cwd):
    return run_cmd(cmd, cwd=cwd, shell=True)

only = sys.argv[1:]
results = []
for i, (name, f, old, new) in enumerate(BUGS):
    if only and str(i) not in only:
        continue
    path = SRC + f
    orig = (REPO / path).read_text()
    if orig.count(old) != 1:
        results.append((name, 'NOT APPLIED (%d matches)' % orig.count(old)))
        print(results[-1], flush=True)
        continue
    with patched(path, old, new):
        if DRY_RUN:
            results.append((name, 'APPLIES (dry run)'))
        elif subprocess.run('moon build --target js', cwd=HERE, shell=True, capture_output=True).returncode != 0:
            results.append((name, 'BUILD FAILED'))
        else:
            out = run('node run.mjs --show 1', HERE)
            diffs = [l.split()[1].rstrip(':') for l in out.splitlines() if l.startswith('DIFF')]
            results.append((name, 'CAUGHT by ' + ','.join(diffs[:4]) + ('...' if len(diffs) > 4 else '') if diffs else 'MISSED'))
    print(i, results[-1], flush=True)
if not DRY_RUN:
    run('moon build --target js', HERE)
print(('applies' if DRY_RUN else 'caught') + ' %d / %d' % (sum(1 for _, r in results if r.startswith(('CAUGHT', 'APPLIES'))), len(results)))
