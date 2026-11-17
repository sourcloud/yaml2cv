//// RFC 9457 problem details (ADR 0010), shared by the HTTP API and the
//// command line (ADR 0048).

import gleam/http/response
import gleam/json.{type Json}
import wisp.{type Response}
import yaml2cv/cv/decode.{
  type DecodeError, DocumentTooComplex, DocumentTooLarge, SchemaError,
  SyntaxError,
}
import yaml2cv/render.{type RenderError}

pub type Problem {
  Problem(
    /// Identifies the problem type; rendered as `type: /problems/<slug>`.
    slug: String,
    title: String,
    status: Int,
    detail: String,
    /// Additional members, e.g. the list of validation errors.
    extensions: List(#(String, Json)),
  )
}

/// Creates a problem without extension members.
pub fn new(
  slug slug: String,
  title title: String,
  status status: Int,
  detail detail: String,
) -> Problem {
  Problem(slug:, title:, status:, detail:, extensions: [])
}

/// Adds an extension member.
pub fn with(problem: Problem, key: String, value: Json) -> Problem {
  Problem(..problem, extensions: [#(key, value), ..problem.extensions])
}

/// The problem describing why a document could not be decoded.
pub fn from_decode_errors(errors: List(DecodeError)) -> Problem {
  case errors {
    [SyntaxError(message:, line:, column:), ..] ->
      invalid_yaml(message)
      |> with("line", json.int(line))
      |> with("column", json.int(column))
    [DocumentTooLarge(..), ..] | [DocumentTooComplex, ..] -> content_too_large()
    _ ->
      new(
        slug: "invalid-cv",
        title: "Invalid CV",
        status: 422,
        detail: "The CV does not match the schema.",
      )
      |> with(
        "errors",
        json.array(errors, fn(error) {
          case error {
            SchemaError(path:, problem:) ->
              json.object([
                #("path", json.string(path)),
                #("message", json.string(decode.describe(problem))),
              ])
            // Syntax and size errors never mix with schema errors.
            SyntaxError(..) | DocumentTooLarge(..) | DocumentTooComplex ->
              json.null()
          }
        }),
      )
  }
}

/// A problem for input that is not valid YAML.
pub fn invalid_yaml(detail: String) -> Problem {
  new(slug: "invalid-yaml", title: "Invalid YAML", status: 422, detail:)
}

/// A problem for a document over the size or complexity limits.
pub fn content_too_large() -> Problem {
  new(
    slug: "content-too-large",
    title: "Content too large",
    status: 413,
    detail: "The CV document is too large or nested too deeply.",
  )
}

/// The problem describing why a valid CV could not be rendered.
pub fn from_render_error(error: RenderError) -> Problem {
  case error {
    render.Overloaded ->
      new(
        slug: "overloaded",
        title: "Server busy",
        status: 503,
        detail: "Too many CVs are being rendered right now. Try again shortly.",
      )
    render.TimedOut ->
      new(
        slug: "render-timeout",
        title: "Rendering timed out",
        status: 503,
        detail: "Rendering the CV took too long.",
      )
    render.RendererUnavailable(..) ->
      new(
        slug: "renderer-unavailable",
        title: "Renderer unavailable",
        status: 503,
        detail: "The PDF renderer is currently unavailable.",
      )
    render.CompileFailed(..) ->
      new(
        slug: "render-failed",
        title: "Rendering failed",
        status: 500,
        detail: "The CV could not be rendered.",
      )
  }
}

/// The problem as a JSON object.
pub fn to_json(problem: Problem) -> Json {
  json.object([
    #("type", json.string("/problems/" <> problem.slug)),
    #("title", json.string(problem.title)),
    #("status", json.int(problem.status)),
    #("detail", json.string(problem.detail)),
    ..problem.extensions
  ])
}

/// Turns a problem into an `application/problem+json` response.
pub fn to_response(problem: Problem) -> Response {
  to_json(problem)
  |> json.to_string
  |> wisp.json_response(problem.status)
  |> response.set_header("content-type", "application/problem+json")
}
