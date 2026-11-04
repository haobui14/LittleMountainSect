// Typing test check for the M2 typing test screen (title screen > "Typing
// test"). See docs/playtests/typing-test.md. Needs Playwright with Chromium,
// and the web build served locally. Controls are found by name through
// window.lmsUi (game/autoload/ui_probe.gd).
//
// Usage: node tools/web-check/typing_check.cjs <url> <screenshots-dir>
const { chromium } = require("playwright");

(async () => {
  const [url, shots] = process.argv.slice(2);
  const browser = await chromium.launch({
    args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader"],
  });
  const page = await (await browser.newContext({
    locale: "en-US",
    viewport: { width: 1280, height: 720 },
    deviceScaleFactor: 1,
  })).newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  page.on("console", (m) => {
    if (m.type() === "error") errors.push(m.text());
  });

  // The center of a control the game published in window.lmsUi.
  const center = async (id) => {
    const handle = await page.waitForFunction(
      (name) => globalThis.lmsUi?.items?.[name],
      id,
      { timeout: 60000 },
    );
    const item = await handle.jsonValue();
    return [item.x + item.w / 2, item.y + item.h / 2];
  };

  await page.goto(url);
  await page.mouse.click(...await center("typing_test"));
  const [boxX, boxY] = await center("typing_box");
  const [toggleX, toggleY] = await center("browser_box");
  await page.waitForTimeout(500);
  await page.screenshot({ path: `${shots}/typing_0_start.png` });
  const report = () => page.evaluate(() => globalThis.lmsTypingReport || "(none)");
  const field = (r, name) => (r.split("\n").find((l) => l.startsWith(name + ":")) || "").trim();

  // 1. Godot's box, plain keys.
  await page.mouse.click(boxX, boxY);
  await page.keyboard.type("Chuong mon", { delay: 20 });
  await page.waitForTimeout(300);
  let r = await report();
  console.log(
    "godot/keys      ",
    field(r, "Box"),
    "|",
    field(r, "Text"),
    "|",
    field(r, "Combining marks"),
  );

  // 2. Godot's box, text committed the way input methods do (insertText, no key codes).
  await page.keyboard.insertText(" Chưởng môn");
  await page.waitForTimeout(300);
  r = await report();
  console.log(
    "godot/insertText",
    field(r, "Box"),
    "|",
    field(r, "Text"),
    "|",
    field(r, "Combining marks"),
  );
  await page.screenshot({ path: `${shots}/typing_1_godot.png` });

  // 3. Switch to the browser's own box and type there.
  await page.mouse.click(toggleX, toggleY);
  await page.waitForSelector("#lms-text-input", { timeout: 5000 });
  const box = await page.$eval("#lms-text-input", (el) => {
    const b = el.getBoundingClientRect();
    return { x: b.x, y: b.y, w: b.width, h: b.height, focused: document.activeElement === el };
  });
  console.log("browser box     ", JSON.stringify(box));
  await page.keyboard.type("Linh thach ", { delay: 20 });
  await page.keyboard.insertText("Trưởng lão");
  await page.waitForTimeout(300);
  r = await report();
  console.log(
    "browser/typed   ",
    field(r, "Box"),
    "|",
    field(r, "Text"),
    "|",
    field(r, "Combining marks"),
  );

  // 4. A decomposed sequence must be flagged.
  await page.fill("#lms-text-input", "Chửơng");
  await page.waitForTimeout(300);
  r = await report();
  console.log("browser/decomp  ", field(r, "Text").length, "chars |", field(r, "Combining marks"));
  await page.fill(
    "#lms-text-input",
    "Một hai ba bốn năm sáu bảy tám chín mười, mười một mười hai mười ba",
  );
  await page.waitForTimeout(500);
  const moved = await page.$eval(
    "#lms-text-input",
    (el) => Math.round(el.getBoundingClientRect().y),
  );
  console.log("overlay y       ", "before", Math.round(box.y), "after layout change", moved);
  await page.screenshot({ path: `${shots}/typing_2_browser.png` });

  // 5. Turning it off removes the element (short text first, so the layout is back).
  await page.fill("#lms-text-input", "x");
  await page.waitForTimeout(300);
  await page.mouse.click(toggleX, toggleY);
  await page.waitForTimeout(300);
  console.log(
    "after toggle off",
    await page.$("#lms-text-input") === null ? "input removed" : "input still present",
  );

  console.log("page errors     ", errors.length ? errors.join(" / ") : "none");
  await browser.close();
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
