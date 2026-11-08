import gleam/bit_array
import gleam/list
import gleam/string
import simplifile
import yaml2cv/cv/decode
import yaml2cv/render.{CompileFailed, RendererUnavailable, TimedOut}
import yaml2cv/render/typst.{type Config, Config}

const work_directory = "build/test-render"

fn config() -> Config {
  Config(
    executable: "typst",
    themes_directory: "priv/themes",
    work_directory:,
    timeout: 10_000,
  )
}

fn example_cv() {
  let assert Ok(yaml) = simplifile.read("test/fixtures/example.yaml")
  let assert Ok(cv) = decode.from_yaml(yaml)
  cv
}

fn work_directory_is_empty() -> Bool {
  simplifile.read_directory(work_directory) == Ok([])
}

pub fn renders_example_cv_to_pdf_test() {
  let assert Ok(pdf) = typst.render_pdf(config(), example_cv())
  assert bit_array.slice(pdf, 0, 5) == Ok(<<"%PDF-">>)
  assert work_directory_is_empty()
}

pub fn treats_user_content_as_text_not_markup_test() {
  let assert Ok(cv) =
    decode.from_yaml(
      "
schema_version: 1
person: { name: '#panic(\"injected\")' }
sections:
  - { name: '#read(\"/etc/passwd\")', kind: text, text: '$ \\\\ #{ ] *_' }
",
    )
  let assert Ok(_) = typst.render_pdf(config(), cv)
}

pub fn reports_compile_errors_test() {
  let config =
    Config(..config(), themes_directory: "test/fixtures/broken_themes")
  let assert Error(CompileFailed(output)) =
    typst.render_pdf(config, example_cv())
  assert string.contains(output, "unknown variable: undefined-function")
  assert work_directory_is_empty()
}

pub fn times_out_slow_compiles_test() {
  let config =
    Config(..config(), executable: "test/fixtures/bin/slow-typst", timeout: 100)
  assert typst.render_pdf(config, example_cv()) == Error(TimedOut)
  assert work_directory_is_empty()
}

pub fn reports_missing_executable_test() {
  let config = Config(..config(), executable: "yaml2cv-no-typst")
  let assert Error(RendererUnavailable(_)) =
    typst.render_pdf(config, example_cv())
}

pub fn renders_example_cv_to_png_pages_test() {
  let assert Ok([page]) = typst.render_png_pages(config(), example_cv())
  assert bit_array.slice(page, 0, 4) == Ok(<<137, "PNG":utf8>>)
  assert work_directory_is_empty()
}

pub fn renders_png_pages_up_to_the_page_limit_test() {
  let entry = "      - { timespan: '2020', title: Job, bullets: [a, b, c] }\n"
  let yaml =
    "schema_version: 1\nperson: {name: X}\nsections:\n  - name: Work\n    entries:\n"
    <> string.repeat(entry, 300)
  let assert Ok(cv) = decode.from_yaml(yaml)

  let assert Ok(pages) = typst.render_png_pages(config(), cv)
  assert list.length(pages) == typst.max_preview_pages
  assert work_directory_is_empty()
}
