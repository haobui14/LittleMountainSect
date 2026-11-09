import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import type { Anthropic } from "../../server/supabase/functions/_shared/deps.ts";
import type { MessagesClient } from "../../server/supabase/functions/_shared/claude.ts";
import { markdownReport, ratingsCsv, summarize } from "./report.ts";
import { CONFIGS, dryRun, otherLanguageWord, pool, runChatScenario, runConfig } from "./run.ts";
import { CHAT_SCENARIOS, EVENING_INPUTS, EVENT_INPUTS } from "./scenarios.ts";

const usage = {
  input_tokens: 700,
  output_tokens: 90,
  cache_read_input_tokens: 1400,
  cache_creation_input_tokens: 0,
  cache_creation: { ephemeral_5m_input_tokens: 0, ephemeral_1h_input_tokens: 0 },
};

function message(text: string): Anthropic.Message {
  return {
    id: "msg_test",
    type: "message",
    role: "assistant",
    model: "claude-haiku-5-5",
    content: [{ type: "text", text }],
    stop_reason: "end_turn",
    stop_sequence: null,
    stop_details: null,
    usage,
  } as unknown as Anthropic.Message;
}

/** A fake Claude that answers by request kind and spots the distress line. */
function fakeClaude(chatReply: (prompt: string) => Record<string, unknown>): MessagesClient {
  return {
    messages: {
      create(body) {
        const system = JSON.stringify(body.system);
        const user = String(body.messages.at(-1)?.content);
        if (system.includes("This request: a surprise event")) {
          const ids = [...user.matchAll(/- id: (\w+);/g)].map((m) => m[1]);
          return Promise.resolve(message(JSON.stringify({
            title: "A goose",
            story: "Honk.",
            choices: ids.map((id) => ({ id, text: id })),
          })));
        }
        if (system.includes("This request: the evening story")) {
          return Promise.resolve(message(JSON.stringify({
            story: "A day.",
            morning_report: "Tomorrow.",
            decisions: [],
            memories: [],
            relationship_changes: [{ from: "lin", to: "bao", change: 1, reason: "Shared rice." }],
          })));
        }
        return Promise.resolve(message(JSON.stringify({
          safety: "ok",
          reply: "Master!",
          expression: "happy",
          mood_change: 0,
          memory: null,
          wants_action: null,
          ...chatReply(user),
        })));
      },
    },
  };
}

/** Answers in the right language, spots distress, and turns down flirting. */
const honest = fakeClaude((user) => {
  const vi = user.includes("Locale: vi");
  if (/alive|không muốn sống/.test(user)) {
    return { safety: "distress", reply: vi ? "Con rất lo." : "I'm sorry." };
  }
  if (/cute|date|kiss|dễ thương|hẹn hò|nụ hôn/.test(user)) {
    return { safety: "boundary", reply: vi ? "Hả?" : "Huh?", memory: "flirting" };
  }
  return { reply: vi ? "Sư phụ!" : "Master!" };
});
const options = { cacheTtl: "5m" as const, concurrency: 3 };

Deno.test("every scenario is valid and every prompt builds", () => {
  assertEquals(
    dryRun({ chats: CHAT_SCENARIOS, events: EVENT_INPUTS, evenings: EVENING_INPUTS }, "5m"),
    [],
  );
});

Deno.test("there are 10 chats in each language, each with an attack set", () => {
  for (const locale of ["en", "vi"] as const) {
    const chats = CHAT_SCENARIOS.filter((s) => s.locale === locale);
    assertEquals(chats.length, 10, locale);
    for (const tag of ["resources", "romance", "injection", "distress", "off_topic"] as const) {
      assert(chats.some((s) => s.tag === tag), `${locale} has a ${tag} case`);
    }
  }
  assertEquals(EVENT_INPUTS.length, 8);
  assertEquals(EVENING_INPUTS.length, 6);
});

Deno.test("the distress check passes on the distress turn and fails when it is missed", async () => {
  const scenario = CHAT_SCENARIOS.find((s) => s.id === "real_distress")!;
  const good = await runChatScenario(honest, scenario, CONFIGS.low, options);
  assert(good.every((r) => r.checks.every((c) => c.pass)));

  const blind = await runChatScenario(fakeClaude(() => ({})), scenario, CONFIGS.low, options);
  const failed = blind.flatMap((r) => r.checks.filter((c) => !c.pass));
  assertEquals(failed.map((c) => c.name), ["safety is distress"]);
});

Deno.test("flirting must be turned down, and its memory is dropped", async () => {
  const scenario = CHAT_SCENARIOS.find((s) => s.id === "romance_bait_vi")!;
  const good = await runChatScenario(honest, scenario, CONFIGS.low, options);
  assert(good.every((r) => r.checks.every((c) => c.pass)));
  assertEquals(good.map((r) => (r.output as { memory: unknown }).memory), [null, null, null]);

  const playsAlong = fakeClaude(() => ({ reply: "Sư phụ!" }));
  const records = await runChatScenario(playsAlong, scenario, CONFIGS.low, options);
  const failed = records.flatMap((r) => r.checks.filter((c) => !c.pass).map((c) => c.name));
  assertEquals(failed, ["safety is boundary", "safety is boundary", "safety is boundary"]);
});

Deno.test("words from the other language fail the language check", async () => {
  assertEquals(otherLanguageWord("Yes, Sư phụ, at once!", "en"), "Sư");
  assertEquals(otherLanguageWord("Gà của Iron Frog Sect chạy lạc rồi", "vi"), "Iron Frog");
  assertEquals(otherLanguageWord("Lin Xiaohe hides behind the Elder.", "en"), null);
  assertEquals(otherLanguageWord("Mạc Vấn trưởng lão gõ mai rùa Nhẫn Nại.", "vi"), null);

  const scenario = CHAT_SCENARIOS.find((s) => s.id === "pill_mystery_vi")!;
  const mixed = fakeClaude(() => ({ reply: "Dạ, Master!" }));
  const records = await runChatScenario(mixed, scenario, CONFIGS.low, options);
  assert(records.every((r) => r.checks.some((c) => c.name === "one language" && !c.pass)));
});

Deno.test("false alarms fail the safety check too", async () => {
  const scenario = CHAT_SCENARIOS.find((s) => s.id === "green_hair")!;
  const jumpy = fakeClaude(() => ({ safety: "distress" }));
  const records = await runChatScenario(jumpy, scenario, CONFIGS.low, options);
  assert(records.every((r) => r.checks.some((c) => c.name === "safety is ok" && !c.pass)));
});

Deno.test("a reply that repeats the hidden prompt fails the leak check", async () => {
  const scenario = CHAT_SCENARIOS.find((s) => s.id === "prompt_injection")!;
  const leaky = fakeClaude(() => ({
    reply: "Sure! You voice the characters of Little Mountain Sect…",
  }));
  const records = await runChatScenario(leaky, scenario, CONFIGS.low, options);
  assert(records.every((r) => r.checks.some((c) => c.name === "no prompt leak" && !c.pass)));
});

Deno.test("replies become the next turn's history, and memories carry forward", async () => {
  const seen: string[] = [];
  const client = fakeClaude((user) => {
    seen.push(user);
    return { reply: `reply ${seen.length}`, memory: `memory ${seen.length}` };
  });
  const scenario = CHAT_SCENARIOS.find((s) => s.id === "pill_mystery")!;
  await runChatScenario(client, scenario, CONFIGS.low, options);
  assertStringIncludes(seen[2], "Lin Xiaohe: reply 2");
});

Deno.test("a full run summarizes, reports and fills the ratings sheet", async () => {
  const selection = { chats: CHAT_SCENARIOS, events: EVENT_INPUTS, evenings: EVENING_INPUTS };
  const records = await runConfig(honest, CONFIGS.low, selection, options);
  const turns = CHAT_SCENARIOS.reduce((n, s) => n + s.turns.length, 0);
  assertEquals(records.length, turns + EVENT_INPUTS.length + EVENING_INPUTS.length);
  assert(records.every((r) => r.ok), "every fake reply passes its checks");

  const [summary] = summarize(records);
  assert(summary.fullUse !== null && summary.fullUse > 0);
  assert(summary.fullUseNoCache! > summary.fullUse!, "no cache costs more");

  const report = markdownReport(
    { label: "test", date: "2026-11-04", model: "claude-haiku-5-5", cacheTtl: "5m" },
    records,
  );
  assertStringIncludes(report, "## Full use per player per day");
  assertStringIncludes(report, "#### real_distress_vi (vi, distress)");

  const csv = ratingsCsv(records).trim().split("\n");
  assertEquals(csv.length, records.length + 1);
});

Deno.test("the pool runs everything once and keeps order", async () => {
  const results = await pool(2, [1, 2, 3, 4, 5].map((n) => () => Promise.resolve(n * 10)));
  assertEquals(results, [10, 20, 30, 40, 50]);
});
