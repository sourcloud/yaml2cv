//// The command-line mode (ADR 0048): renders or validates CV files without
//// starting the server. Side effects are injected through `Io`.

import gleam/bit_array
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import yaml2cv/cli/arguments.{
  type Command, type Input, type Target, File, Help, Render, Serve, Stdin,
  Stdout, ToFile, Validate,
}
import yaml2cv/cv.{type Cv}
import yaml2cv/cv/decode.{
  type DecodeError, DocumentTooComplex, DocumentTooLarge, SchemaError,
  SyntaxError,
}
import yaml2cv/render.{type RenderError, type Renderer}
import yaml2cv/web/problem

/// The side effects of the command line. Errors are messages for the user.
pub type Io {
  Io(
    read_file: fn(String) -> Result(BitArray, String),
    read_stdin: fn() -> Result(BitArray, String),
    write_file: fn(String, BitArray) -> Result(Nil, String),
    write_stdout: fn(BitArray) -> Nil,
    write_stderr: fn(String) -> Nil,
  )
}

/// Exit status when everything succeeded.
pub const exit_ok = 0

/// Exit status when a CV is invalid or could not be rendered.
pub const exit_invalid = 1

/// Exit status for usage errors and files that cannot be read or written.
pub const exit_usage = 2

/// Why one input failed.
type Failure {
  Unreadable(reason: String)
  NotUtf8
  Invalid(errors: List(DecodeError))
  RenderFailed(error: RenderError)
  Unwritable(path: String, reason: String)
}

/// Runs a command-line command and returns the exit status. `Serve` is
/// handled by the caller and does nothing here.
pub fn run(command: Command, renderer: Renderer, io: Io) -> Int {
  case command {
    Serve -> exit_ok
    Help -> {
      io.write_stdout(<<arguments.usage:utf8>>)
      exit_ok
    }
    Render(jobs:, json:) ->
      list.fold(jobs, exit_ok, fn(status, job) {
        let #(input, target) = job
        let outcome = {
          use cv <- result.try(load(input, io))
          use pdf <- result.try(
            renderer.render_pdf(cv) |> result.map_error(RenderFailed),
          )
          write(target, pdf, io)
        }
        int.max(
          status,
          finish(outcome, input, json, io, fn() {
            case target {
              ToFile(path) -> "wrote " <> path
              Stdout -> ""
            }
          }),
        )
      })
    Validate(inputs:, json:) ->
      list.fold(inputs, exit_ok, fn(status, input) {
        let outcome = load(input, io) |> result.replace(Nil)
        int.max(status, finish(outcome, input, json, io, fn() { "valid" }))
      })
  }
}

/// Reports a usage error and returns the exit status for it.
pub fn usage_error(message: String, io: Io) -> Int {
  io.write_stderr("yaml2cv: " <> message <> "\n\n" <> arguments.usage)
  exit_usage
}

fn load(input: Input, io: Io) -> Result(Cv, Failure) {
  use bytes <- result.try(
    case input {
      File(path) -> io.read_file(path)
      Stdin -> io.read_stdin()
    }
    |> result.map_error(Unreadable),
  )
  use source <- result.try(
    bit_array.to_string(bytes) |> result.replace_error(NotUtf8),
  )
  decode.from_yaml(source) |> result.map_error(Invalid)
}

fn write(target: Target, pdf: BitArray, io: Io) -> Result(Nil, Failure) {
  case target {
    Stdout -> Ok(io.write_stdout(pdf))
    ToFile(path) ->
      io.write_file(path, pdf)
      |> result.map_error(fn(reason) { Unwritable(path:, reason:) })
  }
}

/// Reports the outcome of one input and returns its exit status. Progress
/// is only reported as text; an empty message reports nothing.
fn finish(
  outcome: Result(Nil, Failure),
  input: Input,
  json: Bool,
  io: Io,
  progress: fn() -> String,
) -> Int {
  let name = case input {
    File(path) -> path
    Stdin -> "<stdin>"
  }
  case outcome, json {
    Ok(Nil), True -> exit_ok
    Ok(Nil), False -> {
      case progress() {
        "" -> Nil
        message -> io.write_stderr(name <> ": " <> message <> "\n")
      }
      exit_ok
    }
    Error(failure), True -> {
      io.write_stderr(json.to_string(failure_json(failure, name)) <> "\n")
      status(failure)
    }
    Error(failure), False -> {
      failure_lines(failure, name)
      |> list.each(fn(line) { io.write_stderr(line <> "\n") })
      status(failure)
    }
  }
}

fn status(failure: Failure) -> Int {
  case failure {
    Unreadable(..) | Unwritable(..) -> exit_usage
    NotUtf8 | Invalid(..) | RenderFailed(..) -> exit_invalid
  }
}

fn failure_lines(failure: Failure, name: String) -> List(String) {
  case failure {
    Unreadable(reason:) -> [name <> ": cannot read: " <> reason]
    Unwritable(path:, reason:) -> [
      name <> ": cannot write " <> path <> ": " <> reason,
    ]
    NotUtf8 -> [name <> ": not valid UTF-8"]
    Invalid(errors:) -> list.map(errors, decode_error_line(_, name))
    RenderFailed(error:) -> {
      let line = name <> ": " <> problem.from_render_error(error).detail
      case error {
        render.CompileFailed(output:) -> [line, string.trim_end(output)]
        render.RendererUnavailable(reason:) -> [line, reason]
        render.TimedOut | render.Overloaded -> [line]
      }
    }
  }
}

fn decode_error_line(error: DecodeError, name: String) -> String {
  case error {
    SyntaxError(message:, line: 0, ..) -> name <> ": " <> message
    SyntaxError(message:, line:, column:) ->
      name
      <> ":"
      <> int.to_string(line)
      <> ":"
      <> int.to_string(column)
      <> ": "
      <> message
    SchemaError(path: "", problem:) -> name <> ": " <> decode.describe(problem)
    SchemaError(path:, problem:) ->
      name <> ": " <> path <> ": " <> decode.describe(problem)
    DocumentTooLarge(..) | DocumentTooComplex ->
      name <> ": " <> problem.content_too_large().detail
  }
}

fn failure_json(failure: Failure, name: String) -> json.Json {
  case failure {
    Unreadable(reason:) -> file_error("cannot read: " <> reason, name)
    Unwritable(path:, reason:) ->
      file_error("cannot write " <> path <> ": " <> reason, name)
    NotUtf8 ->
      problem.invalid_yaml("The input is not valid UTF-8.")
      |> with_file(name)
    Invalid(errors:) -> problem.from_decode_errors(errors) |> with_file(name)
    RenderFailed(error:) -> problem.from_render_error(error) |> with_file(name)
  }
}

fn with_file(p: problem.Problem, name: String) -> json.Json {
  p |> problem.with("file", json.string(name)) |> problem.to_json
}

/// A problem about the file system rather than the CV. It has no HTTP
/// status, which RFC 9457 makes optional.
fn file_error(detail: String, name: String) -> json.Json {
  json.object([
    #("type", json.string("/problems/file-error")),
    #("title", json.string("File error")),
    #("detail", json.string(detail)),
    #("file", json.string(name)),
  ])
}
