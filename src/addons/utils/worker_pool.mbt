// Upstream examples/jsm/utils/WorkerPool.js. Workers are JS `Worker` objects; messages
// and transfer lists are JS values. `post_message` returns a JS `Promise`, as upstream.

///|
/// A JS `Worker`.
#external
pub type Worker

///|
extern "js" fn worker_pool_new_worker(url : String) -> Worker = "(url) => new Worker(url)"

///|
extern "js" fn worker_pool_post_message(
  worker : Worker,
  msg : JsValue,
  transfer : JsValue,
) -> Unit = "(w, m, t) => w.postMessage(m, t)"

///|
extern "js" fn worker_pool_add_event_listener(
  worker : Worker,
  type_ : String,
  listener : (JsValue) -> Unit,
) -> Unit = "(w, t, f) => w.addEventListener(t, f)"

///|
extern "js" fn worker_pool_terminate(worker : Worker) -> Unit = "(w) => w.terminate()"

///|
/// `new Worker( url )`.
pub fn Worker::new(url : String) -> Worker {
  worker_pool_new_worker(url)
}

///|
/// `worker.postMessage( msg, transfer )`.
pub fn Worker::post_message(
  self : Worker,
  msg : JsValue,
  transfer : Array[JsValue],
) -> Unit {
  worker_pool_post_message(self, msg, JsValue::of(transfer))
}

///|
/// `worker.addEventListener( type, listener )`; the listener gets the event.
pub fn Worker::add_event_listener(
  self : Worker,
  type_ : String,
  listener : (JsValue) -> Unit,
) -> Unit {
  worker_pool_add_event_listener(self, type_, listener)
}

///|
/// `worker.terminate()`.
pub fn Worker::terminate(self : Worker) -> Unit {
  worker_pool_terminate(self)
}

///|
/// A queued message: `{ resolve, msg, transfer }`.
pub(all) struct WorkerPoolMessage {
  resolve : (JsValue) -> Unit
  msg : JsValue
  transfer : Array[JsValue]
}

///|
/// A simple pool for managing Web Workers.
pub(all) struct WorkerPool {
  mut pool : Int32
  queue : Array[WorkerPoolMessage]
  workers : Array[Worker?]
  workers_resolve : Array[((JsValue) -> Unit)?]
  mut worker_status : Int32
  mut worker_creator : (() -> Worker)?
}

///|
pub fn WorkerPool::new(pool~ : Int32 = 4) -> WorkerPool {
  {
    pool,
    queue: [],
    workers: [],
    workers_resolve: [],
    worker_status: 0,
    worker_creator: None,
  }
}

///|
/// `array[ i ]`, `undefined` past the end.
fn[T] worker_pool_at(array : Array[T?], i : Int32) -> T? {
  if i >= 0 && i < array.length() {
    array[i]
  } else {
    None
  }
}

///|
/// `array[ i ] = value`, growing the array with holes as JS does.
fn[T] worker_pool_set_at(array : Array[T?], i : Int32, value : T) -> Unit {
  while array.length() <= i {
    array.push(None)
  }
  array[i] = Some(value)
}

///|
fn WorkerPool::init_worker(self : WorkerPool, worker_id : Int32) -> Unit {
  if worker_pool_at(self.workers, worker_id) is None {
    let worker = self.worker_creator.unwrap()()
    worker.add_event_listener("message", msg => self.on_message(worker_id, msg))
    worker_pool_set_at(self.workers, worker_id, worker)
  }
}

///|
fn WorkerPool::get_idle_worker(self : WorkerPool) -> Int32 {
  for i in 0..<self.pool {
    if (self.worker_status & (1 << i)) == 0 {
      return i
    }
  }
  -1
}

///|
fn WorkerPool::on_message(
  self : WorkerPool,
  worker_id : Int32,
  msg : JsValue,
) -> Unit {
  let resolve = worker_pool_at(self.workers_resolve, worker_id)
  if resolve is Some(resolve) {
    resolve(msg)
  }
  if self.queue.length() > 0 {
    let { resolve, msg, transfer, } = self.queue.remove(0)
    worker_pool_set_at(self.workers_resolve, worker_id, resolve)
    worker_pool_at(self.workers, worker_id).unwrap().post_message(msg, transfer)
  } else {
    self.worker_status = self.worker_status ^ (1 << worker_id)
  }
}

///|
/// Sets a function that is responsible for creating Workers.
pub fn WorkerPool::set_worker_creator(
  self : WorkerPool,
  worker_creator : () -> Worker,
) -> Unit {
  self.worker_creator = Some(worker_creator)
}

///|
/// Sets the Worker limit.
pub fn WorkerPool::set_worker_limit(self : WorkerPool, pool : Int32) -> Unit {
  self.pool = pool
}

///|
/// Posts a message to an idle Worker, or queues it; resolves with the reply event.
pub fn WorkerPool::post_message(
  self : WorkerPool,
  msg : JsValue,
  transfer : Array[JsValue],
) -> AddonPromise {
  AddonPromise::new((resolve, _) => {
    let worker_id = self.get_idle_worker()
    if worker_id != -1 {
      self.init_worker(worker_id)
      self.worker_status = self.worker_status | (1 << worker_id)
      worker_pool_set_at(self.workers_resolve, worker_id, resolve)
      worker_pool_at(self.workers, worker_id)
      .unwrap()
      .post_message(msg, transfer)
    } else {
      self.queue.push({ resolve, msg, transfer, })
    }
  })
}

///|
/// Terminates all Workers of this pool.
pub fn WorkerPool::dispose(self : WorkerPool) -> Unit {
  for worker in self.workers {
    if worker is Some(worker) {
      worker.terminate()
    }
  }
  self.workers_resolve.clear()
  self.workers.clear()
  self.queue.clear()
  self.worker_status = 0
}
