import gleam/dict
import gleam/http
import gleam/http/response
import gleam/list
import gleam/option.{None}
import gleam/string
import wisp/simulate
import yaml2cv/config
import yaml2cv/observe/admin
import yaml2cv/observe/document
import yaml2cv/observe/system.{Status}

fn get(path: String) {
  let assert Ok(config) =
    config.parse(
      dict.new(),
      schedulers: 1,
      priv_directory: "/priv",
      version: "1.2.3",
    )
  let document = fn() {
    document.build(
      config,
      interfaces: [],
      status: Status(memory: None, cpu_load: None, io_load: None, disk: None),
    )
  }
  simulate.request(http.Get, path) |> admin.handle_request(document)
}

fn json_body(response) -> String {
  assert response.get_header(response, "content-type")
    == Ok("application/json; charset=utf-8")
  simulate.read_body(response)
}

pub fn serves_full_document_test() {
  let response = get("/")
  assert response.status == 200
  let body = json_body(response)
  assert string.starts_with(body, "{\"name\":\"yaml2cv\",\"version\":\"1.2.3\"")
}

pub fn serves_config_test() {
  let body = get("/config") |> json_body
  assert string.starts_with(body, "{\"git_revision\":null")
}

pub fn serves_status_test() {
  assert get("/status") |> json_body
    == "{\"memory\":null,\"cpu_load\":null,\"io_load\":null,\"disk\":null}"
}

pub fn serves_health_test() {
  assert get("/healthz") |> json_body == "{\"status\":\"ok\"}"
}

pub fn every_rel_link_exists_test() {
  let assert [_, ..] = document.rel
  use #(_, path) <- list.each(document.rel)
  assert get(path).status == 200
}

pub fn rejects_unknown_paths_and_methods_test() {
  assert get("/editor/preview").status == 404
  let assert Ok(config) =
    config.parse(
      dict.new(),
      schedulers: 1,
      priv_directory: "/priv",
      version: "1.2.3",
    )
  let response =
    simulate.request(http.Post, "/")
    |> admin.handle_request(fn() {
      document.build(
        config,
        interfaces: [],
        status: Status(memory: None, cpu_load: None, io_load: None, disk: None),
      )
    })
  assert response.status == 405
}
