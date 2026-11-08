import exception
import gleam/erlang/process.{type Subject}
import gleam/otp/static_supervisor
import yaml2cv/cv.{type Cv}
import yaml2cv/cv/decode
import yaml2cv/render.{type RenderError, type Renderer, Overloaded, Renderer}
import yaml2cv/render/limiter

fn cv() -> Cv {
  let assert Ok(cv) =
    decode.from_yaml("schema_version: 1\nperson: {name: X}\nsections: []")
  cv
}

/// A renderer whose PDF output comes from `render`; it has no PNG pages.
fn pdf_renderer(render: fn(Cv) -> Result(BitArray, RenderError)) -> Renderer {
  Renderer(render_pdf: render, render_png_pages: fn(_) { Ok([]) })
}

/// A renderer that announces each render by sending a gate to `started` and
/// then blocks until the test opens the gate.
fn gated_renderer(started: Subject(Subject(Nil))) -> Renderer {
  pdf_renderer(fn(_cv) {
    let gate = process.new_subject()
    process.send(started, gate)
    let assert Ok(Nil) = process.receive(gate, 5000)
    Ok(<<"pdf">>)
  })
}

fn new_limited(renderer: Renderer, capacity: Int, wait: Int) -> Renderer {
  let assert Ok(limiter) = limiter.start(capacity)
  limiter.limit(renderer, with: limiter, wait:)
}

/// Starts a render in a separate process and returns the gate that blocks it.
fn start_blocked_render(
  renderer: Renderer,
  started: Subject(Subject(Nil)),
) -> Subject(Nil) {
  process.spawn(fn() { renderer.render_pdf(cv()) })
  let assert Ok(gate) = process.receive(started, 1000)
  gate
}

/// Runs a render in a separate process; its result arrives on the subject.
fn render_in_background(
  renderer: Renderer,
) -> Subject(Result(BitArray, render.RenderError)) {
  let result = process.new_subject()
  process.spawn(fn() { process.send(result, renderer.render_pdf(cv())) })
  result
}

pub fn passes_results_through_test() {
  let renderer = new_limited(pdf_renderer(fn(_) { Ok(<<"pdf">>) }), 1, 100)
  assert renderer.render_pdf(cv()) == Ok(<<"pdf">>)
  assert renderer.render_pdf(cv()) == Ok(<<"pdf">>)
}

pub fn rejects_render_when_no_slot_frees_up_in_time_test() {
  let started = process.new_subject()
  let renderer = new_limited(gated_renderer(started), 1, 50)
  let gate = start_blocked_render(renderer, started)

  assert renderer.render_pdf(cv()) == Error(Overloaded)

  process.send(gate, Nil)
}

pub fn queued_render_runs_once_a_slot_frees_up_test() {
  let started = process.new_subject()
  let renderer = new_limited(gated_renderer(started), 1, 5000)
  let first = start_blocked_render(renderer, started)
  let finished = render_in_background(renderer)

  assert process.receive(started, 50) == Error(Nil)
  process.send(first, Nil)
  let assert Ok(second) = process.receive(started, 1000)
  process.send(second, Nil)
  assert process.receive(finished, 1000) == Ok(Ok(<<"pdf">>))
}

pub fn allows_renders_up_to_capacity_in_parallel_test() {
  let started = process.new_subject()
  let renderer = new_limited(gated_renderer(started), 2, 50)
  let first = start_blocked_render(renderer, started)
  let second = start_blocked_render(renderer, started)

  assert renderer.render_pdf(cv()) == Error(Overloaded)

  process.send(first, Nil)
  process.send(second, Nil)
}

pub fn frees_slot_when_holder_process_dies_test() {
  let started = process.new_subject()
  let renderer = new_limited(gated_renderer(started), 1, 1000)
  let pid = process.spawn_unlinked(fn() { renderer.render_pdf(cv()) })
  let assert Ok(_gate) = process.receive(started, 1000)

  process.kill(pid)

  let result = render_in_background(renderer)
  let assert Ok(gate) = process.receive(started, 1000)
  process.send(gate, Nil)
  assert process.receive(result, 1000) == Ok(Ok(<<"pdf">>))
}

pub fn frees_slot_when_render_crashes_test() {
  let renderer = new_limited(pdf_renderer(fn(_) { panic as "boom" }), 1, 100)

  let assert Error(_) = exception.rescue(fn() { renderer.render_pdf(cv()) })
  let assert Error(_) = exception.rescue(fn() { renderer.render_pdf(cv()) })
}

pub fn timed_out_waiter_does_not_hold_a_slot_test() {
  let started = process.new_subject()
  let renderer = new_limited(gated_renderer(started), 1, 20)
  let gate = start_blocked_render(renderer, started)
  assert renderer.render_pdf(cv()) == Error(Overloaded)
  process.send(gate, Nil)

  let result = render_in_background(renderer)
  let assert Ok(gate) = process.receive(started, 1000)
  process.send(gate, Nil)
  assert process.receive(result, 1000) == Ok(Ok(<<"pdf">>))
}

pub fn works_as_named_supervised_child_test() {
  let name = process.new_name("limiter_test")
  let assert Ok(_) =
    static_supervisor.new(static_supervisor.OneForOne)
    |> static_supervisor.add(limiter.supervised(name, capacity: 1))
    |> static_supervisor.start

  let renderer =
    pdf_renderer(fn(_) { Ok(<<"pdf">>) })
    |> limiter.limit(with: limiter.named(name), wait: 100)
  assert renderer.render_pdf(cv()) == Ok(<<"pdf">>)
}

pub fn limits_png_renders_too_test() {
  let started = process.new_subject()
  let gated = gated_renderer(started)
  let renderer =
    new_limited(
      Renderer(..gated, render_png_pages: fn(_) { Ok([<<"png">>]) }),
      1,
      50,
    )
  let gate = start_blocked_render(renderer, started)

  assert renderer.render_png_pages(cv()) == Error(Overloaded)

  process.send(gate, Nil)
}
