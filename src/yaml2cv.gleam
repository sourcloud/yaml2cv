//// Entry point: without arguments, or with `serve`, loads the
//// configuration and starts the supervision tree; otherwise runs the
//// command line (ADR 0048).

import argv
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
import yaml2cv/build.{Build}
import yaml2cv/cli
import yaml2cv/cli/arguments.{Serve}
import yaml2cv/config.{type Config}
import yaml2cv/notices.{type Component}
import yaml2cv/observe/admin
import yaml2cv/observe/document
import yaml2cv/observe/heartbeat
import yaml2cv/observe/network
import yaml2cv/observe/system
import yaml2cv/render/limiter
import yaml2cv/render/typst
import yaml2cv/web/router.{Context}

pub fn main() -> Nil {
  case arguments.parse(argv.load().arguments) {
    Ok(Serve) -> serve()
    Ok(command) -> halt(cli.run(command, renderer, stdio()))
    Error(message) -> halt(cli.usage_error(message, stdio()))
  }
}

/// A Typst renderer configured from the environment, without the limiter:
/// the command line renders one CV at a time.
fn renderer() {
  config.load()
  |> result.map(fn(config) { typst.new(config.typst) })
}

fn stdio() -> cli.Io {
  cli.Io(
    read_file: fn(path) {
      simplifile.read_bits(path) |> result.map_error(simplifile.describe_error)
    },
    read_stdin:,
    write_file: fn(path, bytes) {
      simplifile.write_bits(path, bytes)
      |> result.map_error(simplifile.describe_error)
    },
    write_stdout:,
    write_stderr:,
  )
}

@external(erlang, "yaml2cv_stdio_ffi", "read_stdin")
fn read_stdin() -> Result(BitArray, String)

@external(erlang, "yaml2cv_stdio_ffi", "write_stdout")
fn write_stdout(bytes: BitArray) -> Nil

@external(erlang, "yaml2cv_stdio_ffi", "write_stderr")
fn write_stderr(text: String) -> Nil

fn serve() -> Nil {
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
      list.each(config.warnings(config), wisp.log_warning)
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
  use notices <- result.try(
    notices.load(config.notices_path)
    |> result.map_error(fn(error) {
      ["could not read third-party notices: " <> error]
    }),
  )
  use _ <- result.try(
    start(config, example, notices)
    |> result.replace_error(["could not start the supervision tree"]),
  )
  Ok(config)
}

/// Starts the render limiter, the public and admin HTTP servers and, when a
/// collector is configured, the heartbeat under one supervisor.
fn start(config: Config, example: String, notices: List(Component)) {
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
      build: Build(
        version: config.version,
        revision: build.revision(config.phone_home.metadata.git_revision),
      ),
      example_cv: example,
      notices:,
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
