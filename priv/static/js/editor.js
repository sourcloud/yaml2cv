// Editor enhancements.
//
// - Textareas marked with `data-tab-indent`: Tab inserts spaces instead of
//   moving focus. Press Escape first to let the next Tab leave the field, so
//   keyboard users are never trapped.
// - Line-number gutters (`data-gutter-for`, ADR 0021) follow the line count
//   and scroll position of their textarea.
// - Buttons with `data-jump-field`, `data-jump-line` and `data-jump-column`
//   move the cursor to that 1-based position in the field.
(() => {
  "use strict";

  let escaped = false;

  document.addEventListener("keydown", (event) => {
    const field = event.target;
    if (!(field instanceof HTMLTextAreaElement) || !field.dataset.tabIndent) {
      return;
    }
    if (event.key === "Escape") {
      escaped = true;
      return;
    }
    if (event.key !== "Tab" || event.shiftKey || escaped) {
      escaped = false;
      return;
    }
    event.preventDefault();
    const indent = " ".repeat(Number(field.dataset.tabIndent) || 2);
    // execCommand keeps the browser's undo history intact.
    if (!document.execCommand("insertText", false, indent)) {
      field.setRangeText(indent, field.selectionStart, field.selectionEnd, "end");
      field.dispatchEvent(new Event("input", { bubbles: true }));
    }
  });

  const gutterOf = (field) =>
    field instanceof HTMLTextAreaElement && field.id
      ? document.querySelector(`[data-gutter-for="${CSS.escape(field.id)}"]`)
      : null;

  const renumber = (field, gutter) => {
    const count = field.value.split("\n").length;
    if (Number(gutter.dataset.lines) !== count) {
      gutter.dataset.lines = String(count);
      gutter.textContent = Array.from({ length: count }, (_, i) => i + 1).join("\n");
      gutter.parentElement.style.setProperty(
        "--gutter-digits",
        String(Math.max(3, String(count).length)),
      );
    }
    gutter.scrollTop = field.scrollTop;
  };

  const sync = (event) => {
    const gutter = gutterOf(event.target);
    if (gutter) renumber(event.target, gutter);
  };

  document.addEventListener("input", sync);
  // Scroll events do not bubble; listen in the capture phase instead.
  document.addEventListener("scroll", sync, true);

  for (const gutter of document.querySelectorAll("[data-gutter-for]")) {
    const field = document.getElementById(gutter.dataset.gutterFor);
    if (field instanceof HTMLTextAreaElement) renumber(field, gutter);
  }

  document.addEventListener("click", (event) => {
    const button = event.target.closest?.("[data-jump-field]");
    if (!button) return;
    const field = document.getElementById(button.dataset.jumpField);
    if (!(field instanceof HTMLTextAreaElement)) return;
    const lines = field.value.split("\n");
    const line = Math.min(Math.max(Number(button.dataset.jumpLine) || 1, 1), lines.length);
    const column = Math.max(Number(button.dataset.jumpColumn) || 1, 1);
    let offset = 0;
    for (let i = 0; i < line - 1; i++) offset += lines[i].length + 1;
    offset += Math.min(column - 1, lines[line - 1].length);
    field.focus();
    field.setSelectionRange(offset, offset);
    // Show the line about a third down the field rather than at its edge.
    const lineHeight = parseFloat(getComputedStyle(field).lineHeight) || 20;
    field.scrollTop = Math.max(0, (line - 1) * lineHeight - field.clientHeight / 3);
    const gutter = gutterOf(field);
    if (gutter) gutter.scrollTop = field.scrollTop;
  });
})();
