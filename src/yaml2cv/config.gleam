//// Application configuration from environment variables (ADR 0010).

import envoy
import gleam/dict.{type Dict}
import gleam/erlang/application
import gleam/int
import gleam/list
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
  )
}

/// Reads the configuration from the process environment.
pub fn load() -> Result(Config, List(String)) {
  case application.priv_directory("yaml2cv") {
    Ok(priv) ->
      parse(envoy.all(), schedulers: schedulers_online(), priv_directory: priv)
    Error(Nil) -> Error(["could not locate the priv directory of yaml2cv"])
  }
}

/// Builds a configuration from environment variables, reporting every
/// invalid variable. `schedulers` sets the default render concurrency;
/// themes, static files and examples are found in `priv_directory`.
pub fn parse(
  env: Dict(String, String),
  schedulers schedulers: Int,
  priv_directory priv_directory: String,
) -> Result(Config, List(String)) {
  let tmp = case dict.get(env, "TMPDIR") {
    Ok(dir) if dir != "" -> trim_trailing_slash(dir)
    _ -> "/tmp"
  }
  let #(port, errors) = port(env, "PORT", 8000, [])
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
        ),
      ))
    _ -> Error(list.reverse(errors))
  }
}

fn port(
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

fn trim_trailing_slash(path: String) -> String {
  case string.ends_with(path, "/") && path != "/" {
    True -> string.drop_end(path, 1)
    False -> path
  }
}

@external(erlang, "yaml2cv_system_ffi", "schedulers_online")
fn schedulers_online() -> Int
