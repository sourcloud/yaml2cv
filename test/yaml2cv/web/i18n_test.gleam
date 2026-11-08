import gleam/http
import gleam/http/request
import gleam/option.{None, Some}
import wisp/simulate
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
