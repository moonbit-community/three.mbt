// Upstream src/core/Clock.js. Deprecated upstream in favour of `Timer`, but public.

///|
pub fn Clock::new(auto_start~ : Bool = true) -> Clock {
  warn(
    "Clock: This module has been deprecated. Please use THREE.Timer instead.",
  )
  { auto_start, start_time: 0, old_time: 0, elapsed_time: 0, running: false, }
}

///|
pub fn Clock::start(self : Clock) -> Unit {
  self.start_time = utils_performance_now()
  self.old_time = self.start_time
  self.elapsed_time = 0
  self.running = true
}

///|
pub fn Clock::stop(self : Clock) -> Unit {
  ignore(self.get_elapsed_time())
  self.running = false
  self.auto_start = false
}

///|
pub fn Clock::get_elapsed_time(self : Clock) -> Double {
  ignore(self.get_delta())
  self.elapsed_time
}

///|
pub fn Clock::get_delta(self : Clock) -> Double {
  let mut diff = 0.0
  if self.auto_start && !self.running {
    self.start()
    return 0
  }
  if self.running {
    let new_time = utils_performance_now()
    diff = (new_time - self.old_time) / 1000.0
    self.old_time = new_time
    self.elapsed_time += diff
  }
  diff
}
