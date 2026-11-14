// Records the README demo (ADR 0044): drives the editor of a running
// yaml2cv instance through its main interactions and saves a video.
//
//   node record.mjs [base-url] [out-dir]
//
// The video is converted to docs/demo.gif by `just demo-gif`.

import { chromium } from "playwright";
import { mkdir, readdir, rename, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";

const baseUrl = process.argv[2] ?? "http://localhost:8000";
const outDir = process.argv[3] ?? "build/demo";
const size = { width: 1280, height: 720 };

// A visible pointer: headless recordings do not show the mouse.
const pointerScript = () => {
  addEventListener("DOMContentLoaded", () => {
    const dot = document.createElement("div");
    Object.assign(dot.style, {
      position: "fixed",
      left: "0",
      top: "0",
      width: "18px",
      height: "18px",
      margin: "-9px 0 0 -9px",
      borderRadius: "50%",
      background: "rgba(220, 38, 38, 0.55)",
      border: "2px solid rgba(255, 255, 255, 0.9)",
      boxShadow: "0 0 0 1px rgba(0, 0, 0, 0.25)",
      pointerEvents: "none",
      zIndex: "2147483647",
      transition: "transform 120ms",
      transform: "translate(-100px, -100px)",
    });
    document.body.append(dot);
    let x = -100;
    let y = -100;
    const place = (scale) =>
      (dot.style.transform = `translate(${x}px, ${y}px) scale(${scale})`);
    addEventListener("mousemove", (event) => {
      x = event.clientX;
      y = event.clientY;
      place(1);
    }, true);
    addEventListener("mousedown", () => place(0.7), true);
    addEventListener("mouseup", () => place(1), true);
  });
};

// An illustrated stand-in portrait, so the demo needs no photo of a real
// person.
const portrait = `
<svg xmlns="http://www.w3.org/2000/svg" width="600" height="800" viewBox="0 0 600 800">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#dbe4ee"/>
      <stop offset="1" stop-color="#9fb3c8"/>
    </linearGradient>
    <linearGradient id="coat" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#3b4a5c"/>
      <stop offset="1" stop-color="#253140"/>
    </linearGradient>
  </defs>
  <rect width="600" height="800" fill="url(#bg)"/>
  <path d="M60 800 C70 610 170 540 300 540 C430 540 530 610 540 800 Z" fill="url(#coat)"/>
  <path d="M255 545 L300 640 L345 545 Z" fill="#f4f1ec"/>
  <rect x="262" y="440" width="76" height="110" rx="30" fill="#d9a77f"/>
  <ellipse cx="300" cy="340" rx="118" ry="140" fill="#e8b994"/>
  <path d="M182 330 C175 200 250 170 310 172 C390 175 432 230 418 330
           C405 270 370 240 300 238 C235 240 195 270 182 330 Z" fill="#4a3426"/>
  <ellipse cx="258" cy="345" rx="10" ry="12" fill="#3a2a20"/>
  <ellipse cx="342" cy="345" rx="10" ry="12" fill="#3a2a20"/>
  <path d="M262 412 Q300 438 338 412" stroke="#9a5b45" stroke-width="7"
        fill="none" stroke-linecap="round"/>
</svg>`;

async function writePortrait(browser, path) {
  const page = await browser.newPage({ viewport: { width: 600, height: 800 } });
  await page.setContent(
    `<body style="margin:0">${portrait}</body>`,
  );
  await writeFile(path, await page.screenshot({ type: "jpeg", quality: 90 }));
  await page.close();
}

// Scrolls the element into view with visible wheel steps. The pointer must
// already be over the scrolling container.
async function scrollTo(page, locator) {
  for (let i = 0; i < 40; i++) {
    const box = await locator.boundingBox();
    if (box.y < 160) await page.mouse.wheel(0, -60);
    else if (box.y + box.height > size.height - 120) {
      await page.mouse.wheel(0, 60);
    } else break;
    await page.waitForTimeout(40);
  }
  await page.waitForTimeout(300);
}

const pause = (page, ms) => page.waitForTimeout(ms);

// Moves the pointer to the centre of an element in visible steps.
async function pointAt(page, locator) {
  const box = await locator.boundingBox();
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2, {
    steps: 20,
  });
  await pause(page, 250);
}

async function click(page, locator) {
  await pointAt(page, locator);
  await locator.click();
}

// Waits until the preview request triggered by the last edit has finished.
async function settle(page) {
  await page.waitForLoadState("networkidle");
  await pause(page, 400);
}

// Selects `text` inside the YAML textarea, as a double-click would.
async function selectInYaml(page, text) {
  const yaml = page.locator("#cv");
  await pointAt(page, yaml);
  await yaml.evaluate((area, needle) => {
    const start = area.value.indexOf(needle);
    area.focus();
    area.setSelectionRange(start, start + needle.length);
  }, text);
  await pause(page, 500);
}

async function typeSlowly(page, text) {
  await page.keyboard.type(text, { delay: 90 });
}

async function main() {
  await rm(outDir, { recursive: true, force: true });
  await mkdir(outDir, { recursive: true });

  const browser = await chromium.launch();
  const photo = join(outDir, "photo.jpg");
  await writePortrait(browser, photo);
  const context = await browser.newContext({
    viewport: size,
    locale: "en-GB",
    colorScheme: "dark",
    acceptDownloads: true,
    recordVideo: { dir: outDir, size },
  });
  await context.addInitScript(pointerScript);
  const page = await context.newPage();

  await page.goto(baseUrl);
  await settle(page);
  await page.mouse.move(640, 400);
  await pause(page, 1500);

  // 1. Edit the YAML: the preview follows.
  await selectInYaml(page, "My personal CV");
  await typeSlowly(page, "Software Engineer");
  await settle(page);
  await pause(page, 1200);

  // 2. A mistake is reported while typing.
  await selectInYaml(page, "blue");
  await typeSlowly(page, "teal");
  await settle(page);
  await pointAt(page, page.locator("#validation"));
  await pause(page, 2200);

  // 3. Autocomplete (ADR 0045) fixes it: Ctrl+Space lists the allowed
  // colours with an explanation; typing narrows the list, Enter inserts.
  await selectInYaml(page, "teal");
  await page.keyboard.press("Backspace");
  await pause(page, 400);
  await page.keyboard.press("Control+Space");
  await pause(page, 1800);
  await typeSlowly(page, "gr");
  await pause(page, 1000);
  await page.keyboard.press("Enter");
  await settle(page);
  await pause(page, 1000);

  // A new key: Enter keeps the indentation, typing offers the keys still
  // missing, and choosing one opens its values.
  // The cursor is still after the inserted value.
  await page.keyboard.press("Enter");
  await typeSlowly(page, "ph");
  await pause(page, 1600);
  await page.keyboard.press("Enter");
  await pause(page, 1200);
  for (let i = 0; i < 2; i++) {
    await page.keyboard.press("ArrowDown");
    await pause(page, 450);
  }
  await pause(page, 600);
  await page.keyboard.press("Enter");
  await settle(page);
  await pause(page, 1500);

  // 4. Visual mode: the same CV as blocks.
  await click(page, page.locator('[data-mode-switch="visual"]'));
  await settle(page);
  await pause(page, 1200);
  const theme = page.locator('select[name="style.theme"]');
  await click(page, theme);
  await theme.selectOption("studio");
  await settle(page);
  await pause(page, 1800);

  // 5. Add a photo: the studio theme shows it instead of the initials,
  // cropped to the circle chosen above.
  const choose = page.locator("[data-photo-choose]");
  await scrollTo(page, choose);
  const chooser = page.waitForEvent("filechooser");
  await click(page, choose);
  await (await chooser).setFiles(photo);
  await settle(page);
  await pause(page, 2000);

  const color = page.locator('select[name="style.color"]');
  await scrollTo(page, color);
  await click(page, color);
  await color.selectOption("burgundy");
  await settle(page);
  await pause(page, 1800);

  // 6. Download the PDF.
  const download = page.waitForEvent("download");
  await click(page, page.getByRole("button", { name: "Download PDF" }));
  await download;
  await pause(page, 1500);

  await context.close();
  await browser.close();

  const [video] = (await readdir(outDir)).filter((f) => f.endsWith(".webm"));
  await rename(join(outDir, video), join(outDir, "demo.webm"));
  console.log(join(outDir, "demo.webm"));
}

await main();
