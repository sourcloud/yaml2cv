//// Encodes a validated CV as JSON, the data format handed to renderers
//// (ADR 0003). Missing optional values become `null`; every section carries
//// an explicit `kind`.

import gleam/json.{type Json}
import yaml2cv/cv.{
  type Color, type Contact, type Cv, type Entry, type Person, type Section,
  type Skill, type Style, type Theme,
}

/// Encodes a CV as a JSON value.
pub fn to_json(cv: Cv) -> Json {
  json.object([
    #("style", style(cv.style)),
    #("person", person(cv.person)),
    #("contact", contact(cv.contact)),
    #("sections", json.array(cv.sections, section)),
  ])
}

fn style(style: Style) -> Json {
  json.object([
    #("theme", json.string(theme_name(style.theme))),
    #("color", json.string(color_name(style.color))),
  ])
}

fn theme_name(theme: Theme) -> String {
  case theme {
    cv.Classic -> "classic"
  }
}

fn color_name(color: Color) -> String {
  case color {
    cv.Black -> "black"
    cv.Blue -> "blue"
    cv.Burgundy -> "burgundy"
    cv.Green -> "green"
    cv.Grey -> "grey"
    cv.Orange -> "orange"
    cv.Purple -> "purple"
    cv.Red -> "red"
  }
}

fn person(person: Person) -> Json {
  json.object([
    #("name", json.string(person.name)),
    #("title", json.nullable(person.title, json.string)),
    #("address", json.nullable(person.address, json.string)),
  ])
}

fn contact(contact: Contact) -> Json {
  json.object([
    #("email", json.nullable(contact.email, json.string)),
    #("phone", json.nullable(contact.phone, json.string)),
    #("website", json.nullable(contact.website, json.string)),
    #(
      "links",
      json.array(contact.links, fn(link) {
        json.object([
          #("label", json.string(link.label)),
          #("url", json.string(link.url)),
        ])
      }),
    ),
  ])
}

fn section(section: Section) -> Json {
  let content = case section.content {
    cv.Entries(entries) -> [
      #("kind", json.string("entries")),
      #("entries", json.array(entries, entry)),
    ]
    cv.Skills(items) -> [
      #("kind", json.string("skills")),
      #("items", json.array(items, skill)),
    ]
    cv.Text(text) -> [
      #("kind", json.string("text")),
      #("text", json.string(text)),
    ]
  }
  json.object([#("name", json.string(section.name)), ..content])
}

fn entry(entry: Entry) -> Json {
  json.object([
    #("timespan", json.string(entry.timespan)),
    #("title", json.string(entry.title)),
    #("organization", json.nullable(entry.organization, json.string)),
    #("location", json.nullable(entry.location, json.string)),
    #("bullets", json.array(entry.bullets, json.string)),
  ])
}

fn skill(skill: Skill) -> Json {
  json.object([
    #("name", json.string(skill.name)),
    #("level", json.nullable(skill.level, json.string)),
  ])
}
