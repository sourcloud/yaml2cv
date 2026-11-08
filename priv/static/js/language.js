// UI language switch (ADR 0025). The switch buttons submit a form, so they
// work without this script; it only remembers the choice in localStorage
// and brings it back on a fresh visit to the editor. Loaded synchronously
// in <head> so the redirect happens before anything is shown.
(() => {
  "use strict";

  const key = "yaml2cv-language";

  const stored = () => {
    try {
      return localStorage.getItem(key);
    } catch {
      return null; // storage blocked, e.g. by privacy settings
    }
  };

  const store = (code) => {
    try {
      localStorage.setItem(key, code);
    } catch {
      // Not persisted; the choice still applies to the page it posts.
    }
  };

  // A plain visit to the editor in a language other than the stored one:
  // ask the server for the stored language instead. Pages that name a
  // language in the URL are left alone, which also prevents a loop. After a
  // switch the posted page already is in the stored language.
  const wanted = stored();
  const page = new URL(location.href);
  if (
    wanted &&
    /^[a-z]{2}$/.test(wanted) &&
    wanted !== document.documentElement.lang &&
    page.pathname === "/" &&
    !page.searchParams.has("lang") &&
    performance.getEntriesByType("navigation")[0]?.type !== "back_forward"
  ) {
    page.searchParams.set("lang", wanted);
    location.replace(page);
    return;
  }

  document.addEventListener("click", (event) => {
    const choice = event.target.closest?.("[data-language-choice]");
    if (choice) store(choice.dataset.languageChoice);
  });
})();
