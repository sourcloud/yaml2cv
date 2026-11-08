//// Languages of the web UI and how a request picks one (ADR 0025).

import gleam/float
import gleam/http/request
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import wisp.{type Request}

/// A supported UI language.
pub type Locale {
  En
  De
}

/// Every supported locale, the default first.
pub const all = [En, De]

/// The request header htmx sends with the page's locale.
pub const header = "x-yaml2cv-lang"

/// The ISO 639-1 code of a locale, as used in `lang` attributes.
pub fn code(locale: Locale) -> String {
  case locale {
    En -> "en"
    De -> "de"
  }
}

/// The name of a locale in its own language.
pub fn endonym(locale: Locale) -> String {
  case locale {
    En -> "English"
    De -> "Deutsch"
  }
}

/// The locale with the given code, ignoring case.
pub fn parse(code: String) -> Result(Locale, Nil) {
  case string.lowercase(code) {
    "en" -> Ok(En)
    "de" -> Ok(De)
    _ -> Error(Nil)
  }
}

/// The best supported locale for an `Accept-Language` header value: the
/// one with the highest weight, matched by primary subtag (`de-AT` is
/// German). Ties keep the listed order; English when nothing matches.
pub fn negotiate(accept_language: String) -> Locale {
  accept_language
  |> string.split(",")
  |> list.filter_map(fn(range) {
    let #(tag, parameters) = case string.split(range, ";") {
      [tag, ..parameters] -> #(tag, parameters)
      [] -> #("", [])
    }
    let primary = case string.split_once(string.trim(tag), "-") {
      Ok(#(primary, _region)) -> primary
      Error(Nil) -> string.trim(tag)
    }
    use locale <- result.try(parse(primary))
    case weight(parameters) {
      weight if weight >. 0.0 -> Ok(#(locale, weight))
      _ -> Error(Nil)
    }
  })
  |> list.fold(#(En, 0.0), fn(best, candidate) {
    case candidate.1 >. best.1 {
      True -> candidate
      False -> best
    }
  })
  |> fn(best) { best.0 }
}

/// The `q` parameter of a language range; 1 when absent, 0 when invalid.
fn weight(parameters: List(String)) -> Float {
  let q =
    list.find_map(parameters, fn(parameter) {
      case string.split_once(string.trim(parameter), "=") {
        Ok(#("q", value)) -> Ok(string.trim(value))
        _ -> Error(Nil)
      }
    })
  case q {
    Error(Nil) -> 1.0
    Ok(value) ->
      float.parse(value)
      |> result.lazy_or(fn() { int.parse(value) |> result.map(int.to_float) })
      |> result.unwrap(0.0)
  }
}

/// The locale for a request, from the first source that names a supported
/// one: `form_lang` (a posted `lang` field), the `lang` query parameter,
/// the `x-yaml2cv-lang` header, then `Accept-Language`.
pub fn from_request(request: Request, form_lang: Option(String)) -> Locale {
  let query = wisp.get_query(request) |> list.key_find("lang")
  let explicit =
    [
      option.to_result(form_lang, Nil),
      query,
      request.get_header(request, header),
    ]
    |> list.find_map(fn(value) { result.try(value, parse) })
  use <- result.lazy_unwrap(explicit)
  request.get_header(request, "accept-language")
  |> result.unwrap("")
  |> negotiate
}
