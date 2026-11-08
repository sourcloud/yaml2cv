//// Entry point: loads the configuration and starts the supervision tree.

import gleam/bit_array
import gleam/erlang/process
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/static_supervisor as supervisor
import gleam/result
import mist
import simplifile
import wisp
import wisp/wisp_mist
import yaml2cv/config.{type Config}
import yaml2cv/observe/admin
import yaml2cv/observe/document
import yaml2cv/observe/heartbeat
import yaml2cv/observe/network
import yaml2cv/observe/system
import yaml2cv/render/limiter
import yaml2cv/render/typst
import yaml2cv/web/router.{Context}

pub fn main() -> Nil {
  wisp.configure_logger()
  case boot() {
    Ok(config) -> {
      wisp.log_info(
        "yaml2cv listening on "
        <> config.bind_address
        <> ":"
        <> int.to_string(config.port),
      )
      wisp.log_info(
        "admin endpoint on "
        <> config.admin.bind_address
        <> ":"
        <> int.to_string(config.admin.port),
      )
      case config.phone_home.target {
        Some(target) ->
          wisp.log_info(
            "sending heartbeats to "
            <> target.host
            <> ":"
            <> int.to_string(target.port),
          )
        None -> Nil
      }
      process.sleep_forever()
    }
    Error(errors) -> {
      list.each(errors, wisp.log_error)
      halt(1)
    }
  }
}

fn boot() -> Result(Config, List(String)) {
  use config <- result.try(
    config.load()
    |> result.map_error(
      list.map(_, fn(error) { "invalid configuration: " <> error }),
    ),
  )
  use example <- result.try(
    simplifile.read(config.example_path)
    |> result.map_error(fn(error) {
      ["could not read example CV: " <> simplifile.describe_error(error)]
    }),
  )
  use _ <- result.try(
    start(config, example)
    |> result.replace_error(["could not start the supervision tree"]),
  )
  Ok(config)
}

/// Starts the render limiter, the public and admin HTTP servers and, when a
/// collector is configured, the heartbeat under one supervisor.
fn start(config: Config, example: String) {
  let limiter_name = process.new_name("yaml2cv_render_limiter")
  let renderer =
    typst.new(config.typst)
    |> limiter.limit(
      with: limiter.named(limiter_name),
      wait: config.render_queue_wait,
    )
  let context =
    Context(
      renderer:,
      max_body_bytes: config.max_body_bytes,
      static_directory: config.static_directory,
      example_cv: example,
    )
  // The app sets no cookies, so the signing key may change on every start.
  let handler =
    wisp_mist.handler(router.handle_request(_, context), wisp.random_string(64))

  let observe = fn() {
    document.build(
      config,
      interfaces: network.reachable(
        network.interfaces(),
        bind: config.bind_address,
      ),
      status: system.sample(config.typst.work_directory),
    )
  }
  let admin_handler =
    wisp_mist.handler(admin.handle_request(_, observe), wisp.random_string(64))

  let tree =
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
    |> supervisor.add(
      mist.new(admin_handler)
      |> mist.bind(config.admin.bind_address)
      |> mist.port(config.admin.port)
      |> mist.supervised,
    )
  case config.phone_home.target {
    Some(target) ->
      supervisor.add(
        tree,
        heartbeat.supervised(
          interval: config.phone_home.interval,
          payload: fn() {
            observe()
            |> document.heartbeat_json
            |> json.to_string
            |> bit_array.from_string
          },
          send: heartbeat.send_udp(target.host, target.port, _),
        ),
      )
    None -> tree
  }
  |> supervisor.start
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
