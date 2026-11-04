import { assert, assertEquals } from "jsr:@std/assert@1";
import { cleanChatReply, shorten } from "../_shared/validate.ts";
import type { ChatReply } from "../_shared/schemas.ts";

const base: ChatReply = {
  safety: "ok",
  reply: "Master, I did not eat the pill. It fell into my mouth.",
  expression: "nervous",
  mood_change: -1,
  memory: "Master asked about the missing pill.",
  wants_action: "hide",
};

Deno.test("a normal reply passes through", () => {
  const result = cleanChatReply(base);
  assert(result.ok);
  assertEquals(result.value.reply, base.reply);
  assertEquals(result.value.mood_change, -1);
  assertEquals(result.value.wants_action, "hide");
});

Deno.test("mood changes are clamped to -2..2", () => {
  for (const [given, expected] of [[9, 2], [-50, -2], [1.6, 2], [0, 0]]) {
    const result = cleanChatReply({ ...base, mood_change: given });
    assert(result.ok);
    assertEquals(result.value.mood_change, expected);
  }
});

Deno.test("empty and over-long replies are rejected", () => {
  assertEquals(cleanChatReply({ ...base, reply: "   " }).ok, false);
  assertEquals(cleanChatReply({ ...base, reply: "x".repeat(601) }).ok, false);
});

Deno.test("memories are trimmed to 120 characters and blanks become null", () => {
  const long = cleanChatReply({ ...base, memory: "word ".repeat(60) });
  assert(long.ok);
  assert(Array.from(long.value.memory ?? "").length <= 120);
  const blank = cleanChatReply({ ...base, memory: "  " });
  assert(blank.ok);
  assertEquals(blank.value.memory, null);
});

Deno.test("unknown actions are dropped", () => {
  // The schema already limits actions; this guards against a schema drift.
  const result = cleanChatReply({
    ...base,
    wants_action: "fly_to_moon" as ChatReply["wants_action"],
  });
  assert(result.ok);
  assertEquals(result.value.wants_action, null);
});

Deno.test("a distress reply never changes mood or stores a memory", () => {
  const result = cleanChatReply({
    ...base,
    safety: "distress",
    mood_change: 2,
    memory: "Master is sad",
    wants_action: "rest",
  });
  assert(result.ok);
  assertEquals(result.value.safety, "distress");
  assertEquals(result.value.mood_change, 0);
  assertEquals(result.value.memory, null);
  assertEquals(result.value.wants_action, null);
});

Deno.test("a boundary reply keeps its line but never changes mood or stores a memory", () => {
  const result = cleanChatReply({
    ...base,
    safety: "boundary",
    mood_change: 1,
    memory: "Master asked me on a date",
    wants_action: "hide",
  });
  assert(result.ok);
  assertEquals(result.value.safety, "boundary");
  assertEquals(result.value.mood_change, 0);
  assertEquals(result.value.memory, null);
  assertEquals(result.value.wants_action, "hide");
});

Deno.test("shorten counts Vietnamese letters as single characters", () => {
  const text = "Sư phụ khen bánh bao của đệ tử ngon nhất núi";
  assertEquals(shorten(text, 100), text);
  const cut = shorten(text, 20);
  assert(Array.from(cut).length <= 20);
  assert(cut.endsWith("…"));
});
