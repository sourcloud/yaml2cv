//// RFC 9457 problem details responses (ADR 0010).

import gleam/http/response
import gleam/json.{type Json}
import wisp.{type Response}

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

/// Turns a problem into an `application/problem+json` response.
pub fn to_response(problem: Problem) -> Response {
  json.object([
    #("type", json.string("/problems/" <> problem.slug)),
    #("title", json.string(problem.title)),
    #("status", json.int(problem.status)),
    #("detail", json.string(problem.detail)),
    ..problem.extensions
  ])
  |> json.to_string
  |> wisp.json_response(problem.status)
  |> response.set_header("content-type", "application/problem+json")
}
