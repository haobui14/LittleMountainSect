import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  cleanChatReply,
  cleanEveningReply,
  cleanEventReply,
  shorten,
} from "../_shared/validate.ts";
import {
  type ChatReply,
  type EveningReply,
  EveningRequestSchema,
  EventRequestSchema,
} from "../_shared/schemas.ts";

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

// Evening stories ------------------------------------------------------------------

const eveningRequest = EveningRequestSchema.parse({
  kind: "evening",
  locale: "en",
  game_day: 2,
  sect: { rank: "unknown_mountain", resources: { stones: 1, food: 1, herbs: 0, reputation: 0 } },
  disciples: ["a", "b", "c"].map((id, i) => ({
    card: {
      id,
      name: `Name ${id}`,
      pronouns: "they",
      quirks: ["gossip"],
      spirit_root: "fire",
      realm: "qi_refining",
      mood: 0,
      loyalty: 50,
    },
    allowed_actions: i === 2 ? [] : ["train", "rest"],
  })),
  facts: [],
});

const evening = (overrides: Partial<EveningReply> = {}): EveningReply => ({
  story: "A day.",
  morning_report: "Tomorrow!",
  decisions: [],
  memories: [],
  relationship_changes: [],
  ...overrides,
});

Deno.test("evening decisions keep only allowed actions, one per disciple, at most two", () => {
  const result = cleanEveningReply(
    evening({
      decisions: [
        { disciple_id: "a", action: "cook", reason: "not allowed" },
        { disciple_id: "a", action: "rest", reason: "tired" },
        { disciple_id: "a", action: "train", reason: "second for a" },
        { disciple_id: "c", action: "rest", reason: "away" },
        { disciple_id: "ghost", action: "rest", reason: "not in the sect" },
        { disciple_id: "b", action: "train", reason: "keen" },
      ],
    }),
    eveningRequest,
  );
  assert(result.ok);
  assertEquals(result.value.decisions.map((d) => [d.disciple_id, d.action]), [["a", "rest"], [
    "b",
    "train",
  ]]);
});

Deno.test("relationship changes are clamped, deduplicated and limited", () => {
  const result = cleanEveningReply(
    evening({
      relationship_changes: [
        { from: "a", to: "b", change: 7, reason: "big" },
        { from: "b", to: "a", change: -1, reason: "same pair again" },
        { from: "a", to: "a", change: 1, reason: "self" },
        { from: "a", to: "ghost", change: 1, reason: "unknown" },
        { from: "b", to: "c", change: 0, reason: "no change" },
        { from: "a", to: "c", change: -3, reason: "spat" },
      ],
    }),
    eveningRequest,
  );
  assert(result.ok);
  assertEquals(result.value.relationship_changes.map((r) => [r.from, r.to, r.change]), [
    ["a", "b", 2],
    ["a", "c", -2],
  ]);
});

Deno.test("evening memories: one per known disciple, shortened", () => {
  const result = cleanEveningReply(
    evening({
      memories: [
        { disciple_id: "a", text: "x".repeat(300) },
        { disciple_id: "a", text: "second" },
        { disciple_id: "ghost", text: "unknown" },
        { disciple_id: "b", text: "  " },
      ],
    }),
    eveningRequest,
  );
  assert(result.ok);
  assertEquals(result.value.memories.length, 1);
  assert(Array.from(result.value.memories[0].text).length <= 120);
});

Deno.test("an empty story or morning report is rejected", () => {
  assertEquals(cleanEveningReply(evening({ story: " " }), eveningRequest).ok, false);
  assertEquals(cleanEveningReply(evening({ morning_report: "" }), eveningRequest).ok, false);
});

// Surprise events -------------------------------------------------------------------

const eventRequest = EventRequestSchema.parse({
  kind: "event",
  locale: "en",
  game_day: 5,
  problem: "broken_sword",
  place: "training_yard",
  disciples: [eveningRequest.disciples[0].card, eveningRequest.disciples[1].card],
});

Deno.test("an event reply keeps every catalog choice, in the catalog's order", () => {
  const result = cleanEventReply({
    title: "  The Snapped Sword ",
    story: "It went 'ping'.",
    choices: [
      { id: "use_broom", text: "Train with a broom" },
      { id: "made_up", text: "Fly away" },
      { id: "buy_new", text: "Buy a shiny new sword" },
      { id: "glue_it", text: "x".repeat(300) },
      { id: "buy_new", text: "A second answer is ignored" },
    ],
  }, eventRequest);
  assert(result.ok);
  assertEquals(result.value.title, "The Snapped Sword");
  assertEquals(result.value.choices.map((c) => c.id), ["buy_new", "glue_it", "use_broom"]);
  assertEquals(result.value.choices[0].text, "Buy a shiny new sword");
  assertEquals(Array.from(result.value.choices[1].text).length, 120);
});

Deno.test("an event reply missing a choice or its words is rejected", () => {
  const reply = {
    title: "T",
    story: "S",
    choices: [{ id: "buy_new", text: "a" }, { id: "glue_it", text: "b" }],
  };
  assertEquals(cleanEventReply(reply, eventRequest).ok, false);
  assertEquals(
    cleanEventReply(
      { ...reply, choices: [...reply.choices, { id: "use_broom", text: " " }] },
      eventRequest,
    )
      .ok,
    false,
  );
  assertEquals(cleanEventReply({ ...reply, title: "" }, eventRequest).ok, false);
});

Deno.test("an event request must name as many disciples as its problem needs", () => {
  const two = [eveningRequest.disciples[0].card, eveningRequest.disciples[1].card];
  const base = { kind: "event", locale: "vi", game_day: 2, place: "mountain_path" };
  assertEquals(
    EventRequestSchema.safeParse({ ...base, problem: "rescue", disciples: two }).success,
    false,
  );
  assertEquals(
    EventRequestSchema.safeParse({ ...base, problem: "rescue", disciples: [two[0]] }).success,
    true,
  );
  assertEquals(
    EventRequestSchema.safeParse({ ...base, problem: "frog_duel", disciples: [two[0]] }).success,
    false,
  );
  assertEquals(
    EventRequestSchema.safeParse({ ...base, problem: "frog_duel", place: "moon", disciples: two })
      .success,
    false,
  );
});
