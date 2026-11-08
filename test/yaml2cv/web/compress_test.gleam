import gleam/bytes_tree
import gleam/http
import gleam/http/response
import gleam/string
import wisp
import wisp/simulate
import yaml2cv/web/compress

const page = "<p>Hello</p>"

fn large_html() -> wisp.Response {
  wisp.html_response(string.repeat(page, 200), 200)
}

fn request(accept_encoding: String) -> wisp.Request {
  simulate.request(http.Get, "/")
  |> simulate.header("accept-encoding", accept_encoding)
}

pub fn compresses_text_when_client_accepts_gzip_test() {
  let response = compress.gzip(request("deflate, gzip, br"), large_html)
  assert response.get_header(response, "content-encoding") == Ok("gzip")
  assert response.get_header(response, "vary") == Ok("accept-encoding")
  assert gunzip(simulate.read_body_bits(response))
    == <<string.repeat(page, 200):utf8>>
}

pub fn leaves_response_alone_without_accept_encoding_test() {
  let response = compress.gzip(simulate.request(http.Get, "/"), large_html)
  assert response.get_header(response, "content-encoding") == Error(Nil)
  assert response.get_header(response, "vary") == Ok("accept-encoding")
  assert simulate.read_body(response) == string.repeat(page, 200)
}

pub fn respects_refused_gzip_test() {
  let response = compress.gzip(request("gzip;q=0, br"), large_html)
  assert response.get_header(response, "content-encoding") == Error(Nil)
}

pub fn leaves_small_bodies_alone_test() {
  let response =
    compress.gzip(request("gzip"), fn() { wisp.html_response(page, 200) })
  assert response.get_header(response, "content-encoding") == Error(Nil)
}

pub fn leaves_binary_content_alone_test() {
  let response =
    compress.gzip(request("gzip"), fn() {
      wisp.response(200)
      |> wisp.set_body(
        wisp.Bytes(bytes_tree.from_string(string.repeat("%PDF-", 500))),
      )
      |> response.set_header("content-type", "application/pdf")
    })
  assert response.get_header(response, "content-encoding") == Error(Nil)
  assert response.get_header(response, "vary") == Error(Nil)
}

pub fn appends_to_existing_vary_header_test() {
  let response =
    compress.gzip(request("gzip"), fn() {
      large_html() |> response.set_header("vary", "origin")
    })
  assert response.get_header(response, "vary") == Ok("origin, accept-encoding")
}

@external(erlang, "zlib", "gunzip")
fn gunzip(data: BitArray) -> BitArray
