// Plays the exported web build for 10 in-game days in headless Chromium,
// at phone size (390x844) and desktop size (1280x720), by clicking the
// controls the game publishes in window.lmsUi (see game/autoload/ui_probe.gd).
// Takes a screenshot of each screen and fails on any page error.
//
// Usage: node tools/web-check/play_check.cjs <url> <screenshots-dir> [days]
// Serve build/web first, for example on port 8060.

const { chromium } = require("playwright");

const [url, shots, daysArg] = process.argv.slice(2);
const DAYS = Number(daysArg || 10);
const SIZES = [
  { name: "phone", viewport: { width: 390, height: 844 } },
  { name: "desktop", viewport: { width: 1280, height: 720 } },
];

async function play(browser, size) {
  const context = await browser.newContext({ viewport: size.viewport, deviceScaleFactor: 1 });
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  page.on("console", (m) => {
    if (m.type() === "error") errors.push(m.text());
  });

  const ui = () => page.evaluate(() => globalThis.lmsUi || null);
  const waitFor = async (check, what, timeout = 15000) => {
    const end = Date.now() + timeout;
    while (Date.now() < end) {
      const state = await ui();
      if (state && check(state)) return state;
      await page.waitForTimeout(100);
    }
    throw new Error(`${size.name}: timed out waiting for ${what}`);
  };
  // Clicks a published control, scrolling the game's list until it is on screen.
  const click = async (id) => {
    let state = await waitFor((s) => s.items[id], `"${id}"`);
    for (let i = 0; i < 20 && !state.items[id].on_screen; i++) {
      const item = state.items[id];
      const center = { x: size.viewport.width / 2, y: size.viewport.height / 2 };
      await page.mouse.move(center.x, center.y);
      await page.mouse.wheel(0, item.y > center.y ? 200 : -200);
      await page.waitForTimeout(350);
      state = await ui();
    }
    const item = state.items[id];
    if (item.disabled) throw new Error(`${size.name}: "${id}" is disabled`);
    await page.mouse.click(item.x + item.w / 2, item.y + item.h / 2);
    await page.waitForTimeout(250);
  };
  const shot = (label) => page.screenshot({ path: `${shots}/${size.name}_${label}.png` });

  await page.goto(url);
  await waitFor((s) => s.items.new_game, "the title screen", 60000);
  await shot("0_title");
  await click("new_game");
  await waitFor((s) => s.screen === "morning" && s.day === 1, "day 1 morning");
  await shot("1_morning");

  for (let day = 1; day <= DAYS; day++) {
    await waitFor((s) => s.screen === "morning" && s.day === day, `morning of day ${day}`);
    await click("plan_day");
    await waitFor((s) => s.screen === "plan", "the day plan");
    if (day === 1) {
      // Build the Spirit Field, look at both tabs, and send a pair to gather herbs.
      await click("tab_mountain");
      await waitFor((s) => s.items.upgrade_spirit_field, "the mountain");
      await shot("2_mountain");
      await click("upgrade_spirit_field");
      await click("tab_disciples");
      await page.waitForTimeout(300);
      await shot("3_disciples");
      await click("tab_today");
      await click("choose_d1_gather_herbs");
      await click("choose_d2_gather_herbs");
      await click("choose_d3_work");
      await waitFor((s) => s.items.choose_d2_gather_herbs?.pressed, "the team choice");
      await shot("4_plan");
    }
    await click("done_planning");
    await waitFor((s) => s.screen === "free_time", "free time");
    if (day === 1) {
      await click("talk_d3");
      await shot("5_free_time");
    }
    await click("end_day");
    await waitFor((s) => s.screen === "results", "the evening");
    if (day === 1 || day === DAYS) await shot(`6_evening_day${day}`);
    await click("next_morning");
  }
  const final = await waitFor((s) => s.screen === "morning", "the last morning");
  await shot("7_after");
  await context.close();
  return { size: size.name, reachedDay: final.day, errors };
}

(async () => {
  const browser = await chromium.launch({
    args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader"],
  });
  let failed = false;
  for (const size of SIZES) {
    try {
      const result = await play(browser, size);
      const ok = result.reachedDay === DAYS + 1 && result.errors.length === 0;
      failed ||= !ok;
      console.log(
        `${ok ? "ok  " : "FAIL"} ${size.name}: played to day ${result.reachedDay}` +
          (result.errors.length
            ? `, page errors: ${result.errors.join(" / ")}`
            : ", no page errors"),
      );
    } catch (error) {
      failed = true;
      console.log(`FAIL ${size.name}: ${error.message}`);
    }
  }
  await browser.close();
  process.exit(failed ? 1 : 0);
})();
