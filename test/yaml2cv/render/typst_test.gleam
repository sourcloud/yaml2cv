import gleam/bit_array
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/string
import simplifile
import yaml2cv/cv.{Style}
import yaml2cv/cv/decode
import yaml2cv/process
import yaml2cv/render.{CompileFailed, RendererUnavailable, TimedOut}
import yaml2cv/render/typst.{type Config, Config}

const work_directory = "build/test-render"

fn config() -> Config {
  // Typst runs inside the job directory, so the font path must be absolute.
  let assert Ok(cwd) = simplifile.current_directory()
  Config(
    executable: "typst",
    themes_directory: "priv/themes",
    fonts_directory: cwd <> "/priv/fonts",
    work_directory:,
    timeout: 10_000,
    generator: "yaml2cv test",
  )
}

fn example_cv() {
  let assert Ok(yaml) = simplifile.read("priv/examples/example.yaml")
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

fn with_theme(cv: cv.Cv, theme: cv.Theme) -> cv.Cv {
  cv.Cv(..cv, style: Style(..cv.style, theme:))
}

pub fn renders_example_cv_in_every_theme_test() {
  use #(_, theme) <- list.each(cv.themes)
  let assert Ok(pdf) =
    typst.render_pdf(config(), with_theme(example_cv(), theme))
  assert bit_array.slice(pdf, 0, 5) == Ok(<<"%PDF-">>)
  assert work_directory_is_empty()
}

pub fn renders_letter_paper_in_every_theme_test() {
  use #(_, theme) <- list.each(cv.themes)
  let cv = with_theme(example_cv(), theme)
  let cv = cv.Cv(..cv, style: Style(..cv.style, paper: cv.Letter))
  // Some themes always start with a cover page; the first page is enough.
  let assert Ok([page, ..]) = typst.render_svg_pages(config(), cv)
  // US letter is 8.5 × 11 in, i.e. 612 × 792 pt.
  assert contains(page, <<"viewBox=\"0 0 612 792\"">>)
}

// PDF metadata describes the candidate (ADR 0036).
pub fn describes_candidate_in_pdf_metadata_in_every_theme_test() {
  use #(name, theme) <- list.each(cv.themes)
  let assert Ok(pdf) =
    typst.render_pdf(config(), with_theme(example_cv(), theme))
  assert #(name, contains(pdf, <<"/Title(John Doe)">>)) == #(name, True)
  assert #(name, contains(pdf, <<"/Author(John Doe)">>)) == #(name, True)
  assert #(name, contains(pdf, <<"/Subject(My personal CV)">>)) == #(name, True)
  assert #(name, contains(pdf, <<"/Keywords(English, Spanish, yaml2cv test)">>))
    == #(name, True)
}

pub fn leaves_out_subject_without_title_and_repeated_skills_test() {
  let assert Ok(cv) =
    decode.from_yaml(
      "
schema_version: 1
person: { name: Jane Roe }
sections:
  - { name: Languages, kind: skills, items: [{ name: English }] }
  - { name: Tools, kind: skills, items: [{ name: Git }, { name: English }] }
",
    )
  use #(name, theme) <- list.each(cv.themes)
  let assert Ok(pdf) = typst.render_pdf(config(), with_theme(cv, theme))
  assert #(name, contains(pdf, <<"/Subject">>)) == #(name, False)
  assert #(name, contains(pdf, <<"/Keywords(English, Git, yaml2cv test)">>))
    == #(name, True)
}

pub fn sets_document_language_in_every_theme_test() {
  let assert Ok(cv) =
    decode.from_yaml(
      "
schema_version: 1
language: de
person: { name: Jane Roe }
sections: [{ name: Profil, kind: text, text: Entwicklerin }]
",
    )
  use #(name, theme) <- list.each(cv.themes)
  let assert Ok(pdf) = typst.render_pdf(config(), with_theme(cv, theme))
  assert #(name, contains(pdf, <<"/Lang(de)">>)) == #(name, True)
  assert #(name, contains(pdf, <<"/Lang(en)">>)) == #(name, False)
}

fn contains(haystack: BitArray, needle: BitArray) -> Bool {
  binary_matches(haystack, needle) != []
}

@external(erlang, "binary", "matches")
fn binary_matches(subject: BitArray, pattern: BitArray) -> List(#(Int, Int))

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
  use #(_, theme) <- list.each(cv.themes)
  let assert Ok(_) = typst.render_pdf(config(), with_theme(cv, theme))
}

pub fn renders_with_shipped_fonts_test() {
  let config = Config(..config(), themes_directory: "test/fixtures/font_themes")
  let assert Ok(pdf) = typst.render_pdf(config, example_cv())
  assert contains(pdf, <<"Inter-Regular">>)
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

pub fn renders_example_cv_to_svg_pages_test() {
  let assert Ok([page]) = typst.render_svg_pages(config(), example_cv())
  assert bit_array.slice(page, 0, 4) == Ok(<<"<svg">>)
  assert work_directory_is_empty()
}

pub fn renders_svg_pages_up_to_the_page_limit_test() {
  let entry = "      - { timespan: '2020', title: Job, bullets: [a, b, c] }\n"
  let yaml =
    "schema_version: 1\nperson: {name: X}\nsections:\n  - name: Work\n    entries:\n"
    <> string.repeat(entry, 300)
  let assert Ok(cv) = decode.from_yaml(yaml)

  let assert Ok(pages) = typst.render_svg_pages(config(), cv)
  assert list.length(pages) == typst.max_preview_pages
  assert work_directory_is_empty()
}

pub fn keeps_render_directories_private_test() {
  let config = Config(..config(), executable: "test/fixtures/bin/mode-typst")
  let assert Error(CompileFailed(job_mode)) =
    typst.render_pdf(config, example_cv())
  assert job_mode == "drwx------\n"

  let assert Ok(info) = simplifile.file_info(work_directory)
  assert int.bitwise_and(info.mode, 0o777) == 0o700
}

fn with_photo(cv: cv.Cv, file: String, format: cv.PhotoFormat) -> cv.Cv {
  let assert Ok(data) = simplifile.read_bits("test/fixtures/" <> file)
  let photo = Some(cv.Photo(format:, data:))
  cv.Cv(..cv, person: cv.Person(..cv.person, photo:))
}

pub fn renders_photo_in_every_theme_and_shape_test() {
  use #(_, theme) <- list.each(cv.themes)
  use #(_, photo_shape) <- list.each(cv.photo_shapes)
  use #(file, format) <- list.each([
    #("photo.jpg", cv.Jpeg),
    #("photo.png", cv.Png),
  ])
  let cv = with_photo(with_theme(example_cv(), theme), file, format)
  let cv = cv.Cv(..cv, style: Style(..cv.style, photo_shape:))
  let assert Ok([page, ..]) = typst.render_svg_pages(config(), cv)
  assert contains(page, <<"<image">>)
  assert work_directory_is_empty()
}

pub fn renders_no_image_without_photo_test() {
  let assert Ok([page, ..]) = typst.render_svg_pages(config(), example_cv())
  assert !contains(page, <<"<image">>)
}

// Machine-readable text (ADR 0035) ------------------------------------------

/// Renders `cv` and returns the text pdftotext extracts from the PDF.
fn extracted_text(cv: cv.Cv) -> String {
  let assert Ok(pdf) = typst.render_pdf(config(), cv)
  let directory = "build/test-extract"
  let assert Ok(_) = simplifile.create_directory_all(directory)
  let file = directory <> "/cv.pdf"
  let assert Ok(_) = simplifile.write_bits(file, pdf)
  let assert Ok(process.Exit(status: 0, output: text)) =
    process.run(
      "pdftotext",
      ["-enc", "UTF-8", file, "-"],
      in: ".",
      timeout: 10_000,
    )
  text
}

fn section_names(cv: cv.Cv) -> List(String) {
  list.map(cv.sections, fn(section) { section.name })
}

pub fn tags_name_and_section_titles_as_headings_in_every_theme_test() {
  use #(name, theme) <- list.each(cv.themes)
  let cv = with_theme(example_cv(), theme)
  let assert Ok(pdf) = typst.render_pdf(config(), cv)
  assert #(name, list.length(binary_matches(pdf, <<"/S/H1">>))) == #(name, 1)
  assert #(name, list.length(binary_matches(pdf, <<"/S/H2">>)))
    == #(name, list.length(cv.sections))
}

pub fn lists_sections_as_bookmarks_in_every_theme_test() {
  use #(name, theme) <- list.each(cv.themes)
  let assert Ok(pdf) =
    typst.render_pdf(config(), with_theme(example_cv(), theme))
  assert #(name, contains(pdf, <<"/Outlines">>)) == #(name, True)
}

pub fn extracts_section_titles_as_words_in_every_theme_test() {
  use #(name, theme) <- list.each(cv.themes)
  let cv = with_theme(example_cv(), theme)
  let text = string.lowercase(extracted_text(cv))
  use section <- list.each(section_names(cv))
  let section = string.lowercase(section)
  assert #(name, section, string.contains(text, section))
    == #(name, section, True)
}

pub fn extracts_link_addresses_in_every_theme_test() {
  let assert Ok(cv) =
    decode.from_yaml(
      "
schema_version: 1
person: { name: Jane Roe }
contact:
  website: https://jane.example.com
  links: [{ label: GitHub, url: 'https://github.com/janeroe' }]
sections: [{ name: Profile, kind: text, text: Engineer }]
",
    )
  use #(name, theme) <- list.each(cv.themes)
  let text = extracted_text(with_theme(cv, theme))
  assert #(name, string.contains(text, "jane.example.com")) == #(name, True)
  assert #(name, string.contains(text, "github.com/janeroe")) == #(name, True)
  assert #(name, string.contains(text, "https://")) == #(name, False)
}

pub fn renders_languages_typst_does_not_know_test() {
  let assert Ok(cv) =
    decode.from_yaml(
      "
schema_version: 1
language: xx
person: { name: Jane Roe }
sections: [{ name: Profile, kind: text, text: Engineer }]
",
    )
  use #(_, theme) <- list.each(cv.themes)
  let assert Ok(pdf) = typst.render_pdf(config(), with_theme(cv, theme))
  assert contains(pdf, <<"/Lang(xx)">>)
}
