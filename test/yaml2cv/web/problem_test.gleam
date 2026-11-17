import gleam/json
import yaml2cv/cv/decode.{
  DocumentTooComplex, Required, SchemaError, SyntaxError, UnknownKey,
}
import yaml2cv/render.{CompileFailed, Overloaded, RendererUnavailable, TimedOut}
import yaml2cv/web/problem

fn encode(p: problem.Problem) -> String {
  p |> problem.to_json |> json.to_string
}

pub fn to_json_puts_standard_members_first_test() {
  let assert "{\"type\":\"/problems/x\",\"title\":\"X\",\"status\":400,\"detail\":\"d\",\"file\":\"cv.yaml\"}" =
    problem.new(slug: "x", title: "X", status: 400, detail: "d")
    |> problem.with("file", json.string("cv.yaml"))
    |> encode
}

pub fn syntax_error_becomes_invalid_yaml_with_location_test() {
  let assert "{\"type\":\"/problems/invalid-yaml\",\"title\":\"Invalid YAML\",\"status\":422,\"detail\":\"bad\",\"column\":5,\"line\":3}" =
    problem.from_decode_errors([SyntaxError(message: "bad", line: 3, column: 5)])
    |> encode
}

pub fn schema_errors_become_invalid_cv_with_errors_test() {
  let assert "{\"type\":\"/problems/invalid-cv\",\"title\":\"Invalid CV\",\"status\":422,\"detail\":\"The CV does not match the schema.\",\"errors\":[{\"path\":\"person.name\",\"message\":\"is required\"},{\"path\":\"foo\",\"message\":\"unknown key\"}]}" =
    problem.from_decode_errors([
      SchemaError(path: "person.name", problem: Required),
      SchemaError(path: "foo", problem: UnknownKey),
    ])
    |> encode
}

pub fn complex_document_is_content_too_large_test() {
  let assert "content-too-large" =
    problem.from_decode_errors([DocumentTooComplex]).slug
}

pub fn render_errors_map_to_api_problem_types_test() {
  let assert "overloaded" = problem.from_render_error(Overloaded).slug
  let assert "render-timeout" = problem.from_render_error(TimedOut).slug
  let assert "renderer-unavailable" =
    problem.from_render_error(RendererUnavailable("x")).slug
  let assert "render-failed" =
    problem.from_render_error(CompileFailed("x")).slug
}
