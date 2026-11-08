// Editor enhancements for textareas marked with `data-tab-indent`:
// Tab inserts spaces instead of moving focus. Press Escape first to let the
// next Tab leave the field, so keyboard users are never trapped.
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
})();
