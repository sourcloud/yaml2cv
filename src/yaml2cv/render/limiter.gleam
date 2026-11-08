//// Caps the number of renders running at the same time (ADR 0009).
////
//// The limiter is a counting semaphore implemented as an actor. Callers
//// queue for a slot in FIFO order and give up after a wait time. A slot is
//// freed when the render returns, when it crashes, and when the calling
//// process dies (the actor monitors every caller).

import exception
import gleam/erlang/process.{type Monitor, type Pid, type Subject}
import gleam/list
import gleam/otp/actor
import gleam/otp/supervision
import gleam/result
import yaml2cv/render.{type RenderError, type Renderer, Overloaded, Renderer}

pub opaque type Limiter {
  Limiter(subject: Subject(Message))
}

/// Messages understood by the limiter actor.
pub opaque type Message {
  /// Asks for a slot; the actor sends `Nil` to `slot` once one is granted.
  Acquire(slot: Subject(Nil), caller: Pid)
  /// Gives up a held slot or leaves the queue.
  Leave(slot: Subject(Nil))
  /// Like `Leave`, but acknowledged, so the caller knows that any grant sent
  /// before it is already in its mailbox.
  Cancel(slot: Subject(Nil), done: Subject(Nil))
  CallerDown(process.Down)
}

type Holder {
  Holder(slot: Subject(Nil), monitor: Monitor)
}

type State {
  State(capacity: Int, active: List(Holder), waiting: List(Holder))
}

/// Starts a limiter allowing `capacity` renders at a time.
pub fn start(capacity: Int) -> Result(Limiter, actor.StartError) {
  builder(capacity)
  |> actor.start
  |> result.map(fn(started) { started.data })
}

/// A child specification that starts a limiter registered under `name`, for
/// use in a supervision tree. Callers reach it through `named(name)`, which
/// keeps working across restarts.
pub fn supervised(
  name: process.Name(Message),
  capacity capacity: Int,
) -> supervision.ChildSpecification(Limiter) {
  supervision.worker(fn() {
    builder(capacity)
    |> actor.named(name)
    |> actor.start
  })
}

/// The limiter registered under `name` by `supervised`.
pub fn named(name: process.Name(Message)) -> Limiter {
  Limiter(process.named_subject(name))
}

fn builder(capacity: Int) -> actor.Builder(State, Message, Limiter) {
  actor.new_with_initialiser(1000, fn(subject) {
    let selector =
      process.new_selector()
      |> process.select(subject)
      |> process.select_monitors(CallerDown)
    State(capacity:, active: [], waiting: [])
    |> actor.initialised
    |> actor.selecting(selector)
    |> actor.returning(Limiter(subject))
    |> Ok
  })
  |> actor.on_message(handle_message)
}

/// Wraps a renderer so that each render first waits up to `wait`
/// milliseconds for a free slot, failing with `Overloaded` otherwise.
pub fn limit(
  renderer: Renderer,
  with limiter: Limiter,
  wait wait: Int,
) -> Renderer {
  Renderer(
    render_pdf: fn(cv) {
      use <- with_slot(limiter, wait)
      renderer.render_pdf(cv)
    },
    render_svg_pages: fn(cv) {
      use <- with_slot(limiter, wait)
      renderer.render_svg_pages(cv)
    },
  )
}

/// Runs `task` while holding a slot.
fn with_slot(
  limiter: Limiter,
  wait: Int,
  task: fn() -> Result(a, RenderError),
) -> Result(a, RenderError) {
  let slot = process.new_subject()
  process.send(limiter.subject, Acquire(slot:, caller: process.self()))
  case process.receive(slot, wait) {
    Ok(Nil) -> {
      use <- exception.defer(fn() { process.send(limiter.subject, Leave(slot)) })
      task()
    }
    Error(Nil) -> {
      process.call(limiter.subject, 1000, Cancel(slot, _))
      // A slot granted just before the cancel is released by it; drop the
      // grant message so it does not linger in the mailbox.
      let _ = process.receive(slot, 0)
      Error(Overloaded)
    }
  }
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    Acquire(slot:, caller:) -> {
      let holder = Holder(slot:, monitor: process.monitor(caller))
      State(..state, waiting: list.append(state.waiting, [holder]))
      |> grant
      |> actor.continue
    }
    Leave(slot:) ->
      remove(state, fn(holder) { holder.slot == slot })
      |> grant
      |> actor.continue
    Cancel(slot:, done:) -> {
      let state = remove(state, fn(holder) { holder.slot == slot }) |> grant
      process.send(done, Nil)
      actor.continue(state)
    }
    CallerDown(process.ProcessDown(monitor:, ..)) ->
      remove(state, fn(holder) { holder.monitor == monitor })
      |> grant
      |> actor.continue
    CallerDown(process.PortDown(..)) -> actor.continue(state)
  }
}

/// Hands free slots to waiting callers, oldest first.
fn grant(state: State) -> State {
  case state.waiting, list.length(state.active) < state.capacity {
    [next, ..rest], True -> {
      process.send(next.slot, Nil)
      grant(State(..state, active: [next, ..state.active], waiting: rest))
    }
    _, _ -> state
  }
}

/// Removes the matching holder from the active and waiting lists and stops
/// monitoring its caller.
fn remove(state: State, matches: fn(Holder) -> Bool) -> State {
  let #(removed, active) = list.partition(state.active, matches)
  let #(removed_waiting, waiting) = list.partition(state.waiting, matches)
  list.each(list.append(removed, removed_waiting), fn(holder) {
    process.demonitor_process(holder.monitor)
  })
  State(..state, active:, waiting:)
}
