import gleam/http
import gleam/http/request
import gleam/list
import gleam/option.{None, Some}
import wisp/simulate
import yaml2cv/cv
import yaml2cv/cv/decode
import yaml2cv/web/i18n.{De, En}

pub fn code_round_trip_test() {
  assert i18n.all == [En, De]
  assert i18n.code(En) == "en"
  assert i18n.code(De) == "de"
  assert i18n.parse("de") == Ok(De)
  assert i18n.parse("en") == Ok(En)
  assert i18n.parse("DE") == Ok(De)
  assert i18n.parse("fr") == Error(Nil)
  assert i18n.parse("") == Error(Nil)
}

pub fn negotiate_defaults_to_english_test() {
  assert i18n.negotiate("") == En
  assert i18n.negotiate("fr, es;q=0.5") == En
  assert i18n.negotiate("*") == En
  assert i18n.negotiate(";;;,,q=") == En
}

pub fn negotiate_picks_primary_subtag_test() {
  assert i18n.negotiate("de") == De
  assert i18n.negotiate("de-AT") == De
  assert i18n.negotiate("fr-CH, de;q=0.8, en;q=0.5") == De
}

pub fn negotiate_honours_weights_test() {
  assert i18n.negotiate("en;q=0.4, de;q=0.9") == De
  assert i18n.negotiate("de;q=0.4, en") == En
  assert i18n.negotiate("de;q=0, en;q=0.1") == En
  assert i18n.negotiate("de;q=0") == En
  // Equal weights keep the listed order.
  assert i18n.negotiate("de, en") == De
}

pub fn from_request_precedence_test() {
  let base =
    simulate.request(http.Get, "/")
    |> request.set_header("accept-language", "de")
  assert i18n.from_request(base, None) == De
  assert i18n.from_request(
      base |> request.set_header("x-yaml2cv-lang", "en"),
      None,
    )
    == En
  assert i18n.from_request(
      simulate.request(http.Get, "/?lang=en")
        |> request.set_header("x-yaml2cv-lang", "de"),
      None,
    )
    == En
  assert i18n.from_request(simulate.request(http.Get, "/?lang=en"), Some("de"))
    == De
  // Unknown values fall through to the next source.
  assert i18n.from_request(
      base |> request.set_header("x-yaml2cv-lang", "fr"),
      Some("xx"),
    )
    == De
  assert i18n.from_request(simulate.request(http.Get, "/"), None) == En
}

pub fn texts_per_locale_test() {
  assert i18n.texts(En).editor.download_pdf == "Download PDF"
  assert i18n.texts(De).editor.download_pdf == "PDF herunterladen"
  assert i18n.texts(En).editor.problems(1) == "1 problem"
  assert i18n.texts(De).editor.problems(3) == "3 Probleme"
}

pub fn english_schema_problems_match_the_api_test() {
  let problem = decode.ExpectedOneOf(["a", "b"])
  assert i18n.texts(En).editor.schema_problem(problem)
    == decode.describe(problem)
  assert i18n.texts(De).editor.schema_problem(problem)
    != decode.describe(problem)
}

pub fn every_style_option_has_a_label_test() {
  let names =
    list.flatten([
      list.map(cv.themes, fn(option) { option.0 }),
      list.map(cv.colors, fn(option) { option.0 }),
      list.map(cv.papers, fn(option) { option.0 }),
      list.map(cv.photo_shapes, fn(option) { option.0 }),
    ])
  list.each(i18n.all, fn(locale) {
    let texts = i18n.texts(locale)
    list.each(names, fn(name) {
      // The fallback returns the YAML name unchanged.
      assert texts.visual.option(name) != name as name
    })
  })
}
