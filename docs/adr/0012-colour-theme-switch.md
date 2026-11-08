# 0012. Colour theme switch

- Status: Accepted
- Date: 2026-11-07

## Context

The design system (ADR 0011) follows the operating system's colour scheme
only. Users want to choose light or dark mode deliberately.

## Decision

- A three-state switch, **System / Light / Dark**, in the application header
  on every page. System is the default and follows `prefers-color-scheme`.
- The choice is stored in `localStorage` (key `yaml2cv-theme`); the server
  stays stateless and sets no cookies.
- The choice is applied as `data-theme="light|dark"` on `<html>`; System
  removes the attribute. A small external script in `<head>`, loaded without
  `defer`, applies it before the first paint so the page does not flash in
  the wrong theme (inline scripts are blocked by the CSP).
- Colour tokens are declared once with CSS `light-dark()`; `color-scheme` on
  `:root` decides which value applies (`light dark` by default, a single
  scheme when `data-theme` is set). No duplicated dark token block.
- The switch is a `ui-theme-switch` component (Gleam + CSS). It is rendered
  `hidden` and revealed by the script, so it never shows without JavaScript.

## Consequences

- Requires browsers with `light-dark()` support (all evergreen browsers
  since 2024).
- The preference is per browser, not per user account (there are none).
