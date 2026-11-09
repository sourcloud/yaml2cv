import gleam/dict
import gleam/option.{None, Some}
import yaml2cv/config.{Admin, Config, Metadata, PhoneHome, Target}
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
      max_body_bytes: 1_048_576,
      render_concurrency: 4,
      render_queue_wait: 5000,
      static_directory: "/priv/static",
      example_path: "/priv/examples/example.yaml",
      typst: typst.Config(
        executable: "typst",
        themes_directory: "/priv/themes",
        fonts_directory: "/priv/fonts",
        work_directory: "/tmp/yaml2cv",
        timeout: 10_000,
        generator: "Generated with yaml2cv 1.2.3 (https://github.com/sourcloud/yaml2cv)",
      ),
      version: "1.2.3",
      admin: Admin(bind_address: "127.0.0.1", port: 9000),
      phone_home: PhoneHome(
        target: None,
        interval: 10_000,
        mia_interval: 30_000,
        requires: [],
        metadata: Metadata(
          git_revision: None,
          build_date: None,
          deployed_from: None,
          deployed_by: None,
          deployed_on: None,
        ),
      ),
    ))
}

pub fn reads_all_variables_test() {
  let assert Ok(config) =
    parse([
      #("PORT", "8080"),
      #("BIND_ADDRESS", "127.0.0.1"),
      #("MAX_BODY_BYTES", "1024"),
      #("RENDER_CONCURRENCY", "2"),
      #("RENDER_QUEUE_WAIT_MS", "100"),
      #("TYPST_PATH", "/usr/bin/typst"),
      #("WORK_DIR", "/var/yaml2cv"),
      #("RENDER_TIMEOUT_MS", "3000"),
    ])

  assert config.port == 8080
  assert config.bind_address == "127.0.0.1"
  assert config.max_body_bytes == 1024
  assert config.render_concurrency == 2
  assert config.render_queue_wait == 100
  assert config.typst
    == typst.Config(
      executable: "/usr/bin/typst",
      themes_directory: "/priv/themes",
      fonts_directory: "/priv/fonts",
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

pub fn reads_admin_and_phone_home_variables_test() {
  let assert Ok(config) =
    parse([
      #("ADMIN_BIND_ADDRESS", "0.0.0.0"),
      #("ADMIN_PORT", "9100"),
      #("PHONE_HOME_TARGET", "collector.local:5140"),
      #("HEARTBEAT_INTERVAL_MS", "2000"),
      #("REQUIRES", " auth, storage ,,"),
      #("GIT_REVISION", "585b6be"),
      #("BUILD_DATE", "2026-11-07T21:00:00Z"),
      #("DEPLOYED_FROM", "ci"),
      #("DEPLOYED_BY", "Jane Roe"),
      #("DEPLOYED_ON", "2026-11-08 10:00:00"),
    ])
  assert config.admin == Admin(bind_address: "0.0.0.0", port: 9100)
  assert config.phone_home
    == PhoneHome(
      target: Some(Target(host: "collector.local", port: 5140)),
      interval: 2000,
      mia_interval: 6000,
      requires: ["auth", "storage"],
      metadata: Metadata(
        git_revision: Some("585b6be"),
        build_date: Some("2026-11-07T21:00:00Z"),
        deployed_from: Some("ci"),
        deployed_by: Some("Jane Roe"),
        deployed_on: Some("2026-11-08 10:00:00"),
      ),
    )
}

pub fn reads_ipv6_phone_home_target_test() {
  let assert Ok(config) = parse([#("PHONE_HOME_TARGET", "[fd00::1]:5140")])
  assert config.phone_home.target == Some(Target(host: "fd00::1", port: 5140))
}

pub fn treats_empty_metadata_as_unset_test() {
  let assert Ok(config) = parse([#("GIT_REVISION", "")])
  assert config.phone_home.metadata.git_revision == None
}

pub fn reports_invalid_phone_home_variables_test() {
  assert parse([
      #("ADMIN_PORT", "8000"),
      #("PHONE_HOME_TARGET", "collector"),
      #("HEARTBEAT_INTERVAL_MS", "5000"),
      #("HEARTBEAT_MIA_MS", "5000"),
    ])
    == Error([
      "ADMIN_PORT must differ from PORT",
      "PHONE_HOME_TARGET must be host:port, got \"collector\"",
      "HEARTBEAT_MIA_MS must be greater than HEARTBEAT_INTERVAL_MS",
    ])
}

pub fn warns_when_heartbeat_links_point_at_loopback_test() {
  let assert Ok(loaded) = parse([#("PHONE_HOME_TARGET", "collector:5140")])
  assert config.warnings(loaded)
    == [
      "ADMIN_BIND_ADDRESS is 127.0.0.1, so collectors cannot follow the "
      <> "links in heartbeats; set it to an address they can reach",
    ]
}

pub fn no_warning_without_heartbeat_or_with_reachable_admin_test() {
  let assert Ok(loaded) = parse([])
  assert config.warnings(loaded) == []
  let assert Ok(loaded) =
    parse([
      #("PHONE_HOME_TARGET", "collector:5140"),
      #("ADMIN_BIND_ADDRESS", "0.0.0.0"),
    ])
  assert config.warnings(loaded) == []
}
