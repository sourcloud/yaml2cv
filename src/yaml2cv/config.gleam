//// Application configuration from environment variables (ADR 0010).

import envoy
import gleam/dict.{type Dict}
import gleam/erlang/application
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import yaml2cv/render/typst

pub type Config {
  Config(
    port: Int,
    bind_address: String,
    max_body_bytes: Int,
    /// Number of renders allowed to run at the same time.
    render_concurrency: Int,
    /// Milliseconds a request waits for a free render slot.
    render_queue_wait: Int,
    /// Directory served under `/static`.
    static_directory: String,
    /// CV preloaded into the editor.
    example_path: String,
    typst: typst.Config,
    /// The yaml2cv release, from the OTP application.
    version: String,
    /// The listener for operational endpoints (ADR 0020).
    admin: Admin,
    phone_home: PhoneHome,
  )
}

/// Where the admin listener accepts connections.
pub type Admin {
  Admin(bind_address: String, port: Int)
}

/// Observability settings (ADR 0020).
pub type PhoneHome {
  PhoneHome(
    /// Collector receiving UDP heartbeats; none disables them.
    target: Option(Target),
    /// Milliseconds between heartbeats.
    interval: Int,
    /// Milliseconds without a heartbeat after which an instance is missing.
    mia_interval: Int,
    /// Components this instance depends on.
    requires: List(String),
    metadata: Metadata,
  )
}

pub type Target {
  Target(host: String, port: Int)
}

/// Build and deployment details; `None` when not provided.
pub type Metadata {
  Metadata(
    git_revision: Option(String),
    build_date: Option(String),
    deployed_from: Option(String),
    deployed_by: Option(String),
    deployed_on: Option(String),
  )
}

/// Reads the configuration from the process environment.
pub fn load() -> Result(Config, List(String)) {
  case application.priv_directory("yaml2cv"), version() {
    Ok(priv), Ok(version) ->
      parse(
        envoy.all(),
        schedulers: schedulers_online(),
        priv_directory: priv,
        version:,
      )
    Error(Nil), _ -> Error(["could not locate the priv directory of yaml2cv"])
    _, Error(Nil) -> Error(["could not read the version of yaml2cv"])
  }
}

/// Builds a configuration from environment variables, reporting every
/// invalid variable. `schedulers` sets the default render concurrency;
/// themes, static files and examples are found in `priv_directory`;
/// `version` is the yaml2cv release named in generated PDFs.
pub fn parse(
  env: Dict(String, String),
  schedulers schedulers: Int,
  priv_directory priv_directory: String,
  version version: String,
) -> Result(Config, List(String)) {
  let tmp = case dict.get(env, "TMPDIR") {
    Ok(dir) if dir != "" -> trim_trailing_slash(dir)
    _ -> "/tmp"
  }
  let #(port, errors) = port_number(env, "PORT", 8000, [])
  let #(bind_address, errors) = text(env, "BIND_ADDRESS", "0.0.0.0", errors)
  let #(max_body_bytes, errors) =
    positive(env, "MAX_BODY_BYTES", 262_144, errors)
  let #(timeout, errors) = positive(env, "RENDER_TIMEOUT_MS", 10_000, errors)
  let #(render_concurrency, errors) =
    positive(env, "RENDER_CONCURRENCY", schedulers, errors)
  let #(render_queue_wait, errors) =
    positive(env, "RENDER_QUEUE_WAIT_MS", 5000, errors)
  let #(executable, errors) = text(env, "TYPST_PATH", "typst", errors)
  let #(work_directory, errors) =
    text(env, "WORK_DIR", tmp <> "/yaml2cv", errors)
  let #(admin_bind_address, errors) =
    text(env, "ADMIN_BIND_ADDRESS", "127.0.0.1", errors)
  let #(admin_port, errors) = port_number(env, "ADMIN_PORT", 9000, errors)
  let errors = case admin_port == port {
    True -> ["ADMIN_PORT must differ from PORT", ..errors]
    False -> errors
  }
  let #(target, errors) =
    read(env, "PHONE_HOME_TARGET", None, errors, fn(value) {
      target(value)
      |> result.map(Some)
      |> result.replace_error(
        "PHONE_HOME_TARGET must be host:port, got " <> string.inspect(value),
      )
    })
  let #(interval, errors) =
    positive(env, "HEARTBEAT_INTERVAL_MS", 10_000, errors)
  let #(mia_interval, errors) =
    positive(env, "HEARTBEAT_MIA_MS", 3 * interval, errors)
  let errors = case mia_interval > interval {
    True -> errors
    False -> [
      "HEARTBEAT_MIA_MS must be greater than HEARTBEAT_INTERVAL_MS",
      ..errors
    ]
  }
  let requires =
    dict.get(env, "REQUIRES")
    |> result.unwrap("")
    |> string.split(",")
    |> list.map(string.trim)
    |> list.filter(fn(name) { name != "" })
  let metadata =
    Metadata(
      git_revision: optional(env, "GIT_REVISION"),
      build_date: optional(env, "BUILD_DATE"),
      deployed_from: optional(env, "DEPLOYED_FROM"),
      deployed_by: optional(env, "DEPLOYED_BY"),
      deployed_on: optional(env, "DEPLOYED_ON"),
    )

  case errors {
    [] ->
      Ok(Config(
        port:,
        bind_address:,
        max_body_bytes:,
        render_concurrency:,
        render_queue_wait:,
        static_directory: priv_directory <> "/static",
        example_path: priv_directory <> "/examples/example.yaml",
        typst: typst.Config(
          executable:,
          themes_directory: priv_directory <> "/themes",
          work_directory:,
          timeout:,
          generator: "Generated with yaml2cv "
            <> version
            <> " (https://github.com/sourcloud/yaml2cv)",
        ),
        version:,
        admin: Admin(bind_address: admin_bind_address, port: admin_port),
        phone_home: PhoneHome(
          target:,
          interval:,
          mia_interval:,
          requires:,
          metadata:,
        ),
      ))
    _ -> Error(list.reverse(errors))
  }
}

fn port_number(
  env: Dict(String, String),
  name: String,
  default: Int,
  errors: List(String),
) -> #(Int, List(String)) {
  read(env, name, default, errors, fn(value) {
    case int.parse(value) {
      Ok(port) if port >= 1 && port <= 65_535 -> Ok(port)
      _ ->
        Error(
          name
          <> " must be an integer between 1 and 65535, got "
          <> string.inspect(value),
        )
    }
  })
}

fn positive(
  env: Dict(String, String),
  name: String,
  default: Int,
  errors: List(String),
) -> #(Int, List(String)) {
  read(env, name, default, errors, fn(value) {
    case int.parse(value) {
      Ok(number) if number > 0 -> Ok(number)
      _ ->
        Error(
          name <> " must be a positive integer, got " <> string.inspect(value),
        )
    }
  })
}

fn text(
  env: Dict(String, String),
  name: String,
  default: String,
  errors: List(String),
) -> #(String, List(String)) {
  read(env, name, default, errors, fn(value) {
    case string.trim(value) {
      "" -> Error(name <> " must not be empty")
      value -> Ok(value)
    }
  })
}

/// Reads and parses one variable, falling back to `default` when it is unset
/// and collecting the error (newest first) when it is invalid.
fn read(
  env: Dict(String, String),
  name: String,
  default: a,
  errors: List(String),
  parse: fn(String) -> Result(a, String),
) -> #(a, List(String)) {
  case dict.get(env, name) |> result.map(parse) {
    Error(Nil) -> #(default, errors)
    Ok(Ok(value)) -> #(value, errors)
    Ok(Error(error)) -> #(default, [error, ..errors])
  }
}

/// Parses `host:port` or `[ipv6]:port`.
fn target(value: String) -> Result(Target, Nil) {
  let value = string.trim(value)
  use #(host, port) <- result.try(case value {
    "[" <> rest -> {
      use #(host, rest) <- result.try(string.split_once(rest, "]:"))
      Ok(#(host, rest))
    }
    _ ->
      case string.split(value, ":") {
        [host, port] -> Ok(#(host, port))
        _ -> Error(Nil)
      }
  })
  case host, int.parse(port) {
    "", _ -> Error(Nil)
    _, Ok(port) if port >= 1 && port <= 65_535 -> Ok(Target(host:, port:))
    _, _ -> Error(Nil)
  }
}

/// An optional free-text variable; unset and blank both mean `None`.
fn optional(env: Dict(String, String), name: String) -> Option(String) {
  case dict.get(env, name) |> result.map(string.trim) {
    Ok("") | Error(Nil) -> None
    Ok(value) -> Some(value)
  }
}

fn trim_trailing_slash(path: String) -> String {
  case string.ends_with(path, "/") && path != "/" {
    True -> string.drop_end(path, 1)
    False -> path
  }
}

/// The version of the yaml2cv OTP application, taken from `gleam.toml`.
@external(erlang, "yaml2cv_system_ffi", "application_version")
pub fn version() -> Result(String, Nil)

@external(erlang, "yaml2cv_system_ffi", "schedulers_online")
fn schedulers_online() -> Int
