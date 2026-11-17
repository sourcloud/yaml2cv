//// Command-line arguments (ADR 0048): which mode to run and, for the
//// command line, which inputs go to which outputs.

import gleam/bool
import gleam/list
import gleam/result
import gleam/string

/// What the program was asked to do.
pub type Command {
  /// Start the HTTP server.
  Serve
  /// Print the usage.
  Help
  /// Render every input to its target.
  Render(jobs: List(#(Input, Target)), errors: ErrorFormat)
  /// Validate every input.
  Validate(inputs: List(Input), errors: ErrorFormat)
}

/// How problems are reported on standard error.
pub type ErrorFormat {
  /// One line of text per problem.
  Text
  /// One RFC 9457 problem document per line.
  Json
}

/// Where a CV is read from.
pub type Input {
  File(path: String)
  Stdin
}

/// Where a PDF is written to.
pub type Target {
  ToFile(path: String)
  Stdout
}

/// The usage text, printed for `help` and after usage errors.
pub const usage =
  "Usage:
  yaml2cv [serve]
      Start the HTTP server (the default).
  yaml2cv render [--error-format FORMAT] [-o FILE | --out-dir DIR] INPUT...
      Render CVs to PDF. cv.yaml becomes cv.pdf next to it, - reads
      standard input and writes standard output. -o FILE names the output
      of a single input (- for standard output), --out-dir DIR writes all
      PDFs into an existing directory.
  yaml2cv validate [--error-format FORMAT] INPUT...
      Check CVs without rendering them.
  yaml2cv help
      Show this text.

  --error-format text|json
      How problems are reported on standard error: one line of text each
      (the default), or one RFC 9457 JSON problem per line.

Exit status: 0 success, 1 invalid CV or render failure, 2 usage or file error.
"

type Options {
  Options(
    inputs: List(Input),
    output: Result(String, Nil),
    out_dir: Result(String, Nil),
    errors: ErrorFormat,
  )
}

/// Interprets the arguments after the program name. The error is a message
/// for the user.
pub fn parse(arguments: List(String)) -> Result(Command, String) {
  case arguments {
    [] | ["serve"] -> Ok(Serve)
    ["help", ..] | ["-h", ..] | ["--help", ..] -> Ok(Help)
    ["render", ..rest] -> {
      use options <- result.try(options(rest, "render"))
      render(options)
    }
    ["validate", ..rest] -> {
      use options <- result.try(options(rest, "validate"))
      validate(options)
    }
    [command, ..] -> Error("unknown command " <> string.inspect(command))
  }
}

fn options(
  arguments: List(String),
  command: String,
) -> Result(Options, String) {
  use options <- result.try(collect(
    arguments,
    Options([], Error(Nil), Error(Nil), Text),
  ))
  let inputs = list.reverse(options.inputs)
  use <- bool.guard(inputs == [], Error(command <> " needs at least one input"))
  use <- bool.guard(
    list.count(inputs, fn(input) { input == Stdin }) > 1,
    Error("standard input (-) can be read only once"),
  )
  Ok(Options(..options, inputs:))
}

fn collect(
  arguments: List(String),
  options: Options,
) -> Result(Options, String) {
  case arguments {
    [] -> Ok(options)
    ["--", ..rest] ->
      Ok(
        Options(
          ..options,
          inputs: list.fold(rest, options.inputs, fn(inputs, path) {
            [input(path), ..inputs]
          }),
        ),
      )
    ["--error-format", value, ..rest] | ["--error-format=" <> value, ..rest] -> {
      use errors <- result.try(error_format(value))
      collect(rest, Options(..options, errors:))
    }
    ["--error-format"] -> Error("--error-format needs a value")
    ["-o", value, ..rest] ->
      collect(rest, Options(..options, output: Ok(value)))
    ["-o"] -> Error("-o needs a value")
    ["--out-dir", value, ..rest] ->
      collect(rest, Options(..options, out_dir: Ok(value)))
    ["--out-dir"] -> Error("--out-dir needs a value")
    ["--out-dir=" <> value, ..rest] ->
      collect(rest, Options(..options, out_dir: Ok(value)))
    ["-", ..rest] ->
      collect(rest, Options(..options, inputs: [Stdin, ..options.inputs]))
    ["-" <> _ as option, ..] ->
      Error("unknown option " <> string.inspect(option))
    [path, ..rest] ->
      collect(rest, Options(..options, inputs: [File(path), ..options.inputs]))
  }
}

fn error_format(value: String) -> Result(ErrorFormat, String) {
  case value {
    "text" -> Ok(Text)
    "json" -> Ok(Json)
    _ ->
      Error(
        "--error-format must be text or json, got " <> string.inspect(value),
      )
  }
}

fn input(argument: String) -> Input {
  case argument {
    "-" -> Stdin
    path -> File(path)
  }
}

fn render(options: Options) -> Result(Command, String) {
  use jobs <- result.try(case options.output, options.out_dir, options.inputs {
    Ok(_), Ok(_), _ -> Error("-o and --out-dir cannot be combined")
    Ok(output), _, [input] -> Ok([#(input, target(output))])
    Ok(_), _, _ ->
      Error("-o needs exactly one input; use --out-dir for several")
    _, Ok(directory), inputs ->
      list.try_map(inputs, fn(input) {
        case input {
          Stdin -> Error("standard input (-) cannot be used with --out-dir")
          File(path) ->
            Ok(#(input, ToFile(join(directory, pdf_name(basename(path))))))
        }
      })
    _, _, inputs ->
      Ok(
        list.map(inputs, fn(input) {
          case input {
            Stdin -> #(Stdin, Stdout)
            File(path) -> #(input, ToFile(pdf_name(path)))
          }
        }),
      )
  })
  use _ <- result.try(unique_targets(jobs, []))
  Ok(Render(jobs:, errors: options.errors))
}

fn validate(options: Options) -> Result(Command, String) {
  case options.output, options.out_dir {
    Ok(_), _ -> Error("validate does not write files; -o is not allowed")
    _, Ok(_) -> Error("validate does not write files; --out-dir is not allowed")
    _, _ -> Ok(Validate(inputs: options.inputs, errors: options.errors))
  }
}

fn target(output: String) -> Target {
  case output {
    "-" -> Stdout
    path -> ToFile(path)
  }
}

/// Replaces a `.yaml` or `.yml` extension with `.pdf`, or appends `.pdf`.
fn pdf_name(path: String) -> String {
  let stem = case
    string.ends_with(path, ".yaml"),
    string.ends_with(path, ".yml")
  {
    True, _ -> string.drop_end(path, 5)
    _, True -> string.drop_end(path, 4)
    _, _ -> path
  }
  stem <> ".pdf"
}

fn basename(path: String) -> String {
  case string.split(path, "/") |> list.last {
    Ok(name) -> name
    Error(Nil) -> path
  }
}

fn join(directory: String, name: String) -> String {
  case string.ends_with(directory, "/") {
    True -> directory <> name
    False -> directory <> "/" <> name
  }
}

fn unique_targets(
  jobs: List(#(Input, Target)),
  seen: List(#(String, String)),
) -> Result(Nil, String) {
  case jobs {
    [] -> Ok(Nil)
    [#(File(path), ToFile(output)), ..rest] ->
      case list.key_find(seen, output) {
        Ok(earlier) ->
          Error(earlier <> " and " <> path <> " would both write " <> output)
        Error(Nil) -> unique_targets(rest, [#(output, path), ..seen])
      }
    [_, ..rest] -> unique_targets(rest, seen)
  }
}
