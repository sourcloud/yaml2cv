//// Entry point: loads the configuration and starts the supervision tree.

import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/otp/static_supervisor as supervisor
import mist
import wisp
import wisp/wisp_mist
import yaml2cv/config.{type Config}
import yaml2cv/render/limiter
import yaml2cv/render/typst
import yaml2cv/web/router.{Context}

pub fn main() -> Nil {
  wisp.configure_logger()
  case config.load() {
    Ok(config) -> {
      case start(config) {
        Ok(_) -> {
          wisp.log_info(
            "yaml2cv listening on "
            <> config.bind_address
            <> ":"
            <> int.to_string(config.port),
          )
          process.sleep_forever()
        }
        Error(_) -> {
          wisp.log_error("could not start yaml2cv")
          halt(1)
        }
      }
    }
    Error(errors) -> {
      list.each(errors, fn(error) {
        wisp.log_error("invalid configuration: " <> error)
      })
      halt(1)
    }
  }
}

/// Starts the render limiter and the HTTP server under one supervisor.
fn start(config: Config) {
  let limiter_name = process.new_name("yaml2cv_render_limiter")
  let renderer =
    typst.new(config.typst)
    |> limiter.limit(
      with: limiter.named(limiter_name),
      wait: config.render_queue_wait,
    )
  let context = Context(renderer:, max_body_bytes: config.max_body_bytes)
  // The app sets no cookies, so the signing key may change on every start.
  let handler =
    wisp_mist.handler(router.handle_request(_, context), wisp.random_string(64))

  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(limiter.supervised(
    limiter_name,
    capacity: config.render_concurrency,
  ))
  |> supervisor.add(
    mist.new(handler)
    |> mist.bind(config.bind_address)
    |> mist.port(config.port)
    |> mist.supervised,
  )
  |> supervisor.start
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
