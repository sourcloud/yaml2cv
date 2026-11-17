//// JSON API handlers: validation and PDF rendering (ADR 0010).

import gleam/bit_array
import gleam/bytes_tree
import gleam/http/request
import gleam/http/response
import gleam/json
import gleam/list
import gleam/string
import wisp.{type Request, type Response}
import yaml2cv/cv.{type Cv}
import yaml2cv/cv/decode
import yaml2cv/render.{type RenderError, type Renderer}
import yaml2cv/web/problem

const yaml_content_types = ["application/yaml", "text/yaml", "text/plain"]

/// Seconds clients are asked to wait before retrying an overloaded server.
const retry_after = "5"

/// `POST /api/v1/validate`
pub fn validate(request: Request, max_body_bytes: Int) -> Response {
  use _cv <- require_cv(request, max_body_bytes)
  json.object([#("valid", json.bool(True))])
  |> json.to_string
  |> wisp.json_response(200)
}

/// `POST /api/v1/render`
pub fn render_pdf(
  request: Request,
  renderer: Renderer,
  max_body_bytes: Int,
) -> Response {
  use cv <- require_cv(request, max_body_bytes)
  render(renderer, cv)
}

fn render(renderer: Renderer, cv: Cv) -> Response {
  case renderer.render_pdf(cv) {
    Ok(pdf) ->
      wisp.response(200)
      |> response.set_header("content-type", "application/pdf")
      |> response.set_header(
        "content-disposition",
        "inline; filename=\"cv.pdf\"",
      )
      |> wisp.set_body(wisp.Bytes(bytes_tree.from_bit_array(pdf)))
    Error(error) -> render_error(error)
  }
}

/// Reads the body as YAML and decodes it into a CV, answering with a problem
/// response when anything about the request or document is wrong.
fn require_cv(
  request: Request,
  max_body_bytes: Int,
  next: fn(Cv) -> Response,
) -> Response {
  use <- require_yaml_content_type(request)
  let request = wisp.set_max_body_size(request, max_body_bytes)
  case wisp.read_body_bits(request) {
    Error(Nil) -> problem.to_response(problem.content_too_large())
    Ok(body) ->
      case bit_array.to_string(body) {
        Error(Nil) ->
          problem.to_response(problem.invalid_yaml(
            "The request body is not valid UTF-8.",
          ))
        Ok(source) ->
          case decode.from_yaml(source) {
            Ok(cv) -> next(cv)
            Error(errors) ->
              problem.to_response(problem.from_decode_errors(errors))
          }
      }
  }
}

fn require_yaml_content_type(
  request: Request,
  next: fn() -> Response,
) -> Response {
  let media_type = case request.get_header(request, "content-type") {
    Ok(value) ->
      value
      |> string.split_once(";")
      |> fn(split) {
        case split {
          Ok(#(media_type, _)) -> media_type
          Error(Nil) -> value
        }
      }
      |> string.trim
      |> string.lowercase
    Error(Nil) -> ""
  }
  case list.contains(yaml_content_types, media_type) {
    True -> next()
    False ->
      problem.new(
        slug: "unsupported-media-type",
        title: "Unsupported media type",
        status: 415,
        detail: "Send the CV as YAML with one of these content types: "
          <> string.join(yaml_content_types, ", ")
          <> ".",
      )
      |> problem.to_response
      |> response.set_header("accept", string.join(yaml_content_types, ", "))
  }
}

fn render_error(error: RenderError) -> Response {
  case error {
    render.Overloaded -> wisp.log_warning("render rejected: server overloaded")
    render.TimedOut -> wisp.log_warning("render timed out")
    render.RendererUnavailable(reason:) ->
      wisp.log_error("renderer unavailable: " <> reason)
    render.CompileFailed(output:) -> wisp.log_error("render failed: " <> output)
  }
  let response = problem.to_response(problem.from_render_error(error))
  case error {
    render.Overloaded ->
      response.set_header(response, "retry-after", retry_after)
    _ -> response
  }
}
