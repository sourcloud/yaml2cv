//// The visual editor: drafts as building blocks (ADR 0024).
////
//// The blocks form posts every edit to `/editor/visual/update`. Typing
//// leaves the blocks in place (`hx-swap="none"`); structural buttons (add,
//// remove, move) replace the form with the re-rendered blocks. Either way
//// the response carries the regenerated YAML out of band in `sync_id`,
//// which `editor.js` copies into the YAML source field.

import gleam/int
import gleam/list
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html
import yaml2cv/cv
import yaml2cv/cv/decode
import yaml2cv/cv/draft.{
  type Draft, type Entry, type Link, type Section, type Skill, Entries, Skills,
  Text,
}
import yaml2cv/web/ui/alert
import yaml2cv/web/ui/block
import yaml2cv/web/ui/button
import yaml2cv/web/ui/field.{Optional, Required}
import yaml2cv/web/visual_form.{
  type ListRef, type Op, Add, AddSection, Bullets, EntriesOf, Links, MoveDown,
  MoveUp, Remove, Sections, SkillsOf,
}

/// The id of the blocks form.
pub const form_id = "visual-form"

/// The id of the element that carries regenerated YAML to `editor.js`.
pub const sync_id = "yaml-sync"

const update_path = "/editor/visual/update"

/// The blocks form for `draft`.
pub fn view(draft: Draft) -> Element(message) {
  html.form(
    [
      attribute.id(form_id),
      attribute.class("visual-editor"),
      attribute.attribute("hx-post", update_path),
      // `flush` sends pending edits at once, before leaving visual mode.
      attribute.attribute("hx-trigger", "input delay:300ms, flush"),
      attribute.attribute("hx-swap", "none"),
      attribute.attribute("hx-sync", "this:queue all"),
    ],
    [
      alert.view(alert.Info, "Editing here rewrites the YAML", [
        html.text(
          "The first change made with the blocks rewrites the YAML in a uniform layout; comments and custom formatting are removed.",
        ),
      ]),
      style_block(draft.style),
      person_block(draft.person),
      contact_block(draft.contact),
      list_of(
        "Sections",
        list.index_map(draft.sections, fn(section, index) {
          section_block(section, index, list.length(draft.sections))
        }),
        list.map(cv_section_kinds(), fn(kind) {
          op_button(AddSection(kind.0), "Add " <> kind.1 <> " section", "")
        }),
      ),
    ],
  )
}

/// An empty placeholder for `sync`, rendered once in the page.
pub fn sync_placeholder() -> Element(message) {
  html.div([attribute.id(sync_id), attribute.attribute("hidden", "")], [])
}

/// The regenerated YAML, swapped out of band into `sync_placeholder`.
pub fn sync(yaml: String) -> Element(message) {
  html.textarea(
    [
      attribute.id(sync_id),
      attribute.attribute("hidden", ""),
      attribute.attribute("hx-swap-oob", "true"),
      attribute.data("yaml-sync", ""),
      attribute.aria_hidden(True),
    ],
    yaml,
  )
}

// --- Blocks ------------------------------------------------------------------

fn style_block(style: draft.Style) -> Element(message) {
  let default = cv.default_style
  block.view(title: "Style", actions: [], body: [
    choice("style.theme", "Theme", cv.themes, default.theme, style.theme),
    choice("style.color", "Colour", cv.colors, default.color, style.color),
    choice("style.paper", "Paper", cv.papers, default.paper, style.paper),
  ])
}

/// A select of the YAML names in `options`; `""` stands for the default.
fn choice(
  name: String,
  label: String,
  options: List(#(String, a)),
  default: a,
  value: String,
) -> Element(message) {
  let default_name = case
    list.find(options, fn(option) { option.1 == default })
  {
    Ok(option) -> option.0
    Error(Nil) -> ""
  }
  field.select(
    name:,
    label:,
    options: [
      #("", "Default (" <> default_name <> ")"),
      ..list.map(options, fn(option) { #(option.0, option.0) })
    ],
    value:,
  )
}

fn person_block(person: draft.Person) -> Element(message) {
  block.view(title: "Person", actions: [], body: [
    text("person.name", "Name", person.name, Required),
    text("person.title", "Title", person.title, Optional),
    text("person.address", "Address", person.address, Optional),
  ])
}

fn contact_block(contact: draft.Contact) -> Element(message) {
  let count = list.length(contact.links)
  block.view(title: "Contact", actions: [], body: [
    text("contact.email", "Email", contact.email, Optional),
    text("contact.phone", "Phone", contact.phone, Optional),
    text("contact.website", "Website", contact.website, Optional),
    list_of(
      "Links",
      list.index_map(contact.links, fn(link, index) {
        link_block(link, index, count)
      }),
      [op_button(Add(Links), "Add link", "")],
    ),
  ])
}

fn link_block(link: Link, index: Int, count: Int) -> Element(message) {
  let prefix = visual_form.item_name(Links, index)
  block.view(
    title: "Link " <> int.to_string(index + 1),
    actions: item_actions(Links, index, count, "link"),
    body: [
      text(prefix <> ".label", "Label", link.label, Required),
      text(prefix <> ".url", "URL", link.url, Required),
    ],
  )
}

fn section_block(section: Section, index: Int, count: Int) -> Element(message) {
  let prefix = visual_form.item_name(Sections, index)
  let kind = draft.kind_name(section.content)
  let content = case section.content {
    Entries(entries) -> {
      let count = list.length(entries)
      list_of(
        "Entries",
        list.index_map(entries, fn(entry, item) {
          entry_block(entry, index, item, count)
        }),
        [op_button(Add(EntriesOf(index)), "Add entry", "")],
      )
    }
    Skills(skills) -> {
      let count = list.length(skills)
      list_of(
        "Skills",
        list.index_map(skills, fn(skill, item) {
          skill_block(skill, index, item, count)
        }),
        [op_button(Add(SkillsOf(index)), "Add skill", "")],
      )
    }
    Text(value) ->
      field.textarea(
        name: prefix <> ".text",
        label: "Text",
        value:,
        requirement: Required,
      )
  }
  block.view(
    title: kind_label(kind) <> " section",
    actions: item_actions(Sections, index, count, "section"),
    body: [
      html.input([
        attribute.type_("hidden"),
        attribute.name(prefix <> ".kind"),
        attribute.value(kind),
      ]),
      text(prefix <> ".name", "Heading", section.name, Required),
      content,
    ],
  )
}

fn entry_block(
  entry: Entry,
  section: Int,
  index: Int,
  count: Int,
) -> Element(message) {
  let ref = EntriesOf(section)
  let prefix = visual_form.item_name(ref, index)
  let bullets = Bullets(section, index)
  let bullet_count = list.length(entry.bullets)
  block.view(
    title: "Entry " <> int.to_string(index + 1),
    actions: item_actions(ref, index, count, "entry"),
    body: [
      text(prefix <> ".timespan", "Timespan", entry.timespan, Required),
      text(prefix <> ".title", "Title", entry.title, Required),
      text(
        prefix <> ".organization",
        "Organisation",
        entry.organization,
        Optional,
      ),
      text(prefix <> ".location", "Location", entry.location, Optional),
      list_of(
        "Bullets",
        list.index_map(entry.bullets, fn(bullet, item) {
          html.div([attribute.class("visual-editor__row")], [
            text(
              visual_form.item_name(bullets, item),
              "Bullet " <> int.to_string(item + 1),
              bullet,
              Required,
            ),
            html.div(
              [attribute.class("visual-editor__row-actions")],
              item_actions(bullets, item, bullet_count, "bullet"),
            ),
          ])
        }),
        [op_button(Add(bullets), "Add bullet", "")],
      ),
    ],
  )
}

fn skill_block(
  skill: Skill,
  section: Int,
  index: Int,
  count: Int,
) -> Element(message) {
  let ref = SkillsOf(section)
  let prefix = visual_form.item_name(ref, index)
  block.view(
    title: "Skill " <> int.to_string(index + 1),
    actions: item_actions(ref, index, count, "skill"),
    body: [
      text(prefix <> ".name", "Name", skill.name, Required),
      text(prefix <> ".level", "Level", skill.level, Optional),
    ],
  )
}

// --- Parts -------------------------------------------------------------------

fn text(
  name: String,
  label: String,
  value: String,
  requirement: field.Requirement,
) -> Element(message) {
  field.text(name:, label:, value:, requirement:)
}

/// A labelled list of blocks followed by its add buttons.
fn list_of(
  label: String,
  items: List(Element(message)),
  add: List(Element(message)),
) -> Element(message) {
  html.div(
    [
      attribute.class("ui-block-list"),
      attribute.role("group"),
      attribute.aria("label", label),
    ],
    list.append(items, [
      html.div([attribute.class("visual-editor__add")], add),
    ]),
  )
}

/// Move up, move down and remove buttons for item `index` of `count`.
fn item_actions(
  ref: ListRef,
  index: Int,
  count: Int,
  noun: String,
) -> List(Element(message)) {
  let which = noun <> " " <> int.to_string(index + 1)
  list.flatten([
    case index > 0 {
      True -> [op_button(MoveUp(ref, index), "↑", "Move " <> which <> " up")]
      False -> []
    },
    case index + 1 < count {
      True -> [
        op_button(MoveDown(ref, index), "↓", "Move " <> which <> " down"),
      ]
      False -> []
    },
    [op_button(Remove(ref, index), "Remove", "Remove " <> which)],
  ])
}

/// A button that posts the form with `op` and replaces it with the result.
/// `description` labels it for assistive technology when `label` is terse.
fn op_button(op: Op, label: String, description: String) -> Element(message) {
  let variant = case op {
    AddSection(..) | Add(..) -> button.Secondary
    _ -> button.Quiet
  }
  button.view(
    variant,
    [
      attribute.type_("button"),
      attribute.name("op"),
      attribute.value(visual_form.op_value(op)),
      attribute.attribute("hx-post", update_path),
      attribute.attribute("hx-target", "#" <> form_id),
      attribute.attribute("hx-swap", "outerHTML"),
      attribute.attribute("hx-sync", "closest form:queue all"),
      ..described(description)
    ],
    label,
  )
}

fn described(description: String) -> List(Attribute(message)) {
  case description {
    "" -> []
    _ -> [attribute.aria_label(description), attribute.title(description)]
  }
}

fn cv_section_kinds() -> List(#(String, String)) {
  list.map(decode.section_kinds, fn(kind) { #(kind.0, kind.0) })
}

fn kind_label(kind: String) -> String {
  case kind {
    "skills" -> "Skills"
    "text" -> "Text"
    _ -> "Entries"
  }
}
