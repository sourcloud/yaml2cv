# 0025. Localise the web UI

- Status: Accepted
- Date: 2026-11-08

## Context

The browser editor speaks English only. German-speaking users want the
interface in their language, and more languages may follow. The UI is
rendered on the server (ADR 0004, 0011): htmx fragments such as the
validation status and the visual blocks carry text too, so the server must
know the language on every request. The server is stateless and sets no
cookies (ADR 0012). The HTTP API (ADR 0010) is consumed by programs and
keeps its English messages.

## Options

For remembering the choice and telling the server:

1. **Cookie, falling back to `Accept-Language`** — sent with every request
   automatically; adds the first cookie to a cookie-free service.
2. **Locale in the URL (`/de/…`)** — no storage; every route and htmx
   endpoint needs a prefix, and a bare `/` forgets the choice.
3. **`localStorage` plus request data** — like the theme switch (ADR 0012);
   no cookie, but full page loads cannot carry a custom header, so the page
   needs a query parameter or a redirect.

For switching: a plain reload (loses unsaved edits) or posting the current
YAML along with the choice.

## Decision

Option 3, with the YAML posted along on a switch.

- Supported locales: English (default) and German, as a `Locale` type in
  `web/i18n`. All UI text lives in one `Texts` record with one constant per
  locale, so a missing translation is a compile error. Parameterised
  messages are functions.
- The server resolves the locale per request: a `lang` query or form field,
  then the `x-yaml2cv-lang` header, then `Accept-Language` (highest-weighted
  supported language), then English. HTML responses send
  `vary: accept-language, x-yaml2cv-lang`.
- The shell renders `<html lang>` and `hx-headers` with `x-yaml2cv-lang` on
  `<body>`, so every htmx request carries the page's locale without script.
- An **EN | DE** segmented switch sits in the header next to the theme
  switch. Its buttons submit the editor form to `POST /` with `lang`, so the
  editor comes back in the new language with the current YAML; this works
  without JavaScript. The editor returns in YAML mode.
- `language.js`, loaded in `<head>`, stores the choice in `localStorage`
  (key `yaml2cv-language`). On a fresh `GET /` whose language differs from
  the stored one it replaces the location with `/?lang=<code>`.
- Decoder schema errors carry a structured `SchemaProblem` instead of a
  message string; the API renders it with the existing English texts, the UI
  translates it. YAML syntax messages come from the parser and stay English;
  their location is translated.
- The schema reference is translated; key names and option values are not.

## Consequences

- No cookies; the server stays stateless.
- With a stored language that differs from the browser's, the first visit to
  `/` loads twice.
- Adding a language means one `Texts` constant and one `Locale` constructor.
- Adding a UI string means adding it to every locale.
