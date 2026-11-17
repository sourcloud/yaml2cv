import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/string
import yaml2cv/cli.{type Io, Io}
import yaml2cv/cli/arguments.{
  File, Help, Json, Render, Stdin, Stdout, Text, ToFile, Validate,
}
import yaml2cv/render.{
  type RenderError, CompileFailed, Renderer, RendererUnavailable,
}

const valid_cv = "schema_version: 1\nperson: {name: Jane Roe}\nsections: []\n"

const invalid_cv = "schema_version: 1\nperson: {}\nsections: []\n"

pub type Event {
  Stderr(String)
  StdoutBytes(BitArray)
  Wrote(String, BitArray)
}

fn fake_io(
  files: List(#(String, String)),
  stdin: String,
  events: Subject(Event),
) -> Io {
  Io(
    read_file: fn(path) {
      case list.key_find(files, path) {
        Ok(content) -> Ok(<<content:utf8>>)
        Error(Nil) -> Error("no such file")
      }
    },
    read_stdin: fn() { Ok(<<stdin:utf8>>) },
    write_file: fn(path, bytes) {
      case string.starts_with(path, "readonly/") {
        True -> Error("permission denied")
        False -> Ok(process.send(events, Wrote(path, bytes)))
      }
    },
    write_stdout: fn(bytes) { process.send(events, StdoutBytes(bytes)) },
    write_stderr: fn(text) { process.send(events, Stderr(text)) },
  )
}

fn renderer(result: Result(BitArray, RenderError)) {
  fn() {
    Ok(
      Renderer(render_pdf: fn(_) { result }, render_svg_pages: fn(_) { Ok([]) }),
    )
  }
}

fn drain(events: Subject(Event), acc: List(Event)) -> List(Event) {
  case process.receive(events, 0) {
    Ok(event) -> drain(events, [event, ..acc])
    Error(Nil) -> list.reverse(acc)
  }
}

fn run(
  command: arguments.Command,
  files: List(#(String, String)),
  stdin: String,
  result: Result(BitArray, RenderError),
) -> #(Int, List(Event)) {
  let events = process.new_subject()
  let code = cli.run(command, renderer(result), fake_io(files, stdin, events))
  #(code, drain(events, []))
}

fn stderr(events: List(Event)) -> String {
  events
  |> list.filter_map(fn(event) {
    case event {
      Stderr(text) -> Ok(text)
      _ -> Error(Nil)
    }
  })
  |> string.concat
}

pub fn help_prints_usage_to_stdout_test() {
  let assert #(0, [StdoutBytes(text)]) = run(Help, [], "", Ok(<<>>))
  let assert <<"Usage:", _:bits>> = text
}

pub fn render_writes_files_test() {
  let assert #(0, events) =
    run(
      Render(
        jobs: [
          #(File("a.yaml"), ToFile("a.pdf")),
          #(File("b.yaml"), ToFile("b.pdf")),
        ],
        errors: Text,
      ),
      [#("a.yaml", valid_cv), #("b.yaml", valid_cv)],
      "",
      Ok(<<"%PDF">>),
    )
  let assert [
    Wrote("a.pdf", <<"%PDF">>),
    Stderr("a.yaml: wrote a.pdf\n"),
    Wrote("b.pdf", <<"%PDF">>),
    Stderr("b.yaml: wrote b.pdf\n"),
  ] = events
}

pub fn render_stdin_to_stdout_test() {
  let assert #(0, [StdoutBytes(<<"%PDF">>)]) =
    run(
      Render(jobs: [#(Stdin, Stdout)], errors: Text),
      [],
      valid_cv,
      Ok(<<"%PDF">>),
    )
}

pub fn invalid_cv_is_reported_and_others_still_render_test() {
  let assert #(1, events) =
    run(
      Render(
        jobs: [
          #(File("bad.yaml"), ToFile("bad.pdf")),
          #(File("good.yaml"), ToFile("good.pdf")),
        ],
        errors: Text,
      ),
      [#("bad.yaml", invalid_cv), #("good.yaml", valid_cv)],
      "",
      Ok(<<"%PDF">>),
    )
  let assert "bad.yaml: person.name: is required\ngood.yaml: wrote good.pdf\n" =
    stderr(events)
  let assert True = list.contains(events, Wrote("good.pdf", <<"%PDF">>))
}

pub fn syntax_error_has_location_test() {
  let assert #(1, events) =
    run(
      Validate(inputs: [Stdin], errors: Text),
      [],
      "person:\n  name: [unclosed\n",
      Ok(<<>>),
    )
  let assert "<stdin>:2:" <> _ = stderr(events)
}

pub fn missing_file_exits_with_2_test() {
  let assert #(2, events) =
    run(
      Validate(inputs: [File("nope.yaml"), File("bad.yaml")], errors: Text),
      [#("bad.yaml", invalid_cv)],
      "",
      Ok(<<>>),
    )
  let assert "nope.yaml: cannot read: no such file\nbad.yaml: person.name: is required\n" =
    stderr(events)
}

pub fn unwritable_output_exits_with_2_test() {
  let assert #(2, events) =
    run(
      Render(jobs: [#(File("a.yaml"), ToFile("readonly/a.pdf"))], errors: Text),
      [#("a.yaml", valid_cv)],
      "",
      Ok(<<"%PDF">>),
    )
  let assert "a.yaml: cannot write readonly/a.pdf: permission denied\n" =
    stderr(events)
}

pub fn render_failure_includes_backend_output_test() {
  let assert #(1, events) =
    run(
      Render(jobs: [#(File("a.yaml"), ToFile("a.pdf"))], errors: Text),
      [#("a.yaml", valid_cv)],
      "",
      Error(CompileFailed("error: boom")),
    )
  let assert "a.yaml: The CV could not be rendered.\nerror: boom\n" =
    stderr(events)
}

pub fn validate_reports_valid_files_test() {
  let assert #(0, events) =
    run(
      Validate(inputs: [File("a.yaml")], errors: Text),
      [#("a.yaml", valid_cv)],
      "",
      Ok(<<>>),
    )
  let assert "a.yaml: valid\n" = stderr(events)
}

pub fn json_reports_problems_with_file_test() {
  let assert #(1, events) =
    run(
      Validate(inputs: [File("bad.yaml"), File("a.yaml")], errors: Json),
      [#("bad.yaml", invalid_cv), #("a.yaml", valid_cv)],
      "",
      Ok(<<>>),
    )
  let assert "{\"type\":\"/problems/invalid-cv\",\"title\":\"Invalid CV\",\"status\":422,\"detail\":\"The CV does not match the schema.\",\"file\":\"bad.yaml\",\"errors\":[{\"path\":\"person.name\",\"message\":\"is required\"}]}\n" =
    stderr(events)
}

pub fn json_reports_render_problems_test() {
  let assert #(1, events) =
    run(
      Render(jobs: [#(Stdin, Stdout)], errors: Json),
      [],
      valid_cv,
      Error(RendererUnavailable("no typst")),
    )
  let assert "{\"type\":\"/problems/renderer-unavailable\"," <> _ =
    stderr(events)
  let assert True = string.contains(stderr(events), "\"file\":\"<stdin>\"")
}

pub fn json_reports_file_errors_test() {
  let assert #(2, events) =
    run(Validate(inputs: [File("nope.yaml")], errors: Json), [], "", Ok(<<>>))
  let assert "{\"type\":\"/problems/file-error\",\"title\":\"File error\",\"detail\":\"cannot read: no such file\",\"file\":\"nope.yaml\"}\n" =
    stderr(events)
}

pub fn invalid_utf8_is_invalid_yaml_test() {
  let events = process.new_subject()
  let io = Io(..fake_io([], "", events), read_stdin: fn() { Ok(<<0xff>>) })
  let assert 1 =
    cli.run(Validate(inputs: [Stdin], errors: Text), renderer(Ok(<<>>)), io)
  let assert "<stdin>: not valid UTF-8\n" = stderr(drain(events, []))
}

pub fn usage_error_test() {
  let events = process.new_subject()
  let assert 2 =
    cli.usage_error("unknown command \"x\"", fake_io([], "", events))
  let assert "yaml2cv: unknown command \"x\"\n\nUsage:" <> _ =
    stderr(drain(events, []))
}

pub fn render_reports_configuration_errors_test() {
  let events = process.new_subject()
  let assert 2 =
    cli.run(
      Render(jobs: [#(File("a.yaml"), ToFile("a.pdf"))], errors: Text),
      fn() { Error(["TYPST_PATH must not be empty"]) },
      fake_io([#("a.yaml", valid_cv)], "", events),
    )
  let assert "yaml2cv: invalid configuration: TYPST_PATH must not be empty\n" =
    stderr(drain(events, []))
}

pub fn validate_does_not_need_a_renderer_test() {
  let events = process.new_subject()
  let assert 0 =
    cli.run(
      Validate(inputs: [File("a.yaml")], errors: Text),
      fn() { Error(["broken"]) },
      fake_io([#("a.yaml", valid_cv)], "", events),
    )
}
