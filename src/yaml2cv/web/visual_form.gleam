//// The visual editor's form (ADR 0024): drafts as named form fields and
//// back, and the structural edits its buttons request.
////
//// Field names are dotted paths through the document, such as
//// `person.name`, `sections.1.entries.0.title` or
//// `sections.1.entries.0.bullets.2`. Every section carries a hidden
//// `sections.N.kind` field, so empty sections keep their kind.

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import yaml2cv/cv/decode
import yaml2cv/cv/draft.{
  type Draft, type Entry, type Section, Contact, Draft, Entries, Entry, Link,
  Person, Section, Skill, Skills, Style, Text,
}

/// A list in the draft that blocks can be added to, removed from or moved
/// within.
pub type ListRef {
  Links
  Sections
  /// The entries of the section at this index.
  EntriesOf(section: Int)
  /// The skills of the section at this index.
  SkillsOf(section: Int)
  /// The bullets of one entry of one section.
  Bullets(section: Int, entry: Int)
}

/// A structural edit requested by a block button.
pub type Op {
  /// Appends a blank section of the given kind.
  AddSection(kind: String)
  /// Appends a blank item to the list.
  Add(ListRef)
  Remove(ListRef, index: Int)
  MoveUp(ListRef, index: Int)
  MoveDown(ListRef, index: Int)
}

// --- Field names -------------------------------------------------------------

/// Joins path segments into a field name.
pub fn name(segments: List(String)) -> String {
  string.join(segments, ".")
}

/// The field name of a list, e.g. `sections.1.entries`.
pub fn list_name(ref: ListRef) -> String {
  case ref {
    Links -> "contact.links"
    Sections -> "sections"
    EntriesOf(section:) -> name(["sections", int.to_string(section), "entries"])
    SkillsOf(section:) -> name(["sections", int.to_string(section), "items"])
    Bullets(section:, entry:) ->
      name([
        "sections",
        int.to_string(section),
        "entries",
        int.to_string(entry),
        "bullets",
      ])
  }
}

/// The field name of an item in a list, e.g. `sections.1.entries.0`.
pub fn item_name(ref: ListRef, index: Int) -> String {
  list_name(ref) <> "." <> int.to_string(index)
}

/// An op as the value of its button.
pub fn op_value(op: Op) -> String {
  case op {
    AddSection(kind:) -> "add-section:" <> kind
    Add(ref) -> "add:" <> list_name(ref)
    Remove(ref, index:) -> "remove:" <> item_name(ref, index)
    MoveUp(ref, index:) -> "up:" <> item_name(ref, index)
    MoveDown(ref, index:) -> "down:" <> item_name(ref, index)
  }
}

// --- Draft to fields ---------------------------------------------------------

/// Every form field of the draft, named by path, in document order.
pub fn fields(draft: Draft) -> List(#(String, String)) {
  list.flatten([
    [
      #("style.theme", draft.style.theme),
      #("style.color", draft.style.color),
      #("style.paper", draft.style.paper),
      #("person.name", draft.person.name),
      #("person.title", draft.person.title),
      #("person.address", draft.person.address),
      #("contact.email", draft.contact.email),
      #("contact.phone", draft.contact.phone),
      #("contact.website", draft.contact.website),
    ],
    list.index_map(draft.contact.links, fn(link, index) {
      let prefix = item_name(Links, index)
      [#(prefix <> ".label", link.label), #(prefix <> ".url", link.url)]
    })
      |> list.flatten,
    list.index_map(draft.sections, section_fields) |> list.flatten,
  ])
}

fn section_fields(section: Section, index: Int) -> List(#(String, String)) {
  let prefix = item_name(Sections, index)
  let content = case section.content {
    Text(text) -> [#(prefix <> ".text", text)]
    Skills(skills) ->
      list.index_map(skills, fn(skill, item) {
        let prefix = item_name(SkillsOf(index), item)
        [#(prefix <> ".name", skill.name), #(prefix <> ".level", skill.level)]
      })
      |> list.flatten
    Entries(entries) ->
      list.index_map(entries, fn(entry, item) {
        let prefix = item_name(EntriesOf(index), item)
        [
          #(prefix <> ".timespan", entry.timespan),
          #(prefix <> ".title", entry.title),
          #(prefix <> ".organization", entry.organization),
          #(prefix <> ".location", entry.location),
          ..list.index_map(entry.bullets, fn(bullet, bullet_index) {
            #(item_name(Bullets(index, item), bullet_index), bullet)
          })
        ]
      })
      |> list.flatten
  }
  [
    #(prefix <> ".kind", draft.kind_name(section.content)),
    #(prefix <> ".name", section.name),
    ..content
  ]
}

// --- Fields to draft ---------------------------------------------------------

/// The submitted fields by name, and the item count of every list, keyed
/// by the list's name. Both are built in one pass, so parsing stays linear
/// in the number of fields.
type Form {
  Form(values: Dict(String, String), counts: Dict(String, Int))
}

/// Rebuilds a draft from submitted form fields. Missing fields are empty;
/// unknown fields and section kinds are ignored.
pub fn parse(values: List(#(String, String))) -> Draft {
  // A list cannot have more items than the form has fields; larger indices
  // are ignored so a crafted name cannot allocate a huge list.
  let max_items = list.length(values)
  let form =
    list.fold(values, Form(dict.new(), dict.new()), fn(form, pair) {
      let #(name, value) = pair
      Form(
        values: dict.insert(
          form.values,
          name,
          string.replace(value, "\r\n", "\n"),
        ),
        counts: count_indices(form.counts, string.split(name, "."), max_items),
      )
    })
  Draft(
    style: Style(
      theme: get(form, "style.theme"),
      color: get(form, "style.color"),
      paper: get(form, "style.paper"),
    ),
    person: Person(
      name: get(form, "person.name"),
      title: get(form, "person.title"),
      address: get(form, "person.address"),
    ),
    contact: Contact(
      email: get(form, "contact.email"),
      phone: get(form, "contact.phone"),
      website: get(form, "contact.website"),
      links: items(form, Links, fn(prefix) {
        Link(
          label: get(form, prefix <> ".label"),
          url: get(form, prefix <> ".url"),
        )
      }),
    ),
    sections: items_indexed(form, Sections, fn(prefix, index) {
      parse_section(form, prefix, index)
    }),
  )
}

fn parse_section(form: Form, prefix: String, index: Int) -> Section {
  let content = case get(form, prefix <> ".kind") {
    "text" -> Text(get(form, prefix <> ".text"))
    "skills" ->
      Skills(
        items(form, SkillsOf(index), fn(prefix) {
          Skill(
            name: get(form, prefix <> ".name"),
            level: get(form, prefix <> ".level"),
          )
        }),
      )
    _ ->
      Entries(
        items_indexed(form, EntriesOf(index), fn(prefix, entry) {
          Entry(
            timespan: get(form, prefix <> ".timespan"),
            title: get(form, prefix <> ".title"),
            organization: get(form, prefix <> ".organization"),
            location: get(form, prefix <> ".location"),
            bullets: items(form, Bullets(index, entry), get(form, _)),
          )
        }),
      )
  }
  Section(name: get(form, prefix <> ".name"), content:)
}

fn get(form: Form, name: String) -> String {
  dict.get(form.values, name) |> result.unwrap("")
}

/// Records, for every numeric segment of a field name, that the list named
/// by the segments before it has at least that index plus one items.
fn count_indices(
  counts: Dict(String, Int),
  segments: List(String),
  max_items: Int,
) -> Dict(String, Int) {
  let #(counts, _) =
    list.fold(segments, #(counts, []), fn(state, segment) {
      let #(counts, before) = state
      let counts = case before, int.parse(segment) {
        [_, ..], Ok(index) if index >= 0 && index < max_items -> {
          let list_name = name(list.reverse(before))
          let count = dict.get(counts, list_name) |> result.unwrap(0)
          dict.insert(counts, list_name, int.max(count, index + 1))
        }
        _, _ -> counts
      }
      #(counts, [segment, ..before])
    })
  counts
}

fn items(form: Form, ref: ListRef, item: fn(String) -> a) -> List(a) {
  items_indexed(form, ref, fn(prefix, _) { item(prefix) })
}

/// The items of a list, one per index used by any field below it.
fn items_indexed(
  form: Form,
  ref: ListRef,
  item: fn(String, Int) -> a,
) -> List(a) {
  let count = dict.get(form.counts, list_name(ref)) |> result.unwrap(0)
  list.repeat(Nil, count)
  |> list.index_map(fn(_, index) { item(item_name(ref, index), index) })
}

// --- Ops ---------------------------------------------------------------------

/// Reads an op from its button value; unknown ops are an error.
pub fn parse_op(value: String) -> Result(Op, Nil) {
  use #(action, path) <- result.try(string.split_once(value, ":"))
  case action {
    "add-section" ->
      case list.key_find(decode.section_kinds, path) {
        Ok(_) -> Ok(AddSection(path))
        Error(Nil) -> Error(Nil)
      }
    "add" -> parse_list(string.split(path, ".")) |> result.map(Add)
    "remove" ->
      parse_item(path) |> result.map(fn(item) { Remove(item.0, item.1) })
    "up" -> parse_item(path) |> result.map(fn(item) { MoveUp(item.0, item.1) })
    "down" ->
      parse_item(path) |> result.map(fn(item) { MoveDown(item.0, item.1) })
    _ -> Error(Nil)
  }
}

fn parse_item(path: String) -> Result(#(ListRef, Int), Nil) {
  let segments = string.split(path, ".")
  use index <- result.try(list.last(segments) |> result.try(int.parse))
  use ref <- result.try(
    parse_list(list.take(segments, list.length(segments) - 1)),
  )
  Ok(#(ref, index))
}

fn parse_list(segments: List(String)) -> Result(ListRef, Nil) {
  case segments {
    ["contact", "links"] -> Ok(Links)
    ["sections"] -> Ok(Sections)
    ["sections", section, "entries"] ->
      int.parse(section) |> result.map(EntriesOf)
    ["sections", section, "items"] -> int.parse(section) |> result.map(SkillsOf)
    ["sections", section, "entries", entry, "bullets"] -> {
      use section <- result.try(int.parse(section))
      use entry <- result.try(int.parse(entry))
      Ok(Bullets(section, entry))
    }
    _ -> Error(Nil)
  }
}

/// What an op does to one list.
type Edit {
  Append
  RemoveAt(Int)
  /// Swaps the items at this index and the next.
  SwapWithNext(Int)
}

/// Applies an op. Ops on lists or items that do not exist change nothing.
pub fn apply(draft: Draft, op: Op) -> Draft {
  case op {
    AddSection(kind:) ->
      Draft(
        ..draft,
        sections: list.append(draft.sections, [
          draft.blank_section(kind),
        ]),
      )
    Add(ref) -> edit(draft, ref, Append)
    Remove(ref, index:) -> edit(draft, ref, RemoveAt(index))
    MoveUp(ref, index:) -> edit(draft, ref, SwapWithNext(index - 1))
    MoveDown(ref, index:) -> edit(draft, ref, SwapWithNext(index))
  }
}

fn edit(draft: Draft, ref: ListRef, edit: Edit) -> Draft {
  case ref {
    Links ->
      Draft(
        ..draft,
        contact: Contact(
          ..draft.contact,
          links: edit_list(draft.contact.links, edit, draft.blank_link),
        ),
      )
    Sections ->
      Draft(
        ..draft,
        sections: edit_list(draft.sections, edit, draft.blank_section("")),
      )
    EntriesOf(section:) ->
      update_section(draft, section, fn(content) {
        case content {
          Entries(entries) ->
            Entries(edit_list(entries, edit, draft.blank_entry))
          other -> other
        }
      })
    SkillsOf(section:) ->
      update_section(draft, section, fn(content) {
        case content {
          Skills(skills) -> Skills(edit_list(skills, edit, draft.blank_skill))
          other -> other
        }
      })
    Bullets(section:, entry:) ->
      update_section(draft, section, fn(content) {
        case content {
          Entries(entries) ->
            Entries(
              update_at(entries, entry, fn(entry: Entry) {
                Entry(..entry, bullets: edit_list(entry.bullets, edit, ""))
              }),
            )
          other -> other
        }
      })
  }
}

fn update_section(
  draft: Draft,
  index: Int,
  with: fn(draft.Content) -> draft.Content,
) -> Draft {
  Draft(
    ..draft,
    sections: update_at(draft.sections, index, fn(section: Section) {
      Section(..section, content: with(section.content))
    }),
  )
}

fn update_at(items: List(a), index: Int, with: fn(a) -> a) -> List(a) {
  list.index_map(items, fn(item, at) {
    case at == index {
      True -> with(item)
      False -> item
    }
  })
}

fn edit_list(items: List(a), edit: Edit, blank: a) -> List(a) {
  let count = list.length(items)
  case edit {
    Append -> list.append(items, [blank])
    RemoveAt(index) if index >= 0 && index < count ->
      list.append(list.take(items, index), list.drop(items, index + 1))
    SwapWithNext(index) if index >= 0 && index + 1 < count -> {
      let before = list.take(items, index)
      case list.drop(items, index) {
        [first, second, ..after] ->
          list.flatten([before, [second, first], after])
        _ -> items
      }
    }
    _ -> items
  }
}
