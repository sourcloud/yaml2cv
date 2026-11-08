//// Gzip compression of in-memory text responses (ADR 0019).

import gleam/bit_array
import gleam/bytes_tree
import gleam/float
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import wisp.{type Request, type Response}

/// Bodies smaller than this are sent uncompressed; gzip would barely help.
const minimum_size = 1024

const compressible_types = [
  "application/json", "application/problem+json", "image/svg+xml",
]

/// Middleware that gzips the response of `next` when the client accepts gzip
/// and the body is textual, held in memory and at least 1 KiB. Such
/// responses also get `vary: accept-encoding`, whether compressed or not.
pub fn gzip(request: Request, next: fn() -> Response) -> Response {
  let response = next()
  case compressible(response), in_memory_body(response.body) {
    True, Ok(body) -> {
      let response = add_vary(response, "accept-encoding")
      case
        accepts_gzip(request)
        && bit_array.byte_size(body) >= minimum_size
        && response.get_header(response, "content-encoding") == Error(Nil)
      {
        True ->
          response
          |> wisp.set_body(
            wisp.Bytes(bytes_tree.from_bit_array(zlib_gzip(body))),
          )
          |> response.set_header("content-encoding", "gzip")
        False -> response
      }
    }
    _, _ -> response
  }
}

fn compressible(response: Response) -> Bool {
  case response.get_header(response, "content-type") {
    Ok(value) -> {
      let media_type = case string.split_once(value, ";") {
        Ok(#(media_type, _)) -> media_type
        Error(Nil) -> value
      }
      let media_type = string.lowercase(string.trim(media_type))
      string.starts_with(media_type, "text/")
      || list.contains(compressible_types, media_type)
    }
    Error(Nil) -> False
  }
}

fn in_memory_body(body: wisp.Body) -> Result(BitArray, Nil) {
  case body {
    wisp.Text(text) -> Ok(bit_array.from_string(text))
    wisp.Bytes(bytes) -> Ok(bytes_tree.to_bit_array(bytes))
    wisp.File(..) -> Error(Nil)
  }
}

/// Whether `accept-encoding` lists gzip without refusing it via `q=0`.
fn accepts_gzip(request: Request) -> Bool {
  request.get_header(request, "accept-encoding")
  |> result.unwrap("")
  |> string.split(",")
  |> list.any(fn(coding) {
    case string.split(coding, ";") {
      [name, ..parameters] ->
        string.lowercase(string.trim(name)) == "gzip"
        && !list.any(parameters, refuses)
      [] -> False
    }
  })
}

fn refuses(parameter: String) -> Bool {
  case string.trim(parameter) {
    "q=" <> weight | "Q=" <> weight ->
      case float.parse(weight), int.parse(weight) {
        Ok(weight), _ -> weight == 0.0
        _, Ok(weight) -> weight == 0
        _, _ -> False
      }
    _ -> False
  }
}

fn add_vary(response: Response, header: String) -> Response {
  case response.get_header(response, "vary") {
    Ok(existing) ->
      response.set_header(response, "vary", existing <> ", " <> header)
    Error(Nil) -> response.set_header(response, "vary", header)
  }
}

@external(erlang, "zlib", "gzip")
fn zlib_gzip(data: BitArray) -> BitArray
