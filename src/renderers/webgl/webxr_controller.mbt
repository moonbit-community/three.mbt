// Upstream src/renderers/webxr/WebXRController.js.
//
// The groups are core `Group`s. Upstream adds ad-hoc properties to them
// (`linearVelocity`, `joints`, `inputState`, `jointRadius`, ...); those live in the side
// tables below, read with `xr_controller_space`, `xr_hand_space` and `xr_joint_radius`.

///|
/// The ad-hoc state upstream puts on a target ray or grip `Group`.
pub(all) struct XRControllerSpace {
  mut has_linear_velocity : Bool
  linear_velocity : @math.Vector3
  mut has_angular_velocity : Bool
  angular_velocity : @math.Vector3
  /// `grip.eventsEnabled`; `false` (upstream `undefined`) on the target ray space.
  mut events_enabled : Bool
}

///|
/// `hand.inputState`.
pub(all) struct XRHandInputState {
  mut pinching : Bool
}

///|
/// The ad-hoc state upstream puts on a hand `Group`: `joints`, keyed by joint name in
/// insertion order, and `inputState`.
pub(all) struct XRHandSpace {
  joints : Map[String, @core.Object3D]
  input_state : XRHandInputState
}

///|
let _webxr_controller_spaces : WeakMap[@core.Object3D, XRControllerSpace] = WeakMap::new()

///|
let _webxr_controller_hands : WeakMap[@core.Object3D, XRHandSpace] = WeakMap::new()

///|
let _webxr_controller_joint_radius : WeakMap[@core.Object3D, Double] = WeakMap::new()

///|
/// The velocity state of a group from `get_controller` / `get_controller_grip`.
pub fn xr_controller_space(group : @core.Object3D) -> XRControllerSpace? {
  _webxr_controller_spaces.get(group)
}

///|
/// The `joints` and `inputState` of a group from `get_hand`.
pub fn xr_hand_space(group : @core.Object3D) -> XRHandSpace? {
  _webxr_controller_hands.get(group)
}

///|
/// `joint.jointRadius`; `None` until a pose was seen (upstream `undefined`).
pub fn xr_joint_radius(joint : @core.Object3D) -> Double? {
  _webxr_controller_joint_radius.get(joint)
}

///|
let _webxr_controller_move_event : @core.Event = @core.Event::new("move")

///|
/// `WebXRController`: the target ray, grip and hand spaces of one input source.
pub struct WebXRController {
  mut _target_ray : @core.Object3D?
  mut _grip : @core.Object3D?
  mut _hand : @core.Object3D?
}

///|
/// `new WebXRController()`.
pub fn WebXRController::new() -> WebXRController {
  { _target_ray: None, _grip: None, _hand: None, }
}

///|
/// `controller.getHandSpace()`.
pub fn WebXRController::get_hand_space(
  self : WebXRController,
) -> @core.Object3D {
  match self._hand {
    Some(hand) => hand
    None => {
      let hand = @core.Group::new()
      hand.matrix_auto_update = false
      hand.visible = false
      _webxr_controller_hands.set(hand, {
        joints: Map([]),
        input_state: { pinching: false, },
      })
      self._hand = Some(hand)
      hand
    }
  }
}

///|
fn webxr_controller_new_space(events_enabled : Bool?) -> @core.Object3D {
  let group = @core.Group::new()
  group.matrix_auto_update = false
  group.visible = false
  _webxr_controller_spaces.set(group, {
    has_linear_velocity: false,
    linear_velocity: @math.Vector3::new(0.0, 0.0, 0.0),
    has_angular_velocity: false,
    angular_velocity: @math.Vector3::new(0.0, 0.0, 0.0),
    events_enabled: events_enabled.unwrap_or(false),
  })
  group
}

///|
/// `controller.getTargetRaySpace()`.
pub fn WebXRController::get_target_ray_space(
  self : WebXRController,
) -> @core.Object3D {
  match self._target_ray {
    Some(target_ray) => target_ray
    None => {
      let target_ray = webxr_controller_new_space(None)
      self._target_ray = Some(target_ray)
      target_ray
    }
  }
}

///|
/// `controller.getGripSpace()`.
pub fn WebXRController::get_grip_space(
  self : WebXRController,
) -> @core.Object3D {
  match self._grip {
    Some(grip) => grip
    None => {
      let grip = webxr_controller_new_space(Some(false))
      self._grip = Some(grip)
      grip
    }
  }
}

///|
/// `controller.dispatchEvent( event )`: to every space that exists.
pub fn WebXRController::dispatch_event(
  self : WebXRController,
  event : @core.Event,
) -> WebXRController {
  if self._target_ray is Some(target_ray) {
    target_ray.dispatch_event(event)
  }
  if self._grip is Some(grip) {
    grip.dispatch_event(event)
  }
  if self._hand is Some(hand) {
    hand.dispatch_event(event)
  }
  self
}

///|
/// `controller.connect( inputSource )`.
pub fn WebXRController::connect(
  self : WebXRController,
  input_source : XRInputSource,
) -> WebXRController {
  if input_source.hand() is Some(input_hand) {
    if self._hand is Some(hand) {
      for inputjoint in input_hand.values() {
        // Initialize hand with joints when connected
        ignore(self._get_hand_joint(hand, inputjoint))
      }
    }
  }
  ignore(
    self.dispatch_event(
      @core.Event::new("connected", data=@core.JsValue::of(input_source)),
    ),
  )
  self
}

///|
/// `controller.disconnect( inputSource )`; `None` is upstream's `undefined`, passed when
/// a session ends on a controller that never had an input source.
pub fn WebXRController::disconnect(
  self : WebXRController,
  input_source : XRInputSource?,
) -> WebXRController {
  let event = match input_source {
    Some(source) =>
      @core.Event::new("disconnected", data=@core.JsValue::of(source))
    None => @core.Event::new("disconnected")
  }
  ignore(self.dispatch_event(event))
  if self._target_ray is Some(target_ray) {
    target_ray.visible = false
  }
  if self._grip is Some(grip) {
    grip.visible = false
  }
  if self._hand is Some(hand) {
    hand.visible = false
  }
  self
}

///|
fn webxr_controller_space_of(group : @core.Object3D) -> XRControllerSpace {
  match _webxr_controller_spaces.get(group) {
    Some(space) => space
    None => abort("WebXRController: group without controller state")
  }
}

///|
/// Copies a pose's transform and velocities into a target ray or grip group.
fn webxr_controller_apply_pose(group : @core.Object3D, pose : XRPose) -> Unit {
  ignore(group.matrix.from_array(pose.transform().matrix()))
  ignore(group.matrix.decompose(group.position, group.quaternion, group.scale))
  group.matrix_world_needs_update = true
  let space = webxr_controller_space_of(group)
  match pose.linear_velocity() {
    Some(velocity) => {
      space.has_linear_velocity = true
      ignore(
        space.linear_velocity.set(velocity.x(), velocity.y(), velocity.z()),
      )
    }
    None => space.has_linear_velocity = false
  }
  match pose.angular_velocity() {
    Some(velocity) => {
      space.has_angular_velocity = true
      ignore(
        space.angular_velocity.set(velocity.x(), velocity.y(), velocity.z()),
      )
    }
    None => space.has_angular_velocity = false
  }
}

///|
/// `controller.update( inputSource, frame, referenceSpace )`; `None` input source is
/// upstream's falsy one, which only hides the spaces.
pub fn WebXRController::update(
  self : WebXRController,
  input_source : XRInputSource?,
  frame : XRFrame,
  reference_space : XRReferenceSpace?,
) -> WebXRController {
  let mut input_pose : XRPose? = None
  let mut grip_pose : XRPose? = None
  let mut hand_pose = false
  let target_ray = self._target_ray
  let grip = self._grip
  let hand = self._hand
  if input_source is Some(input_source) &&
    frame.session().visibility_state() != "visible-blurred" {
    match (hand, input_source.hand()) {
      (Some(hand), Some(input_hand)) => {
        hand_pose = true
        for inputjoint in input_hand.values() {
          // Update the joints groups with the XRJoint poses
          let joint_pose = frame.get_joint_pose(inputjoint, reference_space)

          // The transform of this joint will be updated with the joint pose on each frame
          let joint = self._get_hand_joint(hand, inputjoint)
          if joint_pose is Some(joint_pose) {
            ignore(joint.matrix.from_array(joint_pose.transform().matrix()))
            ignore(
              joint.matrix.decompose(
                joint.position,
                joint.quaternion,
                joint.scale,
              ),
            )
            joint.matrix_world_needs_update = true
            _webxr_controller_joint_radius.set(joint, joint_pose.radius())
          }
          joint.visible = joint_pose is Some(_)
        }

        // Custom events

        // Check pinchz
        let hand_space = webxr_controller_hand_of(hand)
        let index_tip = webxr_controller_joint(hand_space, "index-finger-tip")
        let thumb_tip = webxr_controller_joint(hand_space, "thumb-tip")
        let distance = index_tip.position.distance_to(thumb_tip.position)
        let distance_to_pinch = 0.02
        let threshold = 0.005
        if hand_space.input_state.pinching &&
          distance > distance_to_pinch + threshold {
          hand_space.input_state.pinching = false
          ignore(
            self.dispatch_event(
              @core.Event::new(
                "pinchend",
                data=@core.JsValue::of(input_source.handedness()),
              ),
            ),
          )
        } else if !hand_space.input_state.pinching &&
          distance <= distance_to_pinch - threshold {
          hand_space.input_state.pinching = true
          ignore(
            self.dispatch_event(
              @core.Event::new(
                "pinchstart",
                data=@core.JsValue::of(input_source.handedness()),
              ),
            ),
          )
        }
      }
      _ =>
        if grip is Some(grip) && input_source.grip_space() is Some(grip_space) {
          grip_pose = frame.get_pose(grip_space, reference_space)
          if grip_pose is Some(pose) {
            webxr_controller_apply_pose(grip, pose)

            // grip update event if enabled
            if webxr_controller_space_of(grip).events_enabled {
              grip.dispatch_event(
                @core.Event::new(
                  "gripUpdated",
                  data=@core.JsValue::of(input_source),
                ),
              )
            }
          }
        }
    }
    if target_ray is Some(target_ray) {
      input_pose = frame.get_pose(
        input_source.target_ray_space(),
        reference_space,
      )

      // Some runtimes (namely Vive Cosmos with Vive OpenXR Runtime) have only grip space and ray space is equal to it
      if input_pose is None && grip_pose is Some(_) {
        input_pose = grip_pose
      }
      if input_pose is Some(pose) {
        webxr_controller_apply_pose(target_ray, pose)
        ignore(self.dispatch_event(_webxr_controller_move_event))
      }
    }
  }
  if target_ray is Some(target_ray) {
    target_ray.visible = input_pose is Some(_)
  }
  if grip is Some(grip) {
    grip.visible = grip_pose is Some(_)
  }
  if hand is Some(hand) {
    hand.visible = hand_pose
  }
  self
}

///|
fn webxr_controller_hand_of(hand : @core.Object3D) -> XRHandSpace {
  match _webxr_controller_hands.get(hand) {
    Some(space) => space
    None => abort("WebXRController: hand without joints")
  }
}

///|
/// `hand.joints[ name ]`; upstream throws reading `position` of a missing joint.
fn webxr_controller_joint(hand : XRHandSpace, name : String) -> @core.Object3D {
  match hand.joints.get(name) {
    Some(joint) => joint
    None => abort("WebXRController: hand has no joint " + name)
  }
}

///|
/// `controller._getHandJoint( hand, inputjoint )`.
fn WebXRController::_get_hand_joint(
  _self : WebXRController,
  hand : @core.Object3D,
  inputjoint : XRJointSpace,
) -> @core.Object3D {
  let hand_space = webxr_controller_hand_of(hand)
  let name = inputjoint.joint_name()
  match hand_space.joints.get(name) {
    Some(joint) => joint
    None => {
      let joint = @core.Group::new()
      joint.matrix_auto_update = false
      joint.visible = false
      hand_space.joints[name] = joint
      ignore(hand.add(joint))
      joint
    }
  }
}
