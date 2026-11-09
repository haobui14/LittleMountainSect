// Plays the exported web build for 10 in-game days in headless Chromium,
// at phone size (390x844) and desktop size (1280x720), by clicking the
// controls the game publishes in window.lmsUi (see game/autoload/ui_probe.gd).
// Each morning it picks the first choice it can afford in a surprise event,
// takes in a hopeful at the gate when it can (or sends them home), and in
// the plan has two disciples train and sends the first one ready to break
// through. Takes a
// screenshot of each screen and fails on any page error.
//
// Usage: node tools/web-check/play_check.cjs <url> <screenshots-dir> [days] [--offline]
// Serve build/web first, for example on port 8060. With --offline every
// request to Supabase fails, so the whole game must run on written text
// (Gate 2: playable with the server off). Without it the game talks to the
// project in game/config/backend.json, which costs Spirit Energy.

const { chromium } = require("playwright");

const args = process.argv.slice(2).filter((a) => !a.startsWith("--"));
const OFFLINE = process.argv.includes("--offline");
const [url, shots, daysArg] = args;
const DAYS = Number(daysArg || 10);
const SIZES = [
  { name: "phone", viewport: { width: 390, height: 844 } },
  { name: "desktop", viewport: { width: 1280, height: 720 } },
];

async function play(browser, size) {
  const context = await browser.newContext({ viewport: size.viewport, deviceScaleFactor: 1 });
  const page = await context.newPage();
  if (OFFLINE) await page.route(/supabase\.co/, (route) => route.abort("internetdisconnected"));
  const errors = [];
  // Offline, the browser and Godot's fetch wrapper report each blocked
  // request ("Failed to fetch"); the game treats them as no connection.
  const expected = (text) =>
    OFFLINE && /Failed to fetch|Failed to load resource|net::ERR/.test(text);
  page.on("pageerror", (e) => {
    if (!expected(e.message)) errors.push(e.message);
  });
  page.on("console", (m) => {
    if (m.type() === "error" && !expected(m.text())) errors.push(m.text());
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
  // Clicks a published control, scrolling the game's list until it is on
  // screen and waiting until it has stopped moving (cards pop in).
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
    const where = (s) =>
      s?.items[id] && ["x", "y", "w", "h"].map((k) => Math.round(s.items[id][k])).join();
    for (let i = 0, last = where(state); i < 20; i++) {
      await page.waitForTimeout(120);
      state = await ui();
      const now = where(state);
      if (now === last) break;
      last = now;
    }
    if (!state.items[id]) throw new Error(`${size.name}: "${id}" went away`);
    const item = state.items[id];
    if (item.disabled) throw new Error(`${size.name}: "${id}" is disabled`);
    await page.mouse.click(item.x + item.w / 2, item.y + item.h / 2);
    await page.waitForTimeout(250);
  };
  const shot = (label) => page.screenshot({ path: `${shots}/${size.name}_${label}.png` });
  const counts = { events: 0, recruited: 0, declined: 0, breakthroughs: 0 };

  // The morning's surprise event and hopeful, before the day can be planned.
  const morning = async (day) => {
    const state = await ui();
    if (state.event) {
      const choice = Object.keys(state.items).find(
        (id) => id.startsWith("event_") && !state.items[id].disabled,
      );
      if (!choice) throw new Error(`${size.name}: no choice can be picked in day ${day}'s event`);
      if (counts.events === 0) await shot(`1_event_day${day}`);
      await click(choice);
      await waitFor((s) => !s.event, "the event's result");
      if (counts.events === 0) await shot(`1_event_result_day${day}`);
      counts.events++;
    }
    if ((await ui()).candidate) {
      if (counts.recruited + counts.declined === 0) await shot(`1_hopeful_day${day}`);
      const accept = (await ui()).items.recruit_accept;
      const welcome = accept && !accept.disabled;
      await click(welcome ? "recruit_accept" : "recruit_decline");
      await waitFor((s) => !s.candidate, "the hopeful's answer");
      counts[welcome ? "recruited" : "declined"]++;
    }
  };

  // Types a chat line into the open chat and waits for the reply.
  const chat = async (message, label) => {
    const before = (await ui()).chat_lines;
    await click("chat_input");
    await page.keyboard.type(message, { delay: 10 });
    await page.keyboard.press("Enter");
    await waitFor((s) => s.chat_lines >= before + 2 && s.waiting === 0, "a chat reply", 30000);
    await shot(label);
    await click("chat_back");
  };

  await page.goto(url);
  await waitFor((s) => s.items.new_game || s.items.age_check, "the first screen", 60000);
  if ((await ui()).items.age_check) {
    await shot("0_first_launch");
    await click("age_check");
    await click("first_start");
  }
  await waitFor((s) => s.items.new_game, "the title screen");
  await shot("0_title");
  await click("new_game");
  await waitFor((s) => s.screen === "morning" && s.day === 1, "day 1 morning");
  await shot("1_morning");

  for (let day = 1; day <= DAYS; day++) {
    await waitFor((s) => s.screen === "morning" && s.day === day, `morning of day ${day}`);
    await morning(day);
    await click("plan_day");
    await waitFor((s) => s.screen === "plan", "the day plan");
    // From day 2, two disciples train, so someone is ready to break through
    // within a 30-day run.
    for (const id of day > 1 ? ["choose_d1_train", "choose_d2_train"] : []) {
      const item = (await ui()).items[id];
      if (item && !item.pressed) await click(id);
    }
    const ready = Object.keys((await ui()).items).find((id) => id.endsWith("_breakthrough"));
    if (ready) {
      await click(ready);
      await waitFor((s) => s.items[ready]?.pressed, "the breakthrough choice");
      if (counts.breakthroughs === 0) await shot(`4_breakthrough_day${day}`);
      counts.breakthroughs++;
    }
    if (day === 1) {
      // Build the Spirit Field, look at both tabs, and send a pair to gather herbs.
      await click("tab_mountain");
      await waitFor((s) => s.items.plot_spirit_field, "the mountain");
      await shot("2_mountain");
      await click("plot_spirit_field");
      await click("upgrade_spirit_field");
      await page.waitForTimeout(500);
      await shot("2_mountain_upgraded");
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
      await click("chat_d3");
      await chat("Xin chào! Hôm nay con thế nào?", "5_chat");
      await shot("5_free_time");
    }
    if (day === 2) {
      await click("chat_elder");
      await chat("What should I build first?", "5_elder");
    }
    await click("end_day");
    await waitFor((s) => s.screen === "results" && s.evening === "done", "the evening", 70000);
    if (day === 1 || day === DAYS) await shot(`6_evening_day${day}`);
    await click("next_morning");
  }
  const final = await waitFor((s) => s.screen === "morning", "the last morning");
  await shot("7_after");
  await context.close();
  return { size: size.name, reachedDay: final.day, errors, counts };
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
      const c = result.counts;
      console.log(
        `${ok ? "ok  " : "FAIL"} ${size.name}: played to day ${result.reachedDay}` +
          ` (${c.events} events, ${c.recruited} recruited, ${c.declined} sent home,` +
          ` ${c.breakthroughs} breakthroughs tried)` +
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
