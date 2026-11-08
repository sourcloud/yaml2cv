import gleam/dict
import yaml2cv/config.{Config}
import yaml2cv/render/typst

fn parse(env: List(#(String, String))) {
  config.parse(
    dict.from_list(env),
    schedulers: 4,
    priv_directory: "/priv",
    version: "1.2.3",
  )
}

pub fn uses_defaults_for_empty_environment_test() {
  assert parse([])
    == Ok(Config(
      port: 8000,
      bind_address: "0.0.0.0",
      max_body_bytes: 262_144,
      render_concurrency: 4,
      render_queue_wait: 5000,
      static_directory: "/priv/static",
      example_path: "/priv/examples/example.yaml",
      typst: typst.Config(
        executable: "typst",
        themes_directory: "/priv/themes",
        work_directory: "/tmp/yaml2cv",
        timeout: 10_000,
        generator: "Generated with yaml2cv 1.2.3 (https://github.com/sourcloud/yaml2cv)",
      ),
    ))
}

pub fn reads_all_variables_test() {
  let assert Ok(config) =
    parse([
      #("PORT", "9000"),
      #("BIND_ADDRESS", "127.0.0.1"),
      #("MAX_BODY_BYTES", "1024"),
      #("RENDER_CONCURRENCY", "2"),
      #("RENDER_QUEUE_WAIT_MS", "100"),
      #("TYPST_PATH", "/usr/bin/typst"),
      #("WORK_DIR", "/var/yaml2cv"),
      #("RENDER_TIMEOUT_MS", "3000"),
    ])

  assert config.port == 9000
  assert config.bind_address == "127.0.0.1"
  assert config.max_body_bytes == 1024
  assert config.render_concurrency == 2
  assert config.render_queue_wait == 100
  assert config.typst
    == typst.Config(
      executable: "/usr/bin/typst",
      themes_directory: "/priv/themes",
      work_directory: "/var/yaml2cv",
      timeout: 3000,
      generator: "Generated with yaml2cv 1.2.3 (https://github.com/sourcloud/yaml2cv)",
    )
}

pub fn derives_work_directory_from_tmpdir_test() {
  let assert Ok(config) = parse([#("TMPDIR", "/scratch/")])
  assert config.typst.work_directory == "/scratch/yaml2cv"
}

pub fn reports_every_invalid_variable_test() {
  assert parse([
      #("PORT", "70000"),
      #("RENDER_CONCURRENCY", "0"),
      #("RENDER_TIMEOUT_MS", "soon"),
      #("TYPST_PATH", ""),
    ])
    == Error([
      "PORT must be an integer between 1 and 65535, got \"70000\"",
      "RENDER_TIMEOUT_MS must be a positive integer, got \"soon\"",
      "RENDER_CONCURRENCY must be a positive integer, got \"0\"",
      "TYPST_PATH must not be empty",
    ])
}

pub fn reads_application_version_test() {
  let assert Ok(version) = config.version()
  assert version != ""
}
